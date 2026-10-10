package com.uterspace.realtime;

import javax.websocket.CloseReason;
import javax.websocket.Session;
import java.io.IOException;
import java.util.*;
import java.util.concurrent.*;

/**
 * RealtimeHub — sổ đăng ký các kết nối WebSocket đang mở, theo userId (một người có thể mở nhiều tab / thiết bị).
 *
 * Gửi sự kiện: send(userId, json) không chặn request đang xử lý — việc ghi ra socket chạy ở luồng nền.
 * Mỗi kết nối luôn được gán cố định vào MỘT "làn" (executor 1 luồng) theo hash, nên các sự kiện tới cùng một
 * tab giữ đúng thứ tự gửi (tin nhắn → sửa tin → đã xem...), mà các tab khác nhau vẫn gửi song song.
 *
 * Không lưu gì xuống DB; mất kết nối thì trình duyệt tự nối lại và tải bù dữ liệu (xem assets/js/realtime.js).
 */
public final class RealtimeHub {

    public static final String PROP_UID        = "uid";
    public static final String PROP_HTTP_SESSION = "httpSessionId";
    public static final String PROP_NAME       = "name";

    private static final Map<Integer, Set<Session>> BY_USER = new ConcurrentHashMap<>();

    private static final int LANES = 4;
    private static final ExecutorService[] LANE = new ExecutorService[LANES];
    static {
        for (int i = 0; i < LANES; i++) {
            final int n = i;
            LANE[i] = Executors.newSingleThreadExecutor(r -> {
                Thread t = new Thread(r, "realtime-sender-" + n);
                t.setDaemon(true);
                return t;
            });
        }
    }

    private RealtimeHub() { }

    /** Thêm kết nối. Trả true nếu đây là kết nối ĐẦU TIÊN của người này (vừa online). */
    public static boolean register(int uid, Session s) {
        boolean[] first = { false };
        BY_USER.compute(uid, (k, set) -> {
            if (set == null) { set = ConcurrentHashMap.newKeySet(); first[0] = true; }
            set.add(s);
            return set;
        });
        return first[0];
    }

    /** Gỡ kết nối. Trả true nếu đây là kết nối CUỐI CÙNG của người này (vừa offline). */
    public static boolean unregister(int uid, Session s) {
        boolean[] last = { false };
        BY_USER.computeIfPresent(uid, (k, set) -> {
            set.remove(s);
            if (set.isEmpty()) { last[0] = true; return null; }
            return set;
        });
        return last[0];
    }

    /** Người này đang có ít nhất một tab mở kết nối */
    public static boolean isConnected(int uid) {
        Set<Session> set = BY_USER.get(uid);
        return set != null && !set.isEmpty();
    }

    public static int connectionCount() {
        int n = 0;
        for (Set<Session> set : BY_USER.values()) n += set.size();
        return n;
    }

    /** Gửi sự kiện tới mọi tab của một người (bỏ qua nếu người đó không kết nối) */
    public static void send(int uid, String json) {
        Set<Session> set = BY_USER.get(uid);
        if (set == null) return;
        for (Session s : set) lane(s).execute(() -> deliver(s, json));
    }

    public static void send(Collection<Integer> uids, String json) {
        for (Integer uid : uids) if (uid != null) send(uid, json);
    }

    /** Gửi tới mọi tab của một người TRỪ tab vừa gây ra sự kiện (vd: đang gõ phím) */
    public static void sendExcept(int uid, Session except, String json) {
        Set<Session> set = BY_USER.get(uid);
        if (set == null) return;
        for (Session s : set) if (s != except) lane(s).execute(() -> deliver(s, json));
    }

    /** Đóng mọi kết nối gắn với một phiên HTTP (đăng xuất, bị khóa, phiên hết hạn) */
    public static void closeHttpSession(String httpSessionId) {
        if (httpSessionId == null) return;
        for (Set<Session> set : BY_USER.values()) {
            for (Session s : set) {
                if (httpSessionId.equals(s.getUserProperties().get(PROP_HTTP_SESSION))) {
                    close(s, CloseReason.CloseCodes.VIOLATED_POLICY, "session-ended");
                }
            }
        }
    }

    /** Đóng mọi kết nối của một người (vd: admin khóa tài khoản) */
    public static void closeUser(int uid) {
        Set<Session> set = BY_USER.get(uid);
        if (set == null) return;
        for (Session s : set) close(s, CloseReason.CloseCodes.VIOLATED_POLICY, "account-locked");
    }

    public static void shutdown() {
        for (ExecutorService e : LANE) e.shutdownNow();
    }

    static void close(Session s, CloseReason.CloseCode code, String reason) {
        try { if (s.isOpen()) s.close(new CloseReason(code, reason)); } catch (IOException | IllegalStateException ignored) { }
    }

    private static ExecutorService lane(Session s) {
        return LANE[Math.floorMod(s.getId().hashCode(), LANES)];
    }

    private static void deliver(Session s, String json) {
        if (!s.isOpen()) return;
        synchronized (s) {
            try {
                s.getBasicRemote().sendText(json);
            } catch (IOException | IllegalStateException e) {
                // Kết nối chết giữa chừng: đóng hẳn, @OnClose sẽ gỡ khỏi sổ
                close(s, CloseReason.CloseCodes.GOING_AWAY, "send-failed");
            }
        }
    }
}
