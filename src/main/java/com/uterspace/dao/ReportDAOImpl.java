package com.uterspace.dao;

import com.uterspace.model.Report;
import com.uterspace.model.ReportGroup;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceException;
import java.time.LocalDateTime;
import java.util.*;

/** ReportDAOImpl — Implementation của ReportDAO dùng JPA */
public class ReportDAOImpl implements ReportDAO {

    @Override
    public boolean create(int reporterId, String targetType, int targetId, String reason, String detail) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Report r = new Report();
            r.setReporter(em.getReference(User.class, reporterId));
            r.setTargetType(targetType);
            r.setTargetId(targetId);
            r.setReason(reason);
            r.setDetail(detail);
            em.persist(r);
            em.flush();   // lỗi UNIQUE (đã báo cáo rồi) nổ ra ở đây
            em.getTransaction().commit();
            return true;
        } catch (PersistenceException e) {
            // UNIQUE (reporter_id, target_type, target_id): transaction hỏng → rollback, bỏ EM này
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            return false;
        } finally {
            em.close();
        }
    }

    @Override
    public List<ReportGroup> getPendingGroups(int page, int pageSize) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<ReportGroup> groups = new ArrayList<>();
            for (Object[] row : em.createQuery(
                    "SELECT r.targetType, r.targetId, COUNT(r), MAX(r.createdAt) FROM Report r " +
                    "WHERE r.status = 'PENDING' GROUP BY r.targetType, r.targetId " +
                    "ORDER BY COUNT(r) DESC, MAX(r.createdAt) DESC", Object[].class)
                    .setFirstResult((Math.max(page, 1) - 1) * pageSize)
                    .setMaxResults(pageSize)
                    .getResultList()) {
                groups.add(new ReportGroup((String) row[0], (Integer) row[1], ((Long) row[2]).intValue(), (LocalDateTime) row[3]));
            }
            // Chi tiết từng nhóm (người báo cáo, lý do) — tối đa pageSize truy vấn nhỏ
            for (ReportGroup g : groups) {
                g.getReports().addAll(em.createQuery(
                        "SELECT r FROM Report r JOIN FETCH r.reporter WHERE r.status = 'PENDING' " +
                        "AND r.targetType = :t AND r.targetId = :id ORDER BY r.createdAt DESC", Report.class)
                    .setParameter("t", g.getTargetType()).setParameter("id", g.getTargetId())
                    .getResultList());
            }
            return groups;
        } finally {
            em.close();
        }
    }

    @Override
    public int countPendingGroups() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // Số cặp (targetType, targetId) khác nhau — đếm nhóm GROUP BY
            return em.createQuery("SELECT r.targetType, r.targetId FROM Report r WHERE r.status = 'PENDING' " +
                                  "GROUP BY r.targetType, r.targetId", Object[].class)
                     .getResultList().size();
        } finally {
            em.close();
        }
    }

    @Override
    public int countPending() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(r) FROM Report r WHERE r.status = 'PENDING'", Long.class)
                     .getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public int closeReports(String targetType, int targetId, String status, int adminId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("UPDATE Report r SET r.status = :st, r.handledBy = :admin, r.handledAt = :now " +
                                   "WHERE r.status = 'PENDING' AND r.targetType = :t AND r.targetId = :id")
                      .setParameter("st", status).setParameter("admin", adminId)
                      .setParameter("now", LocalDateTime.now())
                      .setParameter("t", targetType).setParameter("id", targetId)
                      .executeUpdate();
            em.getTransaction().commit();
            return n;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public Map<Integer, Integer> countPendingByPost(List<Integer> postIds) {
        Map<Integer, Integer> result = new HashMap<>();
        if (postIds == null || postIds.isEmpty()) return result;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            for (Object[] row : em.createQuery(
                    "SELECT r.targetId, COUNT(r) FROM Report r WHERE r.status = 'PENDING' AND r.targetType = 'POST' " +
                    "AND r.targetId IN :ids GROUP BY r.targetId", Object[].class)
                    .setParameter("ids", postIds).getResultList()) {
                result.put((Integer) row[0], ((Long) row[1]).intValue());
            }
            return result;
        } finally {
            em.close();
        }
    }

    @Override
    public List<String> pendingReasons(String targetType, int targetId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT DISTINCT r.reason FROM Report r WHERE r.status = 'PENDING' " +
                                  "AND r.targetType = :t AND r.targetId = :id", String.class)
                     .setParameter("t", targetType).setParameter("id", targetId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<Report> getRecent(int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT r FROM Report r JOIN FETCH r.reporter ORDER BY r.createdAt DESC", Report.class)
                     .setMaxResults(limit).getResultList();
        } finally {
            em.close();
        }
    }
}
