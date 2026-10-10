package com.uterspace.dao;

import com.uterspace.model.Post;
import com.uterspace.model.SavedPost;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.TypedQuery;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * SavedPostDAOImpl — Implementation của SavedPostDAO dùng JPA.
 */
public class SavedPostDAOImpl implements SavedPostDAO {

    @Override
    public List<Post> getSavedPosts(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // Bài đã bị ẩn/xóa hoặc không còn quyền xem thì không hiện trong mục đã lưu (quy tắc VISIBLE)
            String jpql = "SELECT sp FROM SavedPost sp JOIN FETCH sp.post p JOIN FETCH p.author " +
                          "WHERE sp.user.userId = :me AND " + PostDAOImpl.VISIBLE +
                          "ORDER BY sp.savedAt DESC";
            List<SavedPost> savedPosts = em.createQuery(jpql, SavedPost.class)
                                           .setParameter("me", userId)
                                           .getResultList();
            
            List<Post> posts = new ArrayList<>();
            for (SavedPost sp : savedPosts) {
                Post p = sp.getPost();
                p.setSavedAt(sp.getSavedAt());
                posts.add(p);
            }
            return posts;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean isSaved(int postId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            TypedQuery<Long> q = em.createQuery("SELECT COUNT(sp) FROM SavedPost sp WHERE sp.post.postId = :postId AND sp.user.userId = :userId", Long.class);
            q.setParameter("postId", postId);
            q.setParameter("userId", userId);
            return q.getSingleResult() > 0;
        } finally {
            em.close();
        }
    }

    @Override
    public void savePost(int postId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            
            // Kiểm tra xem đã lưu chưa
            TypedQuery<Long> q = em.createQuery("SELECT COUNT(sp) FROM SavedPost sp WHERE sp.post.postId = :postId AND sp.user.userId = :userId", Long.class);
            q.setParameter("postId", postId);
            q.setParameter("userId", userId);
            if (q.getSingleResult() == 0) {
                SavedPost sp = new SavedPost();
                sp.setPost(em.find(Post.class, postId));
                sp.setUser(em.find(User.class, userId));
                sp.setSavedAt(LocalDateTime.now());
                em.persist(sp);
            }
            
            em.getTransaction().commit();
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("SavedPostDAOImpl.savePost lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public void unsavePost(int postId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            
            TypedQuery<SavedPost> q = em.createQuery("SELECT sp FROM SavedPost sp WHERE sp.post.postId = :postId AND sp.user.userId = :userId", SavedPost.class);
            q.setParameter("postId", postId);
            q.setParameter("userId", userId);
            List<SavedPost> savedPosts = q.getResultList();
            
            if (!savedPosts.isEmpty()) {
                em.remove(savedPosts.get(0));
            }
            
            em.getTransaction().commit();
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("SavedPostDAOImpl.unsavePost lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }
}
