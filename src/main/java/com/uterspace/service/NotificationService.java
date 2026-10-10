package com.uterspace.service;

import com.uterspace.dao.*;
import com.uterspace.model.Notification;
import com.uterspace.model.User;
import com.uterspace.model.UserSettings;
import com.uterspace.realtime.Live;

import java.time.LocalDateTime;
import java.util.List;

/**
 * NotificationService — NƠI DUY NHẤT tạo thông báo. Mọi Controller gọi vào đây (không gọi thẳng DAO) để luôn:
 *   1. bỏ qua thông báo tự gửi cho chính mình (trừ thông báo tài khoản),
 *   2. bỏ qua nếu hai người đang chặn nhau,
 *   3. tôn trọng tùy chọn "nhận thông báo nhóm này" của người nhận (Cài đặt → Thông báo),
 *   4. đẩy ngay tới trình duyệt người nhận qua WebSocket (toast + thông báo màn hình nếu họ bật),
 *   5. gộp thông báo tin nhắn: mỗi hội thoại chưa đọc chỉ MỘT thông báo ("đã gửi 3 tin nhắn mới").
 */
public final class NotificationService {

    private static final NotificationDAO DAO      = new NotificationDAOImpl();
    private static final UserSettingsDAO SETTINGS = new UserSettingsDAO();
    private static final BlockDAO        BLOCKS   = new BlockDAO();

    private NotificationService() { }

    /**
     * Tạo thông báo và đẩy realtime.
     * @param refKey khóa đối tượng để gỡ / gộp sau này (có thể null)
     * @return thông báo đã tạo, hoặc null nếu bị bỏ qua theo các quy tắc trên
     */
    public static Notification notify(int recipientId, int actorId, String type, String content, String targetUrl, String refKey) {
        boolean account = "ACCOUNT".equals(type) || "SYSTEM".equals(type);
        if (recipientId == actorId && !account) return null;
        if (recipientId != actorId && BLOCKS.isBlockedEitherWay(recipientId, actorId)) return null;
        UserSettings s = SETTINGS.get(recipientId);
        String category = UserSettings.categoryOf(type);
        if (!s.wantsInApp(category)) return null;

        if (content != null && content.length() > 480) content = content.substring(0, 477) + "…";   // cột NVARCHAR(500)
        Notification n = new Notification();
        n.setUserId(recipientId);
        User actor = new User();
        actor.setUserId(actorId);
        n.setActor(actor);                 // DAO nạp lại User thật theo id
        n.setType(type);
        n.setContent(content);
        n.setTargetUrl(targetUrl);
        n.setRefKey(refKey);
        DAO.createNotification(n);
        Live.notification(n, s.wantsPush(category));
        return n;
    }

    /** Cùng một thông báo cho nhiều người (vd: bài mới trong nhóm) — từng người vẫn qua đủ các quy tắc */
    public static void notifyMany(List<Integer> recipients, int actorId, String type, String content, String targetUrl) {
        for (Integer uid : recipients) {
            try { notify(uid, actorId, type, content, targetUrl, null); } catch (RuntimeException ignored) { }
        }
    }

    /** Thông báo bảo mật tài khoản (đăng nhập mới, đổi mật khẩu) — luôn tạo, không tắt được */
    public static Notification account(int userId, String content, String targetUrl) {
        return notify(userId, userId, "ACCOUNT", content, targetUrl, null);
    }

    /**
     * Đăng nhập: chỉ báo khi là THIẾT BỊ / TRÌNH DUYỆT LẠ — chưa có lần đăng nhập nào từ thiết bị này trong 30 ngày qua
     * (tránh mỗi lần đăng nhập lại đều sinh một thông báo).
     */
    public static void loginFromDevice(int userId, String device, String content) {
        String ref = "login:" + device;
        if (ref.length() > 100) ref = ref.substring(0, 100);
        if (DAO.existsSince(userId, ref, LocalDateTime.now().minusDays(30))) return;
        notify(userId, userId, "ACCOUNT", content, "/settings?tab=account", ref);
    }

    /**
     * Tin nhắn mới tới recipient trong hội thoại conversationId. Đã có thông báo CHƯA ĐỌC của hội thoại này
     * thì cập nhật (người gửi mới nhất, số tin, đưa lên đầu) thay vì tạo thêm.
     * @param unread số tin chưa đọc hiện tại của recipient trong hội thoại
     * @param groupTitle tên nhóm (null nếu chat 1-1)
     */
    public static void messageReceived(int recipientId, User sender, int conversationId, String groupTitle, int unread) {
        if (BLOCKS.isBlockedEitherWay(recipientId, sender.getUserId())) return;
        UserSettings s = SETTINGS.get(recipientId);
        if (!s.wantsInApp(UserSettings.CAT_MESSAGE)) return;

        String ref = "conv:" + conversationId;
        String url = "/chat?c=" + conversationId;
        String content;
        if (groupTitle != null) {
            content = (unread > 1 ? "và mọi người đã gửi " + unread + " tin nhắn mới" : "đã gửi tin nhắn mới") +
                      " trong nhóm \"" + groupTitle + "\".";
        } else {
            content = unread > 1 ? "đã gửi cho bạn " + unread + " tin nhắn mới." : "đã gửi cho bạn một tin nhắn mới.";
        }

        Notification existing = DAO.findUnreadByRef(recipientId, ref);
        if (existing != null) {
            DAO.refreshAggregated(existing.getNotificationId(), sender.getUserId(), content, LocalDateTime.now());
            existing.setActor(sender);
            existing.setContent(content);
            existing.setCreatedAt(LocalDateTime.now());
            existing.setUserId(recipientId);
            Live.notification(existing, s.wantsPush(UserSettings.CAT_MESSAGE));
        } else {
            notify(recipientId, sender.getUserId(), "MESSAGE", content, url, ref);
        }
    }

    /** Gỡ thông báo theo đối tượng (lời mời đã bị thu hồi / đã trả lời) */
    public static void removeByRef(int recipientId, String refKey) {
        if (DAO.deleteByRef(recipientId, refKey) > 0) Live.badges(recipientId);
    }

    /** Đánh dấu đã đọc theo đối tượng (đã mở hội thoại) */
    public static void readByRef(int userId, String refKey) {
        if (DAO.markReadByRef(userId, refKey) > 0) Live.badges(userId);
    }
}
