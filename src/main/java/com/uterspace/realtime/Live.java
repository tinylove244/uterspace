package com.uterspace.realtime;

import com.uterspace.dao.*;
import com.uterspace.model.Notification;
import com.uterspace.model.User;
import com.uterspace.util.JsonUtil;

/**
 * Live — dựng và gửi các sự kiện thời gian thực tới trình duyệt (qua RealtimeHub).
 * Mọi URL trong sự kiện tính từ context path; assets/js/realtime.js tự ghép thêm.
 *
 * Các loại sự kiện:
 *   badge         {unreadChat, unreadNotif, friendRequests}   — số trên huy hiệu ở mọi trang
 *   notification  {notification:{...}, push, unreadNotif}     — thông báo mới (toast + đẩy màn hình)
 *   friend        {userId, status, action, name}              — quan hệ bạn bè vừa đổi
 *   presence      {userId, online, label}                     — bạn bè online / offline (Presence)
 *   chat.*        xem ChatLive                                 — tin nhắn, đang gõ, đã nhận, đã xem...
 */
public final class Live {

    private static final MessageDAO      MSG    = new MessageDAOImpl();
    private static final NotificationDAO NOTIF  = new NotificationDAOImpl();
    private static final FriendshipDAO   FRIEND = new FriendshipDAOImpl();

    private Live() { }

    /** JSON số đếm huy hiệu — dùng chung cho sự kiện "badge" và /api/pulse */
    public static String badgeJson(int uid) {
        return "{\"type\":\"badge\",\"unreadChat\":" + MSG.getUnreadMessageCount(uid) +
               ",\"unreadNotif\":" + NOTIF.getUnreadNotificationCount(uid) +
               ",\"friendRequests\":" + FRIEND.countPendingFor(uid) + "}";
    }

    /** Gửi số huy hiệu mới cho mọi tab của uid (bỏ qua nếu không kết nối) */
    public static void badges(int uid) {
        if (!RealtimeHub.isConnected(uid)) return;
        try { RealtimeHub.send(uid, badgeJson(uid)); } catch (RuntimeException ignored) { }
    }

    /** Thông báo vừa tạo / vừa gộp → toast trong trang + (nếu push = true) thông báo đẩy của trình duyệt */
    public static void notification(Notification n, boolean push) {
        int uid = n.getUserId();
        if (!RealtimeHub.isConnected(uid)) return;
        try {
            User a = n.getActor();
            String json = "{\"type\":\"notification\",\"push\":" + push +
                ",\"unreadNotif\":" + NOTIF.getUnreadNotificationCount(uid) +
                ",\"notification\":{\"id\":" + n.getNotificationId() +
                ",\"type\":" + JsonUtil.str(n.getType()) +
                ",\"category\":" + JsonUtil.str(n.getCategory()) +
                ",\"icon\":" + JsonUtil.str(n.getIcon()) +
                ",\"content\":" + JsonUtil.str(n.getContent()) +
                ",\"refKey\":" + JsonUtil.str(n.getRefKey()) +
                ",\"actorId\":" + (a != null ? a.getUserId() : 0) +
                ",\"actorName\":" + JsonUtil.str(a != null ? a.getFullName() : "UTErSpace") +
                ",\"actorInitials\":" + JsonUtil.str(a != null ? a.getInitials() : "U") +
                ",\"actorAvatar\":" + JsonUtil.str(a != null && a.getAvatar() != null ? a.getAvatarUrl() : null) +
                ",\"url\":" + JsonUtil.str("/notifications/open?id=" + n.getNotificationId()) +
                ",\"time\":" + JsonUtil.str(n.getTimeAgo()) + "}}";
            RealtimeHub.send(uid, json);
        } catch (RuntimeException ignored) { }
    }

    /**
     * Quan hệ giữa uid và otherId vừa đổi (status nhìn từ phía uid). action: request | accept | decline | cancel |
     * unfriend | block | unblock. name: tên người gây ra hành động (để hiện toast).
     */
    public static void friend(int uid, int otherId, String status, String action, String name) {
        if (!RealtimeHub.isConnected(uid)) return;
        RealtimeHub.send(uid, "{\"type\":\"friend\",\"userId\":" + otherId + ",\"status\":" + JsonUtil.str(status) +
                              ",\"action\":" + JsonUtil.str(action) + ",\"name\":" + JsonUtil.str(name) + "}");
    }
}
