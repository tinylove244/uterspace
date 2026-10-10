package com.uterspace.model;

import javax.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * Entity: UserBlock — blocker đã chặn blocked (bảng user_blocks, migration 060).
 * Hai người chặn nhau (bất kể chiều nào): không kết bạn, không nhắn tin 1-1, không thấy bài / trang cá nhân
 * / kết quả tìm kiếm / gợi ý của nhau.
 */
@Entity
@Table(name = "user_blocks")
@IdClass(UserBlock.Key.class)
public class UserBlock {

    @Id
    @Column(name = "blocker_id")
    private int blockerId;

    @Id
    @Column(name = "blocked_id")
    private int blockedId;

    /** Người bị chặn (chỉ đọc) — hiện ở danh sách chặn trong Cài đặt */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocked_id", insertable = false, updatable = false)
    private User blocked;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }

    public UserBlock() { }
    public UserBlock(int blockerId, int blockedId) { this.blockerId = blockerId; this.blockedId = blockedId; }

    public int getBlockerId() { return blockerId; }
    public int getBlockedId() { return blockedId; }
    public User getBlocked() { return blocked; }
    public LocalDateTime getCreatedAt() { return createdAt; }

    public String getFormattedCreatedAt() {
        return createdAt == null ? "" : createdAt.format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"));
    }

    /** Khóa chính kép (blocker_id, blocked_id) */
    public static class Key implements Serializable {
        private int blockerId;
        private int blockedId;
        public Key() { }
        public Key(int blockerId, int blockedId) { this.blockerId = blockerId; this.blockedId = blockedId; }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key)) return false;
            Key k = (Key) o;
            return blockerId == k.blockerId && blockedId == k.blockedId;
        }
        @Override public int hashCode() { return Objects.hash(blockerId, blockedId); }
    }
}
