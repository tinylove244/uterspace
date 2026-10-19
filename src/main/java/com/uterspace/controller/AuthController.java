package com.uterspace.controller;

import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.model.User;
import com.uterspace.util.PasswordUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;

/**
 * AuthController — Xử lý đăng nhập, đăng ký, đăng xuất.
 *
 * Giai đoạn DB thật:
 *  - Login: tìm user theo email qua UserDAO, verify password bằng BCrypt.
 *  - Register: lưu user thật vào DB qua UserDAO.createUser(), hash password.
 *  - Redirect sau login: đọc lại redirectAfterLogin từ session nếu có.
 */
@WebServlet(urlPatterns = {"/login", "/logout", "/register"})
public class AuthController extends HttpServlet {

    private final UserDAO userDAO = new UserDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        String path = req.getServletPath();
        String ctx = req.getContextPath();

        // Nếu đã login mà vào trang đăng nhập/đăng ký → redirect vào feed (admin → trang quản trị)
        if (req.getSession(false) != null &&
                req.getSession(false).getAttribute("currentUser") != null &&
                !path.equals("/logout")) {
            User current = (User) req.getSession(false).getAttribute("currentUser");
            resp.sendRedirect(ctx + (current.isAdmin() ? "/admin" : "/feed"));
            return;
        }

        if ("/login".equals(path)) {
            // Thông báo một lần do AuthFilter để lại (vd: tài khoản vừa bị khóa)
            HttpSession s = req.getSession(false);
            if (s != null && s.getAttribute("loginNotice") != null) {
                req.setAttribute("errorMessage", s.getAttribute("loginNotice"));
                s.removeAttribute("loginNotice");
            }
            // Thông báo thành công (vd: vừa đặt lại mật khẩu) + điền sẵn email
            if (s != null && s.getAttribute("loginSuccess") != null) {
                req.setAttribute("successMessage", s.getAttribute("loginSuccess"));
                req.setAttribute("prefillEmail", s.getAttribute("loginEmail"));
                s.removeAttribute("loginSuccess");
                s.removeAttribute("loginEmail");
            }
            req.setAttribute("pageTitle", "Đăng nhập");
            req.getRequestDispatcher("/WEB-INF/views/auth/login.jsp").forward(req, resp);
        } else if ("/register".equals(path)) {
            req.setAttribute("pageTitle", "Đăng ký");
            req.getRequestDispatcher("/WEB-INF/views/auth/register.jsp").forward(req, resp);
        } else if ("/logout".equals(path)) {
            doLogout(req, resp);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        req.setCharacterEncoding("UTF-8");
        String path = req.getServletPath();
        String ctx = req.getContextPath();

        if ("/login".equals(path)) {
            handleLogin(req, resp);
        } else if ("/register".equals(path)) {
            handleRegister(req, resp);
        } else {
            resp.sendRedirect(ctx + "/login");
        }
    }

    // ============================================================
    //  LOGIN
    // ============================================================
    private void handleLogin(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        String email    = req.getParameter("email")    != null ? req.getParameter("email").trim()    : "";
        String password = req.getParameter("password") != null ? req.getParameter("password")         : "";
        String ctx      = req.getContextPath();

        if (email.isEmpty() || password.isEmpty()) {
            req.setAttribute("errorMessage", "Vui lòng điền đầy đủ email và mật khẩu.");
            req.setAttribute("pageTitle", "Đăng nhập");
            req.getRequestDispatcher("/WEB-INF/views/auth/login.jsp").forward(req, resp);
            return;
        }

        User found = userDAO.findByEmail(email);

        if (found == null) {
            req.setAttribute("errorMessage", "Email này không tồn tại trong hệ thống.");
            req.setAttribute("pageTitle", "Đăng nhập");
            req.getRequestDispatcher("/WEB-INF/views/auth/login.jsp").forward(req, resp);
            return;
        }

        // Verify password bằng BCrypt
        if (!PasswordUtil.verifyPassword(password, found.getPasswordHash())) {
            req.setAttribute("errorMessage", "Mật khẩu không đúng. Vui lòng thử lại.");
            req.setAttribute("pageTitle", "Đăng nhập");
            req.getRequestDispatcher("/WEB-INF/views/auth/login.jsp").forward(req, resp);
            return;
        }

        // Tài khoản bị admin khóa → không cho đăng nhập (plan 6.4)
        if (found.isLocked()) {
            req.setAttribute("errorMessage", lockedMessage(found));
            req.setAttribute("pageTitle", "Đăng nhập");
            req.getRequestDispatcher("/WEB-INF/views/auth/login.jsp").forward(req, resp);
            return;
        }

        resp.sendRedirect(ctx + startSession(req, found, ""));
    }

    /**
     * Đăng nhập thành công (mật khẩu, hoặc chữ ký DID ở DidLoginController): tạo session MỚI (chống session fixation),
     * gửi thông báo khi đăng nhập từ thiết bị mới, trả về đường dẫn đích (tương đối với context path).
     * @param via mô tả cách đăng nhập cho thông báo bảo mật, vd " bằng danh tính số (DID)"; "" = mật khẩu
     */
    static String startSession(HttpServletRequest req, User found, String via) {
        String ctx = req.getContextPath();
        HttpSession old = req.getSession(false);
        Object savedTarget = old != null ? old.getAttribute("redirectAfterLogin") : null;
        if (old != null) old.invalidate();
        HttpSession session = req.getSession(true);
        session.setAttribute("currentUser", found);
        session.setMaxInactiveInterval(60 * 60 * 24); // 24h

        // Thông báo bảo mật khi đăng nhập từ trình duyệt / thiết bị chưa dùng trong 30 ngày (phát hiện đăng nhập lạ)
        try {
            String device = describeDevice(req.getHeader("User-Agent"));
            com.uterspace.service.NotificationService.loginFromDevice(found.getUserId(), device,
                    "Đăng nhập" + via + " từ thiết bị mới: " + device +
                    " lúc " + java.time.LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy")) +
                    ". Nếu không phải bạn, hãy đổi mật khẩu ngay.");
        } catch (RuntimeException ignored) { }

        // Trang đích nếu đã lưu, hoặc /feed. redirectAfterLogin là đường dẫn tương đối với context path; chốt chặn
        // dưới đây phòng session cũ còn lưu URI tuyệt đối (đã kèm context path).
        String redirectTarget = savedTarget instanceof String ? (String) savedTarget : null;
        if (redirectTarget == null || !redirectTarget.startsWith("/")) {
            redirectTarget = "/feed";
        } else if (!ctx.isEmpty() && redirectTarget.startsWith(ctx + "/")) {
            redirectTarget = redirectTarget.substring(ctx.length());
        }
        // Tài khoản quản trị chỉ dùng trang quản trị (AuthFilter cũng chặn mọi trang khác)
        if (found.isAdmin()) {
            String p = redirectTarget.split("[?#]", 2)[0];
            if (!com.uterspace.filter.AuthFilter.isAdminArea(p)) redirectTarget = "/admin";
        }
        return redirectTarget;
    }

    // ============================================================
    //  REGISTER
    // ============================================================
    private void handleRegister(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        req.setCharacterEncoding("UTF-8");
        String ctx       = req.getContextPath();
        String firstName = req.getParameter("firstName") != null ? req.getParameter("firstName").trim() : "";
        String lastName  = req.getParameter("lastName")  != null ? req.getParameter("lastName").trim()  : "";
        String email     = req.getParameter("email")     != null ? req.getParameter("email").trim()     : "";
        String password  = req.getParameter("password")  != null ? req.getParameter("password")          : "";

        // Validation cơ bản
        if (firstName.isEmpty() || lastName.isEmpty() || email.isEmpty()) {
            req.setAttribute("errorMessage", "Vui lòng điền đầy đủ các trường bắt buộc.");
            req.setAttribute("pageTitle", "Đăng ký");
            req.getRequestDispatcher("/WEB-INF/views/auth/register.jsp").forward(req, resp);
            return;
        }

        // Bắt buộc đồng ý Điều khoản sử dụng (/terms) — kiểm lại ở server, không chỉ dựa vào checkbox của trình duyệt
        if (req.getParameter("agreeTerms") == null) {
            req.setAttribute("errorMessage", "Bạn cần đồng ý với Điều khoản sử dụng và Chính sách bảo mật để tạo tài khoản.");
            req.setAttribute("pageTitle", "Đăng ký");
            req.getRequestDispatcher("/WEB-INF/views/auth/register.jsp").forward(req, resp);
            return;
        }

        // Luật mật khẩu chung (8+ ký tự, 1 chữ hoa, 1 ký tự đặc biệt) — giống Cài đặt và Quên mật khẩu
        String pwError = PasswordUtil.policyError(password);
        if (pwError != null) {
            req.setAttribute("errorMessage", pwError);
            req.setAttribute("pageTitle", "Đăng ký");
            req.getRequestDispatcher("/WEB-INF/views/auth/register.jsp").forward(req, resp);
            return;
        }

        // Tên được in ở rất nhiều nơi (JSP, JSON, thông báo) → chặn ký tự HTML ngay từ đầu (lớp bảo vệ thứ hai bên cạnh escape)
        if (!isSafeName(firstName) || !isSafeName(lastName)) {
            req.setAttribute("errorMessage", "Họ tên không được chứa các ký tự < > \" & và tối đa 50 ký tự.");
            req.setAttribute("pageTitle", "Đăng ký");
            req.getRequestDispatcher("/WEB-INF/views/auth/register.jsp").forward(req, resp);
            return;
        }

        // Kiểm tra email đã tồn tại chưa
        if (userDAO.findByEmail(email) != null) {
            req.setAttribute("errorMessage", "Email này đã được sử dụng. Vui lòng dùng email khác.");
            req.setAttribute("pageTitle", "Đăng ký");
            req.getRequestDispatcher("/WEB-INF/views/auth/register.jsp").forward(req, resp);
            return;
        }

        // Tạo user mới, hash password trước khi lưu DB
        User newUser = new User();
        newUser.setFirstName(firstName);
        newUser.setLastName(lastName);
        newUser.setEmail(email);
        newUser.setRole("USER");
        newUser.setPasswordHash(PasswordUtil.hashPassword(password));

        // Lưu vào DB, lấy userId thật từ IDENTITY(1,1)
        try {
            newUser = userDAO.createUser(newUser);
        } catch (RuntimeException e) {
            // Vd: hai người đăng ký cùng email cùng lúc, hoặc DB cũ còn ràng buộc lạ (xem db/080_fix_student_id_unique.sql)
            log("Đăng ký thất bại cho " + email, e);
            req.setAttribute("errorMessage", userDAO.findByEmail(email) != null
                    ? "Email này đã được sử dụng. Vui lòng dùng email khác."
                    : "Không tạo được tài khoản lúc này. Vui lòng thử lại sau hoặc báo quản trị viên.");
            req.setAttribute("pageTitle", "Đăng ký");
            req.getRequestDispatcher("/WEB-INF/views/auth/register.jsp").forward(req, resp);
            return;
        }

        // Set session
        HttpSession session = req.getSession(true);
        session.setAttribute("currentUser", newUser);
        session.setMaxInactiveInterval(60 * 60 * 24);

        resp.sendRedirect(ctx + "/feed");
    }

    /** "Chrome trên Windows" — mô tả gọn thiết bị từ User-Agent cho thông báo đăng nhập */
    public static String describeDevice(String ua) {
        if (ua == null) return "thiết bị không xác định";
        String browser = ua.contains("Edg/") ? "Edge" : ua.contains("OPR/") ? "Opera" : ua.contains("Firefox/") ? "Firefox"
                       : ua.contains("Chrome/") ? "Chrome" : ua.contains("Safari/") ? "Safari" : ua.contains("curl/") ? "curl" : "trình duyệt khác";
        String os = ua.contains("Windows") ? "Windows" : ua.contains("Android") ? "Android"
                  : (ua.contains("iPhone") || ua.contains("iPad")) ? "iOS" : ua.contains("Mac OS") ? "macOS"
                  : ua.contains("Linux") ? "Linux" : "hệ điều hành khác";
        return browser + " trên " + os;
    }

    private static boolean isSafeName(String name) {
        return name.length() <= 50 && !name.matches(".*[<>\"&].*");
    }

    /** Câu báo "tài khoản bị khóa" kèm lý do — dùng chung với AuthFilter */
    public static String lockedMessage(User u) {
        String reason = u.getLockedReason();
        return "Tài khoản của bạn đã bị khóa bởi quản trị viên" +
               (reason != null && !reason.trim().isEmpty() ? ". Lý do: " + reason.trim() : ".");
    }

    // ============================================================
    //  LOGOUT
    // ============================================================
    private void doLogout(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {
        HttpSession session = req.getSession(false);
        if (session != null) session.invalidate();
        resp.sendRedirect(req.getContextPath() + "/login");
    }
}
