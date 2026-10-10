package com.uterspace.controller;

import com.uterspace.dao.NotificationDAO;
import com.uterspace.dao.NotificationDAOImpl;
import com.uterspace.model.Notification;
import com.uterspace.model.User;
import com.uterspace.realtime.Live;
import com.uterspace.service.RelationService;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.LayoutSupport;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.*;

/**
 * NotificationController — Thông báo.
 *
 * GET  /notifications?tab=all|unread|friend|interaction|group|message|account&page=N
 *        phân loại theo nhóm chức năng, mới nhất trước, gom "Hôm nay / Hôm qua / 7 ngày qua / Trước đó".
 *        Mở trang KHÔNG tự đánh dấu đã đọc — mỗi thông báo giữ trạng thái riêng tới khi người dùng mở / đánh dấu.
 * GET  /notifications/open?id=   đánh dấu đã đọc rồi chuyển thẳng tới nội dung liên quan (bài, hồ sơ, hội thoại...)
 * POST /notifications/read       {id, read=true|false}   đánh dấu đã đọc / chưa đọc một thông báo
 * POST /notifications/read-all   đánh dấu tất cả đã đọc
 * POST /notifications/delete     {id}                    xóa một thông báo
 * POST /notifications/delete-read                        xóa mọi thông báo đã đọc
 * Mọi thao tác chỉ tác động thông báo CỦA CHÍNH người gọi (điều kiện user_id trong câu lệnh).
 */
@WebServlet(urlPatterns = {"/notifications", "/notifications/*"})
public class NotificationController extends HttpServlet {

    private static final int PAGE = 30;

    /** Tab → các loại thông báo thuộc tab đó (null = mọi loại) */
    static final Map<String, List<String>> TABS = new LinkedHashMap<>();
    static {
        TABS.put("all", null);
        TABS.put("unread", null);
        TABS.put("friend", Arrays.asList("FRIEND_REQUEST", "FRIEND_ACCEPT"));
        TABS.put("interaction", Arrays.asList("LIKE", "COMMENT", "SHARE"));
        TABS.put("group", Arrays.asList("GROUP_INVITE", "GROUP_JOIN_REQUEST", "GROUP_APPROVED", "GROUP_POST"));
        TABS.put("message", Collections.singletonList("MESSAGE"));
        TABS.put("account", Arrays.asList("ACCOUNT", "SYSTEM"));
    }

    private final NotificationDAO notifDAO = new NotificationDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        String action = action(req);
        if ("open".equals(action)) { open(req, resp, me); return; }
        if (!action.isEmpty()) { resp.sendError(404); return; }

        int uid = me.getUserId();
        String tab = TABS.containsKey(req.getParameter("tab")) ? req.getParameter("tab") : "all";
        int page = Math.max(1, parse(req.getParameter("page"), 1));
        List<String> types = TABS.get(tab);
        boolean unreadOnly = "unread".equals(tab);

        List<Notification> list = notifDAO.getPage(uid, types, unreadOnly, 0, PAGE * page);
        int total = notifDAO.count(uid, types, unreadOnly);

        // Số chưa đọc của từng tab
        Map<String, Integer> byType = notifDAO.unreadByType(uid);
        Map<String, Integer> tabUnread = new LinkedHashMap<>();
        int all = 0;
        for (int v : byType.values()) all += v;
        for (Map.Entry<String, List<String>> e : TABS.entrySet()) {
            int n = 0;
            if (e.getValue() == null) n = all;
            else for (String t : e.getValue()) n += byType.getOrDefault(t, 0);
            tabUnread.put(e.getKey(), n);
        }

        // Thông báo lời mời kết bạn: trạng thái hiện tại để hiện nút Chấp nhận / Từ chối ngay trong danh sách
        Set<Integer> requesters = new HashSet<>();
        for (Notification n : list) if ("FRIEND_REQUEST".equals(n.getType())) requesters.add(n.getActor().getUserId());
        Map<String, String> relation = new HashMap<>();
        RelationService.statusOf(uid, requesters).forEach((k, v) -> relation.put(String.valueOf(k), v.name()));

        req.setAttribute("notifications", list);
        req.setAttribute("hasMore",       total > list.size());
        req.setAttribute("nextPage",      page + 1);
        req.setAttribute("currentTab",    tab);
        req.setAttribute("tabUnread",     tabUnread);
        req.setAttribute("relation",      relation);
        req.setAttribute("currentPage",   "notifications");
        req.setAttribute("pageTitle",     "Thông báo");
        LayoutSupport.populate(req, me);
        req.getRequestDispatcher("/WEB-INF/views/notifications/notifications.jsp").forward(req, resp);
    }

    /** Mở thông báo: đánh dấu đã đọc + chuyển tới target_url (chỉ đường dẫn nội bộ — chống open redirect) */
    private void open(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        int id = parse(req.getParameter("id"), -1);
        Notification n = notifDAO.getById(me.getUserId(), id);
        if (n == null) { resp.sendRedirect(req.getContextPath() + "/notifications"); return; }
        if (!n.isRead()) {
            notifDAO.setRead(me.getUserId(), id, true);
            Live.badges(me.getUserId());
        }
        String target = n.getTargetUrl();
        boolean internal = target != null && target.startsWith("/") && !target.startsWith("//") && !target.contains("\\");
        resp.sendRedirect(req.getContextPath() + (internal ? target : "/notifications"));
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        int uid = me.getUserId();
        boolean ok;
        switch (action(req)) {
            case "read":        ok = notifDAO.setRead(uid, parse(req.getParameter("id"), -1), !"false".equals(req.getParameter("read"))); break;
            case "read-all":    notifDAO.markAllAsRead(uid); ok = true; break;
            case "delete":      ok = notifDAO.delete(uid, parse(req.getParameter("id"), -1)); break;
            case "delete-read": notifDAO.deleteRead(uid); ok = true; break;
            default:            resp.sendError(404); return;
        }
        if (!ok) { JsonUtil.error(resp, 404, "Thông báo không tồn tại."); return; }
        Live.badges(uid);   // đồng bộ huy hiệu ở mọi tab
        JsonUtil.write(resp, "{\"success\":true,\"unreadNotif\":" + notifDAO.getUnreadNotificationCount(uid) + "}");
    }

    private static String action(HttpServletRequest req) {
        String info = req.getPathInfo();
        return info == null || info.equals("/") ? "" : info.substring(1);
    }

    private static int parse(String s, int def) {
        try { return s == null ? def : Integer.parseInt(s.trim()); } catch (NumberFormatException e) { return def; }
    }
}
