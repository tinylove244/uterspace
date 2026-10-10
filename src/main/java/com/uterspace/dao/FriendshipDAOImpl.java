package com.uterspace.dao;

import com.uterspace.model.FriendSuggestion;
import com.uterspace.model.Friendship;
import com.uterspace.model.User;
import com.uterspace.model.UserSettings;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceException;
import java.time.LocalDateTime;
import java.util.*;

/** FriendshipDAOImpl — Implementation của FriendshipDAO dùng JPA (quy tắc xem ở FriendshipDAO). */
public class FriendshipDAOImpl implements FriendshipDAO {

    /** Điều kiện "f là quan hệ giữa :a và :b" (không phân biệt chiều) */
    private static final String PAIR =
        " ((f.requester.userId = :a AND f.receiver.userId = :b) OR (f.requester.userId = :b AND f.receiver.userId = :a)) ";

    // ============================================================ Đọc

    @Override
    public List<User> getFriendsOf(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT u FROM User u WHERE u.userId IN (" + PostDAOImpl.friendIdsOfMe("ff") + ") " +
                                  "ORDER BY u.firstName, u.lastName", User.class)
                     .setParameter("me", userId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Integer> getFriendIds(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery(PostDAOImpl.friendIdsOfMe("ff"), Integer.class).setParameter("me", userId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public int countFriends(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(f) FROM Friendship f WHERE f.status = 'accepted' AND " +
                                  "(f.requester.userId = :u OR f.receiver.userId = :u)", Long.class)
                     .setParameter("u", userId).getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Friendship> getFriendships(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT f FROM Friendship f JOIN FETCH f.requester JOIN FETCH f.receiver " +
                                  "WHERE f.status = 'accepted' AND (f.requester.userId = :u OR f.receiver.userId = :u) " +
                                  "ORDER BY f.acceptedAt DESC, f.friendshipId DESC", Friendship.class)
                     .setParameter("u", userId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Friendship> getPendingRequestsFor(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT f FROM Friendship f JOIN FETCH f.requester JOIN FETCH f.receiver " +
                                  "WHERE f.receiver.userId = :u AND f.status = 'pending' ORDER BY f.createdAt DESC", Friendship.class)
                     .setParameter("u", userId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public int countPendingFor(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(f) FROM Friendship f WHERE f.receiver.userId = :u AND f.status = 'pending'", Long.class)
                     .setParameter("u", userId).getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Friendship> getSentRequests(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT f FROM Friendship f JOIN FETCH f.requester JOIN FETCH f.receiver " +
                                  "WHERE f.requester.userId = :u AND f.status = 'pending' ORDER BY f.createdAt DESC", Friendship.class)
                     .setParameter("u", userId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public Friendship findBetween(int a, int b) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return findBetween(em, a, b);
        } finally {
            em.close();
        }
    }

    private static Friendship findBetween(EntityManager em, int a, int b) {
        List<Friendship> r = em.createQuery("SELECT f FROM Friendship f JOIN FETCH f.requester JOIN FETCH f.receiver WHERE" + PAIR,
                                            Friendship.class)
                               .setParameter("a", a).setParameter("b", b).getResultList();
        return r.isEmpty() ? null : r.get(0);
    }

    @Override
    public boolean areFriends(int userId1, int userId2) {
        Friendship f = findBetween(userId1, userId2);
        return f != null && f.isAccepted();
    }

    @Override
    public Friendship getFriendshipById(int fsId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Friendship> r = em.createQuery("SELECT f FROM Friendship f JOIN FETCH f.requester JOIN FETCH f.receiver " +
                                                "WHERE f.friendshipId = :id", Friendship.class)
                                   .setParameter("id", fsId).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public Map<Integer, Integer> mutualCounts(int userId, Collection<Integer> others) {
        Map<Integer, Integer> result = new HashMap<>();
        if (others == null || others.isEmpty()) return result;
        Set<Integer> mine = new HashSet<>(getFriendIds(userId));
        if (mine.isEmpty()) return result;
        Set<Integer> wanted = new HashSet<>(others);
        for (Map.Entry<Integer, Integer> e : friendsOfFriends(userId, mine).entrySet()) {
            if (wanted.contains(e.getKey())) result.put(e.getKey(), e.getValue());
        }
        return result;
    }

    /**
     * Đếm bạn chung cho mọi "bạn của bạn": duyệt các quan hệ accepted có một đầu là bạn của mình —
     * đầu còn lại (không phải mình) nhận +1 bạn chung. Một truy vấn duy nhất, gom trong Java.
     */
    private Map<Integer, Integer> friendsOfFriends(int userId, Set<Integer> mine) {
        Map<Integer, Integer> counts = new HashMap<>();
        EntityManager em = JPAUtil.getEntityManager();
        try {
            for (Object[] row : em.createQuery(
                    "SELECT f.requester.userId, f.receiver.userId FROM Friendship f WHERE f.status = 'accepted' " +
                    "AND (f.requester.userId IN :fs OR f.receiver.userId IN :fs)", Object[].class)
                    .setParameter("fs", mine).getResultList()) {
                int a = (Integer) row[0], b = (Integer) row[1];
                if (mine.contains(a) && b != userId) counts.merge(b, 1, Integer::sum);
                if (mine.contains(b) && a != userId) counts.merge(a, 1, Integer::sum);
            }
            return counts;
        } finally {
            em.close();
        }
    }

    @Override
    public List<FriendSuggestion> getSuggestions(int userId, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            User me = em.find(User.class, userId);
            Set<Integer> mine = new HashSet<>(getFriendIds(userId));

            // Loại: mình, bạn bè, lời mời hai chiều, chặn hai chiều
            Set<Integer> excluded = new HashSet<>(mine);
            excluded.add(userId);
            for (Object[] row : em.createQuery("SELECT f.requester.userId, f.receiver.userId FROM Friendship f " +
                                               "WHERE f.status = 'pending' AND (f.requester.userId = :u OR f.receiver.userId = :u)",
                                               Object[].class).setParameter("u", userId).getResultList()) {
                excluded.add((Integer) row[0]);
                excluded.add((Integer) row[1]);
            }
            excluded.addAll(new BlockDAO().blockedEitherWay(userId));

            Map<Integer, Integer> mutual = mine.isEmpty() ? new HashMap<>() : friendsOfFriends(userId, mine);
            mutual.keySet().removeAll(excluded);

            // Ứng viên: bạn của bạn + (bổ sung) mọi tài khoản đang hoạt động khác, rồi lọc theo quyền riêng tư
            List<User> candidates = em.createQuery(
                    "SELECT u FROM User u WHERE u.status = 'ACTIVE' AND u.userId NOT IN :ex ORDER BY u.createdAt DESC", User.class)
                .setParameter("ex", excluded).setMaxResults(200).getResultList();
            Map<Integer, UserSettings> settings = new UserSettingsDAO().getMany(
                    candidates.stream().map(User::getUserId).collect(java.util.stream.Collectors.toList()));

            List<FriendSuggestion> list = new ArrayList<>();
            String myLocation = me != null ? me.getLocation() : null;
            for (User u : candidates) {
                int m = mutual.getOrDefault(u.getUserId(), 0);
                String policy = settings.get(u.getUserId()).getFriendRequestPolicy();
                if (UserSettings.FR_NOBODY.equals(policy)) continue;
                if (UserSettings.FR_FRIENDS_OF_FRIENDS.equals(policy) && m == 0) continue;
                String reason;
                if (m > 0) reason = m + " bạn chung";
                else if (myLocation != null && !myLocation.isEmpty() && myLocation.equalsIgnoreCase(u.getLocation())) reason = "Cùng khu vực";
                else reason = "Thành viên UTErSpace";
                list.add(new FriendSuggestion(u, m, reason));
            }
            // Nhiều bạn chung trước → cùng khu vực → còn lại (giữ thứ tự mới tham gia)
            list.sort((x, y) -> {
                if (x.getMutualCount() != y.getMutualCount()) return y.getMutualCount() - x.getMutualCount();
                boolean lx = "Cùng khu vực".equals(x.getReason()), ly = "Cùng khu vực".equals(y.getReason());
                return lx == ly ? 0 : (lx ? -1 : 1);
            });
            return list.size() > limit ? new ArrayList<>(list.subList(0, limit)) : list;
        } finally {
            em.close();
        }
    }

    @Override
    public List<User> getSuggestedFriends(int userId) {
        List<User> users = new ArrayList<>();
        for (FriendSuggestion s : getSuggestions(userId, 20)) users.add(s.getUser());
        return users;
    }

    // ============================================================ Ghi

    @Override
    public RequestResult sendRequest(int from, int to) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Friendship existing = findBetween(em, from, to);
            if (existing != null) {
                RequestResult r;
                if (existing.isAccepted()) {
                    r = RequestResult.ALREADY_FRIENDS;
                } else if (existing.getRequester().getUserId() == from) {
                    r = RequestResult.ALREADY_SENT;                       // bấm 2 lần → không tạo lời mời trùng
                } else {
                    existing.setStatus("accepted");                       // người kia đã mời mình trước → thành bạn luôn
                    existing.setAcceptedAt(LocalDateTime.now());
                    r = RequestResult.AUTO_ACCEPTED;
                }
                em.getTransaction().commit();
                return r;
            }
            Friendship f = new Friendship();
            f.setRequester(em.getReference(User.class, from));
            f.setReceiver(em.getReference(User.class, to));
            f.setStatus("pending");
            f.setCreatedAt(LocalDateTime.now());
            em.persist(f);
            em.flush();                                                   // vi phạm UNIQUE cặp (gửi đồng thời) nổ ở đây
            em.getTransaction().commit();
            return RequestResult.SENT;
        } catch (PersistenceException e) {
            // Hai request cùng lúc: một bên bị UNIQUE(user_lo, user_hi) chặn → đọc lại trạng thái đã được bên kia ghi
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            em.close();
            Friendship now = findBetween(from, to);
            if (now == null) throw e;
            if (now.isAccepted()) return RequestResult.ALREADY_FRIENDS;
            if (now.getRequester().getUserId() == from) return RequestResult.ALREADY_SENT;
            return accept(from, now.getRequester().getUserId()) ? RequestResult.AUTO_ACCEPTED : RequestResult.ALREADY_SENT;
        } finally {
            if (em.isOpen()) em.close();
        }
    }

    @Override
    public boolean accept(int receiverId, int requesterId) {
        return update("UPDATE Friendship f SET f.status = 'accepted', f.acceptedAt = :now " +
                      "WHERE f.receiver.userId = :rec AND f.requester.userId = :req AND f.status = 'pending'",
                      receiverId, requesterId, true) == 1;
    }

    @Override
    public boolean decline(int receiverId, int requesterId) {
        return update("DELETE FROM Friendship f WHERE f.receiver.userId = :rec AND f.requester.userId = :req AND f.status = 'pending'",
                      receiverId, requesterId, false) == 1;
    }

    @Override
    public boolean cancel(int requesterId, int receiverId) {
        return update("DELETE FROM Friendship f WHERE f.receiver.userId = :rec AND f.requester.userId = :req AND f.status = 'pending'",
                      receiverId, requesterId, false) == 1;
    }

    @Override
    public boolean unfriend(int a, int b) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("DELETE FROM Friendship f WHERE f.status = 'accepted' AND" + PAIR)
                      .setParameter("a", a).setParameter("b", b).executeUpdate();
            em.getTransaction().commit();
            return n == 1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    /** Một câu UPDATE/DELETE theo cặp (receiver, requester) trong transaction riêng; trả số dòng bị ảnh hưởng */
    private int update(String jpql, int receiverId, int requesterId, boolean withNow) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            javax.persistence.Query q = em.createQuery(jpql).setParameter("rec", receiverId).setParameter("req", requesterId);
            if (withNow) q.setParameter("now", LocalDateTime.now());
            int n = q.executeUpdate();
            em.getTransaction().commit();
            return n;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }
}
