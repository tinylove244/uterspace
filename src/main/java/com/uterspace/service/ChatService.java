package com.uterspace.service;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.realtime.ChatLive;
import com.uterspace.realtime.Live;
import com.uterspace.realtime.RealtimeHub;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;

/**
 * ChatService — nghiệp vụ Tin nhắn: quyền gửi, gửi tin, đã nhận / đã xem, sửa / thu hồi / cảm xúc / ghim, nhóm chat.
 * Controller chỉ đọc tham số và gọi vào đây. Sau mỗi thay đổi, dịch vụ đẩy sự kiện realtime (ChatLive) cho
 * MỌI thành viên để các tab đang mở cập nhật ngay, và tạo / gộp thông báo "tin nhắn mới".
 */
public final class ChatService {

    public static final int MAX_TEXT        = 4000;
    public static final int EDIT_WINDOW_MIN = 15;     // sửa tin trong 15 phút sau khi gửi
    public static final int GROUP_MIN_OTHERS = 2;     // nhóm cần ít nhất 3 người (mình + 2)
    public static final int GROUP_MAX       = 50;
    public static final int TITLE_MAX       = 100;

    private static final ConversationDAO CONV    = new ConversationDAOImpl();
    private static final MessageDAO      MSG     = new MessageDAOImpl();
    private static final FriendshipDAO   FRIENDS = new FriendshipDAOImpl();
    private static final BlockDAO        BLOCKS  = new BlockDAO();
    private static final UserDAO         USERS   = new UserDAOImpl();

    /** Lỗi nghiệp vụ: message hiển thị thẳng cho người dùng, status là mã HTTP */
    public static final class ChatException extends Exception {
        public final int status;
        public ChatException(int status, String message) { super(message); this.status = status; }
    }

    private ChatService() { }

    // ============================================================ Quyền

    /** Lý do không được gửi tin vào hội thoại (null = được gửi). Nhóm: chỉ cần là thành viên. */
    public static String sendDeniedReason(Conversation c, int uid) {
        if (c.isGroup()) return null;
        User p = c.partnerOf(uid);
        if (p == null) return "Cuộc trò chuyện không hợp lệ.";
        if (p.isLocked()) return "Tài khoản này hiện không khả dụng.";
        return RelationService.messageDeniedReason(uid, p.getUserId());
    }

    /** Hội thoại + thành viên nếu uid là thành viên, ngược lại ném 403 (chặn đọc trộm bằng cách đổi id) */
    public static Conversation require(int conversationId, int uid) throws ChatException {
        Conversation c = CONV.getForMember(conversationId, uid);
        if (c == null) throw new ChatException(403, "Bạn không thuộc cuộc trò chuyện này.");
        return c;
    }

    /** Tin + hội thoại của nó, chỉ khi uid là thành viên và còn thấy tin */
    public static ChatMessage requireMessage(int messageId, int uid) throws ChatException {
        ChatMessage m = MSG.getById(messageId);
        if (m == null || !CONV.isMember(m.getConversationId(), uid)) throw new ChatException(404, "Tin nhắn không tồn tại.");
        return m;
    }

    // ============================================================ Gửi tin

    /**
     * Gửi tin. draft đã có content / clientId / replyToId / file đính kèm (Controller điền).
     * Gửi lại cùng clientId (sau lỗi mạng) → trả tin cũ, không tạo bản trùng, không thông báo lại.
     */
    public static ChatMessage send(User me, Conversation c, ChatMessage draft) throws ChatException {
        String denied = sendDeniedReason(c, me.getUserId());
        if (denied != null) throw new ChatException(403, denied);
        String text = draft.getContent() == null ? "" : draft.getContent().trim();
        if (text.isEmpty() && draft.getAttachmentPath() == null) throw new ChatException(400, "Tin nhắn trống.");
        if (text.length() > MAX_TEXT) throw new ChatException(400, "Tin nhắn tối đa " + MAX_TEXT + " ký tự.");
        draft.setContent(text);
        if (draft.getReplyToId() != null) {
            ChatMessage target = MSG.getById(draft.getReplyToId());
            if (target == null || target.getConversationId() != c.getConversationId()) draft.setReplyToId(null);
        }

        ChatMessage m = MSG.send(c.getConversationId(), me.getUserId(), draft);
        boolean duplicate = draft.getMessageId() != m.getMessageId();
        MSG.attachExtras(Collections.singletonList(m));
        if (!duplicate) afterSend(me, c, m);
        return m;
    }

    private static void afterSend(User me, Conversation c, ChatMessage m) {
        int cid = c.getConversationId();
        List<Integer> members = CONV.getMemberIds(cid);
        ChatLive.message(cid, members, m);
        for (Integer other : members) {
            if (other == me.getUserId()) continue;
            // Người nhận đang mở kết nối → tin đã tới thiết bị của họ: "Đã nhận"
            if (RealtimeHub.isConnected(other) && CONV.markDelivered(cid, other, m.getMessageId()) > 0) {
                ChatLive.receipt(cid, members, other, null, m.getMessageId());
            }
            if (!m.isSystem()) {
                try {
                    NotificationService.messageReceived(other, me, cid, c.isGroup() ? c.getDisplayName() : null, MSG.unreadIn(cid, other));
                } catch (RuntimeException ignored) { }
            }
            Live.badges(other);
        }
    }

    /** Tin hệ thống trong nhóm ("A đã thêm B vào nhóm") */
    private static void system(User actor, Conversation c, String text) {
        ChatMessage m = MSG.system(c.getConversationId(), actor.getUserId(), text);
        MSG.attachExtras(Collections.singletonList(m));
        ChatLive.message(c.getConversationId(), CONV.getMemberIds(c.getConversationId()), m);
    }

    // ============================================================ Đã nhận / đã xem

    /** Đã xem tới upToId (giới hạn bởi tin lớn nhất thật sự có) → báo các thành viên + gỡ thông báo tin nhắn */
    public static void read(User me, Conversation c, int upToId) {
        int cid = c.getConversationId();
        int v = CONV.markRead(cid, me.getUserId(), Math.min(upToId, MSG.maxMessageId(cid)));
        if (v > 0) ChatLive.receipt(cid, CONV.getMemberIds(cid), me.getUserId(), v, v);
        NotificationService.readByRef(me.getUserId(), "conv:" + cid);
        Live.badges(me.getUserId());
    }

    /** Thiết bị vừa tải tin tới upToId (poll dự phòng khi không có WebSocket) → "Đã nhận" */
    public static void delivered(User me, Conversation c, int upToId) {
        int cid = c.getConversationId();
        int v = CONV.markDelivered(cid, me.getUserId(), Math.min(upToId, MSG.maxMessageId(cid)));
        if (v > 0) ChatLive.receipt(cid, CONV.getMemberIds(cid), me.getUserId(), null, v);
    }

    public static void markUnread(User me, Conversation c) {
        CONV.markUnread(c.getConversationId(), me.getUserId());
        Live.badges(me.getUserId());
        ChatLive.conversationChanged(c.getConversationId(), Collections.singletonList(me.getUserId()), "unread");
    }

    public static void clearHistory(User me, Conversation c) {
        CONV.clearHistory(c.getConversationId(), me.getUserId());
        NotificationService.readByRef(me.getUserId(), "conv:" + c.getConversationId());
        Live.badges(me.getUserId());
        ChatLive.conversationChanged(c.getConversationId(), Collections.singletonList(me.getUserId()), "cleared");
    }

    // ============================================================ Thao tác trên một tin

    public static ChatMessage edit(User me, ChatMessage m, String content) throws ChatException {
        if (m.getSenderId() != me.getUserId() || m.isSystem()) throw new ChatException(403, "Bạn chỉ sửa được tin của chính mình.");
        if (m.isRecalled()) throw new ChatException(409, "Tin nhắn đã được thu hồi.");
        if (Duration.between(m.getSentAt(), LocalDateTime.now()).toMinutes() >= EDIT_WINDOW_MIN) {
            throw new ChatException(409, "Chỉ sửa được tin trong " + EDIT_WINDOW_MIN + " phút sau khi gửi.");
        }
        String text = content == null ? "" : content.trim();
        if (text.isEmpty() && !m.hasAttachment()) throw new ChatException(400, "Nội dung không được để trống.");
        if (text.length() > MAX_TEXT) throw new ChatException(400, "Tin nhắn tối đa " + MAX_TEXT + " ký tự.");
        MSG.edit(m.getMessageId(), text);
        return broadcastUpdate(m.getMessageId());
    }

    /** Thu hồi với mọi người. Trả đường dẫn file đính kèm cũ (Controller xóa khỏi đĩa) */
    public static String recall(User me, ChatMessage m) throws ChatException {
        if (m.getSenderId() != me.getUserId() || m.isSystem()) throw new ChatException(403, "Bạn chỉ thu hồi được tin của chính mình.");
        if (m.isRecalled()) throw new ChatException(409, "Tin nhắn đã được thu hồi.");
        String path = MSG.recall(m.getMessageId());
        broadcastUpdate(m.getMessageId());
        return path;
    }

    public static void hide(User me, ChatMessage m) {
        MSG.hide(m.getMessageId(), me.getUserId());
        ChatLive.removeForUser(me.getUserId(), m.getConversationId(), m.getMessageId());
    }

    public static ChatMessage react(User me, ChatMessage m, String emoji) throws ChatException {
        if (!MessageReaction.ALLOWED.contains(emoji)) throw new ChatException(400, "Cảm xúc không hợp lệ.");
        if (m.isRecalled() || m.isSystem()) throw new ChatException(409, "Không thể thả cảm xúc cho tin này.");
        MSG.react(m.getMessageId(), me.getUserId(), emoji);
        return broadcastUpdate(m.getMessageId());
    }

    public static ChatMessage pin(User me, ChatMessage m, boolean pinned) throws ChatException {
        if (m.isRecalled() || m.isSystem()) throw new ChatException(409, "Không thể ghim tin này.");
        MSG.setPinned(m.getMessageId(), pinned ? me.getUserId() : null);
        ChatMessage updated = broadcastUpdate(m.getMessageId());
        Conversation c = CONV.getConversationById(m.getConversationId());
        if (c != null && c.isGroup()) {
            system(me, c, me.getFullName() + (pinned ? " đã ghim một tin nhắn." : " đã bỏ ghim một tin nhắn."));
        }
        return updated;
    }

    /** Nạp lại tin (kèm cảm xúc, tin được trả lời) rồi gửi chat.update tới mọi thành viên */
    private static ChatMessage broadcastUpdate(int messageId) {
        ChatMessage m = MSG.getById(messageId);
        MSG.attachExtras(Collections.singletonList(m));
        ChatLive.update(m.getConversationId(), CONV.getMemberIds(m.getConversationId()), m);
        return m;
    }

    // ============================================================ Nhóm chat

    /** Người được mời vào nhóm phải là bạn bè của mình, không chặn nhau, tài khoản còn hoạt động */
    private static List<Integer> validInvitees(User me, Collection<Integer> ids) throws ChatException {
        Set<Integer> friends = new HashSet<>(FRIENDS.getFriendIds(me.getUserId()));
        Set<Integer> blocked = BLOCKS.blockedEitherWay(me.getUserId());
        List<Integer> ok = new ArrayList<>();
        for (Integer id : new LinkedHashSet<>(ids)) {
            if (id == null || id == me.getUserId()) continue;
            if (!friends.contains(id) || blocked.contains(id)) {
                throw new ChatException(403, "Chỉ có thể thêm bạn bè của bạn vào nhóm chat.");
            }
            User u = USERS.getUserById(id);
            if (u != null && !u.isLocked()) ok.add(id);
        }
        return ok;
    }

    public static Conversation createGroup(User me, String title, Collection<Integer> memberIds) throws ChatException {
        List<Integer> ids = validInvitees(me, memberIds);
        if (ids.size() < GROUP_MIN_OTHERS) throw new ChatException(400, "Hãy chọn ít nhất " + GROUP_MIN_OTHERS + " người bạn để tạo nhóm.");
        if (ids.size() + 1 > GROUP_MAX) throw new ChatException(400, "Nhóm chat tối đa " + GROUP_MAX + " người.");
        String t = cleanTitle(title);
        if (t.isEmpty()) {
            // Không đặt tên → ghép tên các thành viên (giống Messenger)
            List<String> names = new ArrayList<>();
            names.add(me.getFirstName());
            for (Integer id : ids.subList(0, Math.min(3, ids.size()))) names.add(USERS.getUserById(id).getFirstName());
            t = String.join(", ", names) + (ids.size() > 3 ? "…" : "");
        }
        Conversation c = CONV.createGroup(me.getUserId(), t, ids);
        c.setGroup(true);
        c.setTitle(t);
        system(me, c, me.getFullName() + " đã tạo nhóm \"" + t + "\".");
        List<Integer> all = CONV.getMemberIds(c.getConversationId());
        ChatLive.conversationChanged(c.getConversationId(), all, "created");
        for (Integer id : ids) {
            NotificationService.notify(id, me.getUserId(), "MESSAGE", "đã thêm bạn vào nhóm chat \"" + t + "\".",
                                       "/chat?c=" + c.getConversationId(), "conv:" + c.getConversationId());
        }
        return c;
    }

    public static void addMembers(User me, Conversation c, Collection<Integer> memberIds) throws ChatException {
        if (!c.isGroup()) throw new ChatException(400, "Chỉ thêm người được vào nhóm chat.");
        List<Integer> ids = validInvitees(me, memberIds);
        if (c.getMemberCount() + ids.size() > GROUP_MAX) throw new ChatException(400, "Nhóm chat tối đa " + GROUP_MAX + " người.");
        List<Integer> added = CONV.addMembers(c.getConversationId(), ids);
        if (added.isEmpty()) throw new ChatException(409, "Những người này đã ở trong nhóm.");
        List<String> names = new ArrayList<>();
        for (Integer id : added) names.add(USERS.getUserById(id).getFullName());
        system(me, c, me.getFullName() + " đã thêm " + String.join(", ", names) + " vào nhóm.");
        ChatLive.conversationChanged(c.getConversationId(), CONV.getMemberIds(c.getConversationId()), "members");
        for (Integer id : added) {
            NotificationService.notify(id, me.getUserId(), "MESSAGE", "đã thêm bạn vào nhóm chat \"" + c.getDisplayName() + "\".",
                                       "/chat?c=" + c.getConversationId(), "conv:" + c.getConversationId());
        }
    }

    public static void removeMember(User me, Conversation c, int targetId) throws ChatException {
        if (!c.isGroup()) throw new ChatException(400, "Không phải nhóm chat.");
        ConversationMember mine = CONV.getMember(c.getConversationId(), me.getUserId());
        if (mine == null || !mine.isOwner()) throw new ChatException(403, "Chỉ trưởng nhóm mới xóa được thành viên.");
        if (targetId == me.getUserId()) throw new ChatException(400, "Dùng \"Rời nhóm\" để tự rời khỏi nhóm.");
        User target = USERS.getUserById(targetId);
        List<Integer> before = CONV.getMemberIds(c.getConversationId());
        if (target == null || !before.contains(targetId)) throw new ChatException(404, "Người này không ở trong nhóm.");
        system(me, c, me.getFullName() + " đã xóa " + target.getFullName() + " khỏi nhóm.");
        CONV.removeMember(c.getConversationId(), targetId);
        ChatLive.conversationChanged(c.getConversationId(), before, "members");
        Live.badges(targetId);
    }

    public static void leave(User me, Conversation c) throws ChatException {
        if (!c.isGroup()) throw new ChatException(400, "Chỉ rời được nhóm chat.");
        List<Integer> before = CONV.getMemberIds(c.getConversationId());
        if (before.size() > 1) system(me, c, me.getFullName() + " đã rời nhóm.");
        CONV.removeMember(c.getConversationId(), me.getUserId());
        NotificationService.readByRef(me.getUserId(), "conv:" + c.getConversationId());
        ChatLive.conversationChanged(c.getConversationId(), before, "members");
        Live.badges(me.getUserId());
    }

    public static void rename(User me, Conversation c, String title) throws ChatException {
        if (!c.isGroup()) throw new ChatException(400, "Chỉ đổi tên được nhóm chat.");
        String t = cleanTitle(title);
        if (t.isEmpty()) throw new ChatException(400, "Tên nhóm không được để trống.");
        CONV.rename(c.getConversationId(), t);
        c.setTitle(t);
        system(me, c, me.getFullName() + " đã đổi tên nhóm thành \"" + t + "\".");
        ChatLive.conversationChanged(c.getConversationId(), CONV.getMemberIds(c.getConversationId()), "renamed");
    }

    private static String cleanTitle(String title) {
        String t = title == null ? "" : title.trim().replaceAll("\\s+", " ");
        return t.length() > TITLE_MAX ? t.substring(0, TITLE_MAX) : t;
    }
}
