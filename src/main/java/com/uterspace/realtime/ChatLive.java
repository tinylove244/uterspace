package com.uterspace.realtime;

import com.uterspace.dao.ConversationDAO;
import com.uterspace.dao.ConversationDAOImpl;
import com.uterspace.model.ChatMessage;
import com.uterspace.util.ChatJson;
import com.uterspace.util.JsonUtil;

import javax.websocket.Session;
import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * ChatLive — sự kiện thời gian thực của Tin nhắn:
 *   chat.message  tin mới                      → mọi thành viên (kể cả các tab khác của người gửi)
 *   chat.update   tin bị sửa / thu hồi / cảm xúc / ghim
 *   chat.remove   tin bị "xóa ở phía tôi"       → chỉ các tab của người đó
 *   chat.receipt  mốc đã nhận / đã xem của một thành viên đổi
 *   chat.typing   đang gõ / ngừng gõ           → các thành viên khác
 *   chat.conv     danh sách hội thoại cần làm mới (tạo nhóm, đổi tên, thêm / bớt người)
 */
public final class ChatLive {

    private static final ConversationDAO CONV = new ConversationDAOImpl();

    private ChatLive() { }

    public static void message(int conversationId, Collection<Integer> members, ChatMessage m) {
        RealtimeHub.send(members, "{\"type\":\"chat.message\",\"conversationId\":" + conversationId +
                                  ",\"message\":" + ChatJson.message(m) + "}");
    }

    public static void update(int conversationId, Collection<Integer> members, ChatMessage m) {
        RealtimeHub.send(members, "{\"type\":\"chat.update\",\"conversationId\":" + conversationId +
                                  ",\"message\":" + ChatJson.message(m) + "}");
    }

    public static void removeForUser(int userId, int conversationId, int messageId) {
        RealtimeHub.send(userId, "{\"type\":\"chat.remove\",\"conversationId\":" + conversationId + ",\"messageId\":" + messageId + "}");
    }

    /** read / delivered = null nghĩa là không đổi */
    public static void receipt(int conversationId, Collection<Integer> members, int userId, Integer read, Integer delivered) {
        RealtimeHub.send(members, "{\"type\":\"chat.receipt\",\"conversationId\":" + conversationId + ",\"userId\":" + userId +
                                  ",\"read\":" + (read != null ? read : "null") + ",\"delivered\":" + (delivered != null ? delivered : "null") + "}");
    }

    public static void conversationChanged(int conversationId, Collection<Integer> userIds, String action) {
        RealtimeHub.send(userIds, "{\"type\":\"chat.conv\",\"conversationId\":" + conversationId +
                                  ",\"action\":" + JsonUtil.str(action) + "}");
    }

    /** Trình duyệt báo đang gõ: chỉ chuyển tiếp nếu người đó thực sự là thành viên hội thoại */
    static void typing(int uid, String name, int conversationId, boolean typing, Session from) {
        try {
            List<Integer> members = CONV.getMemberIds(conversationId);
            if (!members.contains(uid)) return;
            String json = "{\"type\":\"chat.typing\",\"conversationId\":" + conversationId + ",\"userId\":" + uid +
                          ",\"name\":" + JsonUtil.str(name) + ",\"typing\":" + typing + "}";
            for (Integer m : members) if (m != uid) RealtimeHub.send(m, json);
        } catch (RuntimeException ignored) { }
    }

    /** Người dùng vừa có kết nối: mọi tin đang chờ coi như "đã nhận" → báo người gửi (hiện ✓✓ Đã nhận) */
    static void deliverPending(int uid) {
        try {
            Map<Integer, Integer> changed = CONV.deliverAll(uid);
            for (Map.Entry<Integer, Integer> e : changed.entrySet()) {
                receipt(e.getKey(), CONV.getMemberIds(e.getKey()), uid, null, e.getValue());
            }
        } catch (RuntimeException ignored) { }
    }
}
