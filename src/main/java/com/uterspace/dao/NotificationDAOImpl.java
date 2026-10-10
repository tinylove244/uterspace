package com.uterspace.dao;

import com.uterspace.model.Notification;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.TypedQuery;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** NotificationDAOImpl — Implementation của NotificationDAO dùng JPA */
public class NotificationDAOImpl implements NotificationDAO {

    @Override
    public List<Notification> getNotificationsFor(int userId) {
        return getPage(userId, null, false, 0, 500);
    }

    private static String where(List<String> types, boolean unreadOnly) {
        return " WHERE n.userId = :uid" + (types != null ? " AND n.type IN :types" : "") + (unreadOnly ? " AND n.read = false" : "") + " ";
    }

    private static <T> TypedQuery<T> bind(TypedQuery<T> q, int userId, List<String> types) {
        q.setParameter("uid", userId);
        if (types != null) q.setParameter("types", types);
        return q;
    }

    @Override
    public List<Notification> getPage(int userId, List<String> types, boolean unreadOnly, int offset, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return bind(em.createQuery("SELECT n FROM Notification n JOIN FETCH n.actor" + where(types, unreadOnly) +
                                       "ORDER BY n.createdAt DESC, n.notificationId DESC", Notification.class), userId, types)
                     .setFirstResult(offset).setMaxResults(limit).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public int count(int userId, List<String> types, boolean unreadOnly) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return bind(em.createQuery("SELECT COUNT(n) FROM Notification n" + where(types, unreadOnly), Long.class), userId, types)
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public int getUnreadNotificationCount(int userId) {
        return count(userId, null, true);
    }

    @Override
    public Map<String, Integer> unreadByType(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            Map<String, Integer> map = new HashMap<>();
            for (Object[] r : em.createQuery("SELECT n.type, COUNT(n) FROM Notification n WHERE n.userId = :uid AND n.read = false " +
                                             "GROUP BY n.type", Object[].class).setParameter("uid", userId).getResultList()) {
                map.put((String) r[0], ((Long) r[1]).intValue());
            }
            return map;
        } finally {
            em.close();
        }
    }

    @Override
    public Notification getById(int userId, int notificationId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Notification> r = em.createQuery("SELECT n FROM Notification n JOIN FETCH n.actor " +
                                                  "WHERE n.notificationId = :id AND n.userId = :uid", Notification.class)
                                     .setParameter("id", notificationId).setParameter("uid", userId).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public void markAllAsRead(int userId) {
        execute("UPDATE Notification n SET n.read = true WHERE n.userId = :uid AND n.read = false", userId, null, null);
    }

    @Override
    public boolean setRead(int userId, int notificationId, boolean read) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("UPDATE Notification n SET n.read = :r WHERE n.notificationId = :id AND n.userId = :uid")
                      .setParameter("r", read).setParameter("id", notificationId).setParameter("uid", userId).executeUpdate();
            em.getTransaction().commit();
            return n == 1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public int markReadByRef(int userId, String refKey) {
        return execute("UPDATE Notification n SET n.read = true WHERE n.userId = :uid AND n.refKey = :ref AND n.read = false",
                       userId, "ref", refKey);
    }

    @Override
    public boolean delete(int userId, int notificationId) {
        return execute("DELETE FROM Notification n WHERE n.userId = :uid AND n.notificationId = :id", userId, "id", notificationId) == 1;
    }

    @Override
    public int deleteRead(int userId) {
        return execute("DELETE FROM Notification n WHERE n.userId = :uid AND n.read = true", userId, null, null);
    }

    @Override
    public int deleteByRef(int userId, String refKey) {
        return execute("DELETE FROM Notification n WHERE n.userId = :uid AND n.refKey = :ref", userId, "ref", refKey);
    }

    @Override
    public boolean existsSince(int userId, String refKey, LocalDateTime since) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(n) FROM Notification n WHERE n.userId = :uid AND n.refKey = :ref AND n.createdAt >= :since", Long.class)
                     .setParameter("uid", userId).setParameter("ref", refKey).setParameter("since", since)
                     .getSingleResult() > 0;
        } finally {
            em.close();
        }
    }

    @Override
    public Notification findUnreadByRef(int userId, String refKey) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Notification> r = em.createQuery("SELECT n FROM Notification n WHERE n.userId = :uid AND n.refKey = :ref " +
                                                  "AND n.read = false ORDER BY n.notificationId DESC", Notification.class)
                                     .setParameter("uid", userId).setParameter("ref", refKey).setMaxResults(1).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public void refreshAggregated(int notificationId, int actorId, String content, LocalDateTime at) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Notification n = em.find(Notification.class, notificationId);
            if (n != null) {
                n.setActor(em.getReference(User.class, actorId));
                n.setContent(content);
                n.setCreatedAt(at);
            }
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public void createNotification(Notification notif) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            if (notif.getCreatedAt() == null) notif.setCreatedAt(LocalDateTime.now());
            if (notif.getActor() != null && notif.getActor().getUserId() > 0) {
                notif.setActor(em.find(User.class, notif.getActor().getUserId()));
            }
            em.persist(notif);
            em.getTransaction().commit();
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("NotificationDAOImpl.createNotification lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public void notifyUsers(List<Integer> userIds, int actorId, String type, String content, String targetUrl) {
        if (userIds == null || userIds.isEmpty()) return;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            User actor = em.getReference(User.class, actorId);
            LocalDateTime now = LocalDateTime.now();
            for (Integer uid : userIds) {
                Notification n = new Notification();
                n.setUserId(uid);
                n.setActor(actor);
                n.setType(type);
                n.setContent(content);
                n.setTargetUrl(targetUrl);
                n.setCreatedAt(now);
                em.persist(n);
            }
            em.getTransaction().commit();
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("NotificationDAOImpl.notifyUsers lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    /** UPDATE/DELETE theo userId (+ một tham số tùy chọn) trong transaction riêng */
    private int execute(String jpql, int userId, String pName, Object pValue) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            javax.persistence.Query q = em.createQuery(jpql).setParameter("uid", userId);
            if (pName != null) q.setParameter(pName, pValue);
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
