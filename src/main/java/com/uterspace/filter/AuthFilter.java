package com.uterspace.filter;

import com.uterspace.controller.AuthController;
import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.model.User;

import javax.servlet.*;
import javax.servlet.http.*;
import java.io.IOException;

/**
 * AuthFilter — Bảo vệ các trang yêu cầu đăng nhập.
 *  - Chưa có session "currentUser" → redirect về /login (endpoint /api/* trả 401 JSON).
 *  - Đã đăng nhập: đọc lại user từ DB MỖI request (truy vấn theo khóa chính, rẻ) để
 *      + tài khoản bị admin khóa bị đá ra ngay ở request kế tiếp (plan 6.4),
 *      + vai trò trong session luôn khớp DB (hạ quyền admin có hiệu lực ngay).
 *    User mới đọc được đặt vào request attribute "authUser" cho AdminFilter dùng lại.
 *
 * Khai báo và thứ tự chạy nằm trong web.xml: EncodingFilter → AuthFilter → AdminFilter → CsrfFilter.
 */
public class AuthFilter implements Filter {

    private final UserDAO userDAO = new UserDAOImpl();

    @Override
    public void doFilter(ServletRequest request, ServletResponse response,
                         FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest  req  = (HttpServletRequest)  request;
        HttpServletResponse resp = (HttpServletResponse) response;

        HttpSession session = req.getSession(false);
        User sessionUser = session != null ? (User) session.getAttribute("currentUser") : null;

        if (sessionUser == null) {
            denyAnonymous(req, resp);
            return;
        }

        User fresh = userDAO.getUserById(sessionUser.getUserId());
        if (fresh == null || fresh.isLocked()) {
            // Bị khóa (hoặc tài khoản không còn) → hủy phiên, để lại lời nhắn cho trang đăng nhập
            session.invalidate();
            req.getSession(true).setAttribute("loginNotice",
                    fresh != null ? AuthController.lockedMessage(fresh) : "Phiên đăng nhập không còn hợp lệ.");
            denyAnonymous(req, resp);
            return;
        }

        // Mật khẩu vừa được đổi / đặt lại ở nơi khác → phiên cũ hết hiệu lực (phiên đổi mật khẩu tự cập nhật hash của mình)
        if (sessionUser.getPasswordHash() != null && !sessionUser.getPasswordHash().equals(fresh.getPasswordHash())) {
            session.invalidate();
            req.getSession(true).setAttribute("loginNotice", "Mật khẩu tài khoản vừa được thay đổi. Vui lòng đăng nhập lại.");
            denyAnonymous(req, resp);
            return;
        }

        // Đồng bộ vai trò/trạng thái vào object trong session (sidebar hiện mục "Quản trị" theo role)
        sessionUser.setRole(fresh.getRole());
        sessionUser.setStatus(fresh.getStatus());
        req.setAttribute("authUser", fresh);
        req.setAttribute("csrfToken", CsrfFilter.token(session));

        chain.doFilter(request, response);
    }

    private void denyAnonymous(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        if (req.getServletPath().startsWith("/api/") || wantsJson(req)) {
            // Gọi bằng fetch: trả 401 JSON, không redirect sang trang HTML đăng nhập
            resp.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            resp.setContentType("application/json;charset=UTF-8");
            resp.getWriter().write("{\"error\":\"unauthorized\"}");
            return;
        }
        // Chưa đăng nhập → về login, giữ lại URL (GET) để redirect sau.
        // Lưu đường dẫn TƯƠNG ĐỐI với context path, vì AuthController
        // sẽ tự nối lại contextPath khi redirect (tránh /uterspace/uterspace/feed).
        String ctxPath = req.getContextPath();
        if ("GET".equals(req.getMethod())) {
            String targetUrl = req.getRequestURI();
            if (ctxPath != null && !ctxPath.isEmpty() && targetUrl.startsWith(ctxPath)) {
                targetUrl = targetUrl.substring(ctxPath.length());
            }
            if (targetUrl.isEmpty()) targetUrl = "/feed";
            String query = req.getQueryString();
            if (query != null) targetUrl += "?" + query;
            req.getSession(true).setAttribute("redirectAfterLogin", targetUrl);
        }
        resp.sendRedirect(ctxPath + "/login");
    }

    /** Request do fetch gửi, mong nhận JSON (các thao tác POST của admin / báo cáo) */
    static boolean wantsJson(HttpServletRequest req) {
        String accept = req.getHeader("Accept");
        return (accept != null && accept.contains("application/json"))
            || req.getHeader("X-CSRF-Token") != null;
    }

    @Override public void init(FilterConfig filterConfig) {}
    @Override public void destroy() {}
}
