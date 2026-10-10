package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.realtime.RealtimeHub;
import com.uterspace.service.NotificationService;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.UploadUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * AdminController — khu quản trị (admin_ui_plan.md).
 *
 * Phân quyền do AdminFilter (chỉ ADMIN, đọc role từ DB), CSRF do CsrfFilter — controller không kiểm lại.
 * Mọi thao tác thay đổi dữ liệu đều ghi admin_logs (kèm IP) và trả JSON cho fetch.
 *
 * Trang (GET):
 *   /admin              Tổng quan: 4 thẻ số liệu, biểu đồ 7 ngày, hoạt động gần đây
 *   /admin/users        Người dùng: tìm theo tên/email, lọc all|active|locked|admin, khóa / mở khóa
 *   /admin/reports      Kiểm duyệt: báo cáo đang chờ gom theo đối tượng
 *   /admin/posts        Bài viết bị ẩn / đã xóa / đang bị báo cáo: ẩn, khôi phục, xóa
 *   /admin/groups       Nhóm: giải tán nhóm vi phạm
 *   /admin/logs         Nhật ký quản trị
 * Thao tác (POST → JSON):
 *   /admin/users/lock (userId, reason) · /admin/users/unlock (userId)
 *   /admin/reports/resolve (targetType, targetId, note) · /admin/reports/dismiss (targetType, targetId)
 *   /admin/posts/hide · /admin/posts/restore · /admin/posts/delete (postId, reason)
 *   /admin/groups/delete (groupId, reason)
 */
@WebServlet(urlPatterns = {"/admin", "/admin/*"})
public class AdminController extends HttpServlet {

    private static final String[] WEEKDAYS = {"Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"};
    private static final int USERS_PAGE = 15, REPORTS_PAGE = 10, POSTS_PAGE = 12, GROUPS_PAGE = 15, LOGS_PAGE = 20;

    private final UserDAO userDAO = new UserDAOImpl();
    private final PostDAO postDAO = new PostDAOImpl();
    private final CommentDAO commentDAO = new CommentDAOImpl();
    private final GroupDAO groupDAO = new GroupDAOImpl();
    private final ReportDAO reportDAO = new ReportDAOImpl();
    private final AdminLogDAO logDAO = new AdminLogDAO();

    // ============================================================
    //  GET — các trang
    // ============================================================
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String path = req.getPathInfo() == null ? "/" : req.getPathInfo();
        switch (path) {
            case "/":        dashboard(req); break;
            case "/users":   users(req); break;
            case "/reports": reports(req); break;
            case "/posts":   posts(req); break;
            case "/groups":  groups(req); break;
            case "/logs":    logs(req); break;
            default:         resp.sendError(HttpServletResponse.SC_NOT_FOUND); return;
        }
        req.setAttribute("me", req.getAttribute("authUser"));
        req.setAttribute("pendingReportCount", reportDAO.countPendingGroups());
        String view = "/".equals(path) ? "dashboard" : path.substring(1);
        req.setAttribute("adminPage", view);
        req.getRequestDispatcher("/WEB-INF/views/admin/" + view + ".jsp").forward(req, resp);
    }

    private void dashboard(HttpServletRequest req) {
        req.setAttribute("pageTitle", "Bảng điều khiển");
        req.setAttribute("userCount", userDAO.countUsers());
        req.setAttribute("lockedCount", userDAO.countSearchUsers("", "locked"));
        req.setAttribute("postCount", postDAO.countPosts());
        req.setAttribute("hiddenPostCount", postDAO.countAdminSearch("", "hidden"));
        req.setAttribute("reportCount", reportDAO.countPending());
        req.setAttribute("groupCount", groupDAO.countGroups());
        req.setAttribute("didCount", new com.uterspace.security.DidDAO().countLinked());

        // Biểu đồ 7 ngày: đăng ký mới + bài mới theo ngày
        LocalDate today = LocalDate.now();
        LocalDateTime since = today.minusDays(6).atStartOfDay();
        int[] users = perDay(userDAO.getCreatedSince(since), today), posts = perDay(postDAO.getCreatedSince(since), today);
        int peak = 1;
        for (int i = 0; i < 7; i++) peak = Math.max(peak, Math.max(users[i], posts[i]));
        // Trục Y "đẹp": 4 vạch chia, bước là 1 / 2 / 5 × 10^k
        int step = niceStep(peak / 4.0), max = step * 4;
        List<Integer> ticks = new ArrayList<>();
        for (int i = 4; i >= 0; i--) ticks.add(step * i);
        req.setAttribute("chartTicks", ticks);
        List<Map<String, Object>> days = new ArrayList<>();
        int newUsers = 0, newPosts = 0;
        for (int i = 0; i < 7; i++) {
            LocalDate d = today.minusDays(6 - i);
            Map<String, Object> m = new HashMap<>();
            m.put("label", i == 6 ? "Hôm nay" : d.format(DateTimeFormatter.ofPattern("dd/MM")));
            m.put("weekday", WEEKDAYS[d.getDayOfWeek().getValue() - 1] + ", " + d.format(DateTimeFormatter.ofPattern("dd/MM")));
            m.put("users", users[i]);
            m.put("posts", posts[i]);
            m.put("usersPct", users[i] * 100 / max);
            m.put("postsPct", posts[i] * 100 / max);
            days.add(m);
            newUsers += users[i];
            newPosts += posts[i];
        }
        req.setAttribute("chartDays", days);
        req.setAttribute("todayLabel", WEEKDAYS[today.getDayOfWeek().getValue() - 1] + ", " +
                today.format(DateTimeFormatter.ofPattern("dd/MM/yyyy")));
        req.setAttribute("newUsers7", newUsers);
        req.setAttribute("newPosts7", newPosts);

        // Hoạt động gần đây: gộp nhật ký admin + báo cáo mới + tài khoản mới, mới nhất trước
        List<AdminActivity> feed = new ArrayList<>();
        for (AdminLog l : logDAO.getRecent(10)) {
            feed.add(new AdminActivity(l.getActionIcon(), l.getAdmin().getFullName(),
                    l.getActionLabel().toLowerCase() + " — " + l.getTargetLabel() +
                    (l.getDetail() != null ? " (" + l.getDetail() + ")" : ""), "/admin/logs", l.getActionTone(), l.getCreatedAt()));
        }
        for (Report r : reportDAO.getRecent(10)) {
            String what = Report.TARGET_POST.equals(r.getTargetType()) ? "1 bài viết"
                        : Report.TARGET_COMMENT.equals(r.getTargetType()) ? "1 bình luận" : "1 tài khoản";
            feed.add(new AdminActivity("flag", r.getReporter().getFullName(),
                    "đã báo cáo " + what + " · " + r.getReasonLabel(),
                    Report.STATUS_PENDING.equals(r.getStatus()) ? "/admin/reports" : null,
                    Report.STATUS_PENDING.equals(r.getStatus()) ? "danger" : "", r.getCreatedAt()));
        }
        for (User u : userDAO.getNewest(10)) {
            feed.add(new AdminActivity("user-plus", u.getFullName(), "vừa đăng ký tài khoản mới",
                    "/admin/users?q=" + urlEncode(u.getEmail()), "ok", u.getCreatedAt()));
        }
        feed.removeIf(a -> a.getAt() == null);
        feed.sort((a, b) -> b.getAt().compareTo(a.getAt()));
        req.setAttribute("activities", feed.size() > 12 ? feed.subList(0, 12) : feed);
    }

    private static int niceStep(double raw) {
        if (raw <= 1) return 1;
        double mag = Math.pow(10, Math.floor(Math.log10(raw)));
        double f = raw / mag;
        return (int) ((f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * mag);
    }

    private static int[] perDay(List<LocalDateTime> times, LocalDate today) {
        int[] r = new int[7];
        for (LocalDateTime t : times) {
            int idx = 6 - (int) java.time.temporal.ChronoUnit.DAYS.between(t.toLocalDate(), today);
            if (idx >= 0 && idx < 7) r[idx]++;
        }
        return r;
    }

    private void users(HttpServletRequest req) {
        String q = param(req, "q");
        String status = oneOf(param(req, "status"), "all", "active", "locked", "admin");
        int total = userDAO.countSearchUsers(q, status);
        int page = page(req, total, USERS_PAGE);
        req.setAttribute("pageTitle", "Quản lý Người dùng");
        List<User> list = userDAO.searchUsers(q, status, page, USERS_PAGE);
        List<Integer> ids = new ArrayList<>();
        for (User u : list) ids.add(u.getUserId());
        req.setAttribute("users", list);
        req.setAttribute("didUsers", new com.uterspace.security.DidDAO().linkedAmong(ids));
        req.setAttribute("q", q);
        req.setAttribute("status", status);
        req.setAttribute("total", total);
        req.setAttribute("counts", new int[]{
                userDAO.countSearchUsers("", "all"), userDAO.countSearchUsers("", "active"),
                userDAO.countSearchUsers("", "locked"), userDAO.countSearchUsers("", "admin")});
    }

    private void reports(HttpServletRequest req) {
        int total = reportDAO.countPendingGroups();
        int page = page(req, total, REPORTS_PAGE);
        List<ReportGroup> groups = reportDAO.getPendingGroups(page, REPORTS_PAGE);
        for (ReportGroup g : groups) {
            switch (g.getTargetType()) {
                case Report.TARGET_POST:    g.setPost(postDAO.getPostById(g.getTargetId())); break;
                case Report.TARGET_COMMENT: g.setComment(commentDAO.getCommentById(g.getTargetId())); break;
                default:                    g.setUser(userDAO.getUserById(g.getTargetId()));
            }
        }
        req.setAttribute("pageTitle", "Báo cáo vi phạm");
        req.setAttribute("groups", groups);
        req.setAttribute("total", total);
        req.setAttribute("reportCount", reportDAO.countPending());
    }

    private void posts(HttpServletRequest req) {
        String q = param(req, "q");
        String filter = oneOf(param(req, "filter"), "hidden", "reported", "negative", "deleted", "all");
        int total = postDAO.countAdminSearch(q, filter);
        int page = page(req, total, POSTS_PAGE);
        List<Post> posts = postDAO.adminSearch(q, filter, page, POSTS_PAGE);
        List<Integer> ids = new ArrayList<>();
        for (Post p : posts) ids.add(p.getPostId());
        req.setAttribute("pageTitle", "Quản lý bài viết");
        req.setAttribute("posts", posts);
        req.setAttribute("reportCounts", reportDAO.countPendingByPost(ids));
        req.setAttribute("q", q);
        req.setAttribute("filter", filter);
        req.setAttribute("total", total);
        req.setAttribute("counts", new int[]{
                postDAO.countAdminSearch("", "hidden"), postDAO.countAdminSearch("", "reported"),
                postDAO.countAdminSearch("", "negative"),
                postDAO.countAdminSearch("", "deleted"), postDAO.countAdminSearch("", "all")});
    }

    private void groups(HttpServletRequest req) {
        String q = param(req, "q");
        int total = groupDAO.countAdminList(q);
        int page = page(req, total, GROUPS_PAGE);
        req.setAttribute("pageTitle", "Quản lý Nhóm");
        req.setAttribute("groups", groupDAO.adminList(q, page, GROUPS_PAGE));
        req.setAttribute("q", q);
        req.setAttribute("total", total);
    }

    private static final List<String> LOG_ACTIONS = Arrays.asList(
            "LOCK_USER", "UNLOCK_USER", "HIDE_POST", "RESTORE_POST", "DELETE_POST", "DELETE_COMMENT", "DISMISS_REPORT", "DELETE_GROUP");

    private void logs(HttpServletRequest req) {
        String action = param(req, "action");
        if (!LOG_ACTIONS.contains(action)) action = null;
        int total = logDAO.count(action);
        int page = page(req, total, LOGS_PAGE);
        Map<String, String> actions = new LinkedHashMap<>();
        for (String a : LOG_ACTIONS) {
            AdminLog tmp = new AdminLog();
            tmp.setAction(a);
            actions.put(a, tmp.getActionLabel());
        }
        req.setAttribute("pageTitle", "Nhật ký quản trị");
        req.setAttribute("logs", logDAO.getPage(action, page, LOGS_PAGE));
        req.setAttribute("action", action);
        req.setAttribute("actions", actions);
        req.setAttribute("total", total);
    }

    // ============================================================
    //  POST — thao tác (JSON)
    // ============================================================
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        req.setCharacterEncoding("UTF-8");
        User admin = (User) req.getAttribute("authUser");
        String path = req.getPathInfo() == null ? "" : req.getPathInfo();
        try {
            switch (path) {
                case "/users/lock":      lockUser(req, resp, admin); break;
                case "/users/unlock":    unlockUser(req, resp, admin); break;
                case "/reports/resolve": resolveReport(req, resp, admin); break;
                case "/reports/dismiss": dismissReport(req, resp, admin); break;
                case "/posts/hide":      moderatePost(req, resp, admin, Post.MODERATION_HIDDEN); break;
                case "/posts/restore":   moderatePost(req, resp, admin, Post.MODERATION_ACTIVE); break;
                case "/posts/delete":    moderatePost(req, resp, admin, Post.MODERATION_DELETED); break;
                case "/groups/delete":   deleteGroup(req, resp, admin); break;
                default:                 JsonUtil.error(resp, 404, "Không tìm thấy thao tác.");
            }
        } catch (NumberFormatException e) {
            JsonUtil.error(resp, 400, "Tham số không hợp lệ.");
        }
    }

    // ---------- Người dùng ----------

    private void lockUser(HttpServletRequest req, HttpServletResponse resp, User admin) throws IOException {
        User target = userDAO.getUserById(intParam(req, "userId"));
        String reason = trim(param(req, "reason"), 255);
        String deny = lockDeniedReason(admin, target);
        if (deny != null) { JsonUtil.error(resp, deny.startsWith("Không tìm") ? 404 : 403, deny); return; }
        if (reason.length() < 3) { JsonUtil.error(resp, 400, "Vui lòng nhập lý do khóa (ít nhất 3 ký tự)."); return; }
        if (target.isLocked()) { JsonUtil.error(resp, 409, "Tài khoản này đã bị khóa."); return; }
        doLock(req, admin, target, reason);
        JsonUtil.write(resp, "{\"success\":true,\"status\":\"LOCKED\",\"message\":" +
                JsonUtil.str("Đã khóa tài khoản " + target.getFullName() + ".") + "}");
    }

    /** Khóa + đá khỏi mọi kết nối realtime + ghi log. AuthFilter đọc trạng thái từ DB nên request kế tiếp bị đăng xuất. */
    private void doLock(HttpServletRequest req, User admin, User target, String reason) {
        userDAO.setStatus(target.getUserId(), User.STATUS_LOCKED, reason);
        RealtimeHub.closeUser(target.getUserId());
        log(req, admin, "LOCK_USER", "USER", target.getUserId(), target.getEmail() + " — " + reason);
    }

    /** null = được khóa. Không khóa chính mình, không khóa admin khác (phải hạ quyền trước). */
    private static String lockDeniedReason(User admin, User target) {
        if (target == null) return "Không tìm thấy người dùng.";
        if (target.getUserId() == admin.getUserId()) return "Bạn không thể tự khóa tài khoản của mình.";
        if (target.isAdmin()) return "Không thể khóa tài khoản quản trị viên khác.";
        return null;
    }

    private void unlockUser(HttpServletRequest req, HttpServletResponse resp, User admin) throws IOException {
        User target = userDAO.getUserById(intParam(req, "userId"));
        if (target == null) { JsonUtil.error(resp, 404, "Không tìm thấy người dùng."); return; }
        if (!target.isLocked()) { JsonUtil.error(resp, 409, "Tài khoản này đang hoạt động."); return; }
        userDAO.setStatus(target.getUserId(), User.STATUS_ACTIVE, null);
        log(req, admin, "UNLOCK_USER", "USER", target.getUserId(), target.getEmail());
        notifySystem(target.getUserId(), "Tài khoản của bạn đã được quản trị viên mở khóa. Chào mừng bạn quay lại!", "/feed");
        JsonUtil.write(resp, "{\"success\":true,\"status\":\"ACTIVE\",\"message\":" +
                JsonUtil.str("Đã mở khóa tài khoản " + target.getFullName() + ".") + "}");
    }

    // ---------- Báo cáo ----------

    /**
     * Xử lý vi phạm theo loại đối tượng rồi đóng mọi báo cáo đang chờ của nó (RESOLVED):
     * bài viết → ẩn (khôi phục được ở trang Bài viết ẩn) · bình luận → xóa · tài khoản → khóa.
     * Đối tượng đã bị xóa từ trước → chỉ đóng báo cáo.
     */
    private void resolveReport(HttpServletRequest req, HttpServletResponse resp, User admin) throws IOException {
        String type = param(req, "targetType");
        int id = intParam(req, "targetId");
        String note = trim(param(req, "note"), 200);
        String reasons = reasonSummary(type, id);
        String done;
        switch (type) {
            case Report.TARGET_POST: {
                Post p = postDAO.getPostById(id);
                if (p != null && !Post.MODERATION_DELETED.equals(p.getModerationStatus())) {
                    postDAO.setModerationStatus(id, Post.MODERATION_HIDDEN);
                    log(req, admin, "HIDE_POST", "POST", id, "Báo cáo: " + reasons + (note.isEmpty() ? "" : " — " + note));
                    notifySystem(p.getUserId(), "Bài viết của bạn đã bị ẩn do vi phạm tiêu chuẩn cộng đồng (" + reasons + ").",
                                 "/profile?userId=" + p.getUserId());
                    done = "Đã ẩn bài viết";
                } else done = "Bài viết không còn tồn tại — đã đóng báo cáo";
                break;
            }
            case Report.TARGET_COMMENT: {
                Comment c = commentDAO.getCommentById(id);
                if (c != null) {
                    commentDAO.deleteComment(id);
                    String excerpt = c.getContent() == null ? "" : c.getContent();
                    if (excerpt.length() > 80) excerpt = excerpt.substring(0, 77) + "…";
                    log(req, admin, "DELETE_COMMENT", "COMMENT", id, "Báo cáo: " + reasons + " — \"" + excerpt + "\"");
                    notifySystem(c.getUserId(), "Bình luận của bạn đã bị xóa do vi phạm tiêu chuẩn cộng đồng (" + reasons + ").", "/feed");
                    done = "Đã xóa bình luận";
                } else done = "Bình luận không còn tồn tại — đã đóng báo cáo";
                break;
            }
            case Report.TARGET_USER: {
                User u = userDAO.getUserById(id);
                if (u != null && !u.isLocked()) {
                    String deny = lockDeniedReason(admin, u);
                    if (deny != null) { JsonUtil.error(resp, 403, deny + " Hãy chọn \"Bỏ qua\"."); return; }
                    doLock(req, admin, u, "Bị báo cáo: " + reasons + (note.isEmpty() ? "" : " — " + note));
                    done = "Đã khóa tài khoản";
                } else done = u == null ? "Tài khoản không còn tồn tại — đã đóng báo cáo" : "Tài khoản đã bị khóa trước đó — đã đóng báo cáo";
                break;
            }
            default:
                JsonUtil.error(resp, 400, "Loại đối tượng không hợp lệ."); return;
        }
        int closed = reportDAO.closeReports(type, id, Report.STATUS_RESOLVED, admin.getUserId());
        JsonUtil.write(resp, "{\"success\":true,\"closed\":" + closed + ",\"pending\":" + reportDAO.countPendingGroups() +
                ",\"message\":" + JsonUtil.str(done + " (" + closed + " báo cáo).") + "}");
    }

    private void dismissReport(HttpServletRequest req, HttpServletResponse resp, User admin) throws IOException {
        String type = param(req, "targetType");
        int id = intParam(req, "targetId");
        if (!Arrays.asList(Report.TARGET_POST, Report.TARGET_COMMENT, Report.TARGET_USER).contains(type)) {
            JsonUtil.error(resp, 400, "Loại đối tượng không hợp lệ."); return;
        }
        String reasons = reasonSummary(type, id);
        int closed = reportDAO.closeReports(type, id, Report.STATUS_DISMISSED, admin.getUserId());
        if (closed == 0) { JsonUtil.error(resp, 409, "Các báo cáo này đã được xử lý."); return; }
        log(req, admin, "DISMISS_REPORT", type, id, closed + " báo cáo: " + reasons);
        JsonUtil.write(resp, "{\"success\":true,\"closed\":" + closed + ",\"pending\":" + reportDAO.countPendingGroups() +
                ",\"message\":" + JsonUtil.str("Đã bỏ qua " + closed + " báo cáo.") + "}");
    }

    /** "Spam / Quảng cáo, Ngôn từ xúc phạm" — các lý do của báo cáo đang chờ về một đối tượng */
    private String reasonSummary(String type, int id) {
        Set<String> s = new LinkedHashSet<>();
        for (String r : reportDAO.pendingReasons(type, id)) s.add(Report.REASONS.getOrDefault(r, r));
        return s.isEmpty() ? "không rõ" : String.join(", ", s);
    }

    // ---------- Bài viết ----------

    private void moderatePost(HttpServletRequest req, HttpServletResponse resp, User admin, String status) throws IOException {
        int id = intParam(req, "postId");
        String reason = trim(param(req, "reason"), 200);
        Post p = postDAO.getPostById(id);
        if (p == null) { JsonUtil.error(resp, 404, "Không tìm thấy bài viết."); return; }
        if (status.equals(p.getModerationStatus())) { JsonUtil.error(resp, 409, "Bài viết đã ở trạng thái này."); return; }
        postDAO.setModerationStatus(id, status);
        String action, msg;
        if (Post.MODERATION_ACTIVE.equals(status)) {
            action = "RESTORE_POST"; msg = "Đã khôi phục bài viết.";
            notifySystem(p.getUserId(), "Bài viết của bạn đã được quản trị viên khôi phục.", "/profile?userId=" + p.getUserId());
        } else if (Post.MODERATION_HIDDEN.equals(status)) {
            action = "HIDE_POST"; msg = "Đã ẩn bài viết.";
            notifySystem(p.getUserId(), "Bài viết của bạn đã bị ẩn do vi phạm tiêu chuẩn cộng đồng" +
                         (reason.isEmpty() ? "." : ": " + reason), "/profile?userId=" + p.getUserId());
        } else {
            action = "DELETE_POST"; msg = "Đã xóa bài viết.";
            notifySystem(p.getUserId(), "Bài viết của bạn đã bị xóa do vi phạm tiêu chuẩn cộng đồng" +
                         (reason.isEmpty() ? "." : ": " + reason), "/feed");
        }
        // Ẩn / xóa = đã xử lý xong mọi báo cáo đang chờ về bài này
        if (!Post.MODERATION_ACTIVE.equals(status)) reportDAO.closeReports(Report.TARGET_POST, id, Report.STATUS_RESOLVED, admin.getUserId());
        log(req, admin, action, "POST", id, (p.getAuthor() != null ? p.getAuthor().getEmail() : "") + (reason.isEmpty() ? "" : " — " + reason));
        JsonUtil.write(resp, "{\"success\":true,\"status\":" + JsonUtil.str(status) + ",\"pending\":" + reportDAO.countPendingGroups() +
                ",\"message\":" + JsonUtil.str(msg) + "}");
    }

    // ---------- Nhóm ----------

    private void deleteGroup(HttpServletRequest req, HttpServletResponse resp, User admin) throws IOException {
        Group g = groupDAO.getGroupById(intParam(req, "groupId"));
        String reason = trim(param(req, "reason"), 200);
        if (g == null) { JsonUtil.error(resp, 404, "Không tìm thấy nhóm."); return; }
        if (reason.length() < 3) { JsonUtil.error(resp, 400, "Vui lòng nhập lý do giải tán (ít nhất 3 ký tự)."); return; }
        // Lấy danh sách thành viên TRƯỚC khi xóa để báo cho họ
        List<Integer> members = new ArrayList<>();
        for (GroupMember m : groupDAO.getMembers(g.getGroupId(), GroupMember.STATUS_ACTIVE)) members.add(m.getUserId());
        List<String> files = groupDAO.deleteGroup(g.getGroupId());
        for (String f : files) UploadUtil.delete(req.getServletContext(), f);
        UploadUtil.delete(req.getServletContext(), g.getCoverImage());
        log(req, admin, "DELETE_GROUP", "GROUP", g.getGroupId(), g.getName() + " (" + members.size() + " thành viên) — " + reason);
        for (Integer uid : members) {
            notifySystem(uid, "Nhóm \"" + g.getName() + "\" đã bị quản trị viên giải tán. Lý do: " + reason, "/groups");
        }
        JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Đã giải tán nhóm " + g.getName() + ".") + "}");
    }

    // ============================================================
    //  Helpers
    // ============================================================

    private void log(HttpServletRequest req, User admin, String action, String type, Integer id, String detail) {
        String ip = req.getRemoteAddr();
        if ("0:0:0:0:0:0:0:1".equals(ip)) ip = "::1";   // IPv6 loopback dạng rút gọn
        logDAO.log(admin.getUserId(), action, type, id, detail, ip);
    }

    /** Thông báo kiểm duyệt gửi tới người bị tác động — actor là chính họ để không lộ admin nào đã xử lý */
    private static void notifySystem(int userId, String content, String url) {
        try { NotificationService.notify(userId, userId, "SYSTEM", content, url, null); } catch (RuntimeException ignored) { }
    }

    private static String param(HttpServletRequest req, String name) {
        String v = req.getParameter(name);
        return v == null ? "" : v.trim();
    }

    private static int intParam(HttpServletRequest req, String name) {
        return Integer.parseInt(param(req, name));
    }

    private static String trim(String s, int max) {
        return s.length() > max ? s.substring(0, max) : s;
    }

    private static String oneOf(String v, String... allowed) {
        for (String a : allowed) if (a.equals(v)) return v;
        return allowed[0];
    }

    /** Đọc ?page=, kẹp trong [1, số trang]; đặt page / totalPages cho JSP */
    private static int page(HttpServletRequest req, int total, int size) {
        int pages = Math.max(1, (total + size - 1) / size);
        int p;
        try { p = Integer.parseInt(param(req, "page")); } catch (NumberFormatException e) { p = 1; }
        p = Math.max(1, Math.min(p, pages));
        req.setAttribute("page", p);
        req.setAttribute("totalPages", pages);
        return p;
    }

    private static String urlEncode(String s) {
        try { return java.net.URLEncoder.encode(s == null ? "" : s, "UTF-8"); } catch (java.io.UnsupportedEncodingException e) { return ""; }
    }
}
