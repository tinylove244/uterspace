package com.uterspace.security;

import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * WebAuthnDAO — bảng webauthn_credentials (migration 090). Chỉ lưu KHÓA CÔNG KHAI, không có dữ liệu sinh trắc học.
 * SQL gốc đơn giản (giống StoryDAOImpl với story_views) — bảng nhỏ, không cần entity.
 */
public class WebAuthnDAO {

    private static final String COLS = "id, user_id, credential_id, public_key, alg, sign_count, label, created_at, last_used_at";

    public List<Passkey> listFor(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            @SuppressWarnings("unchecked")
            List<Object[]> rows = em.createNativeQuery("SELECT " + COLS + " FROM webauthn_credentials WHERE user_id = :u ORDER BY created_at DESC")
                                    .setParameter("u", userId).getResultList();
            List<Passkey> out = new ArrayList<>();
            for (Object[] r : rows) out.add(map(r));
            return out;
        } catch (RuntimeException e) {
            return new ArrayList<>();   // chưa chạy migration 090 → coi như chưa có passkey, trang Cài đặt vẫn mở được
        } finally {
            em.close();
        }
    }

    public int countFor(int userId) { return listFor(userId).size(); }

    public Passkey findByCredentialId(String credentialId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            @SuppressWarnings("unchecked")
            List<Object[]> rows = em.createNativeQuery("SELECT " + COLS + " FROM webauthn_credentials WHERE credential_id = :c")
                                    .setParameter("c", credentialId).getResultList();
            return rows.isEmpty() ? null : map(rows.get(0));
        } finally {
            em.close();
        }
    }

    public void add(int userId, String credentialId, byte[] publicKey, int alg, long signCount, String label) {
        exec("INSERT INTO webauthn_credentials (user_id, credential_id, public_key, alg, sign_count, label, created_at) " +
             "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
             userId, credentialId, publicKey, alg, signCount, label, Timestamp.valueOf(LocalDateTime.now()));
    }

    public void touch(int id, long signCount) {
        exec("UPDATE webauthn_credentials SET sign_count = ?1, last_used_at = ?2 WHERE id = ?3",
             signCount, Timestamp.valueOf(LocalDateTime.now()), id);
    }

    public boolean delete(int id, int userId) {
        return exec("DELETE FROM webauthn_credentials WHERE id = ?1 AND user_id = ?2", id, userId) == 1;
    }

    private static int exec(String sql, Object... params) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            javax.persistence.Query q = em.createNativeQuery(sql);
            for (int i = 0; i < params.length; i++) q.setParameter(i + 1, params[i]);
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

    private static Passkey map(Object[] r) {
        Passkey p = new Passkey();
        p.setId(((Number) r[0]).intValue());
        p.setUserId(((Number) r[1]).intValue());
        p.setCredentialId((String) r[2]);
        p.setPublicKey((byte[]) r[3]);
        p.setAlg(((Number) r[4]).intValue());
        p.setSignCount(((Number) r[5]).longValue());
        p.setLabel((String) r[6]);
        p.setCreatedAt(r[7] == null ? null : ((Timestamp) r[7]).toLocalDateTime());
        p.setLastUsedAt(r[8] == null ? null : ((Timestamp) r[8]).toLocalDateTime());
        return p;
    }
}
