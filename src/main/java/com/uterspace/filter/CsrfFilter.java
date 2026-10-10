package com.uterspace.filter;

import javax.servlet.*;
import javax.servlet.http.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * CsrfFilter — chống giả mạo request cho các thao tác POST có tính phá hủy (plan 6.4).
 *
 *  - Mỗi phiên đăng nhập có một token ngẫu nhiên (session attribute "csrfToken"),
 *    JSP in ra thẻ <meta name="csrf-token"> (header.jsp) để JS đọc.
 *  - fetch gửi kèm header "X-CSRF-Token" (hoặc form gửi field "_csrf").
 *  - Filter này được map cho /admin/* và /report/* (web.xml): POST thiếu/sai token → 403.
 *
 * Token được tạo ở token(session) — AuthFilter gọi cho mọi request đã đăng nhập và đặt vào
 * request attribute "csrfToken", nên trang nào cũng in được thẻ meta dù không đi qua filter này.
 */
public class CsrfFilter implements Filter {

    public static final String SESSION_KEY = "csrfToken";
    public static final String HEADER      = "X-CSRF-Token";
    public static final String PARAM       = "_csrf";

    private static final SecureRandom RANDOM = new SecureRandom();

    /** Lấy (tạo nếu chưa có) token của phiên */
    public static String token(HttpSession session) {
        if (session == null) return "";
        synchronized (session) {
            String t = (String) session.getAttribute(SESSION_KEY);
            if (t == null) {
                byte[] b = new byte[32];
                RANDOM.nextBytes(b);
                t = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
                session.setAttribute(SESSION_KEY, t);
            }
            return t;
        }
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest  req  = (HttpServletRequest)  request;
        HttpServletResponse resp = (HttpServletResponse) response;

        if ("POST".equals(req.getMethod())) {
            HttpSession session = req.getSession(false);
            String expected = session != null ? (String) session.getAttribute(SESSION_KEY) : null;
            String sent = req.getHeader(HEADER);
            if (sent == null) sent = req.getParameter(PARAM);

            if (expected == null || sent == null ||
                !MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8), sent.getBytes(StandardCharsets.UTF_8))) {
                resp.setStatus(HttpServletResponse.SC_FORBIDDEN);
                resp.setContentType("application/json;charset=UTF-8");
                resp.getWriter().write("{\"error\":\"Phiên làm việc không hợp lệ (CSRF). Hãy tải lại trang rồi thử lại.\"}");
                return;
            }
        }
        chain.doFilter(request, response);
    }

    @Override public void init(FilterConfig filterConfig) {}
    @Override public void destroy() {}
}
