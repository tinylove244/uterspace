package com.uterspace.realtime;

import com.uterspace.dao.FriendshipDAO;
import com.uterspace.dao.FriendshipDAOImpl;
import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.dao.UserSettingsDAO;
import com.uterspace.model.User;
import com.uterspace.util.JsonUtil;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Presence — trạng thái online / offline.
 *
 * "Đang hoạt động" = đang mở kết nối WebSocket, HOẶC (trình duyệt không dùng được WebSocket) vừa gửi
 * /api/pulse trong {@value #ONLINE_SECONDS} giây qua. Người tắt "Hiển thị trạng thái hoạt động" trong Cài đặt
 * luôn hiện offline với người khác.
 * last_active_at chỉ ghi DB tối đa 1 lần / phút / người để không tạo tải.
 */
public final class Presence {

    public static final int ONLINE_SECONDS = 90;
    private static final long TOUCH_EVERY_MS = 60_000;

    private static final Map<Integer, Long> LAST_TOUCH = new ConcurrentHashMap<>();
    private static final UserDAO         USER_DAO     = new UserDAOImpl();
    private static final FriendshipDAO   FRIEND_DAO   = new FriendshipDAOImpl();
    private static final UserSettingsDAO SETTINGS_DAO = new UserSettingsDAO();

    private Presence() { }

    /** Ghi nhận "vừa hoạt động" (có giới hạn tần suất ghi DB) */
    public static void touch(int uid) { touch(uid, false); }

    private static void touch(int uid, boolean force) {
        long now = System.currentTimeMillis();
        Long prev = LAST_TOUCH.get(uid);
        if (!force && prev != null && now - prev < TOUCH_EVERY_MS) return;
        LAST_TOUCH.put(uid, now);
        try { USER_DAO.touchLastActive(uid); } catch (RuntimeException ignored) { }
    }

    /** u (vừa nạp từ DB) có đang hoạt động không, xét cả cài đặt hiển thị của u */
    public static boolean isOnline(User u, boolean showOnline) {
        if (u == null || !showOnline) return false;
        if (RealtimeHub.isConnected(u.getUserId())) return true;
        LocalDateTime t = u.getLastActiveAt();
        return t != null && Duration.between(t, LocalDateTime.now()).getSeconds() < ONLINE_SECONDS;
    }

    /** Nhãn hiển thị: "Đang hoạt động" | "Hoạt động 5 phút trước" | "" (ẩn / quá lâu) */
    public static String label(User u, boolean showOnline) {
        if (u == null || !showOnline) return "";
        if (isOnline(u, true)) return "Đang hoạt động";
        LocalDateTime t = u.getLastActiveAt();
        if (t == null) return "";
        long min = Duration.between(t, LocalDateTime.now()).toMinutes();
        if (min < 60)        return "Hoạt động " + Math.max(1, min) + " phút trước";
        if (min < 24 * 60)   return "Hoạt động " + (min / 60) + " giờ trước";
        if (min < 7 * 24 * 60) return "Hoạt động " + (min / (24 * 60)) + " ngày trước";
        return "";
    }

    /** Kết nối đầu tiên của uid vừa mở → báo cho bạn bè đang online */
    static void wentOnline(int uid) {
        touch(uid, true);
        broadcast(uid, true);
    }

    /** Kết nối cuối cùng của uid vừa đóng → báo bạn bè (kèm thời điểm hoạt động cuối) */
    static void wentOffline(int uid) {
        touch(uid, true);
        broadcast(uid, false);
    }

    private static void broadcast(int uid, boolean online) {
        try {
            if (!SETTINGS_DAO.get(uid).isShowOnline()) return;
            String json = "{\"type\":\"presence\",\"userId\":" + uid + ",\"online\":" + online +
                          ",\"label\":" + JsonUtil.str(online ? "Đang hoạt động" : "Hoạt động 1 phút trước") + "}";
            for (Integer fid : FRIEND_DAO.getFriendIds(uid)) {
                if (RealtimeHub.isConnected(fid)) RealtimeHub.send(fid, json);
            }
        } catch (RuntimeException ignored) { }
    }
}
