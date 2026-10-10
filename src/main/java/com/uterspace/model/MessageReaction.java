package com.uterspace.model;

import javax.persistence.*;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/** Entity: MessageReaction — cảm xúc thả vào tin nhắn, mỗi người tối đa 1 cảm xúc / tin (bảng message_reactions). */
@Entity
@Table(name = "message_reactions")
@IdClass(MessageReaction.Key.class)
public class MessageReaction {

    /** Bộ cảm xúc cho phép (server kiểm tra, không nhận chuỗi tùy ý) */
    public static final java.util.List<String> ALLOWED =
        java.util.Arrays.asList("👍", "❤️", "😂", "😮", "😢", "😡");

    @Id
    @Column(name = "message_id")
    private int messageId;

    @Id
    @Column(name = "user_id")
    private int userId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", insertable = false, updatable = false)
    private User user;

    private String emoji;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }

    public MessageReaction() { }
    public MessageReaction(int messageId, int userId, String emoji) {
        this.messageId = messageId; this.userId = userId; this.emoji = emoji;
    }

    public int getMessageId() { return messageId; }
    public int getUserId() { return userId; }
    public User getUser() { return user; }
    public String getEmoji() { return emoji; }
    public void setEmoji(String emoji) { this.emoji = emoji; }

    public static class Key implements Serializable {
        private int messageId;
        private int userId;
        public Key() { }
        public Key(int messageId, int userId) { this.messageId = messageId; this.userId = userId; }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key)) return false;
            Key k = (Key) o;
            return messageId == k.messageId && userId == k.userId;
        }
        @Override public int hashCode() { return Objects.hash(messageId, userId); }
    }
}
