package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Entity: Post
 * Bài viết của User. visibility: "public" | "friends"
 */
@Entity
@Table(name = "posts")
public class Post {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "post_id")
    private int postId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User author;

    @Transient
    private int userId;           // Dùng tạm cho các form set ID vào

    private String content;

    @Column(name = "image_path")
    private String imagePath;     // null nếu bài text only

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    private String visibility;    // "public" | "friends"

    @Column(name = "like_count")
    private int likeCount;

    @Column(name = "comment_count")
    private int commentCount;

    @Column(name = "share_count")
    private int shareCount;

    @Column(name = "media_type")
    private String mediaType;       // null (bài thường) | "IMAGE" | "VIDEO"

    @Column(name = "video_path")
    private String videoPath;       // null nếu không phải video

    @Column(name = "video_duration_sec")
    private int videoDurationSec;   // 0 nếu không phải video

    // Chia sẻ kèm bình luận: null = bài thường, != null = bài chia sẻ trỏ tới bài GỐC.
    // Luôn trỏ tới bài gốc (không trỏ tới bài chia sẻ khác) nên chỉ lồng đúng 1 cấp.
    @Column(name = "shared_post_id")
    private Integer sharedPostId;

    // Transient: bài gốc được nạp bởi PostDAO.attachSharedPosts().
    // null khi bài gốc đã bị xoá hoặc người xem không có quyền xem.
    @Transient
    private Post sharedPost;

    // Bài thuộc nhóm nào (null = bài cá nhân)
    @Column(name = "group_id")
    private Integer groupId;

    // Transient: tên nhóm để hiện nhãn trên post card
    @Transient
    private String groupName;

    // Kiểm duyệt — CHỈ admin đổi. Gán sẵn giá trị vì Hibernate INSERT đủ mọi cột (cột NOT NULL).
    @Column(name = "moderation_status")
    private String moderationStatus = MODERATION_ACTIVE;

    // Chủ bài tự ẩn — CHỈ chủ bài đổi. Độc lập với moderationStatus.
    @Column(name = "is_hidden_by_owner")
    private boolean hiddenByOwner;

    // ---------- Migration 090: cảm xúc bài viết (AI / từ điển) ----------
    public static final String SENTIMENT_POSITIVE = "POSITIVE";
    public static final String SENTIMENT_NEUTRAL  = "NEUTRAL";
    public static final String SENTIMENT_NEGATIVE = "NEGATIVE";

    @Column(name = "sentiment")
    private String sentiment;            // NULL = chưa phân tích

    @Column(name = "sentiment_score")
    private Double sentimentScore;       // -1 .. +1

    @Column(name = "sentiment_source")
    private String sentimentSource;      // AI | LEXICON

    // ---------- Migration 090: media nâng cao ----------
    public static final String MODE_PANORAMA = "PANORAMA";   // ảnh 360° (equirectangular)
    public static final String MODE_DEPTH    = "DEPTH";      // ảnh 3D chiều sâu (nghiêng thiết bị / rê chuột)
    public static final String MODE_MODEL3D  = "MODEL3D";    // mô hình .glb xem 3D + AR

    @Column(name = "media_mode")
    private String mediaMode;

    @Column(name = "model_path")
    private String modelPath;

    @Column(name = "captions_vtt")
    private String captionsVtt;          // phụ đề WebVTT của video

    // Transient: bảng tin cá nhân hóa — lý do bài được xếp lên ("Vì bạn hay tương tác với An")
    @Transient
    private String feedReason;

    // Transient: bộ lọc nội dung của người xem — từ khóa đã khớp (null = không bị lọc)
    @Transient
    private String filteredBy;

    public static final String MODERATION_ACTIVE  = "ACTIVE";
    public static final String MODERATION_HIDDEN  = "HIDDEN";
    public static final String MODERATION_DELETED = "DELETED";

    // Transient: user hiện tại đã like bài này chưa (tính theo session)
    @Transient
    private boolean likedByCurrentUser;

    // Transient: danh sách comments (join khi load cho feed)
    @Transient
    private List<Comment> comments;

    // Transient: thời điểm lưu (chỉ có giá trị khi load qua SavedPostDAO)
    @Transient
    private java.time.LocalDateTime savedAt;

    public Post() {}

    public Post(int postId, int userId, String content, String imagePath,
                LocalDateTime createdAt, String visibility) {
        this.postId = postId;
        this.userId = userId;
        this.content = content;
        this.imagePath = imagePath;
        this.createdAt = createdAt;
        this.visibility = visibility;
    }

    // ---------- Helpers ----------

    public String getVisibilityLabel() {
        if ("friends".equalsIgnoreCase(visibility)) return "Bạn bè";
        return "Công khai";
    }

    public String getVisibilityIcon() {
        if ("friends".equalsIgnoreCase(visibility)) return "👥";
        return "🌎";
    }

    public String getFormattedCreatedAt() {
        if (createdAt == null) return "";
        java.time.format.DateTimeFormatter formatter = java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
        return createdAt.format(formatter);
    }

    public String getFormattedSavedAt() {
        if (savedAt == null) return "";
        java.time.Duration d = java.time.Duration.between(savedAt, java.time.LocalDateTime.now());
        long mins = d.toMinutes();
        if (mins < 1)  return "Vừa lưu";
        if (mins < 60) return mins + " phút trước";
        long hours = d.toHours();
        if (hours < 24) return hours + " giờ trước";
        long days = d.toDays();
        return days + " ngày trước";
    }

    public boolean isVideo() {
        return "VIDEO".equals(mediaType);
    }

    /** true nếu đây là bài chia sẻ (JSP: ${post.share}) */
    public boolean isShare() {
        return sharedPostId != null;
    }

    /** Bị admin ẩn do vi phạm (JSP: ${post.hiddenByAdmin}) */
    public boolean isHiddenByAdmin() {
        return MODERATION_HIDDEN.equals(moderationStatus);
    }

    /** Đường dẫn ảnh (tính từ context path) — JSP: ${ctx}${post.imageUrl} */
    public String getImageUrl() {
        return com.uterspace.util.MediaUrl.of(imagePath);
    }

    /** Đường dẫn file video (tính từ context path), null nếu chưa có file */
    public String getVideoUrl() {
        return com.uterspace.util.MediaUrl.of(videoPath);
    }

    public String getFormattedDuration() {
        if (videoDurationSec <= 0) return "0:00";
        int m = videoDurationSec / 60;
        int s = videoDurationSec % 60;
        return m + ":" + String.format("%02d", s);
    }

    public boolean isNegative() { return SENTIMENT_NEGATIVE.equals(sentiment); }
    public boolean isPositive() { return SENTIMENT_POSITIVE.equals(sentiment); }

    public String getSentimentLabel() {
        if (SENTIMENT_POSITIVE.equals(sentiment)) return "Tích cực";
        if (SENTIMENT_NEGATIVE.equals(sentiment)) return "Tiêu cực";
        if (SENTIMENT_NEUTRAL.equals(sentiment))  return "Trung tính";
        return "";
    }

    public boolean isPanorama() { return MODE_PANORAMA.equals(mediaMode); }
    public boolean isDepth()    { return MODE_DEPTH.equals(mediaMode); }
    public boolean isModel3d()  { return MODE_MODEL3D.equals(mediaMode) && modelPath != null; }
    public String getModelUrl() { return com.uterspace.util.MediaUrl.of(modelPath); }
    public boolean isHasCaptions() { return captionsVtt != null && !captionsVtt.isEmpty(); }

    // ---------- Getters & Setters ----------

    public int getPostId() { return postId; }
    public void setPostId(int postId) { this.postId = postId; }

    public int getUserId() { 
        if (author != null) return author.getUserId();
        return userId; 
    }
    public void setUserId(int userId) { this.userId = userId; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getImagePath() { return imagePath; }
    public void setImagePath(String imagePath) { this.imagePath = imagePath; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public String getVisibility() { return visibility; }
    public void setVisibility(String visibility) { this.visibility = visibility; }

    public int getLikeCount() { return likeCount; }
    public void setLikeCount(int likeCount) { this.likeCount = likeCount; }

    public int getCommentCount() { return commentCount; }
    public void setCommentCount(int commentCount) { this.commentCount = commentCount; }

    public int getShareCount() { return shareCount; }
    public void setShareCount(int shareCount) { this.shareCount = shareCount; }

    public User getAuthor() { return author; }
    public void setAuthor(User author) { this.author = author; }

    public boolean isLikedByCurrentUser() { return likedByCurrentUser; }
    public void setLikedByCurrentUser(boolean likedByCurrentUser) { this.likedByCurrentUser = likedByCurrentUser; }

    public List<Comment> getComments() { return comments; }
    public void setComments(List<Comment> comments) { this.comments = comments; }

    public String getMediaType() { return mediaType; }
    public void setMediaType(String mediaType) { this.mediaType = mediaType; }

    public String getVideoPath() { return videoPath; }
    public void setVideoPath(String videoPath) { this.videoPath = videoPath; }

    public int getVideoDurationSec() { return videoDurationSec; }
    public void setVideoDurationSec(int videoDurationSec) { this.videoDurationSec = videoDurationSec; }

    public java.time.LocalDateTime getSavedAt() { return savedAt; }
    public void setSavedAt(java.time.LocalDateTime savedAt) { this.savedAt = savedAt; }

    public Integer getSharedPostId() { return sharedPostId; }
    public void setSharedPostId(Integer sharedPostId) { this.sharedPostId = sharedPostId; }

    public Post getSharedPost() { return sharedPost; }
    public void setSharedPost(Post sharedPost) { this.sharedPost = sharedPost; }

    public Integer getGroupId() { return groupId; }
    public void setGroupId(Integer groupId) { this.groupId = groupId; }

    public String getGroupName() { return groupName; }
    public void setGroupName(String groupName) { this.groupName = groupName; }

    public String getModerationStatus() { return moderationStatus; }
    public void setModerationStatus(String moderationStatus) { this.moderationStatus = moderationStatus; }

    public boolean isHiddenByOwner() { return hiddenByOwner; }

    public String getSentiment() { return sentiment; }
    public void setSentiment(String sentiment) { this.sentiment = sentiment; }
    public Double getSentimentScore() { return sentimentScore; }
    public void setSentimentScore(Double sentimentScore) { this.sentimentScore = sentimentScore; }
    public String getSentimentSource() { return sentimentSource; }
    public void setSentimentSource(String sentimentSource) { this.sentimentSource = sentimentSource; }
    public String getMediaMode() { return mediaMode; }
    public void setMediaMode(String mediaMode) { this.mediaMode = mediaMode; }
    public String getModelPath() { return modelPath; }
    public void setModelPath(String modelPath) { this.modelPath = modelPath; }
    public String getCaptionsVtt() { return captionsVtt; }
    public void setCaptionsVtt(String captionsVtt) { this.captionsVtt = captionsVtt; }
    public String getFeedReason() { return feedReason; }
    public void setFeedReason(String feedReason) { this.feedReason = feedReason; }
    public String getFilteredBy() { return filteredBy; }
    public void setFilteredBy(String filteredBy) { this.filteredBy = filteredBy; }
    public void setHiddenByOwner(boolean hiddenByOwner) { this.hiddenByOwner = hiddenByOwner; }
}
