package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

/**
 * Entity: Conversation — một cuộc trò chuyện.
 *   - Chat 1-1  (isGroup = false): userA < userB, mỗi cặp chỉ một hội thoại (UX_conversations_pair).
 *   - Nhóm chat (isGroup = true) : userA/userB = NULL, có tên (title); thành viên ở conversation_members.
 * Cả hai loại đều có thành viên trong conversation_members (mốc đã nhận / đã xem của từng người).
 */
@Entity
@Table(name = "conversations")
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "conversation_id")
    private int conversationId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_a_id")
    private User userA;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_b_id")
    private User userB;

    @Column(name = "last_message_at")
    private LocalDateTime lastMessageTime;

    @Column(name = "is_group")
    private boolean group;

    private String title;

    @Column(name = "created_by")
    private Integer createdBy;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    // ---------- Thông tin theo người xem (không lưu DB) ----------
    @Transient private User partner;                       // chat 1-1: người còn lại
    @Transient private String lastMessage;                 // xem trước tin cuối
    @Transient private String lastSenderName;              // nhóm: "Lan: ..."
    @Transient private int unreadCount;
    @Transient private boolean online;                     // 1-1: người kia đang hoạt động
    @Transient private boolean lastMessageMine;
    @Transient private List<ConversationMember> members = new ArrayList<>();

    @PrePersist
    void onCreate() { if (createdAt == null) createdAt = LocalDateTime.now(); }

    public Conversation() {}

    /** userId có phải người trong hội thoại 1-1 không (nhóm chat: kiểm qua ConversationDAO.isMember) */
    public boolean hasParticipant(int userId) {
        return (userA != null && userA.getUserId() == userId)
            || (userB != null && userB.getUserId() == userId);
    }

    /** Người còn lại trong hội thoại 1-1 */
    public User partnerOf(int userId) {
        return (userA != null && userA.getUserId() == userId) ? userB : userA;
    }

    /** Tên hiển thị: tên nhóm hoặc tên người kia */
    public String getDisplayName() {
        if (group) return title != null && !title.trim().isEmpty() ? title : "Nhóm chat";
        return partner != null ? partner.getFullName() : "";
    }

    /** Chữ cái đại diện cho nhóm (không có ảnh) */
    public String getGroupInitials() {
        String t = getDisplayName().trim();
        if (t.isEmpty()) return "N";
        String[] parts = t.split("\\s+");
        String s = parts[0].substring(0, 1) + (parts.length > 1 ? parts[parts.length - 1].substring(0, 1) : "");
        return s.toUpperCase();
    }

    public int getMemberCount() { return members.size(); }

    /** Hôm nay → "HH:mm", ngày khác → "dd/MM" */
    public String getFormattedTime() {
        if (lastMessageTime == null) return "";
        boolean today = lastMessageTime.toLocalDate().equals(java.time.LocalDate.now());
        return lastMessageTime.format(DateTimeFormatter.ofPattern(today ? "HH:mm" : "dd/MM"));
    }

    public int getConversationId() { return conversationId; }
    public void setConversationId(int conversationId) { this.conversationId = conversationId; }
    public User getUserA() { return userA; }
    public void setUserA(User userA) { this.userA = userA; }
    public User getUserB() { return userB; }
    public void setUserB(User userB) { this.userB = userB; }
    public LocalDateTime getLastMessageTime() { return lastMessageTime; }
    public void setLastMessageTime(LocalDateTime lastMessageTime) { this.lastMessageTime = lastMessageTime; }
    public boolean isGroup() { return group; }
    public void setGroup(boolean group) { this.group = group; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public Integer getCreatedBy() { return createdBy; }
    public void setCreatedBy(Integer createdBy) { this.createdBy = createdBy; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public User getPartner() { return partner; }
    public void setPartner(User partner) { this.partner = partner; }
    public String getLastMessage() { return lastMessage; }
    public void setLastMessage(String lastMessage) { this.lastMessage = lastMessage; }
    public String getLastSenderName() { return lastSenderName; }
    public void setLastSenderName(String lastSenderName) { this.lastSenderName = lastSenderName; }
    public int getUnreadCount() { return unreadCount; }
    public void setUnreadCount(int unreadCount) { this.unreadCount = unreadCount; }
    public boolean isOnline() { return online; }
    public void setOnline(boolean online) { this.online = online; }
    public boolean isLastMessageMine() { return lastMessageMine; }
    public void setLastMessageMine(boolean lastMessageMine) { this.lastMessageMine = lastMessageMine; }
    public List<ConversationMember> getMembers() { return members; }
    public void setMembers(List<ConversationMember> members) { this.members = members; }
}
