package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.Comment;
import com.uterspace.model.Post;
import com.uterspace.model.Report;
import com.uterspace.model.User;
import com.uterspace.util.JsonUtil;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;

/**
 * ReportController — người dùng báo cáo vi phạm (plan 6.4).
 *
 * POST /report/create  (JSON, cần CSRF token — CsrfFilter)
 *   targetType = POST | COMMENT | USER, targetId, reason (mã trong Report.REASONS), detail (tùy chọn)
 *
 * Chặn IDOR: chỉ báo cáo được bài/bình luận mình ĐƯỢC PHÉP XEM, không tự báo cáo chính mình.
 * Mỗi người chỉ báo cáo một đối tượng một lần (UNIQUE trong DB) → lần sau trả thông báo thân thiện.
 */
@WebServlet(urlPatterns = {"/report/create"})
public class ReportController extends HttpServlet {

    private final ReportDAO  reportDAO  = new ReportDAOImpl();
    private final PostDAO    postDAO    = new PostDAOImpl();
    private final CommentDAO commentDAO = new CommentDAOImpl();
    private final UserDAO    userDAO    = new UserDAOImpl();

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        req.setCharacterEncoding("UTF-8");
        User me = (User) req.getSession().getAttribute("currentUser");

        String type   = req.getParameter("targetType");
        String reason = req.getParameter("reason");
        String detail = req.getParameter("detail");
        int targetId;
        try { targetId = Integer.parseInt(req.getParameter("targetId")); }
        catch (NumberFormatException e) { JsonUtil.error(resp, 400, "Đối tượng báo cáo không hợp lệ."); return; }

        if (reason == null || !Report.REASONS.containsKey(reason)) {
            JsonUtil.error(resp, 400, "Vui lòng chọn lý do báo cáo."); return;
        }
        detail = detail == null ? null : detail.trim();
        if (detail != null && detail.isEmpty()) detail = null;
        if (detail != null && detail.length() > 500) detail = detail.substring(0, 500);

        // Kiểm tra đối tượng tồn tại + người báo cáo có quyền nhìn thấy nó
        int ownerId;
        if (Report.TARGET_POST.equals(type)) {
            Post p = postDAO.getPostById(targetId);
            if (p == null || !postDAO.canView(targetId, me.getUserId())) {
                JsonUtil.error(resp, 404, "Bài viết không tồn tại hoặc bạn không có quyền xem."); return;
            }
            ownerId = p.getAuthor().getUserId();
        } else if (Report.TARGET_COMMENT.equals(type)) {
            Comment c = commentDAO.getCommentById(targetId);
            if (c == null || !postDAO.canView(c.getPost().getPostId(), me.getUserId())) {
                JsonUtil.error(resp, 404, "Bình luận không tồn tại hoặc bạn không có quyền xem."); return;
            }
            ownerId = c.getAuthor().getUserId();
        } else if (Report.TARGET_USER.equals(type)) {
            User u = userDAO.getUserById(targetId);
            if (u == null) { JsonUtil.error(resp, 404, "Tài khoản không tồn tại."); return; }
            ownerId = u.getUserId();
        } else {
            JsonUtil.error(resp, 400, "Loại báo cáo không hợp lệ."); return;
        }
        if (ownerId == me.getUserId()) {
            JsonUtil.error(resp, 400, "Bạn không thể báo cáo nội dung của chính mình."); return;
        }

        if (!reportDAO.create(me.getUserId(), type, targetId, reason, detail)) {
            JsonUtil.write(resp, "{\"success\":true,\"duplicate\":true,\"message\":" +
                    JsonUtil.str("Bạn đã báo cáo nội dung này rồi — quản trị viên sẽ sớm xem xét.") + "}");
            return;
        }
        JsonUtil.write(resp, "{\"success\":true,\"message\":" +
                JsonUtil.str("Đã gửi báo cáo. Cảm ơn bạn đã giúp cộng đồng an toàn hơn! 🚩") + "}");
    }
}
