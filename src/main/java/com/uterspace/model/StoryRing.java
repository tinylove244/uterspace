package com.uterspace.model;

import java.time.LocalDateTime;

/**
 * StoryRing — một vòng tròn trên thanh "Tin" của bảng tin: một người + các tin còn hạn của họ.
 * hasUnseen = còn tin người xem chưa xem → vòng màu; ngược lại vòng xám. Không phải entity.
 */
public class StoryRing {

    private final User user;
    private int count;
    private boolean hasUnseen;
    private LocalDateTime latestAt;

    public StoryRing(User user) { this.user = user; }

    /** Cộng thêm một tin vào vòng */
    public void add(Story s) {
        count++;
        if (!s.isSeen()) hasUnseen = true;
        if (latestAt == null || s.getCreatedAt().isAfter(latestAt)) latestAt = s.getCreatedAt();
    }

    public User getUser() { return user; }
    public int getCount() { return count; }
    public boolean isHasUnseen() { return hasUnseen; }
    public LocalDateTime getLatestAt() { return latestAt; }
}
