package com.uterspace.dao;

import com.uterspace.model.Like;
import com.uterspace.model.Post;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.TypedQuery;
import java.time.LocalDateTime;
import java.util.List;

/** LikeDAOImpl — Implementation của LikeDAO dùng JPA */
public class LikeDAOImpl implements LikeDAO {

    @Override
    public boolean isLikedBy(int postId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            TypedQuery<Long> q = em.createQuery("SELECT COUNT(l) FROM Like l WHERE l.post.postId = :postId AND l.user.userId = :userId", Long.class);
            q.setParameter("postId", postId);
            q.setParameter("userId", userId);
            return q.getSingleResult() > 0;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean toggleLike(int postId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        boolean result;
        try {
            em.getTransaction().begin();
            
            TypedQuery<Like> q = em.createQuery("SELECT l FROM Like l WHERE l.post.postId = :postId AND l.user.userId = :userId", Like.class);
            q.setParameter("postId", postId);
            q.setParameter("userId", userId);
            List<Like> likes = q.getResultList();
            
            Post post = em.find(Post.class, postId);
            
            if (!likes.isEmpty()) {
                // Đã like -> Xóa like
                em.remove(likes.get(0));
                if (post != null && post.getLikeCount() > 0) {
                    post.setLikeCount(post.getLikeCount() - 1);
                    em.merge(post);
                }
                result = false;
            } else {
                // Chưa like -> Thêm like
                User user = em.find(User.class, userId);
                Like like = new Like();
                like.setPost(post);
                like.setUser(user);
                like.setCreatedAt(LocalDateTime.now());
                em.persist(like);
                
                if (post != null) {
                    post.setLikeCount(post.getLikeCount() + 1);
                    em.merge(post);
                }
                result = true;
            }
            
            em.getTransaction().commit();
            return result;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("LikeDAOImpl.toggleLike lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public int getLikeCount(int postId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            Post post = em.find(Post.class, postId);
            return post != null ? post.getLikeCount() : 0;
        } finally {
            em.close();
        }
    }
}
