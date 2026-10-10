package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

/** Entity: AdminLog — nhật ký thao tác quản trị: ai làm gì, với đối tượng nào, lúc nào (plan mục 6.4). */
@Entity
@Table(name = "admin_logs")
public class AdminLog {

    private static final Map<String, String> LABELS = new HashMap<>();
    static {
        LABELS.put("LOCK_USER",      "Khóa tài khoản");
        LABELS.put("UNLOCK_USER",    "Mở khóa tài khoản");
        LABELS.put("SET_ROLE",       "Đổi vai trò");
        LABELS.put("HIDE_POST",      "Ẩn bài viết");
        LABELS.put("DELETE_POST",    "Xóa mềm bài viết");
        LABELS.put("RESTORE_POST",   "Khôi phục bài viết");
        LABELS.put("DELETE_COMMENT", "Xóa bình luận");
        LABELS.put("DISMISS_REPORT", "Bỏ qua báo cáo");
        LABELS.put("DELETE_GROUP",   "Giải tán nhóm");
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "log_id")
    private int logId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "admin_id")
    private User admin;

    private String action;

    @Column(name = "target_type")
    private String targetType;

    @Column(name = "target_id")
    private Integer targetId;

    private String detail;

    @Column(name = "ip_address")
    private String ipAddress;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }

    public String getActionLabel() { return LABELS.getOrDefault(action, action); }

    /** Tên icon SVG (sprite #i-…) theo nhóm thao tác — dòng nhật ký / bảng tin dashboard */
    public String getActionIcon() {
        if (action == null) return "shield";
        if (action.startsWith("LOCK")) return "lock";
        if (action.startsWith("UNLOCK")) return "lock-open";
        if (action.startsWith("RESTORE")) return "arrow-path";
        if (action.startsWith("HIDE")) return "eye-slash";
        if (action.startsWith("DELETE")) return "trash";
        if (action.startsWith("DISMISS")) return "check";
        return "shield";
    }

    /** Màu nhãn: danger (khóa / xóa / ẩn) | ok (mở khóa / khôi phục / bỏ qua) */
    public String getActionTone() {
        if (action == null) return "";
        return action.startsWith("UNLOCK") || action.startsWith("RESTORE") || action.startsWith("DISMISS") ? "ok" : "danger";
    }

    /** "Bài viết #12" — mô tả đối tượng bị tác động */
    public String getTargetLabel() {
        if (targetType == null) return "";
        String t;
        switch (targetType) {
            case "POST":    t = "Bài viết"; break;
            case "COMMENT": t = "Bình luận"; break;
            case "USER":    t = "Người dùng"; break;
            case "GROUP":   t = "Nhóm"; break;
            default:        t = targetType;
        }
        return targetId != null ? t + " #" + targetId : t;
    }

    public String getTimeAgo() {
        return createdAt == null ? "" : AdminActivity.timeAgo(createdAt);
    }

    public String getFormattedCreatedAt() {
        return createdAt == null ? "" : createdAt.format(DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"));
    }

    public int getLogId() { return logId; }
    public User getAdmin() { return admin; }
    public void setAdmin(User admin) { this.admin = admin; }
    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }
    public String getTargetType() { return targetType; }
    public void setTargetType(String targetType) { this.targetType = targetType; }
    public Integer getTargetId() { return targetId; }
    public void setTargetId(Integer targetId) { this.targetId = targetId; }
    public String getDetail() { return detail; }
    public void setDetail(String detail) { this.detail = detail; }
    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
