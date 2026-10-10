package com.uterspace.filter;

import com.uterspace.model.User;

import javax.servlet.*;
import javax.servlet.http.*;
import java.io.IOException;

/**
 * AdminFilter — lớp phân quyền thứ hai cho /admin/* (plan 6.4).
 * Chạy SAU AuthFilter, nên request tới đây chắc chắn đã đăng nhập và "authUser" là bản đọc từ DB —
 * không tin role trong session, nhờ vậy hạ quyền admin có hiệu lực ngay ở request kế tiếp.
 * Không phải admin → trang: về /feed; fetch JSON: 403.
 */
public class AdminFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest  req  = (HttpServletRequest)  request;
        HttpServletResponse resp = (HttpServletResponse) response;

        User u = (User) req.getAttribute("authUser");
        if (u != null && u.isAdmin()) {
            chain.doFilter(request, response);
        } else if (AuthFilter.wantsJson(req) || "POST".equals(req.getMethod())) {
            resp.setStatus(HttpServletResponse.SC_FORBIDDEN);
            resp.setContentType("application/json;charset=UTF-8");
            resp.getWriter().write("{\"error\":\"Bạn không có quyền quản trị.\"}");
        } else {
            resp.sendRedirect(req.getContextPath() + "/feed");
        }
    }

    @Override public void init(FilterConfig filterConfig) {}
    @Override public void destroy() {}
}
