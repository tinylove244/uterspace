package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Entity: Report — người dùng báo cáo bài viết / bình luận / tài khoản vi phạm (plan mục 6).
 * Mỗi người chỉ báo cáo một đối tượng một lần (UNIQUE reporter_id, target_type, target_id).
 */
@Entity
@Table(name = "reports")
public class Report {

    public static final String TARGET_POST    = "POST";
    public static final String TARGET_COMMENT = "COMMENT";
    public static final String TARGET_USER    = "USER";

    public static final String STATUS_PENDING   = "PENDING";
    public static final String STATUS_RESOLVED  = "RESOLVED";
    public static final String STATUS_DISMISSED = "DISMISSED";

    /** Mã lý do → nhãn tiếng Việt (giữ thứ tự hiển thị trong hộp thoại báo cáo) */
    public static final Map<String, String> REASONS = new LinkedHashMap<>();
    static {
        REASONS.put("SPAM",           "Spam / Quảng cáo");
        REASONS.put("OFFENSIVE",      "Ngôn từ xúc phạm");
        REASONS.put("HARASSMENT",     "Quấy rối / Bắt nạt");
        REASONS.put("MISINFORMATION", "Thông tin sai lệch");
        REASONS.put("INAPPROPRIATE",  "Nội dung không phù hợp");
        REASONS.put("IMPERSONATION",  "Mạo danh");
        REASONS.put("OTHER",          "Lý do khác");
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "report_id")
    private int reportId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reporter_id")
    private User reporter;

    @Column(name = "target_type")
    private String targetType;

    @Column(name = "target_id")
    private int targetId;

    private String reason;
    private String detail;

    private String status = STATUS_PENDING;

    @Column(name = "handled_by")
    private Integer handledBy;

    @Column(name = "handled_at")
    private LocalDateTime handledAt;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }

    public String getReasonLabel() {
        return REASONS.getOrDefault(reason, reason);
    }

    public String getFormattedCreatedAt() {
        return createdAt == null ? "" : createdAt.format(DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"));
    }

    public int getReportId() { return reportId; }
    public void setReportId(int reportId) { this.reportId = reportId; }

    public User getReporter() { return reporter; }
    public void setReporter(User reporter) { this.reporter = reporter; }

    public String getTargetType() { return targetType; }
    public void setTargetType(String targetType) { this.targetType = targetType; }

    public int getTargetId() { return targetId; }
    public void setTargetId(int targetId) { this.targetId = targetId; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getDetail() { return detail; }
    public void setDetail(String detail) { this.detail = detail; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Integer getHandledBy() { return handledBy; }
    public void setHandledBy(Integer handledBy) { this.handledBy = handledBy; }

    public LocalDateTime getHandledAt() { return handledAt; }
    public void setHandledAt(LocalDateTime handledAt) { this.handledAt = handledAt; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
