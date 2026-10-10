package com.uterspace.controller;

import com.uterspace.dao.BlockDAO;
import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.dao.UserSettingsDAO;
import com.uterspace.model.User;
import com.uterspace.model.UserSettings;
import com.uterspace.service.NotificationService;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.LayoutSupport;
import com.uterspace.util.PasswordUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.Arrays;

/**
 * SettingsController — Cài đặt.
 *
 * GET  /settings?tab=account|privacy|notifications|content|archive|security|identity|blocked
 * POST /settings/password       {currentPassword, newPassword, confirmPassword}
 * POST /settings/privacy        {friendRequestPolicy, messagePolicy, showOnline}
 * POST /settings/notifications  {notifFriend, notifInteraction, notifGroup, notifMessage,
 *                                pushFriend, pushInteraction, pushGroup, pushMessage, pushAccount}  (true/false)
 * POST /settings/content        {feedMode=SMART|LATEST, hideNegative, contentFilter (mỗi dòng một từ khóa)}
 * POST /settings/archive        {archiveStories}  — tắt = tin hết hạn bị xóa vĩnh viễn (kể cả tin đã lưu trữ)
 * Kho lưu trữ tin tải bằng GET /stories/archive; passkey ở /security/*; DID ở /security/did/*.
 * Bỏ chặn dùng chung endpoint /friends/unblock. Mọi POST cần CSRF token.
 */
@WebServlet(urlPatterns = {"/settings", "/settings/*"})
public class SettingsController extends HttpServlet {

    private final UserSettingsDAO settingsDAO = new UserSettingsDAO();
    private final UserDAO         userDAO     = new UserDAOImpl();
    private final BlockDAO        blockDAO    = new BlockDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        String tab = req.getParameter("tab");
        if (!Arrays.asList("account", "privacy", "notifications", "content", "archive", "security", "identity", "blocked").contains(tab)) tab = "account";
        req.setAttribute("settings",     settingsDAO.get(me.getUserId()));
        req.setAttribute("blockedList",  blockDAO.listBlockedBy(me.getUserId()));
        req.setAttribute("passkeys",     new com.uterspace.security.WebAuthnDAO().listFor(me.getUserId()));
        req.setAttribute("myDid",        new com.uterspace.security.DidDAO().findByUser(me.getUserId()));
        req.setAttribute("activeTab",    tab);
        req.setAttribute("currentPage",  "settings");
        req.setAttribute("pageTitle",    "Cài đặt");
        LayoutSupport.populate(req, me);
        req.getRequestDispatcher("/WEB-INF/views/settings/settings.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        req.setCharacterEncoding("UTF-8");
        User me = (User) req.getSession().getAttribute("currentUser");
        String info = req.getPathInfo() == null ? "" : req.getPathInfo();
        switch (info) {
            case "/password":      changePassword(req, resp, me); break;
            case "/privacy":       savePrivacy(req, resp, me); break;
            case "/notifications": saveNotifications(req, resp, me); break;
            case "/content":       saveContent(req, resp, me); break;
            case "/archive":       saveArchive(req, resp, me); break;
            default:               resp.sendError(404);
        }
    }

    private void changePassword(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        String current = req.getParameter("currentPassword"), next = req.getParameter("newPassword"),
               confirm = req.getParameter("confirmPassword");
        if (current == null || next == null || confirm == null) { JsonUtil.error(resp, 400, "Vui lòng điền đủ các ô."); return; }
        // Đã bật sinh trắc học → đổi mật khẩu cần quét vân tay / khuôn mặt trong 5 phút gần nhất (WebAuthn, xem StepUp)
        if (new com.uterspace.security.WebAuthnDAO().countFor(me.getUserId()) > 0
                && !com.uterspace.security.StepUp.recentBiometric(req.getSession())) {
            resp.setStatus(403);
            JsonUtil.write(resp, "{\"error\":" + JsonUtil.str("Xác thực vân tay / khuôn mặt để đổi mật khẩu.") +
                                 ",\"needStepUp\":true,\"method\":\"biometric\"}");
            return;
        }
        User fresh = userDAO.getUserById(me.getUserId());
        if (!PasswordUtil.verifyPassword(current, fresh.getPasswordHash())) { JsonUtil.error(resp, 400, "Mật khẩu hiện tại không đúng."); return; }
        String pwError = PasswordUtil.policyError(next);
        if (pwError != null) { JsonUtil.error(resp, 400, pwError); return; }
        if (!next.equals(confirm)) { JsonUtil.error(resp, 400, "Xác nhận mật khẩu không khớp."); return; }
        if (next.equals(current)) { JsonUtil.error(resp, 400, "Mật khẩu mới phải khác mật khẩu hiện tại."); return; }
        String hash = PasswordUtil.hashPassword(next);
        userDAO.updatePasswordHash(me.getUserId(), hash);
        // Phiên đang thao tác giữ đăng nhập; các phiên khác bị AuthFilter đăng xuất ở request kế tiếp
        Object su = req.getSession().getAttribute("currentUser");
        if (su instanceof User) ((User) su).setPasswordHash(hash);
        NotificationService.account(me.getUserId(),
                "Mật khẩu tài khoản của bạn vừa được thay đổi (" + AuthController.describeDevice(req.getHeader("User-Agent")) +
                "). Nếu không phải bạn, hãy liên hệ quản trị viên ngay.", "/settings?tab=account");
        JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Đã đổi mật khẩu thành công.") + "}");
    }

    private void savePrivacy(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        UserSettings s = settingsDAO.get(me.getUserId());
        String fr = req.getParameter("friendRequestPolicy"), msg = req.getParameter("messagePolicy");
        if (!Arrays.asList(UserSettings.FR_EVERYONE, UserSettings.FR_FRIENDS_OF_FRIENDS, UserSettings.FR_NOBODY).contains(fr)
                || !Arrays.asList(UserSettings.MSG_EVERYONE, UserSettings.MSG_FRIENDS).contains(msg)) {
            JsonUtil.error(resp, 400, "Lựa chọn không hợp lệ."); return;
        }
        s.setFriendRequestPolicy(fr);
        s.setMessagePolicy(msg);
        s.setShowOnline(bool(req, "showOnline"));
        settingsDAO.save(s);
        JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Đã lưu cài đặt quyền riêng tư.") + "}");
    }

    private void saveNotifications(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        UserSettings s = settingsDAO.get(me.getUserId());
        s.setNotifFriend(bool(req, "notifFriend"));
        s.setNotifInteraction(bool(req, "notifInteraction"));
        s.setNotifGroup(bool(req, "notifGroup"));
        s.setNotifMessage(bool(req, "notifMessage"));
        s.setPushFriend(bool(req, "pushFriend"));
        s.setPushInteraction(bool(req, "pushInteraction"));
        s.setPushGroup(bool(req, "pushGroup"));
        s.setPushMessage(bool(req, "pushMessage"));
        s.setPushAccount(bool(req, "pushAccount"));
        settingsDAO.save(s);
        JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Đã lưu tùy chọn thông báo.") + "}");
    }

    private void saveContent(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        UserSettings s = settingsDAO.get(me.getUserId());
        String mode = req.getParameter("feedMode");
        if (!UserSettings.FEED_SMART.equals(mode) && !UserSettings.FEED_LATEST.equals(mode)) {
            JsonUtil.error(resp, 400, "Chế độ bảng tin không hợp lệ."); return;
        }
        // Bộ lọc: mỗi dòng một mục, bỏ trống / trùng, mỗi mục ≤ 50 ký tự, tối đa FILTER_MAX_ITEMS mục
        java.util.LinkedHashSet<String> terms = new java.util.LinkedHashSet<>();
        String raw = req.getParameter("contentFilter");
        if (raw != null) {
            for (String line : raw.split("[\\r\\n,]+")) {
                String t = line.trim();
                if (t.isEmpty()) continue;
                if (t.length() > 50) { JsonUtil.error(resp, 400, "Mỗi từ khóa tối đa 50 ký tự: \"" + t.substring(0, 20) + "…\""); return; }
                terms.add(t);
            }
        }
        if (terms.size() > UserSettings.FILTER_MAX_ITEMS) {
            JsonUtil.error(resp, 400, "Bộ lọc tối đa " + UserSettings.FILTER_MAX_ITEMS + " từ khóa."); return;
        }
        s.setFeedMode(mode);
        s.setHideNegative(bool(req, "hideNegative"));
        s.setContentFilter(terms.isEmpty() ? null : String.join("\n", terms));
        settingsDAO.save(s);
        JsonUtil.write(resp, "{\"success\":true,\"count\":" + terms.size() + ",\"message\":" +
                JsonUtil.str("Đã lưu cài đặt bảng tin và bộ lọc nội dung.") + "}");
    }

    private void saveArchive(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        UserSettings s = settingsDAO.get(me.getUserId());
        s.setArchiveStories(bool(req, "archiveStories"));
        settingsDAO.save(s);
        JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str(s.isArchiveStories()
                ? "Đã bật lưu trữ tin — tin hết hạn sẽ được giữ lại trong kho lưu trữ."
                : "Đã tắt lưu trữ tin — tin hết hạn (kể cả tin đã lưu trữ) sẽ bị xóa vĩnh viễn.") + "}");
    }

    private static boolean bool(HttpServletRequest req, String name) {
        String v = req.getParameter(name);
        return "true".equals(v) || "on".equals(v) || "1".equals(v);
    }
}
