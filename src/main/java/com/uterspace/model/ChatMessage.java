package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

/**
 * Entity: ChatMessage — một tin nhắn (bảng chat_messages; cột mở rộng ở migration 060).
 *   messageType  TEXT (người dùng gửi) | SYSTEM ("A đã thêm B vào nhóm")
 *   clientId     mã trình duyệt sinh cho mỗi tin → gửi lại sau lỗi mạng không tạo tin trùng
 *   replyToId    trả lời tin nào · editedAt đã sửa · recalledAt đã thu hồi (nội dung + file bị xóa)
 *   pinnedAt/By  ghim · attachment*  ảnh / file đính kèm (lưu ngoài thư mục công khai, tải qua /chat/file)
 */
@Entity
@Table(name = "chat_messages")
public class ChatMessage {

    public static final String TYPE_TEXT   = "TEXT";
    public static final String TYPE_SYSTEM = "SYSTEM";
    public static final String ATT_IMAGE   = "IMAGE";
    public static final String ATT_FILE    = "FILE";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "message_id")
    private int messageId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "conversation_id")
    private Conversation conversation;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id")
    private User sender;

    private String content;

    @Column(name = "sent_at")
    private LocalDateTime timestamp;

    /** Cột cũ (trước 060) — trạng thái đọc nay theo conversation_members.last_read_message_id */
    @Column(name = "is_read")
    private boolean isRead;

    @Column(name = "client_id")       private String clientId;
    @Column(name = "message_type")    private String messageType = TYPE_TEXT;
    @Column(name = "reply_to_id")     private Integer replyToId;
    @Column(name = "edited_at")       private LocalDateTime editedAt;
    @Column(name = "recalled_at")     private LocalDateTime recalledAt;
    @Column(name = "pinned_at")       private LocalDateTime pinnedAt;
    @Column(name = "pinned_by")       private Integer pinnedBy;
    @Column(name = "attachment_path") private String attachmentPath;
    @Column(name = "attachment_type") private String attachmentType;
    @Column(name = "attachment_name") private String attachmentName;
    @Column(name = "attachment_size") private Long attachmentSize;

    // ---------- Nạp kèm khi trả về cho trình duyệt ----------
    @Transient private ChatMessage replyTo;
    @Transient private List<MessageReaction> reactions = new ArrayList<>();
    @Transient private boolean isMine;

    public ChatMessage() {}

    public boolean isRecalled() { return recalledAt != null; }
    public boolean isSystem()   { return TYPE_SYSTEM.equals(messageType); }
    public boolean isPinned()   { return pinnedAt != null; }
    public boolean hasAttachment() { return attachmentPath != null && !isRecalled(); }

    /** Xem trước một dòng (danh sách hội thoại, tin được trả lời, kết quả tìm kiếm) */
    public String getPreview() {
        if (isRecalled()) return "Tin nhắn đã được thu hồi";
        if (content != null && !content.trim().isEmpty()) return content;
        if (ATT_IMAGE.equals(attachmentType)) return "📷 Hình ảnh";
        if (ATT_FILE.equals(attachmentType))  return "📎 " + (attachmentName != null ? attachmentName : "Tệp đính kèm");
        return "";
    }

    public int getMessageId() { return messageId; }
    public void setMessageId(int messageId) { this.messageId = messageId; }
    public Conversation getConversation() { return conversation; }
    public void setConversation(Conversation conversation) { this.conversation = conversation; }
    public int getConversationId() { return conversation != null ? conversation.getConversationId() : 0; }
    public User getSender() { return sender; }
    public void setSender(User sender) { this.sender = sender; }
    public int getSenderId() { return sender != null ? sender.getUserId() : 0; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }
    public LocalDateTime getSentAt() { return timestamp; }
    public void setSentAt(LocalDateTime sentAt) { this.timestamp = sentAt; }
    public boolean isRead() { return isRead; }
    public void setRead(boolean read) { isRead = read; }
    public String getClientId() { return clientId; }
    public void setClientId(String clientId) { this.clientId = clientId; }
    public String getMessageType() { return messageType; }
    public void setMessageType(String messageType) { this.messageType = messageType; }
    public Integer getReplyToId() { return replyToId; }
    public void setReplyToId(Integer replyToId) { this.replyToId = replyToId; }
    public LocalDateTime getEditedAt() { return editedAt; }
    public void setEditedAt(LocalDateTime editedAt) { this.editedAt = editedAt; }
    public LocalDateTime getRecalledAt() { return recalledAt; }
    public void setRecalledAt(LocalDateTime recalledAt) { this.recalledAt = recalledAt; }
    public LocalDateTime getPinnedAt() { return pinnedAt; }
    public void setPinnedAt(LocalDateTime pinnedAt) { this.pinnedAt = pinnedAt; }
    public Integer getPinnedBy() { return pinnedBy; }
    public void setPinnedBy(Integer pinnedBy) { this.pinnedBy = pinnedBy; }
    public String getAttachmentPath() { return attachmentPath; }
    public void setAttachmentPath(String attachmentPath) { this.attachmentPath = attachmentPath; }
    public String getAttachmentType() { return attachmentType; }
    public void setAttachmentType(String attachmentType) { this.attachmentType = attachmentType; }
    public String getAttachmentName() { return attachmentName; }
    public void setAttachmentName(String attachmentName) { this.attachmentName = attachmentName; }
    public Long getAttachmentSize() { return attachmentSize; }
    public void setAttachmentSize(Long attachmentSize) { this.attachmentSize = attachmentSize; }
    public ChatMessage getReplyTo() { return replyTo; }
    public void setReplyTo(ChatMessage replyTo) { this.replyTo = replyTo; }
    public List<MessageReaction> getReactions() { return reactions; }
    public void setReactions(List<MessageReaction> reactions) { this.reactions = reactions; }
    public boolean isMine() { return isMine; }
    public void setMine(boolean mine) { isMine = mine; }
    public boolean isSentByCurrentUser() { return isMine; }
    public void setSentByCurrentUser(boolean val) { this.isMine = val; }

    public String getFormattedTime() {
        return timestamp == null ? "" : timestamp.format(DateTimeFormatter.ofPattern("HH:mm"));
    }
}
