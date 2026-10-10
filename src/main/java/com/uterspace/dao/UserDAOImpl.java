package com.uterspace.dao;

import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.TypedQuery;
import java.util.List;

/**
 * UserDAOImpl — Implementation của UserDAO dùng JPA.
 */
public class UserDAOImpl implements UserDAO {

    @Override
    public List<User> getAllUsers() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT u FROM User u ORDER BY u.userId", User.class).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public User getUserById(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.find(User.class, userId);
        } finally {
            em.close();
        }
    }

    @Override
    public User findByEmail(String email) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            TypedQuery<User> q = em.createQuery("SELECT u FROM User u WHERE u.email = :email", User.class);
            q.setParameter("email", email);
            List<User> results = q.getResultList();
            return results.isEmpty() ? null : results.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public User createUser(User user) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            if (user.getRole() == null) user.setRole("USER");
            if (user.getCreatedAt() == null) user.setCreatedAt(java.time.LocalDateTime.now());
            em.persist(user);
            em.getTransaction().commit();
            return user;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("UserDAOImpl.createUser lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public boolean updateProfile(int userId, String bio, String website, String location) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            User u = em.find(User.class, userId);
            if (u != null) {
                u.setBio(bio);
                u.setWebsite(website);
                u.setLocation(location);
                em.getTransaction().commit();
                return true;
            }
            return false;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            return false;
        } finally {
            em.close();
        }
    }
    @Override
    public boolean updateAvatar(int userId, String avatarPath) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            User u = em.find(User.class, userId);
            if (u != null) {
                u.setAvatar(avatarPath);
                em.getTransaction().commit();
                return true;
            }
            return false;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            return false;
        } finally {
            em.close();
        }
    }

    // ---------- Quản trị ----------

    private static String filterClause(String filter) {
        switch (filter == null ? "all" : filter) {
            case "active": return " AND u.status = 'ACTIVE' ";
            case "locked": return " AND u.status = 'LOCKED' ";
            case "admin":  return " AND u.role = 'ADMIN' ";
            default:       return " ";
        }
    }

    private static final String USER_SEARCH =
        " WHERE (:q = '' OR LOWER(u.email) LIKE :like ESCAPE '!' OR LOWER(CONCAT(CONCAT(u.firstName, ' '), u.lastName)) LIKE :like ESCAPE '!') ";

    /** Chuỗi tìm kiếm → mẫu LIKE, thoát ký tự đặc biệt % _ [ bằng '!' */
    private static String likePattern(String q) {
        return "%" + q.replace("!", "!!").replace("%", "!%").replace("_", "!_").replace("[", "![") + "%";
    }

    @Override
    public List<User> searchUsers(String query, String filter, int page, int pageSize) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = query == null ? "" : query.trim().toLowerCase();
            return em.createQuery("SELECT u FROM User u" + USER_SEARCH + filterClause(filter) +
                                  "ORDER BY u.createdAt DESC, u.userId DESC", User.class)
                     .setParameter("q", q).setParameter("like", likePattern(q))
                     .setFirstResult((Math.max(page, 1) - 1) * pageSize)
                     .setMaxResults(pageSize)
                     .getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public int countSearchUsers(String query, String filter) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String q = query == null ? "" : query.trim().toLowerCase();
            return em.createQuery("SELECT COUNT(u) FROM User u" + USER_SEARCH + filterClause(filter), Long.class)
                     .setParameter("q", q).setParameter("like", likePattern(q))
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public void touchLastActive(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            em.createQuery("UPDATE User u SET u.lastActiveAt = :now WHERE u.userId = :uid")
              .setParameter("now", java.time.LocalDateTime.now()).setParameter("uid", userId).executeUpdate();
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean updatePasswordHash(int userId, String passwordHash) {
        return bulkUpdate("UPDATE User u SET u.passwordHash = :h WHERE u.userId = :uid", "h", passwordHash, null, null, userId);
    }

    @Override
    public boolean setStatus(int userId, String status, String reason) {
        return bulkUpdate("UPDATE User u SET u.status = :st, u.lockedReason = :reason WHERE u.userId = :uid",
                "st", status, "reason", User.STATUS_LOCKED.equals(status) ? reason : null, userId);
    }

    @Override
    public boolean setRole(int userId, String role) {
        return bulkUpdate("UPDATE User u SET u.role = :role WHERE u.userId = :uid", "role", role, null, null, userId);
    }

    private boolean bulkUpdate(String jpql, String p1, Object v1, String p2, Object v2, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            javax.persistence.Query q = em.createQuery(jpql).setParameter(p1, v1).setParameter("uid", userId);
            if (p2 != null) q.setParameter(p2, v2);
            int n = q.executeUpdate();
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
    public int countActiveAdmins() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(u) FROM User u WHERE u.role = 'ADMIN' AND u.status = 'ACTIVE'", Long.class)
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public int countUsers() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(u) FROM User u", Long.class).getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public List<java.time.LocalDateTime> getCreatedSince(java.time.LocalDateTime since) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT u.createdAt FROM User u WHERE u.createdAt >= :since", java.time.LocalDateTime.class)
                     .setParameter("since", since).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<User> getNewest(int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT u FROM User u ORDER BY u.createdAt DESC, u.userId DESC", User.class)
                     .setMaxResults(limit).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public boolean updateCover(int userId, String coverPath) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            User u = em.find(User.class, userId);
            if (u != null) {
                u.setCoverImage(coverPath);
                em.getTransaction().commit();
                return true;
            }
            return false;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            return false;
        } finally {
            em.close();
        }
    }
}
