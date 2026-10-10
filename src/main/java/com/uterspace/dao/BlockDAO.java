package com.uterspace.dao;

import com.uterspace.model.UserBlock;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.util.*;

/**
 * BlockDAO — chặn người dùng (bảng user_blocks).
 * "Chặn" có hiệu lực HAI CHIỀU: A chặn B thì cả A lẫn B đều không thấy / không tương tác được với nhau.
 * Điều kiện JPQL dùng lại ở các truy vấn khác: NOT_BLOCKED(alias cột userId).
 */
public class BlockDAO {

    /**
     * Mảnh JPQL: người có id = {@code userIdExpr} KHÔNG chặn :me và KHÔNG bị :me chặn.
     * Ghép vào truy vấn bài viết (VISIBLE), tìm kiếm, gợi ý kết bạn...
     */
    public static String notBlocked(String userIdExpr) {
        return " (" + userIdExpr + " NOT IN (SELECT ub1.blockedId FROM UserBlock ub1 WHERE ub1.blockerId = :me)" +
               " AND " + userIdExpr + " NOT IN (SELECT ub2.blockerId FROM UserBlock ub2 WHERE ub2.blockedId = :me)) ";
    }

    /** Một trong hai đã chặn người kia */
    public boolean isBlockedEitherWay(int a, int b) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(b) FROM UserBlock b WHERE (b.blockerId = :a AND b.blockedId = :b) " +
                                  "OR (b.blockerId = :b AND b.blockedId = :a)", Long.class)
                     .setParameter("a", a).setParameter("b", b).getSingleResult() > 0;
        } finally {
            em.close();
        }
    }

    /** blocker đã chặn blocked (đúng chiều) */
    public boolean hasBlocked(int blocker, int blocked) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.find(UserBlock.class, new UserBlock.Key(blocker, blocked)) != null;
        } finally {
            em.close();
        }
    }

    /** Id những người có quan hệ chặn với uid (bất kể chiều) */
    public Set<Integer> blockedEitherWay(int uid) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            Set<Integer> ids = new HashSet<>(em.createQuery(
                    "SELECT b.blockedId FROM UserBlock b WHERE b.blockerId = :u", Integer.class)
                .setParameter("u", uid).getResultList());
            ids.addAll(em.createQuery("SELECT b.blockerId FROM UserBlock b WHERE b.blockedId = :u", Integer.class)
                         .setParameter("u", uid).getResultList());
            return ids;
        } finally {
            em.close();
        }
    }

    /**
     * Chặn: thêm dòng chặn và XÓA mọi quan hệ bạn bè / lời mời giữa hai người, trong MỘT transaction.
     * @return true nếu là lần chặn mới
     */
    public boolean block(int blocker, int blocked) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            boolean added = false;
            if (em.find(UserBlock.class, new UserBlock.Key(blocker, blocked)) == null) {
                em.persist(new UserBlock(blocker, blocked));
                added = true;
            }
            em.createQuery("DELETE FROM Friendship f WHERE (f.requester.userId = :a AND f.receiver.userId = :b) " +
                           "OR (f.requester.userId = :b AND f.receiver.userId = :a)")
              .setParameter("a", blocker).setParameter("b", blocked).executeUpdate();
            em.getTransaction().commit();
            return added;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    public boolean unblock(int blocker, int blocked) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("DELETE FROM UserBlock b WHERE b.blockerId = :a AND b.blockedId = :b")
                      .setParameter("a", blocker).setParameter("b", blocked).executeUpdate();
            em.getTransaction().commit();
            return n == 1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    /** Danh sách người mà blocker đã chặn (mới nhất trước) — trang Cài đặt */
    public List<UserBlock> listBlockedBy(int blocker) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT b FROM UserBlock b JOIN FETCH b.blocked WHERE b.blockerId = :u ORDER BY b.createdAt DESC",
                                  UserBlock.class)
                     .setParameter("u", blocker).getResultList();
        } finally {
            em.close();
        }
    }
}
