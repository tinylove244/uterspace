package com.uterspace.model;

import javax.persistence.*;
import java.io.Serializable;
import java.util.Objects;

/** Entity: MessageHidden — userId đã "Xóa ở phía tôi" tin messageId (bảng message_hidden). Người khác vẫn thấy tin. */
@Entity
@Table(name = "message_hidden")
@IdClass(MessageHidden.Key.class)
public class MessageHidden {

    @Id
    @Column(name = "message_id")
    private int messageId;

    @Id
    @Column(name = "user_id")
    private int userId;

    public MessageHidden() { }
    public MessageHidden(int messageId, int userId) { this.messageId = messageId; this.userId = userId; }

    public int getMessageId() { return messageId; }
    public int getUserId() { return userId; }

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
