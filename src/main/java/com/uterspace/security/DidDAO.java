package com.uterspace.security;

import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** DidDAO — bảng user_dids (migration 090): mỗi tài khoản liên kết tối đa một did:key, chỉ lưu khóa công khai. */
public class DidDAO {

    /** Thông tin DID của một tài khoản */
    public static final class DidInfo {
        private final int userId;
        private final String did;
        private final LocalDateTime createdAt;
        DidInfo(int userId, String did, LocalDateTime createdAt) { this.userId = userId; this.did = did; this.createdAt = createdAt; }
        public int getUserId() { return userId; }
        public String getDid() { return did; }
        public String getShortDid() { return did.length() > 30 ? did.substring(0, 20) + "…" + did.substring(did.length() - 8) : did; }
        public String getFormattedCreatedAt() {
            return createdAt == null ? "" : createdAt.format(java.time.format.DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"));
        }
    }

    public DidInfo findByUser(int userId) {
        return one("SELECT user_id, did, created_at FROM user_dids WHERE user_id = ?1", userId);
    }

    public DidInfo findByDid(String did) {
        return one("SELECT user_id, did, created_at FROM user_dids WHERE did = ?1", did);
    }

    /** Số tài khoản đã liên kết DID (dashboard quản trị); 0 nếu chưa chạy migration 090 */
    public int countLinked() {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return ((Number) em.createNativeQuery("SELECT COUNT(*) FROM user_dids").getSingleResult()).intValue();
        } catch (RuntimeException e) {
            return 0;
        } finally {
            em.close();
        }
    }

    /** Trong các userId cho trước, những ai đã liên kết DID (huy hiệu ở bảng người dùng của admin) */
    public Set<Integer> linkedAmong(Collection<Integer> userIds) {
        Set<Integer> out = new HashSet<>();
        if (userIds == null || userIds.isEmpty()) return out;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            @SuppressWarnings("unchecked")
            List<Object> rows = em.createNativeQuery("SELECT user_id FROM user_dids WHERE user_id IN (:ids)")
                                  .setParameter("ids", userIds).getResultList();
            for (Object r : rows) out.add(((Number) r).intValue());
        } catch (RuntimeException e) {
            // chưa chạy migration 090
        } finally {
            em.close();
        }
        return out;
    }

    /** Liên kết (thay DID cũ nếu có). DID đã thuộc tài khoản khác → false */
    public boolean link(int userId, String did, byte[] publicKey) {
        DidInfo other = findByDid(did);
        if (other != null && other.getUserId() != userId) return false;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            em.createNativeQuery("DELETE FROM user_dids WHERE user_id = ?1").setParameter(1, userId).executeUpdate();
            em.createNativeQuery("INSERT INTO user_dids (user_id, did, public_key, created_at) VALUES (?1, ?2, ?3, ?4)")
              .setParameter(1, userId).setParameter(2, did).setParameter(3, publicKey)
              .setParameter(4, Timestamp.valueOf(LocalDateTime.now())).executeUpdate();
            em.getTransaction().commit();
            return true;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    public void unlink(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            em.createNativeQuery("DELETE FROM user_dids WHERE user_id = ?1").setParameter(1, userId).executeUpdate();
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    private static DidInfo one(String sql, Object param) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            @SuppressWarnings("unchecked")
            List<Object[]> rows = em.createNativeQuery(sql).setParameter(1, param).getResultList();
            if (rows.isEmpty()) return null;
            Object[] r = rows.get(0);
            return new DidInfo(((Number) r[0]).intValue(), (String) r[1], r[2] == null ? null : ((Timestamp) r[2]).toLocalDateTime());
        } catch (RuntimeException e) {
            return null;   // chưa chạy migration 090
        } finally {
            em.close();
        }
    }
}
