package com.uterspace.dao;

import com.uterspace.model.Post;
import com.uterspace.model.User;
import com.uterspace.util.HashtagUtil;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.TypedQuery;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * PostDAOImpl — Implementation của PostDAO dùng JPA.
 */
public class PostDAOImpl implements PostDAO {

    /** Subquery JPQL: id bạn bè (đã accepted) của :me. alias = tên biến Friendship, mỗi subquery một tên. */
    static String friendIdsOfMe(String alias) {
        return "SELECT CASE WHEN " + alias + ".requester.userId = :me THEN " + alias + ".receiver.userId " +
               "ELSE " + alias + ".requester.userId END FROM Friendship " + alias + " " +
               "WHERE (" + alias + ".requester.userId = :me OR " + alias + ".receiver.userId = :me) " +
               "AND " + alias + ".status = 'accepted'";
    }

    /**
     * NƠI DUY NHẤT định nghĩa "bài p nào người xem :me được thấy" (plan mục 2.2).
     * Ghép vào MỌI truy vấn bài: feed, hashtag, saved, video, bài gốc của bài chia sẻ...
     *   - admin chưa ẩn/xóa (moderationStatus = ACTIVE) và chủ bài chưa tự ẩn
     *   - bài cá nhân: công khai, hoặc của chính mình, hoặc của bạn bè
     *   - bài trong nhóm: chỉ khi :me đang là thành viên ACTIVE của nhóm (kể cả nhóm công khai —
     *     người ngoài xem bài nhóm công khai ở trang nhóm qua getGroupPosts, không ở feed/hashtag/profile)
     * Ngoại lệ KHÔNG dùng hằng này: trang cá nhân của chính mình (getProfilePosts)
     * và trang một nhóm công khai (getGroupPosts).
     * Truy vấn dùng hằng này phải đặt alias bài là "p" và truyền tham số :me.
     */
    static final String VISIBLE =
        " (p.moderationStatus = 'ACTIVE' AND p.hiddenByOwner = false AND " + BlockDAO.notBlocked("p.author.userId") + " AND (" +
        "    (p.groupId IS NULL AND (p.visibility = 'public' OR p.author.userId = :me" +
        "                            OR p.author.userId IN (" + friendIdsOfMe("vf") + ")))" +
        "    OR p.groupId IN (SELECT vgm.group.groupId FROM GroupMember vgm" +
        "                     WHERE vgm.user.userId = :me AND vgm.status = 'ACTIVE')" +
        " )) ";

    @Override
    public List<Post> getAllPosts() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT p FROM Post p JOIN FETCH p.author ORDER BY p.createdAt DESC", Post.class).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public boolean canView(int postId, int viewerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(p) FROM Post p WHERE p.postId = :postId AND " + VISIBLE, Long.class)
                     .setParameter("postId", postId)
                     .setParameter("me", viewerId)
                     .getSingleResult() > 0;
        } finally {
            em.close();
        }
    }

    @Override
    public Post getPostById(int postId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            TypedQuery<Post> q = em.createQuery("SELECT p FROM Post p JOIN FETCH p.author WHERE p.postId = :postId", Post.class);
            q.setParameter("postId", postId);
            List<Post> results = q.getResultList();
            return results.isEmpty() ? null : results.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public List<Post> getFeedPosts(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // Bảng tin: bài mình + bạn bè + bài trong các nhóm mình đang tham gia
            // (trong số bài mình được thấy — VISIBLE đã lọc nhóm theo tư cách thành viên)
            String jpql = "SELECT p FROM Post p JOIN FETCH p.author " +
                          "WHERE " + VISIBLE +
                          "  AND (p.groupId IS NOT NULL OR p.author.userId = :me" +
                          "       OR p.author.userId IN (" + friendIdsOfMe("ff") + ")) " +
                          "ORDER BY p.createdAt DESC";
            return em.createQuery(jpql, Post.class)
                     .setParameter("me", userId)
                     .getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Post> getProfilePosts(int profileUserId, int viewerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            TypedQuery<Post> q;
            if (profileUserId == viewerId) {
                // Trang của chính mình: thấy cả bài tự ẩn và bài bị admin ẩn (JSP gắn nhãn),
                // chỉ không thấy bài admin đã xóa mềm.
                q = em.createQuery("SELECT p FROM Post p JOIN FETCH p.author " +
                                   "WHERE p.author.userId = :uid AND p.moderationStatus <> 'DELETED' " +
                                   "ORDER BY p.createdAt DESC", Post.class);
            } else {
                q = em.createQuery("SELECT p FROM Post p JOIN FETCH p.author " +
                                   "WHERE p.author.userId = :uid AND " + VISIBLE +
                                   "ORDER BY p.createdAt DESC", Post.class)
                      .setParameter("me", viewerId);
            }
            return q.setParameter("uid", profileUserId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Post> getGroupPosts(int groupId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // Không dùng VISIBLE: người ngoài được xem bài nhóm công khai. Controller kiểm quyền xem nhóm trước.
            return em.createQuery("SELECT p FROM Post p JOIN FETCH p.author " +
                                  "WHERE p.groupId = :gid AND p.moderationStatus = 'ACTIVE' AND p.hiddenByOwner = false " +
                                  "ORDER BY p.createdAt DESC", Post.class)
                     .setParameter("gid", groupId)
                     .getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public void attachGroupNames(List<Post> posts) {
        Set<Integer> ids = new HashSet<>();
        for (Post p : posts) if (p.getGroupId() != null) ids.add(p.getGroupId());
        if (ids.isEmpty()) return;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            Map<Integer, String> names = new HashMap<>();
            for (Object[] row : em.createQuery("SELECT g.groupId, g.name FROM Group g WHERE g.groupId IN :ids", Object[].class)
                                  .setParameter("ids", ids).getResultList()) {
                names.put((Integer) row[0], (String) row[1]);
            }
            for (Post p : posts) if (p.getGroupId() != null) p.setGroupName(names.get(p.getGroupId()));
        } finally {
            em.close();
        }
    }

    @Override
    public int countPostsByUser(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(p) FROM Post p WHERE p.author.userId = :uid " +
                                  "AND p.moderationStatus <> 'DELETED'", Long.class)
                     .setParameter("uid", userId)
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    private static String videoWhere(boolean friendsOnly) {
        return "WHERE p.mediaType = 'VIDEO' AND " + VISIBLE +
               (friendsOnly ? " AND p.author.userId IN (" + friendIdsOfMe("vff") + ") " : "");
    }

    @Override
    public List<Post> getVideoPosts(int viewerId, boolean friendsOnly, int page, int pageSize) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // Phân trang bằng setFirstResult/setMaxResults — Hibernate sinh đúng cú pháp từng DB (plan 2.1)
            return em.createQuery("SELECT p FROM Post p JOIN FETCH p.author " + videoWhere(friendsOnly) +
                                  "ORDER BY p.createdAt DESC, p.postId DESC", Post.class)
                     .setParameter("me", viewerId)
                     .setFirstResult((Math.max(page, 1) - 1) * pageSize)
                     .setMaxResults(pageSize)
                     .getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public int countVideoPosts(int viewerId, boolean friendsOnly) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(p) FROM Post p " + videoWhere(friendsOnly), Long.class)
                     .setParameter("me", viewerId)
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public Post createPost(Post post) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            
            // Tìm User (author) từ userId được truyền vào
            User author = em.find(User.class, post.getUserId());
            post.setAuthor(author);
            
            if (post.getVisibility() == null) post.setVisibility("public");
            if (post.getCreatedAt() == null) post.setCreatedAt(LocalDateTime.now());
            
            em.persist(post);
            em.getTransaction().commit();
            return post;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("PostDAOImpl.createPost lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public void deletePost(int postId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            // Nếu là bài chia sẻ → giảm share_count của bài gốc.
            // (Nếu là bài gốc: các bài chia sẻ nó vẫn giữ lại, hiện "không khả dụng".)
            Post target = em.find(Post.class, postId);
            if (target != null && target.getSharedPostId() != null) {
                em.createQuery("UPDATE Post p SET p.shareCount = p.shareCount - 1 " +
                               "WHERE p.postId = :originalId AND p.shareCount > 0")
                  .setParameter("originalId", target.getSharedPostId())
                  .executeUpdate();
            }
            // Xóa comments trước (FK constraint)
            em.createQuery("DELETE FROM Comment c WHERE c.post.postId = :postId")
              .setParameter("postId", postId)
              .executeUpdate();
            // Xóa likes — Like entity dùng ManyToOne 'post', không phải column postId
            em.createQuery("DELETE FROM Like l WHERE l.post.postId = :postId")
              .setParameter("postId", postId)
              .executeUpdate();
            // Xóa saved_posts — SavedPost entity dùng ManyToOne 'post'
            em.createQuery("DELETE FROM SavedPost sp WHERE sp.post.postId = :postId")
              .setParameter("postId", postId)
              .executeUpdate();
            // Xóa bài viết
            em.createQuery("DELETE FROM Post p WHERE p.postId = :postId")
              .setParameter("postId", postId)
              .executeUpdate();
            em.getTransaction().commit();
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("PostDAOImpl.deletePost lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public Post updatePost(int postId, String content, String visibility) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Post post = em.find(Post.class, postId);
            if (post == null) throw new RuntimeException("Không tìm thấy bài viết postId=" + postId);
            post.setContent(content);
            if (visibility != null && !visibility.isEmpty()) post.setVisibility(visibility);
            Post merged = em.merge(post);
            em.getTransaction().commit();
            return merged;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("PostDAOImpl.updatePost lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public Post sharePost(int userId, int originalPostId, String content, String visibility, boolean hiddenByOwner) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();

            Post share = new Post();
            share.setAuthor(em.find(User.class, userId));
            share.setContent(content != null ? content : "");
            share.setVisibility(visibility != null ? visibility : "public");
            share.setSharedPostId(originalPostId);
            share.setHiddenByOwner(hiddenByOwner);
            share.setCreatedAt(LocalDateTime.now());
            em.persist(share);

            em.createQuery("UPDATE Post p SET p.shareCount = p.shareCount + 1 WHERE p.postId = :originalId")
              .setParameter("originalId", originalPostId)
              .executeUpdate();

            em.getTransaction().commit();
            return share;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("PostDAOImpl.sharePost lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public void attachSharedPosts(List<Post> posts, int viewerId) {
        Set<Integer> originalIds = new HashSet<>();
        for (Post p : posts) {
            if (p.getSharedPostId() != null) originalIds.add(p.getSharedPostId());
        }
        if (originalIds.isEmpty()) return;

        EntityManager em = JPAUtil.getEntityManager();
        try {
            // 1 query cho cả danh sách (tránh N+1), chỉ lấy bài gốc người xem được phép xem
            List<Post> originals = em.createQuery(
                    "SELECT p FROM Post p JOIN FETCH p.author " +
                    "WHERE p.postId IN :ids AND " + VISIBLE, Post.class)
                .setParameter("ids", originalIds)
                .setParameter("me", viewerId)
                .getResultList();

            Map<Integer, Post> byId = new HashMap<>();
            for (Post o : originals) byId.put(o.getPostId(), o);
            for (Post p : posts) {
                if (p.getSharedPostId() != null) p.setSharedPost(byId.get(p.getSharedPostId()));
            }
        } finally {
            em.close();
        }
    }

    @Override
    public List<Post> getPostsByHashtag(String tag, int viewerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // '_' là ký tự đại diện của LIKE → escape bằng '!'
            String pattern = "%#" + tag.replace("!", "!!").replace("_", "!_") + "%";
            List<Post> candidates = em.createQuery(
                    "SELECT p FROM Post p JOIN FETCH p.author " +
                    "WHERE p.content LIKE :pattern ESCAPE '!' AND " + VISIBLE +
                    "ORDER BY p.createdAt DESC", Post.class)
                .setParameter("pattern", pattern)
                .setParameter("me", viewerId)
                .getResultList();

            // LIKE '%#IoT%' cũng khớp "#IoTProject" → lọc lại để chỉ giữ bài có đúng thẻ này
            return candidates.stream()
                             .filter(p -> HashtagUtil.containsTag(p.getContent(), tag))
                             .collect(Collectors.toList());
        } finally {
            em.close();
        }
    }

    @Override
    public List<String> getRecentContentsVisibleTo(int viewerId, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery(
                    "SELECT p.content FROM Post p WHERE " + VISIBLE + " ORDER BY p.createdAt DESC",
                    String.class)
                .setParameter("me", viewerId)
                .setMaxResults(limit)
                .getResultList();
        } finally {
            em.close();
        }
    }

    // ---------- Ẩn bài / kiểm duyệt ----------

    @Override
    public boolean setHiddenByOwner(int postId, int ownerId, boolean hidden) {
        return executeUpdate(em -> em.createQuery(
                "UPDATE Post p SET p.hiddenByOwner = :h WHERE p.postId = :pid AND p.author.userId = :uid")
            .setParameter("h", hidden).setParameter("pid", postId).setParameter("uid", ownerId)) == 1;
    }

    @Override
    public boolean setModerationStatus(int postId, String status) {
        return executeUpdate(em -> em.createQuery(
                "UPDATE Post p SET p.moderationStatus = :st WHERE p.postId = :pid")
            .setParameter("st", status).setParameter("pid", postId)) == 1;
    }

    private int executeUpdate(java.util.function.Function<EntityManager, javax.persistence.Query> build) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = build.apply(em).executeUpdate();
            em.getTransaction().commit();
            return n;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    private static String adminWhere(String filter) {
        String f;
        switch (filter == null ? "all" : filter) {
            case "active":       f = " AND p.moderationStatus = 'ACTIVE' AND p.hiddenByOwner = false "; break;
            case "hidden":       f = " AND p.moderationStatus = 'HIDDEN' "; break;
            case "deleted":      f = " AND p.moderationStatus = 'DELETED' "; break;
            case "owner-hidden": f = " AND p.hiddenByOwner = true AND p.moderationStatus <> 'DELETED' "; break;
            // AI / từ điển gắn nhãn tiêu cực (migration 090) — gợi ý cho quản trị viên xem xét chủ động
            case "negative":     f = " AND p.sentiment = 'NEGATIVE' AND p.moderationStatus <> 'DELETED' "; break;
            case "reported":     f = " AND p.postId IN (SELECT r.targetId FROM Report r " +
                                     "WHERE r.status = 'PENDING' AND r.targetType = 'POST') "; break;
            default:             f = " ";
        }
        return " WHERE (:q = '' OR LOWER(p.content) LIKE :like ESCAPE '!' OR LOWER(p.author.email) LIKE :like ESCAPE '!'" +
               " OR LOWER(CONCAT(CONCAT(p.author.firstName, ' '), p.author.lastName)) LIKE :like ESCAPE '!') " + f;
    }

    /** Chuỗi tìm kiếm → mẫu LIKE, thoát ký tự đặc biệt % _ [ bằng '!' */
    private static String likePattern(String q) {
        return "%" + q.replace("!", "!!").replace("%", "!%").replace("_", "!_").replace("[", "![") + "%";
    }

    @Override
    public List<Post> adminSearch(String query, String filter, int page, int pageSize) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = query == null ? "" : query.trim().toLowerCase();
            return em.createQuery("SELECT p FROM Post p JOIN FETCH p.author" + adminWhere(filter) +
                                  "ORDER BY p.createdAt DESC, p.postId DESC", Post.class)
                     .setParameter("q", q).setParameter("like", likePattern(q))
                     .setFirstResult((Math.max(page, 1) - 1) * pageSize)
                     .setMaxResults(pageSize)
                     .getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public int countAdminSearch(String query, String filter) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = query == null ? "" : query.trim().toLowerCase();
            return em.createQuery("SELECT COUNT(p) FROM Post p" + adminWhere(filter), Long.class)
                     .setParameter("q", q).setParameter("like", likePattern(q))
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public int countPosts() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(p) FROM Post p WHERE p.moderationStatus <> 'DELETED'", Long.class)
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public List<LocalDateTime> getCreatedSince(LocalDateTime since) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT p.createdAt FROM Post p WHERE p.createdAt >= :since", LocalDateTime.class)
                     .setParameter("since", since).getResultList();
        } finally {
            em.close();
        }
    }
}
