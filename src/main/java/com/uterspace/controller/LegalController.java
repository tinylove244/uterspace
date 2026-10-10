package com.uterspace.controller;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * LegalController — trang Điều khoản sử dụng và Chính sách bảo mật.
 * Công khai (không nằm trong AuthFilter): người chưa đăng ký cũng phải đọc được trước khi tạo tài khoản.
 *
 * GET /terms    → legal/terms.jsp
 * GET /privacy  → legal/privacy.jsp
 */
@WebServlet(urlPatterns = {"/terms", "/privacy"})
public class LegalController extends HttpServlet {

    /** Ngày cập nhật hiển thị trên cả hai trang — đổi khi sửa nội dung */
    static final String UPDATED_AT = "08/10/2026";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        boolean terms = "/terms".equals(req.getServletPath());
        req.setAttribute("legalPage", terms ? "terms" : "privacy");
        req.setAttribute("legalUpdatedAt", UPDATED_AT);
        req.getRequestDispatcher(terms ? "/WEB-INF/views/legal/terms.jsp" : "/WEB-INF/views/legal/privacy.jsp")
           .forward(req, resp);
    }
}
