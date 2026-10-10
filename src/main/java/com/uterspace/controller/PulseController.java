package com.uterspace.controller;

import com.uterspace.model.User;
import com.uterspace.realtime.Live;
import com.uterspace.realtime.Presence;
import com.uterspace.util.JsonUtil;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;

/**
 * PulseController — GET /api/pulse → {"type":"badge","unreadChat":n,"unreadNotif":m,"friendRequests":k}
 * Đường DỰ PHÒNG khi trình duyệt không giữ được WebSocket (realtime.js): ~12 giây/lần khi mất kết nối,
 * ~60 giây/lần khi WebSocket đang chạy (chỉ để đồng bộ lại). Đồng thời ghi nhận "đang hoạt động" (Presence).
 */
@WebServlet("/api/pulse")
public class PulseController extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        HttpSession session = req.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (user == null) { JsonUtil.error(resp, 401, "Chưa đăng nhập."); return; }
        Presence.touch(user.getUserId());
        JsonUtil.write(resp, Live.badgeJson(user.getUserId()));
    }
}
