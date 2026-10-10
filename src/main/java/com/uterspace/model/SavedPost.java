package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "saved_posts")
public class SavedPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "saved_id")
    private int savedId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id")
    private Post post;

    @Column(name = "saved_at")
    private LocalDateTime savedAt;

    public SavedPost() {}

    public int getSavedId() { return savedId; }
    public void setSavedId(int savedId) { this.savedId = savedId; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public Post getPost() { return post; }
    public void setPost(Post post) { this.post = post; }

    public LocalDateTime getSavedAt() { return savedAt; }
    public void setSavedAt(LocalDateTime savedAt) { this.savedAt = savedAt; }
}
