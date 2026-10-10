package com.uterspace.model;

import javax.persistence.*;
import java.time.Duration;
import java.time.LocalDateTime;

@Entity
@Table(name = "notifications")
public class Notification {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notification_id")
    private int notificationId;
    
    @Column(name = "user_id")
    private int userId; // người nhận

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_id")
    private User actor; // người gây ra hành động

    private String type; // "LIKE", "COMMENT", "SHARE", "FRIEND_REQUEST", "SYSTEM"
    private String content;
    
    @Column(name = "target_url")
    private String targetUrl;
    
    @Column(name = "is_read")
    private boolean read;
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    /**
     * Khóa đối tượng (migration 060) để GỘP hoặc GỠ thông báo: "fr:28" (lời mời của user 28),
     * "conv:12" (tin nhắn mới trong hội thoại 12 — nhiều tin gộp thành một thông báo)...
     */
    @Column(name = "ref_key")
    private String refKey;

    public Notification() {}

    public Notification(int notificationId, int userId, User actor, String type,
                        String content, String targetUrl, boolean read, LocalDateTime createdAt) {
        this.notificationId = notificationId;
        this.userId = userId;
        this.actor = actor;
        this.type = type;
        this.content = content;
        this.targetUrl = targetUrl;
        this.read = read;
        this.createdAt = createdAt;
    }

    public int getNotificationId() { return notificationId; }
    public void setNotificationId(int notificationId) { this.notificationId = notificationId; }
    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }
    public User getActor() { return actor; }
    public void setActor(User actor) { this.actor = actor; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getTargetUrl() { return targetUrl; }
    public void setTargetUrl(String targetUrl) { this.targetUrl = targetUrl; }
    public boolean isRead() { return read; }
    public void setRead(boolean read) { this.read = read; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public String getRefKey() { return refKey; }
    public void setRefKey(String refKey) { this.refKey = refKey; }

    /** Nhóm chức năng: friend | interaction | group | message | account (UserSettings.categoryOf) */
    public String getCategory() { return UserSettings.categoryOf(type); }

    /** Tiêu đề nhóm thời gian ở trang Thông báo */
    public String getTimeGroup() {
        if (createdAt == null) return "Trước đó";
        java.time.LocalDate d = createdAt.toLocalDate(), today = java.time.LocalDate.now();
        if (d.equals(today)) return "Hôm nay";
        if (d.equals(today.minusDays(1))) return "Hôm qua";
        if (d.isAfter(today.minusDays(7))) return "7 ngày qua";
        return "Trước đó";
    }

    public String getFormattedCreatedAt() {
        return createdAt == null ? "" : createdAt.format(java.time.format.DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"));
    }

    public String getTimeAgo() {
        if (createdAt == null) return "";
        Duration d = Duration.between(createdAt, LocalDateTime.now());
        long mins = d.toMinutes();
        if (mins < 1) return "Vừa xong";
        if (mins < 60) return mins + " phút trước";
        long hours = d.toHours();
        if (hours < 24) return hours + " giờ trước";
        long days = d.toDays();
        return days + " ngày trước";
    }

    public String getIcon() {
        if ("LIKE".equalsIgnoreCase(type)) return "❤️";
        if ("COMMENT".equalsIgnoreCase(type)) return "💬";
        if ("SHARE".equalsIgnoreCase(type)) return "🔁";
        if ("STORY_REACT".equalsIgnoreCase(type)) return "💗";
        if ("GROUP_JOIN_REQUEST".equalsIgnoreCase(type)) return "🙋";
        if ("GROUP_APPROVED".equalsIgnoreCase(type)) return "✅";
        if ("GROUP_POST".equalsIgnoreCase(type)) return "🏷️";
        if ("FRIEND_REQUEST".equalsIgnoreCase(type)) return "👥";
        if ("FRIEND_ACCEPT".equalsIgnoreCase(type)) return "🤝";
        if ("MESSAGE".equalsIgnoreCase(type)) return "💌";
        if ("ACCOUNT".equalsIgnoreCase(type)) return "🔐";
        return "📢";
    }
}
