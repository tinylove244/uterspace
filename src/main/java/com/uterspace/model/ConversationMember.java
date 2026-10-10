package com.uterspace.model;

import javax.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * Entity: ConversationMember — một người trong một hội thoại (bảng conversation_members, migration 060).
 * Dùng chung cho chat 1-1 (2 thành viên) và nhóm chat. Lưu các mốc riêng của từng người:
 *   lastDeliveredMessageId — thiết bị của người này đã NHẬN tới tin nào  → "Đã nhận"
 *   lastReadMessageId      — người này đã XEM tới tin nào               → "Đã xem", đếm chưa đọc
 *   clearedMessageId       — "Xóa cuộc trò chuyện" phía người này: ẩn mọi tin <= mốc
 */
@Entity
@Table(name = "conversation_members")
@IdClass(ConversationMember.Key.class)
public class ConversationMember {

    public static final String ROLE_OWNER  = "OWNER";
    public static final String ROLE_MEMBER = "MEMBER";

    @Id
    @Column(name = "conversation_id")
    private int conversationId;

    @Id
    @Column(name = "user_id")
    private int userId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", insertable = false, updatable = false)
    private User user;

    private String role = ROLE_MEMBER;

    @Column(name = "joined_at")
    private LocalDateTime joinedAt;

    @Column(name = "last_read_message_id")
    private int lastReadMessageId;

    @Column(name = "last_delivered_message_id")
    private int lastDeliveredMessageId;

    @Column(name = "cleared_message_id")
    private int clearedMessageId;

    @Transient
    private boolean online;

    @PrePersist
    void onCreate() { if (joinedAt == null) joinedAt = LocalDateTime.now(); }

    public ConversationMember() { }
    public ConversationMember(int conversationId, int userId, String role) {
        this.conversationId = conversationId; this.userId = userId; this.role = role;
    }

    public boolean isOwner() { return ROLE_OWNER.equals(role); }

    public int getConversationId() { return conversationId; }
    public int getUserId() { return userId; }
    public User getUser() { return user; }
    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
    public LocalDateTime getJoinedAt() { return joinedAt; }
    public int getLastReadMessageId() { return lastReadMessageId; }
    public void setLastReadMessageId(int v) { this.lastReadMessageId = v; }
    public int getLastDeliveredMessageId() { return lastDeliveredMessageId; }
    public void setLastDeliveredMessageId(int v) { this.lastDeliveredMessageId = v; }
    public int getClearedMessageId() { return clearedMessageId; }
    public void setClearedMessageId(int v) { this.clearedMessageId = v; }
    public boolean isOnline() { return online; }
    public void setOnline(boolean online) { this.online = online; }

    public static class Key implements Serializable {
        private int conversationId;
        private int userId;
        public Key() { }
        public Key(int conversationId, int userId) { this.conversationId = conversationId; this.userId = userId; }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key)) return false;
            Key k = (Key) o;
            return conversationId == k.conversationId && userId == k.userId;
        }
        @Override public int hashCode() { return Objects.hash(conversationId, userId); }
    }
}
