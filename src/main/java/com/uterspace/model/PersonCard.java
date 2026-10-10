package com.uterspace.model;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * PersonCard — một người trong danh sách ở trang Bạn bè (lời mời, đã gửi, gợi ý, bạn bè):
 * User + quan hệ với người xem + số bạn chung + trạng thái hoạt động + mốc thời gian. Không phải entity.
 */
public class PersonCard {

    private final User user;
    private String status = "NONE";       // RelationService.Status
    private int mutualCount;
    private boolean online;
    private String presence = "";         // "Đang hoạt động" / "Hoạt động 5 phút trước" / ""
    private LocalDateTime since;          // bạn bè từ (accepted_at) hoặc lúc gửi lời mời
    private String reason;                // gợi ý: "3 bạn chung" / "Cùng khu vực"

    public PersonCard(User user) { this.user = user; }

    /** "Bạn bè từ 09/2026" */
    public String getSinceLabel() {
        return since == null ? "" : since.format(DateTimeFormatter.ofPattern("MM/yyyy"));
    }

    /** "3 giờ trước" — thời điểm gửi lời mời */
    public String getTimeAgo() {
        if (since == null) return "";
        long min = Duration.between(since, LocalDateTime.now()).toMinutes();
        if (min < 1) return "vừa xong";
        if (min < 60) return min + " phút trước";
        if (min < 24 * 60) return (min / 60) + " giờ trước";
        return (min / (24 * 60)) + " ngày trước";
    }

    /** Kết bạn trong 30 ngày qua (bộ lọc "Mới kết bạn") */
    public boolean isRecent() {
        return since != null && since.isAfter(LocalDateTime.now().minusDays(30));
    }

    /** Khóa sắp xếp "mới kết bạn" (epoch giây) */
    public long getSinceEpoch() {
        return since == null ? 0 : since.atZone(java.time.ZoneId.systemDefault()).toEpochSecond();
    }

    public User getUser() { return user; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public int getMutualCount() { return mutualCount; }
    public void setMutualCount(int mutualCount) { this.mutualCount = mutualCount; }
    public boolean isOnline() { return online; }
    public void setOnline(boolean online) { this.online = online; }
    public String getPresence() { return presence; }
    public void setPresence(String presence) { this.presence = presence; }
    public LocalDateTime getSince() { return since; }
    public void setSince(LocalDateTime since) { this.since = since; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
}
