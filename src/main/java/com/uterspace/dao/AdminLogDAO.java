package com.uterspace.dao;

import com.uterspace.model.AdminLog;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.TypedQuery;
import java.util.List;

/**
 * AdminLogDAO — nhật ký quản trị (bảng admin_logs): "ai làm gì, với đối tượng nào, lúc nào, từ IP nào".
 * Lớp nhỏ, chỉ ghi và đọc nên không tách interface.
 */
public class AdminLogDAO {

    public void log(int adminId, String action, String targetType, Integer targetId, String detail, String ip) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            AdminLog l = new AdminLog();
            l.setAdmin(em.getReference(com.uterspace.model.User.class, adminId));
            l.setAction(action);
            l.setTargetType(targetType);
            l.setTargetId(targetId);
            l.setDetail(detail != null && detail.length() > 500 ? detail.substring(0, 500) : detail);
            l.setIpAddress(ip != null && ip.length() > 45 ? ip.substring(0, 45) : ip);
            em.persist(l);
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    /** Trang nhật ký, mới nhất trước. action = null → mọi loại thao tác */
    public List<AdminLog> getPage(String action, int page, int pageSize) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            TypedQuery<AdminLog> q = em.createQuery("SELECT l FROM AdminLog l JOIN FETCH l.admin" +
                    (action != null ? " WHERE l.action = :a" : "") + " ORDER BY l.createdAt DESC, l.logId DESC", AdminLog.class);
            if (action != null) q.setParameter("a", action);
            return q.setFirstResult((Math.max(page, 1) - 1) * pageSize).setMaxResults(pageSize).getResultList();
        } finally {
            em.close();
        }
    }

    public int count(String action) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            TypedQuery<Long> q = em.createQuery("SELECT COUNT(l) FROM AdminLog l" +
                    (action != null ? " WHERE l.action = :a" : ""), Long.class);
            if (action != null) q.setParameter("a", action);
            return q.getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    public List<AdminLog> getRecent(int limit) {
        return getPage(null, 1, limit);
    }
}
