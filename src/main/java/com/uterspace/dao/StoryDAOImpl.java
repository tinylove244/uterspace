package com.uterspace.dao;

import com.uterspace.model.Story;
import com.uterspace.model.StoryRing;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.*;

/**
 * StoryDAOImpl — Implementation của StoryDAO dùng JPA.
 * Bảng story_views không có entity riêng (chỉ 3 cột, không cần nạp object) → dùng vài câu SQL gốc đơn giản,
 * cú pháp chuẩn (INSERT ... SELECT ... WHERE NOT EXISTS) chạy được trên mọi CSDL.
 */
public class StoryDAOImpl implements StoryDAO {

    /** Điều kiện "tin của s thuộc chính mình hoặc bạn bè của :me" — dùng lại subquery bạn bè của PostDAOImpl */
    private static final String MINE_OR_FRIENDS =
        " (s.author.userId = :me OR s.author.userId IN (" + PostDAOImpl.friendIdsOfMe("sf") + ")) ";

    @Override
    public Story create(int userId, String mediaPath, String mediaType, String caption, Integer durationSec) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Story s = new Story();
            s.setAuthor(em.getReference(User.class, userId));
            s.setMediaPath(mediaPath);
            s.setMediaType(mediaType);
            s.setCaption(caption);
            s.setDurationSec(durationSec);
            em.persist(s);
            em.getTransaction().commit();
            return s;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public int countActive(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(s) FROM Story s WHERE s.author.userId = :uid AND s.expiresAt > :now", Long.class)
                     .setParameter("uid", userId).setParameter("now", LocalDateTime.now())
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public List<StoryRing> getRings(int viewerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Story> stories = em.createQuery(
                    "SELECT s FROM Story s JOIN FETCH s.author WHERE s.expiresAt > :now AND " + MINE_OR_FRIENDS +
                    "ORDER BY s.createdAt ASC", Story.class)
                .setParameter("now", LocalDateTime.now()).setParameter("me", viewerId)
                .getResultList();
            markSeen(em, stories, viewerId);

            // Gom theo tác giả, giữ thứ tự đăng
            Map<Integer, StoryRing> byUser = new LinkedHashMap<>();
            for (Story s : stories) {
                byUser.computeIfAbsent(s.getAuthor().getUserId(), k -> new StoryRing(s.getAuthor())).add(s);
            }
            List<StoryRing> rings = new ArrayList<>(byUser.values());
            rings.sort((a, b) -> {
                boolean ma = a.getUser().getUserId() == viewerId, mb = b.getUser().getUserId() == viewerId;
                if (ma != mb) return ma ? -1 : 1;                                   // của mình đứng đầu
                if (a.isHasUnseen() != b.isHasUnseen()) return a.isHasUnseen() ? -1 : 1;   // còn tin chưa xem trước
                return b.getLatestAt().compareTo(a.getLatestAt());                  // mới nhất trước
            });
            return rings;
        } finally {
            em.close();
        }
    }

    @Override
    public List<Story> getActiveStoriesOf(int ownerId, int viewerId) {
        if (!canViewStoriesOf(ownerId, viewerId)) return null;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Story> stories = em.createQuery(
                    "SELECT s FROM Story s JOIN FETCH s.author WHERE s.author.userId = :uid AND s.expiresAt > :now " +
                    "ORDER BY s.createdAt ASC, s.storyId ASC", Story.class)
                .setParameter("uid", ownerId).setParameter("now", LocalDateTime.now())
                .getResultList();
            markSeen(em, stories, viewerId);
            if (ownerId == viewerId) attachCounts(em, stories);   // chủ tin: số người xem + số tim
            else markLiked(em, stories, viewerId);                // người xem: đã thả tim chưa
            return stories;
        } finally {
            em.close();
        }
    }

    @Override
    public Story getActiveStory(int storyId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Story> r = em.createQuery("SELECT s FROM Story s JOIN FETCH s.author WHERE s.storyId = :id AND s.expiresAt > :now", Story.class)
                              .setParameter("id", storyId).setParameter("now", LocalDateTime.now()).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public boolean canViewStoriesOf(int ownerId, int viewerId) {
        if (ownerId == viewerId) return true;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(f) FROM Friendship f WHERE f.status = 'accepted' AND " +
                                  "((f.requester.userId = :a AND f.receiver.userId = :b) OR " +
                                  " (f.requester.userId = :b AND f.receiver.userId = :a))", Long.class)
                     .setParameter("a", ownerId).setParameter("b", viewerId)
                     .getSingleResult() > 0;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean markViewed(int storyId, int viewerId) {
        Story s = getActiveStory(storyId);
        if (s == null || s.getAuthor().getUserId() == viewerId
                || !canViewStoriesOf(s.getAuthor().getUserId(), viewerId)) return false;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createNativeQuery(
                    "INSERT INTO story_views (story_id, viewer_id, viewed_at) SELECT :s, :v, :at " +
                    "WHERE NOT EXISTS (SELECT 1 FROM story_views WHERE story_id = :s AND viewer_id = :v)")
                .setParameter("s", storyId).setParameter("v", viewerId)
                .setParameter("at", Timestamp.valueOf(LocalDateTime.now()))
                .executeUpdate();
            em.getTransaction().commit();
            return n == 1;
        } catch (PersistenceException e) {
            // Hai tab cùng ghi một lượt xem → trùng khóa chính: coi như đã xem
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            return false;
        } finally {
            em.close();
        }
    }

    @Override
    public List<Object[]> getViewers(int storyId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            @SuppressWarnings("unchecked")
            List<Object[]> rows = em.createNativeQuery(
                    "SELECT v.viewer_id, v.viewed_at, CASE WHEN r.user_id IS NULL THEN 0 ELSE 1 END " +
                    "FROM story_views v LEFT JOIN story_reactions r ON r.story_id = v.story_id AND r.user_id = v.viewer_id " +
                    "WHERE v.story_id = :s ORDER BY CASE WHEN r.user_id IS NULL THEN 1 ELSE 0 END, v.viewed_at DESC")
                .setParameter("s", storyId).getResultList();
            if (rows.isEmpty()) return new ArrayList<>();
            List<Integer> ids = new ArrayList<>();
            for (Object[] r : rows) ids.add(((Number) r[0]).intValue());
            Map<Integer, User> users = new HashMap<>();
            for (User u : em.createQuery("SELECT u FROM User u WHERE u.userId IN :ids", User.class)
                            .setParameter("ids", ids).getResultList()) users.put(u.getUserId(), u);
            List<Object[]> result = new ArrayList<>();
            for (Object[] r : rows) {
                User u = users.get(((Number) r[0]).intValue());
                if (u != null) result.add(new Object[]{ u, ((Timestamp) r[1]).toLocalDateTime(), ((Number) r[2]).intValue() == 1 });
            }
            return result;
        } finally {
            em.close();
        }
    }

    @Override
    public String delete(int storyId, int ownerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            List<String> paths = em.createQuery("SELECT s.mediaPath FROM Story s WHERE s.storyId = :id AND s.author.userId = :uid", String.class)
                                   .setParameter("id", storyId).setParameter("uid", ownerId).getResultList();
            if (paths.isEmpty()) { em.getTransaction().rollback(); return null; }
            // story_views xóa theo (ON DELETE CASCADE)
            em.createQuery("DELETE FROM Story s WHERE s.storyId = :id").setParameter("id", storyId).executeUpdate();
            em.getTransaction().commit();
            return paths.get(0);
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public Boolean toggleReaction(int storyId, int userId) {
        Story s = getActiveStory(storyId);
        if (s == null || s.getAuthor().getUserId() == userId || !canViewStoriesOf(s.getAuthor().getUserId(), userId)) return null;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int removed = em.createNativeQuery("DELETE FROM story_reactions WHERE story_id = :s AND user_id = :u")
                            .setParameter("s", storyId).setParameter("u", userId).executeUpdate();
            if (removed == 0) {
                Timestamp now = Timestamp.valueOf(LocalDateTime.now());
                em.createNativeQuery("INSERT INTO story_reactions (story_id, user_id, created_at) VALUES (:s, :u, :at)")
                  .setParameter("s", storyId).setParameter("u", userId).setParameter("at", now).executeUpdate();
                // Thả tim nghĩa là đã xem — ghi luôn lượt xem nếu chưa có
                em.createNativeQuery("INSERT INTO story_views (story_id, viewer_id, viewed_at) SELECT :s, :u, :at " +
                                     "WHERE NOT EXISTS (SELECT 1 FROM story_views WHERE story_id = :s AND viewer_id = :u)")
                  .setParameter("s", storyId).setParameter("u", userId).setParameter("at", now).executeUpdate();
            }
            em.getTransaction().commit();
            return removed == 0;
        } catch (PersistenceException e) {
            // Bấm 2 lần cùng lúc → trùng khóa chính: coi như đã thả tim
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            return true;
        } finally {
            em.close();
        }
    }

    @Override
    public List<Story> getArchive(int ownerId, int offset, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Story> stories = em.createQuery(
                    "SELECT s FROM Story s JOIN FETCH s.author WHERE s.author.userId = :uid AND s.expiresAt <= :now " +
                    "ORDER BY s.createdAt DESC, s.storyId DESC", Story.class)
                .setParameter("uid", ownerId).setParameter("now", LocalDateTime.now())
                .setFirstResult(Math.max(offset, 0)).setMaxResults(limit)
                .getResultList();
            for (Story s : stories) s.setSeen(true);
            attachCounts(em, stories);
            return stories;
        } finally {
            em.close();
        }
    }

    @Override
    public int countArchive(int ownerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(s) FROM Story s WHERE s.author.userId = :uid AND s.expiresAt <= :now", Long.class)
                     .setParameter("uid", ownerId).setParameter("now", LocalDateTime.now())
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    /** Chủ tin: số người xem + số lượt thả tim của từng tin (2 truy vấn GROUP BY cho cả danh sách) */
    private static void attachCounts(EntityManager em, List<Story> stories) {
        if (stories.isEmpty()) return;
        Map<Integer, Story> byId = new HashMap<>();
        for (Story s : stories) byId.put(s.getStoryId(), s);
        List<Integer> ids = new ArrayList<>(byId.keySet());
        @SuppressWarnings("unchecked")
        List<Object[]> views = em.createNativeQuery(
                "SELECT story_id, COUNT(*) FROM story_views WHERE story_id IN (:ids) GROUP BY story_id")
            .setParameter("ids", ids).getResultList();
        for (Object[] r : views) byId.get(((Number) r[0]).intValue()).setViewCount(((Number) r[1]).intValue());
        @SuppressWarnings("unchecked")
        List<Object[]> hearts = em.createNativeQuery(
                "SELECT story_id, COUNT(*) FROM story_reactions WHERE story_id IN (:ids) GROUP BY story_id")
            .setParameter("ids", ids).getResultList();
        for (Object[] r : hearts) byId.get(((Number) r[0]).intValue()).setReactionCount(((Number) r[1]).intValue());
    }

    /** Người xem đã thả tim những tin nào */
    private static void markLiked(EntityManager em, List<Story> stories, int viewerId) {
        if (stories.isEmpty()) return;
        List<Integer> ids = new ArrayList<>();
        for (Story s : stories) ids.add(s.getStoryId());
        @SuppressWarnings("unchecked")
        List<Number> liked = em.createNativeQuery(
                "SELECT story_id FROM story_reactions WHERE user_id = :v AND story_id IN (:ids)")
            .setParameter("v", viewerId).setParameter("ids", ids).getResultList();
        Set<Integer> set = new HashSet<>();
        for (Number n : liked) set.add(n.intValue());
        for (Story s : stories) s.setLiked(set.contains(s.getStoryId()));
    }

    /** Tin hết hạn của người ĐÃ TẮT "Lưu trữ tin" (người chưa từng lưu cài đặt = mặc định bật lưu trữ → giữ lại) */
    private static final String PURGEABLE =
        "s.expiresAt <= :t AND s.author.userId IN (SELECT us.userId FROM UserSettings us WHERE us.archiveStories = false)";

    @Override
    public List<String> purgeExpired(LocalDateTime before) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            List<String> paths = em.createQuery("SELECT s.mediaPath FROM Story s WHERE " + PURGEABLE, String.class)
                                   .setParameter("t", before).getResultList();
            if (!paths.isEmpty()) {
                // story_views + story_reactions xóa theo (ON DELETE CASCADE)
                em.createNativeQuery("DELETE FROM stories WHERE expires_at <= :t AND user_id IN " +
                                     "(SELECT user_id FROM user_settings WHERE archive_stories = 0)")
                  .setParameter("t", Timestamp.valueOf(before)).executeUpdate();
            }
            em.getTransaction().commit();
            return paths;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    /** Gắn cờ seen cho danh sách tin theo người xem (tin của chính mình luôn coi là đã xem) */
    private static void markSeen(EntityManager em, List<Story> stories, int viewerId) {
        if (stories.isEmpty()) return;
        List<Integer> ids = new ArrayList<>();
        for (Story s : stories) ids.add(s.getStoryId());
        @SuppressWarnings("unchecked")
        List<Number> seen = em.createNativeQuery(
                "SELECT story_id FROM story_views WHERE viewer_id = :v AND story_id IN (:ids)")
            .setParameter("v", viewerId).setParameter("ids", ids).getResultList();
        Set<Integer> seenIds = new HashSet<>();
        for (Number n : seen) seenIds.add(n.intValue());
        for (Story s : stories) {
            s.setSeen(s.getAuthor().getUserId() == viewerId || seenIds.contains(s.getStoryId()));
        }
    }
}
