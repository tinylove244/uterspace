package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity: Story — một "tin" (ảnh HOẶC video) tồn tại 24 giờ (bảng stories, migration 050).
 * Chỉ chủ tin và bạn bè được xem (kiểm tra ở StoryDAO).
 */
@Entity
@Table(name = "stories")
public class Story {

    public static final String TYPE_IMAGE = "IMAGE";
    public static final String TYPE_VIDEO = "VIDEO";

    /** Thời gian sống của một tin */
    public static final int LIFETIME_HOURS = 24;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "story_id")
    private int storyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User author;

    @Column(name = "media_path")
    private String mediaPath;

    @Column(name = "media_type")
    private String mediaType;

    private String caption;

    @Column(name = "duration_sec")
    private Integer durationSec;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    // ---------- Trạng thái theo người xem (không lưu DB) ----------
    @Transient
    private boolean seen;        // người xem hiện tại đã xem tin này chưa

    @Transient
    private int viewCount;       // số người đã xem (chỉ tính cho chủ tin)

    @Transient
    private boolean liked;       // người xem hiện tại đã thả tim tin này chưa

    @Transient
    private int reactionCount;   // số lượt thả tim (chỉ tính cho chủ tin)

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (expiresAt == null) expiresAt = createdAt.plusHours(LIFETIME_HOURS);
    }

    public boolean isVideo() { return TYPE_VIDEO.equals(mediaType); }

    /** URL tính từ context path — JSP/JS: ctx + mediaUrl */
    public String getMediaUrl() { return com.uterspace.util.MediaUrl.of(mediaPath); }

    public int getStoryId() { return storyId; }
    public void setStoryId(int storyId) { this.storyId = storyId; }
    public User getAuthor() { return author; }
    public void setAuthor(User author) { this.author = author; }
    public String getMediaPath() { return mediaPath; }
    public void setMediaPath(String mediaPath) { this.mediaPath = mediaPath; }
    public String getMediaType() { return mediaType; }
    public void setMediaType(String mediaType) { this.mediaType = mediaType; }
    public String getCaption() { return caption; }
    public void setCaption(String caption) { this.caption = caption; }
    public Integer getDurationSec() { return durationSec; }
    public void setDurationSec(Integer durationSec) { this.durationSec = durationSec; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDateTime expiresAt) { this.expiresAt = expiresAt; }
    public boolean isSeen() { return seen; }
    public void setSeen(boolean seen) { this.seen = seen; }
    public int getViewCount() { return viewCount; }
    public boolean isLiked() { return liked; }
    public void setLiked(boolean liked) { this.liked = liked; }
    public int getReactionCount() { return reactionCount; }
    public void setReactionCount(int reactionCount) { this.reactionCount = reactionCount; }
    public boolean isExpired() { return expiresAt != null && !expiresAt.isAfter(LocalDateTime.now()); }
    public String getFormattedCreatedAt() {
        return createdAt == null ? "" : createdAt.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm"));
    }
    public void setViewCount(int viewCount) { this.viewCount = viewCount; }
}
