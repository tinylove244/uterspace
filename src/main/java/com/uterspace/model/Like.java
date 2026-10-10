package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity: Like
 * Lượt thích của User cho Post.
 */
@Entity
@Table(name = "likes")
public class Like {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "like_id")
    private int likeId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id")
    private Post post;

    @Transient
    private int userId;

    @Transient
    private int postId;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public Like() {}

    public Like(int userId, int postId, LocalDateTime createdAt) {
        this.userId = userId;
        this.postId = postId;
        this.createdAt = createdAt;
    }

    // ---------- Getters & Setters ----------
    
    public int getLikeId() { return likeId; }
    public void setLikeId(int likeId) { this.likeId = likeId; }

    public int getUserId() { 
        if (user != null) return user.getUserId();
        return userId; 
    }
    public void setUserId(int userId) { this.userId = userId; }

    public int getPostId() { 
        if (post != null) return post.getPostId();
        return postId; 
    }
    public void setPostId(int postId) { this.postId = postId; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public Post getPost() { return post; }
    public void setPost(Post post) { this.post = post; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
