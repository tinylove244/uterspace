package com.uterspace.dao;

import com.uterspace.model.Group;
import com.uterspace.model.GroupMember;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceException;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * GroupDAOImpl — Implementation của GroupDAO dùng JPA.
 *
 * member_count: mỗi thao tác thành viên chạy trong một transaction NGẮN (một câu INSERT/UPDATE/DELETE trên
 * group_members), commit xong mới đồng bộ lại số đếm bằng MỘT câu
 *     UPDATE groups_tbl SET member_count = (SELECT COUNT(*) ... status = 'ACTIVE')
 * trong transaction riêng (syncMemberCount). Không đọc số cũ về Java rồi ghi lại (mất lượt đếm khi hai người
 * vào cùng lúc), và cũng không giữ khóa hàng nhóm suốt nhiều câu lệnh: khi đó hàng chục request cùng nhóm
 * xếp hàng chờ một khóa, chiếm hết worker của SQL Server Express và treo cả nhóm (đã tái hiện khi test tải).
 * Số đếm luôn tự đúng vì lần đồng bộ sau cùng chạy sau khi mọi thay đổi đã commit.
 */
public class GroupDAOImpl implements GroupDAO {

    private static final String SEARCH =
        " AND (:q = '' OR LOWER(g.name) LIKE :like OR LOWER(g.description) LIKE :like) ";

    @Override
    public Group getGroupById(int groupId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.find(Group.class, groupId);
        } finally {
            em.close();
        }
    }

    @Override
    public GroupMember getMembership(int groupId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<GroupMember> r = em.createQuery(
                    "SELECT m FROM GroupMember m WHERE m.group.groupId = :gid AND m.user.userId = :uid",
                    GroupMember.class)
                .setParameter("gid", groupId).setParameter("uid", userId).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public List<Group> getGroupsOf(int userId) {
        return groupsByStatus(userId, GroupMember.STATUS_ACTIVE);
    }

    @Override
    public List<Group> getPendingGroupsOf(int userId) {
        return groupsByStatus(userId, GroupMember.STATUS_PENDING);
    }

    private List<Group> groupsByStatus(int userId, String status) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<GroupMember> rows = em.createQuery(
                    "SELECT m FROM GroupMember m JOIN FETCH m.group g " +
                    "WHERE m.user.userId = :uid AND m.status = :st " +
                    "ORDER BY CASE WHEN m.role = 'OWNER' THEN 0 ELSE 1 END, g.name", GroupMember.class)
                .setParameter("uid", userId).setParameter("st", status).getResultList();
            List<Group> groups = new ArrayList<>();
            for (GroupMember m : rows) {
                Group g = m.getGroup();
                g.setMyMembership(m);
                groups.add(g);
            }
            if (GroupMember.STATUS_ACTIVE.equals(status)) attachPendingCounts(em, groups);
            return groups;
        } finally {
            em.close();
        }
    }

    /** Số yêu cầu chờ duyệt cho các nhóm mình làm chủ (hiện trên thẻ nhóm) */
    private void attachPendingCounts(EntityManager em, List<Group> groups) {
        List<Integer> owned = new ArrayList<>();
        for (Group g : groups) if (g.getMyMembership().isOwner()) owned.add(g.getGroupId());
        if (owned.isEmpty()) return;
        for (Object[] row : em.createQuery(
                "SELECT m.group.groupId, COUNT(m) FROM GroupMember m " +
                "WHERE m.group.groupId IN :ids AND m.status = 'PENDING' GROUP BY m.group.groupId", Object[].class)
                .setParameter("ids", owned).getResultList()) {
            for (Group g : groups) if (g.getGroupId() == (Integer) row[0]) g.setPendingCount(((Long) row[1]).intValue());
        }
    }

    @Override
    public List<Group> explore(int userId, String query, int page, int pageSize) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = normalize(query);
            List<Group> groups = em.createQuery(
                    "SELECT g FROM Group g WHERE g.groupId NOT IN (" +
                    "  SELECT m.group.groupId FROM GroupMember m WHERE m.user.userId = :uid AND m.status = 'ACTIVE')" +
                    SEARCH + "ORDER BY g.memberCount DESC, g.groupId DESC", Group.class)
                .setParameter("uid", userId)
                .setParameter("q", q).setParameter("like", "%" + q + "%")
                .setFirstResult((Math.max(page, 1) - 1) * pageSize)
                .setMaxResults(pageSize)
                .getResultList();
            if (groups.isEmpty()) return groups;

            // Gắn trạng thái PENDING/BANNED (nếu có) của người xem cho từng nhóm — 1 truy vấn
            List<Integer> ids = new ArrayList<>();
            for (Group g : groups) ids.add(g.getGroupId());
            for (GroupMember m : em.createQuery(
                    "SELECT m FROM GroupMember m WHERE m.user.userId = :uid AND m.group.groupId IN :ids",
                    GroupMember.class).setParameter("uid", userId).setParameter("ids", ids).getResultList()) {
                for (Group g : groups) if (g.getGroupId() == m.getGroupId()) g.setMyMembership(m);
            }
            return groups;
        } finally {
            em.close();
        }
    }

    @Override
    public int countExplore(int userId, String query) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = normalize(query);
            return em.createQuery(
                    "SELECT COUNT(g) FROM Group g WHERE g.groupId NOT IN (" +
                    "  SELECT m.group.groupId FROM GroupMember m WHERE m.user.userId = :uid AND m.status = 'ACTIVE')" +
                    SEARCH, Long.class)
                .setParameter("uid", userId)
                .setParameter("q", q).setParameter("like", "%" + q + "%")
                .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public List<GroupMember> getMembers(int groupId, String status) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery(
                    "SELECT m FROM GroupMember m JOIN FETCH m.user " +
                    "WHERE m.group.groupId = :gid AND m.status = :st " +
                    "ORDER BY CASE m.role WHEN 'OWNER' THEN 0 WHEN 'ADMIN' THEN 1 ELSE 2 END, m.joinedAt",
                    GroupMember.class)
                .setParameter("gid", groupId).setParameter("st", status).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public Group createGroup(Group group, int ownerId) {
        return inTransaction(em -> {
            group.setMemberCount(1);
            em.persist(group);
            GroupMember owner = new GroupMember();
            owner.setGroup(group);
            owner.setUser(em.find(User.class, ownerId));
            owner.setRole(GroupMember.ROLE_OWNER);
            owner.setStatus(GroupMember.STATUS_ACTIVE);
            em.persist(owner);
            return group;
        });
    }

    @Override
    public String join(int groupId, int userId, boolean privateGroup) {
        String status = privateGroup ? GroupMember.STATUS_PENDING : GroupMember.STATUS_ACTIVE;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            GroupMember m = new GroupMember();
            m.setGroup(em.getReference(Group.class, groupId));
            m.setUser(em.getReference(User.class, userId));
            m.setRole(GroupMember.ROLE_MEMBER);
            m.setStatus(status);
            em.persist(m);
            em.flush();   // INSERT ngay để lỗi trùng khóa (bấm 2 lần) nổ ra ở đây
            em.getTransaction().commit();
        } catch (PersistenceException e) {
            // Khóa chính kép (group_id, user_id) đã có hàng: đã là thành viên / đang chờ / bị chặn.
            // Transaction hỏng → rollback; EM này bỏ đi (finally đóng), không dùng tiếp.
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            return null;
        } finally {
            em.close();
        }
        if (GroupMember.STATUS_ACTIVE.equals(status)) syncMemberCount(groupId);
        return status;
    }

    @Override
    public boolean leave(int groupId, int userId) {
        // DELETE hàng loạt + đếm số hàng: bấm "Rời nhóm" 2 lần cùng lúc thì lần sau xóa 0 hàng và thôi,
        // không ném OptimisticLockException như em.remove() trên entity đã bị xóa.
        boolean removed = inTransaction(em -> em.createQuery(
                "DELETE FROM GroupMember m WHERE m.group.groupId = :gid AND m.user.userId = :uid " +
                "AND m.status IN ('ACTIVE', 'PENDING') AND m.role <> 'OWNER'")
            .setParameter("gid", groupId).setParameter("uid", userId).executeUpdate() == 1);
        if (removed) syncMemberCount(groupId);
        return removed;
    }

    @Override
    public boolean approve(int groupId, int userId) {
        boolean ok = inTransaction(em -> em.createQuery(
                "UPDATE GroupMember m SET m.status = 'ACTIVE', m.joinedAt = CURRENT_TIMESTAMP " +
                "WHERE m.group.groupId = :gid AND m.user.userId = :uid AND m.status = 'PENDING'")
            .setParameter("gid", groupId).setParameter("uid", userId).executeUpdate() == 1);
        if (ok) syncMemberCount(groupId);
        return ok;
    }

    @Override
    public boolean reject(int groupId, int userId) {
        return inTransaction(em -> em.createQuery(
                "DELETE FROM GroupMember m WHERE m.group.groupId = :gid AND m.user.userId = :uid AND m.status = 'PENDING'")
            .setParameter("gid", groupId).setParameter("uid", userId).executeUpdate() == 1);
    }

    @Override
    public boolean kick(int groupId, int userId) {
        boolean ok = inTransaction(em -> em.createQuery(
                "UPDATE GroupMember m SET m.status = 'BANNED' " +
                "WHERE m.group.groupId = :gid AND m.user.userId = :uid AND m.status = 'ACTIVE' AND m.role <> 'OWNER'")
            .setParameter("gid", groupId).setParameter("uid", userId).executeUpdate() == 1);
        if (ok) syncMemberCount(groupId);
        return ok;
    }

    @Override
    public boolean unban(int groupId, int userId) {
        return inTransaction(em -> em.createQuery(
                "DELETE FROM GroupMember m WHERE m.group.groupId = :gid AND m.user.userId = :uid AND m.status = 'BANNED'")
            .setParameter("gid", groupId).setParameter("uid", userId).executeUpdate() == 1);
    }

    @Override
    public boolean transferOwnership(int groupId, int fromUserId, int toUserId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            // Hạ chủ cũ TRƯỚC: unique index UX_group_one_owner kiểm theo từng câu lệnh
            int down = em.createQuery("UPDATE GroupMember m SET m.role = 'MEMBER' " +
                                      "WHERE m.group.groupId = :gid AND m.user.userId = :uid AND m.role = 'OWNER'")
                         .setParameter("gid", groupId).setParameter("uid", fromUserId).executeUpdate();
            int up = em.createQuery("UPDATE GroupMember m SET m.role = 'OWNER' " +
                                    "WHERE m.group.groupId = :gid AND m.user.userId = :uid AND m.status = 'ACTIVE'")
                       .setParameter("gid", groupId).setParameter("uid", toUserId).executeUpdate();
            if (down != 1 || up != 1) {
                em.getTransaction().rollback();   // cùng thành công hoặc cùng hủy
                return false;
            }
            em.getTransaction().commit();
            return true;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public void updateGroup(int groupId, String name, String description, String category,
                            String privacy, String coverIcon) {
        Boolean opened = inTransaction(em -> {
            Group g = em.find(Group.class, groupId);
            if (g == null) return false;
            boolean openedUp = g.isPrivateGroup() && Group.PUBLIC.equals(privacy);
            g.setName(name);
            g.setDescription(description);
            g.setCategory(category);
            g.setPrivacy(privacy);
            g.setCoverIcon(coverIcon);
            em.flush();
            if (openedUp) {
                // Nhóm kín → công khai: duyệt luôn mọi yêu cầu đang chờ
                em.createQuery("UPDATE GroupMember m SET m.status = 'ACTIVE', m.joinedAt = CURRENT_TIMESTAMP " +
                               "WHERE m.group.groupId = :gid AND m.status = 'PENDING'")
                  .setParameter("gid", groupId).executeUpdate();
            }
            return openedUp;
        });
        if (Boolean.TRUE.equals(opened)) syncMemberCount(groupId);
    }

    @Override
    public void updateCover(int groupId, String coverPath) {
        inTransaction(em -> {
            Group g = em.find(Group.class, groupId);
            if (g != null) g.setCoverImage(coverPath);
            return null;
        });
    }

    @Override
    public List<String> deleteGroup(int groupId) {
        return inTransaction(em -> {
            List<String> files = new ArrayList<>();
            for (Object[] row : em.createQuery(
                    "SELECT p.imagePath, p.videoPath FROM Post p WHERE p.groupId = :gid", Object[].class)
                    .setParameter("gid", groupId).getResultList()) {
                if (row[0] != null) files.add((String) row[0]);
                if (row[1] != null) files.add((String) row[1]);
            }
            String inGroup = "(SELECT p.postId FROM Post p WHERE p.groupId = :gid)";
            em.createQuery("DELETE FROM Comment c WHERE c.post.postId IN " + inGroup).setParameter("gid", groupId).executeUpdate();
            em.createQuery("DELETE FROM Like l WHERE l.post.postId IN " + inGroup).setParameter("gid", groupId).executeUpdate();
            em.createQuery("DELETE FROM SavedPost s WHERE s.post.postId IN " + inGroup).setParameter("gid", groupId).executeUpdate();
            em.createQuery("DELETE FROM Post p WHERE p.groupId = :gid").setParameter("gid", groupId).executeUpdate();
            em.createQuery("DELETE FROM GroupMember m WHERE m.group.groupId = :gid").setParameter("gid", groupId).executeUpdate();
            em.createQuery("DELETE FROM Group g WHERE g.groupId = :gid").setParameter("gid", groupId).executeUpdate();
            return files;
        });
    }

    @Override
    public int countGroups() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(g) FROM Group g", Long.class).getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Group> adminList(String query, int page, int pageSize) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = normalize(query);
            List<Group> groups = em.createQuery("SELECT g FROM Group g WHERE g.groupId > 0" + SEARCH +
                                                "ORDER BY g.createdAt DESC, g.groupId DESC", Group.class)
                .setParameter("q", q).setParameter("like", "%" + q + "%")
                .setFirstResult((Math.max(page, 1) - 1) * pageSize)
                .setMaxResults(pageSize)
                .getResultList();
            if (groups.isEmpty()) return groups;
            List<Integer> ids = new ArrayList<>();
            for (Group g : groups) ids.add(g.getGroupId());
            for (GroupMember m : em.createQuery(
                    "SELECT m FROM GroupMember m JOIN FETCH m.user WHERE m.group.groupId IN :ids " +
                    "AND m.role = 'OWNER' AND m.status = 'ACTIVE'", GroupMember.class)
                    .setParameter("ids", ids).getResultList()) {
                for (Group g : groups) if (g.getGroupId() == m.getGroupId()) g.setOwner(m.getUser());
            }
            return groups;
        } finally {
            em.close();
        }
    }

    @Override
    public int countAdminList(String query) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = normalize(query);
            return em.createQuery("SELECT COUNT(g) FROM Group g WHERE g.groupId > 0" + SEARCH, Long.class)
                .setParameter("q", q).setParameter("like", "%" + q + "%")
                .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    // ---------- Helpers ----------

    /**
     * Đồng bộ member_count theo số thành viên ACTIVE thật — MỘT câu UPDATE, transaction riêng, chạy SAU khi
     * thay đổi thành viên đã commit. Khóa hàng nhóm chỉ bị giữ trong đúng câu lệnh này.
     */
    private static void syncMemberCount(int groupId) {
        inTransaction(em -> em.createQuery(
                "UPDATE Group g SET g.memberCount = (SELECT COUNT(m) FROM GroupMember m " +
                "WHERE m.group.groupId = :gid AND m.status = 'ACTIVE') WHERE g.groupId = :gid")
            .setParameter("gid", groupId).executeUpdate());
    }

    private static String normalize(String query) {
        return query == null ? "" : query.trim().toLowerCase();
    }

    /** Chạy trong một transaction; lỗi thì rollback và ném lại */
    private static <T> T inTransaction(Function<EntityManager, T> work) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            T result = work.apply(em);
            if (em.getTransaction().getRollbackOnly()) em.getTransaction().rollback();
            else em.getTransaction().commit();
            return result;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }
}
