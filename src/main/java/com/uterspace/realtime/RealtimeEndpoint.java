package com.uterspace.realtime;

import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.model.User;

import javax.servlet.http.HttpSession;
import javax.websocket.*;
import javax.websocket.server.HandshakeRequest;
import javax.websocket.server.ServerEndpoint;
import javax.websocket.server.ServerEndpointConfig;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * RealtimeEndpoint — kết nối WebSocket ws://.../uterspace/ws, mỗi tab đã đăng nhập mở MỘT kết nối
 * (assets/js/realtime.js) để nhận sự kiện tức thời: tin nhắn, đang gõ, đã xem, thông báo, lời mời kết bạn, online.
 *
 * Xác thực: lúc bắt tay (handshake) đọc "currentUser" từ HttpSession của chính trình duyệt đó
 * (cookie JSESSIONID gửi kèm, SameSite=Lax nên trang khác không mở hộ được). Không có phiên / tài khoản bị khóa
 * → đóng ngay với mã 1008 (VIOLATED_POLICY), trình duyệt không thử nối lại.
 *
 * Trình duyệt chỉ được GỬI LÊN 2 loại tin: {"type":"ping"} (giữ kết nối, ghi nhận đang hoạt động) và
 * {"type":"typing","conversationId":12,"typing":true} (đang gõ). Mọi thao tác ghi dữ liệu khác vẫn đi qua
 * HTTP POST bình thường (có kiểm quyền + CSRF), WebSocket chỉ dùng để ĐẨY sự kiện xuống.
 */
@ServerEndpoint(value = "/ws", configurator = RealtimeEndpoint.AuthConfigurator.class)
public class RealtimeEndpoint {

    /** Mất ping quá thời gian này → coi như kết nối chết (trình duyệt ping mỗi 25 giây) */
    private static final long IDLE_TIMEOUT_MS = 70_000;
    private static final Pattern TYPE    = Pattern.compile("\"type\"\\s*:\\s*\"(\\w+)\"");
    private static final Pattern CONV_ID = Pattern.compile("\"conversationId\"\\s*:\\s*(\\d{1,9})");
    private static final Pattern TYPING  = Pattern.compile("\"typing\"\\s*:\\s*(true|false)");

    private static final UserDAO USERS = new UserDAOImpl();

    /** Lúc bắt tay: chép userId + id phiên HTTP vào thuộc tính riêng của kết nối này (Tomcat tạo config riêng mỗi kết nối) */
    public static class AuthConfigurator extends ServerEndpointConfig.Configurator {
        @Override
        public void modifyHandshake(ServerEndpointConfig sec, HandshakeRequest request, HandshakeResponse response) {
            Object hs = request.getHttpSession();
            if (!(hs instanceof HttpSession)) return;
            try {
                HttpSession session = (HttpSession) hs;
                Object u = session.getAttribute("currentUser");
                if (u instanceof User) {
                    sec.getUserProperties().put(RealtimeHub.PROP_UID, ((User) u).getUserId());
                    sec.getUserProperties().put(RealtimeHub.PROP_HTTP_SESSION, session.getId());
                    String pw = ((User) u).getPasswordHash();
                    if (pw != null) sec.getUserProperties().put("pwHash", pw);
                }
            } catch (IllegalStateException invalidated) {
                // phiên vừa bị hủy giữa chừng → coi như chưa đăng nhập
            }
        }
    }

    @OnOpen
    public void onOpen(Session session, EndpointConfig config) {
        Object uidObj = config.getUserProperties().get(RealtimeHub.PROP_UID);
        if (!(uidObj instanceof Integer)) {
            RealtimeHub.close(session, CloseReason.CloseCodes.VIOLATED_POLICY, "unauthorized");
            return;
        }
        int uid = (Integer) uidObj;
        User u = USERS.getUserById(uid);
        Object pwHash = config.getUserProperties().get("pwHash");
        if (u == null || u.isLocked() || (pwHash != null && !pwHash.equals(u.getPasswordHash()))) {
            // bị khóa / mật khẩu đã đổi ở nơi khác → phiên cũ không được nối realtime lại
            RealtimeHub.close(session, CloseReason.CloseCodes.VIOLATED_POLICY, "unauthorized");
            return;
        }
        session.getUserProperties().put(RealtimeHub.PROP_UID, uid);
        session.getUserProperties().put(RealtimeHub.PROP_HTTP_SESSION, config.getUserProperties().get(RealtimeHub.PROP_HTTP_SESSION));
        session.getUserProperties().put(RealtimeHub.PROP_NAME, u.getFullName());
        session.setMaxIdleTimeout(IDLE_TIMEOUT_MS);

        if (RealtimeHub.register(uid, session)) Presence.wentOnline(uid);
        else Presence.touch(uid);
        // Tin chào: trình duyệt biết đã kết nối xong + nhận ngay số huy hiệu mới nhất (đồng bộ lại sau khi mất mạng)
        RealtimeHub.send(uid, "{\"type\":\"hello\",\"userId\":" + uid + "}");
        Live.badges(uid);
        ChatLive.deliverPending(uid);   // tin nhắn tới trong lúc offline → giờ đã "đã nhận"
    }

    @OnMessage
    public void onMessage(Session session, String text) {
        Object uidObj = session.getUserProperties().get(RealtimeHub.PROP_UID);
        if (!(uidObj instanceof Integer) || text == null || text.length() > 512) return;
        int uid = (Integer) uidObj;
        Matcher t = TYPE.matcher(text);
        if (!t.find()) return;
        switch (t.group(1)) {
            case "ping":
                Presence.touch(uid);
                break;
            case "typing": {
                Matcher c = CONV_ID.matcher(text), ty = TYPING.matcher(text);
                if (c.find()) {
                    boolean typing = !ty.find() || "true".equals(ty.group(1));
                    ChatLive.typing(uid, (String) session.getUserProperties().get(RealtimeHub.PROP_NAME),
                                    Integer.parseInt(c.group(1)), typing, session);
                }
                break;
            }
            default:
                // bỏ qua loại không hỗ trợ
        }
    }

    @OnClose
    public void onClose(Session session) {
        Object uidObj = session.getUserProperties().get(RealtimeHub.PROP_UID);
        if (uidObj instanceof Integer && RealtimeHub.unregister((Integer) uidObj, session)) {
            Presence.wentOffline((Integer) uidObj);
        }
    }

    @OnError
    public void onError(Session session, Throwable error) {
        // Lỗi mạng / client đóng đột ngột: @OnClose được gọi tiếp theo để dọn dẹp
    }
}
