package com.uterspace.model;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * ReportGroup — các báo cáo ĐANG CHỜ gom theo một đối tượng (bài / bình luận / tài khoản),
 * để trang admin hiện "5 người báo cáo" thay vì 5 thẻ trùng nhau. Không phải entity.
 * Controller gắn thêm bản xem trước đối tượng (post / comment / user) để admin xem trước khi xử lý.
 */
public class ReportGroup {

    private final String targetType;
    private final int targetId;
    private final int count;
    private final LocalDateTime latestAt;
    private final List<Report> reports = new ArrayList<>();

    // Bản xem trước đối tượng bị báo cáo (một trong ba, tùy targetType); null = đối tượng đã bị xóa
    private Post post;
    private Comment comment;
    private User user;

    public ReportGroup(String targetType, int targetId, int count, LocalDateTime latestAt) {
        this.targetType = targetType;
        this.targetId = targetId;
        this.count = count;
        this.latestAt = latestAt;
    }

    /** Các lý do khác nhau (nhãn tiếng Việt), theo thứ tự gặp */
    public Set<String> getReasonLabels() {
        Set<String> s = new LinkedHashSet<>();
        for (Report r : reports) s.add(r.getReasonLabel());
        return s;
    }

    public String getTargetLabel() {
        switch (targetType) {
            case Report.TARGET_POST:    return "bài viết";
            case Report.TARGET_COMMENT: return "bình luận";
            default:                    return "tài khoản";
        }
    }

    public String getFormattedLatestAt() {
        return latestAt == null ? "" : latestAt.format(DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"));
    }

    public boolean isTargetMissing() {
        return (Report.TARGET_POST.equals(targetType) && post == null)
            || (Report.TARGET_COMMENT.equals(targetType) && comment == null)
            || (Report.TARGET_USER.equals(targetType) && user == null);
    }

    public String getTargetType() { return targetType; }
    public int getTargetId() { return targetId; }
    public int getCount() { return count; }
    public LocalDateTime getLatestAt() { return latestAt; }
    public List<Report> getReports() { return reports; }
    public Post getPost() { return post; }
    public void setPost(Post post) { this.post = post; }
    public Comment getComment() { return comment; }
    public void setComment(Comment comment) { this.comment = comment; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
}
