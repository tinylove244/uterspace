package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity: Comment
 * Bình luận dưới bài viết.
 */
@Entity
@Table(name = "comments")
public class Comment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "comment_id")
    private int commentId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id")
    private Post post;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User author;

    @Transient
    private int postId;     // tạm dùng cho form

    @Transient
    private int userId;     // tạm dùng cho form

    private String content;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    public Comment() {}

    public Comment(int commentId, int postId, int userId,
                   String content, LocalDateTime createdAt) {
        this.commentId = commentId;
        this.postId = postId;
        this.userId = userId;
        this.content = content;
        this.createdAt = createdAt;
    }

    // ---------- Getters & Setters ----------

    public String getFormattedCreatedAt() {
        return createdAt == null ? "" : createdAt.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
    }

    public int getCommentId() { return commentId; }
    public void setCommentId(int commentId) { this.commentId = commentId; }

    public int getPostId() { 
        if (post != null) return post.getPostId();
        return postId; 
    }
    public void setPostId(int postId) { this.postId = postId; }

    public int getUserId() { 
        if (author != null) return author.getUserId();
        return userId; 
    }
    public void setUserId(int userId) { this.userId = userId; }

    public Post getPost() { return post; }
    public void setPost(Post post) { this.post = post; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public User getAuthor() { return author; }
    public void setAuthor(User author) { this.author = author; }
}
