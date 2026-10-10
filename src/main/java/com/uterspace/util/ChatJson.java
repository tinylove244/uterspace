package com.uterspace.util;

import com.uterspace.model.*;

import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * ChatJson — chuyển tin nhắn / hội thoại sang JSON, dùng CHUNG cho phản hồi HTTP và sự kiện WebSocket
 * để trình duyệt chỉ có một hàm vẽ tin nhắn (chat.js). Mọi URL tính từ context path.
 * Không có cờ "mine": cùng một sự kiện gửi tới nhiều người, trình duyệt tự so senderId với người đang xem.
 */
public final class ChatJson {

    private static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");
    private static final DateTimeFormatter FULL = DateTimeFormatter.ofPattern("HH:mm, dd/MM/yyyy");
    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    private ChatJson() { }

    public static String messages(List<ChatMessage> list) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < list.size(); i++) {
            if (i > 0) sb.append(',');
            sb.append(message(list.get(i)));
        }
        return sb.append(']').toString();
    }

    public static String message(ChatMessage m) {
        User s = m.getSender();
        StringBuilder sb = new StringBuilder(256);
        sb.append("{\"id\":").append(m.getMessageId())
          .append(",\"conversationId\":").append(m.getConversationId())
          .append(",\"clientId\":").append(JsonUtil.str(m.getClientId()))
          .append(",\"type\":").append(JsonUtil.str(m.getMessageType()))
          .append(",\"senderId\":").append(s != null ? s.getUserId() : 0)
          .append(",\"senderName\":").append(JsonUtil.str(s != null ? s.getFullName() : ""))
          .append(",\"senderFirst\":").append(JsonUtil.str(s != null ? s.getFirstName() : ""))
          .append(",\"senderInitials\":").append(JsonUtil.str(s != null ? s.getInitials() : ""))
          .append(",\"senderAvatar\":").append(JsonUtil.str(s != null && s.getAvatar() != null ? s.getAvatarUrl() : null))
          .append(",\"content\":").append(JsonUtil.str(m.isRecalled() ? "" : m.getContent()))
          .append(",\"time\":").append(JsonUtil.str(m.getSentAt() != null ? m.getSentAt().format(HHMM) : ""))
          .append(",\"fullTime\":").append(JsonUtil.str(m.getSentAt() != null ? m.getSentAt().format(FULL) : ""))
          .append(",\"date\":").append(JsonUtil.str(m.getSentAt() != null ? m.getSentAt().format(DATE) : ""))
          .append(",\"edited\":").append(m.getEditedAt() != null)
          .append(",\"recalled\":").append(m.isRecalled())
          .append(",\"pinned\":").append(m.isPinned());

        if (m.hasAttachment()) {
            sb.append(",\"attachment\":{\"type\":").append(JsonUtil.str(m.getAttachmentType()))
              .append(",\"name\":").append(JsonUtil.str(m.getAttachmentName()))
              .append(",\"size\":").append(m.getAttachmentSize() != null ? m.getAttachmentSize() : 0)
              .append(",\"url\":").append(JsonUtil.str("/chat/file?id=" + m.getMessageId()))
              .append('}');
        } else {
            sb.append(",\"attachment\":null");
        }

        ChatMessage r = m.getReplyTo();
        if (m.getReplyToId() != null) {
            sb.append(",\"reply\":{\"id\":").append(m.getReplyToId())
              .append(",\"senderName\":").append(JsonUtil.str(r != null && r.getSender() != null ? r.getSender().getFullName() : ""))
              .append(",\"preview\":").append(JsonUtil.str(r != null ? shorten(r.getPreview(), 120) : "Tin nhắn không còn tồn tại"))
              .append(",\"recalled\":").append(r == null || r.isRecalled())
              .append('}');
        } else {
            sb.append(",\"reply\":null");
        }

        // Cảm xúc gom theo emoji: [{emoji, count, users:[{id,name}]}]
        Map<String, List<User>> byEmoji = new LinkedHashMap<>();
        for (MessageReaction re : m.getReactions()) byEmoji.computeIfAbsent(re.getEmoji(), k -> new ArrayList<>()).add(re.getUser());
        sb.append(",\"reactions\":[");
        String sep = "";
        for (Map.Entry<String, List<User>> e : byEmoji.entrySet()) {
            sb.append(sep).append("{\"emoji\":").append(JsonUtil.str(e.getKey())).append(",\"count\":").append(e.getValue().size()).append(",\"users\":[");
            String sep2 = "";
            for (User u : e.getValue()) {
                sb.append(sep2).append("{\"id\":").append(u.getUserId()).append(",\"name\":").append(JsonUtil.str(u.getFullName())).append('}');
                sep2 = ",";
            }
            sb.append("]}");
            sep = ",";
        }
        return sb.append("]}").toString();
    }

    /** Mốc đã nhận / đã xem của từng thành viên: {"12":{"read":40,"delivered":41},...} */
    public static String receipts(List<ConversationMember> members) {
        StringBuilder sb = new StringBuilder("{");
        String sep = "";
        for (ConversationMember m : members) {
            sb.append(sep).append('"').append(m.getUserId()).append("\":{\"read\":").append(m.getLastReadMessageId())
              .append(",\"delivered\":").append(m.getLastDeliveredMessageId()).append('}');
            sep = ",";
        }
        return sb.append('}').toString();
    }

    /** Thành viên (cho đầu khung chat / bảng thông tin nhóm) */
    public static String members(List<ConversationMember> members) {
        StringBuilder sb = new StringBuilder("[");
        String sep = "";
        for (ConversationMember m : members) {
            User u = m.getUser();
            sb.append(sep).append("{\"id\":").append(m.getUserId())
              .append(",\"name\":").append(JsonUtil.str(u != null ? u.getFullName() : ""))
              .append(",\"first\":").append(JsonUtil.str(u != null ? u.getFirstName() : ""))
              .append(",\"initials\":").append(JsonUtil.str(u != null ? u.getInitials() : ""))
              .append(",\"avatar\":").append(JsonUtil.str(u != null && u.getAvatar() != null ? u.getAvatarUrl() : null))
              .append(",\"role\":").append(JsonUtil.str(m.getRole()))
              .append(",\"online\":").append(m.isOnline())
              .append('}');
            sep = ",";
        }
        return sb.append(']').toString();
    }

    /** Một mục ở danh sách hội thoại */
    public static String conversation(Conversation c, String presenceLabel) {
        User p = c.getPartner();
        StringBuilder sb = new StringBuilder(200);
        sb.append("{\"conversationId\":").append(c.getConversationId())
          .append(",\"group\":").append(c.isGroup())
          .append(",\"name\":").append(JsonUtil.str(c.getDisplayName()))
          .append(",\"initials\":").append(JsonUtil.str(c.isGroup() ? c.getGroupInitials() : (p != null ? p.getInitials() : "")))
          .append(",\"avatar\":").append(JsonUtil.str(!c.isGroup() && p != null && p.getAvatar() != null ? p.getAvatarUrl() : null))
          .append(",\"partnerId\":").append(!c.isGroup() && p != null ? p.getUserId() : 0)
          .append(",\"memberCount\":").append(c.getMemberCount())
          .append(",\"lastMessage\":").append(JsonUtil.str(c.getLastMessage()))
          .append(",\"lastSender\":").append(JsonUtil.str(c.getLastSenderName()))
          .append(",\"lastMessageMine\":").append(c.isLastMessageMine())
          .append(",\"time\":").append(JsonUtil.str(c.getFormattedTime()))
          .append(",\"unread\":").append(c.getUnreadCount())
          .append(",\"online\":").append(c.isOnline())
          .append(",\"presence\":").append(JsonUtil.str(presenceLabel))
          .append('}');
        return sb.toString();
    }

    private static String shorten(String s, int max) {
        if (s == null) return "";
        return s.length() > max ? s.substring(0, max) + "…" : s;
    }
}
