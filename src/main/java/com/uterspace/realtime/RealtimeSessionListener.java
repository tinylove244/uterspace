package com.uterspace.realtime;

import javax.servlet.annotation.WebListener;
import javax.servlet.http.HttpSessionEvent;
import javax.servlet.http.HttpSessionListener;

/**
 * Phiên HTTP kết thúc (đăng xuất, hết hạn, AuthFilter hủy vì tài khoản bị khóa) → đóng luôn các kết nối
 * WebSocket mở bằng phiên đó, để không ai tiếp tục nhận tin nhắn / thông báo sau khi đã đăng xuất.
 */
@WebListener
public class RealtimeSessionListener implements HttpSessionListener {

    @Override
    public void sessionCreated(HttpSessionEvent se) { }

    @Override
    public void sessionDestroyed(HttpSessionEvent se) {
        RealtimeHub.closeHttpSession(se.getSession().getId());
    }
}
