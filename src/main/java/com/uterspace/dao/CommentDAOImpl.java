package com.uterspace.dao;

import com.uterspace.model.Comment;
import com.uterspace.model.Post;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.time.LocalDateTime;
import java.util.List;

/** CommentDAOImpl — Implementation của CommentDAO dùng JPA */
public class CommentDAOImpl implements CommentDAO {

    @Override
    public List<Comment> getCommentsByPostId(int postId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT c FROM Comment c JOIN FETCH c.author WHERE c.post.postId = :postId ORDER BY c.createdAt ASC", Comment.class)
                     .setParameter("postId", postId)
                     .getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public Comment addComment(int postId, int userId, String content) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            
            Post post = em.find(Post.class, postId);
            User author = em.find(User.class, userId);
            
            Comment comment = new Comment();
            comment.setPost(post);
            comment.setAuthor(author);
            comment.setContent(content);
            comment.setCreatedAt(LocalDateTime.now());
            
            em.persist(comment);
            
            // Tăng comment_count trong bảng posts
            if (post != null) {
                post.setCommentCount(post.getCommentCount() + 1);
                em.merge(post);
            }
            
            em.getTransaction().commit();
            return comment;
        } catch (Exception e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw new RuntimeException("CommentDAOImpl.addComment lỗi: " + e.getMessage(), e);
        } finally {
            em.close();
        }
    }

    @Override
    public Comment getCommentById(int commentId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Comment> r = em.createQuery("SELECT c FROM Comment c JOIN FETCH c.author JOIN FETCH c.post WHERE c.commentId = :id", Comment.class)
                                .setParameter("id", commentId).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public boolean deleteComment(int commentId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            List<Integer> postIds = em.createQuery("SELECT c.post.postId FROM Comment c WHERE c.commentId = :id", Integer.class)
                                      .setParameter("id", commentId).getResultList();
            int n = em.createQuery("DELETE FROM Comment c WHERE c.commentId = :id")
                      .setParameter("id", commentId).executeUpdate();
            if (n == 1 && !postIds.isEmpty()) {
                em.createQuery("UPDATE Post p SET p.commentCount = p.commentCount - 1 WHERE p.postId = :pid AND p.commentCount > 0")
                  .setParameter("pid", postIds.get(0)).executeUpdate();
            }
            em.getTransaction().commit();
            return n == 1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }
}
