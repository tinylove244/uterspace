package com.uterspace.controller;

import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.model.User;
import com.uterspace.realtime.RealtimeHub;
import com.uterspace.service.NotificationService;
import com.uterspace.util.MailUtil;
import com.uterspace.util.PasswordUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * ForgotPasswordController — Quên mật khẩu, xác thực bằng mã OTP gửi qua email (3 bước).
 *
 *   GET  /forgot-password                 hiện bước hiện tại theo trạng thái lưu trong session
 *   POST /forgot-password  action=sendOtp       (email)            → bước 2
 *                          action=resend                           gửi lại mã (cách nhau ≥ 60 giây)
 *                          action=verifyOtp     (otp)              → bước 3
 *                          action=resetPassword (password, confirmPassword) → /login
 *                          action=restart                          làm lại từ đầu (đổi email)
 * Mọi POST đều redirect về GET (PRG) — tải lại trang không gửi lại form / không gửi thêm email.
 *
 * Bảo mật:
 *  - Mã 6 số sinh bằng SecureRandom, chỉ lưu bản băm SHA-256 trong session, hiệu lực 5 phút, dùng một lần.
 *  - Sai quá 5 lần → mã bị hủy, phải xin mã mới (chặn dò mã).
 *  - Email chưa đăng ký → báo rõ ngay ở bước 1 (theo plan của nhóm); số lần thử bị giới hạn theo IP để hạn chế dò tài khoản.
 *  - Giới hạn gửi: 60 giây / lần, tối đa 5 mã / email / giờ và 10 mã / IP / giờ (chống spam hộp thư).
 *  - Sau khi xác thực OTP có 10 phút để đặt mật khẩu mới; mật khẩu mới theo luật chung và phải khác mật khẩu cũ.
 *  - Đổi xong: mọi phiên đăng nhập cũ của tài khoản bị đăng xuất (AuthFilter so password hash), đóng WebSocket,
 *    gửi thông báo bảo mật vào tài khoản.
 */
@WebServlet("/forgot-password")
public class ForgotPasswordController extends HttpServlet {

    static final int OTP_MINUTES = 5;
    private static final long OTP_TTL = OTP_MINUTES * 60_000L;
    private static final long VERIFIED_TTL = 10 * 60_000L;
    private static final long RESEND_COOLDOWN = 60_000L;
    private static final int MAX_ATTEMPTS = 5;
    private static final int MAX_PER_EMAIL_HOUR = 5;
    private static final int MAX_PER_IP_HOUR = 10;
    private static final String SESSION_KEY = "passwordReset";
    private static final String VIEW = "/WEB-INF/views/auth/forgot-password.jsp";

    private static final SecureRandom RANDOM = new SecureRandom();
    /** Mốc thời gian các lần gửi gần đây theo email / IP (bộ nhớ trong — đủ cho một máy chủ) */
    private static final Map<String, Deque<Long>> SENT_BY_EMAIL = new ConcurrentHashMap<>();
    private static final Map<String, Deque<Long>> SENT_BY_IP = new ConcurrentHashMap<>();

    private final UserDAO userDAO = new UserDAOImpl();

    /** Trạng thái một lượt đặt lại mật khẩu, lưu trong session của trình duyệt đang thao tác */
    static class ResetState implements Serializable {
        private static final long serialVersionUID = 1L;
        String email;
        Integer userId;
        String otpHash;         // null = mã đã bị hủy (sai quá số lần / đã dùng)
        long expiresAt;
        long lastSentAt;
        int attempts;
        boolean verified;
        long verifiedAt;
    }

    // ============================================================
    //  GET
    // ============================================================
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        HttpSession s = req.getSession(false);
        if (s != null && s.getAttribute("currentUser") != null) {   // đã đăng nhập → đổi mật khẩu trong Cài đặt
            resp.sendRedirect(req.getContextPath() + "/settings?tab=account");
            return;
        }
        // Thông báo một lần (flash) từ bước POST trước
        if (s != null) {
            for (String k : new String[]{"fpError", "fpInfo", "fpOk", "fpDev", "fpEmail"}) {
                Object v = s.getAttribute(k);
                if (v != null) { req.setAttribute(k, v); s.removeAttribute(k); }
            }
        }
        ResetState st = s == null ? null : (ResetState) s.getAttribute(SESSION_KEY);
        long now = System.currentTimeMillis();
        String step = "email";
        if (st != null) {
            if (st.verified && now - st.verifiedAt <= VERIFIED_TTL) step = "reset";
            else if (st.verified) { s.removeAttribute(SESSION_KEY); req.setAttribute("fpError", "Phiên đặt lại mật khẩu đã hết hạn. Vui lòng làm lại."); st = null; }
            else step = "otp";
        }
        req.setAttribute("step", step);
        if (st != null) {
            req.setAttribute("maskedEmail", mask(st.email));
            req.setAttribute("otpSecondsLeft", st.otpHash == null ? 0 : Math.max(0, (st.expiresAt - now) / 1000));
            req.setAttribute("resendSecondsLeft", Math.max(0, (st.lastSentAt + RESEND_COOLDOWN - now + 999) / 1000));
            req.setAttribute("attemptsLeft", MAX_ATTEMPTS - st.attempts);
            if ("reset".equals(step)) req.setAttribute("resetEmail", st.email);   // cho trình quản lý mật khẩu lưu đúng tài khoản
        }
        req.setAttribute("pageTitle", "reset".equals(step) ? "Đặt mật khẩu mới" : "otp".equals(step) ? "Nhập mã xác nhận" : "Quên mật khẩu");
        req.setAttribute("passwordPolicy", PasswordUtil.POLICY_TEXT);
        req.getRequestDispatcher(VIEW).forward(req, resp);
    }

    // ============================================================
    //  POST
    // ============================================================
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        req.setCharacterEncoding("UTF-8");
        HttpSession s = req.getSession(true);
        String action = req.getParameter("action");
        ResetState st = (ResetState) s.getAttribute(SESSION_KEY);

        if ("sendOtp".equals(action)) {
            String email = req.getParameter("email") == null ? "" : req.getParameter("email").trim().toLowerCase();
            if (email.length() <= 100) s.setAttribute("fpEmail", email);   // giữ lại trong ô nếu phải nhập lại
            if (!email.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$") || email.length() > 100) {
                flash(s, "fpError", "Vui lòng nhập một địa chỉ email hợp lệ.");
            } else {
                ResetState fresh = new ResetState();
                fresh.email = email;
                if (send(req, s, fresh)) { s.setAttribute(SESSION_KEY, fresh); s.removeAttribute("fpEmail"); }
            }
        } else if ("resend".equals(action) && st != null && !st.verified) {
            long wait = st.lastSentAt + RESEND_COOLDOWN - System.currentTimeMillis();
            if (wait > 0) flash(s, "fpError", "Vui lòng đợi " + ((wait + 999) / 1000) + " giây nữa rồi mới gửi lại mã.");
            else send(req, s, st);
        } else if ("verifyOtp".equals(action) && st != null && !st.verified) {
            verify(s, st, req.getParameter("otp"));
        } else if ("resetPassword".equals(action) && st != null && st.verified) {
            if (reset(req, s, st)) {
                resp.sendRedirect(req.getContextPath() + "/login");
                return;
            }
        } else if ("restart".equals(action)) {
            s.removeAttribute(SESSION_KEY);
        }
        resp.sendRedirect(req.getContextPath() + "/forgot-password");
    }

    /** Sinh mã mới + gửi mail (theo giới hạn gửi). true = đã chuyển sang bước nhập mã */
    private boolean send(HttpServletRequest req, HttpSession s, ResetState st) {
        String ip = req.getRemoteAddr();
        // 60 giây giữa hai lần gửi cho CÙNG một email — kể cả khi gửi lại từ bước 1 hay từ trình duyệt khác
        long wait = lastSent(SENT_BY_EMAIL, st.email) + RESEND_COOLDOWN - System.currentTimeMillis();
        if (wait > 0) {
            flash(s, "fpError", "Vui lòng đợi " + ((wait + 999) / 1000) + " giây nữa rồi mới gửi lại mã.");
            return false;
        }
        if (!allow(SENT_BY_EMAIL, st.email, MAX_PER_EMAIL_HOUR) || !allow(SENT_BY_IP, ip, MAX_PER_IP_HOUR)) {
            flash(s, "fpError", "Bạn đã yêu cầu quá nhiều mã trong một giờ. Vui lòng thử lại sau.");
            return false;
        }
        User u = userDAO.findByEmail(st.email);
        long now = System.currentTimeMillis();
        record(SENT_BY_IP, ip, now);   // tính cả lần nhập email chưa đăng ký → hạn chế dò tài khoản hàng loạt
        if (u == null) {
            // Theo plan của nhóm: báo rõ email chưa đăng ký (đổi lại: người khác có thể dò email nào đã có tài khoản,
            // nhưng bị giới hạn 10 lần / IP / giờ ở trên)
            flash(s, "fpError", "Email " + st.email + " chưa được đăng ký tài khoản UTErSpace. Hãy kiểm tra lại email.");
            return false;
        }
        String otp = String.format("%06d", RANDOM.nextInt(1_000_000));
        st.userId = u.getUserId();
        st.otpHash = hash(otp);
        st.expiresAt = now + OTP_TTL;
        st.lastSentAt = now;
        st.attempts = 0;
        record(SENT_BY_EMAIL, st.email, now);

        MailUtil.Result r = MailUtil.sendResetOtp(u.getEmail(), u.getFullName(), otp, OTP_MINUTES);
        if (r == MailUtil.Result.FAILED) {
            st.otpHash = null;
            unrecord(SENT_BY_EMAIL, st.email);   // gửi hỏng không tính vào thời gian chờ → thử lại được ngay
            flash(s, "fpError", "Không gửi được email lúc này. Vui lòng thử lại sau ít phút.");
            return false;
        }
        if (r == MailUtil.Result.DEV_LOGGED) {
            flash(s, "fpDev", "Máy chủ chưa cấu hình email (chế độ phát triển): mã OTP được in ra log của Tomcat.");
        }
        flash(s, "fpInfo", "Mã xác nhận gồm 6 chữ số đã được gửi tới " + mask(st.email) +
                           ". Hãy kiểm tra hộp thư, kể cả thư mục Spam / Quảng cáo.");
        return true;
    }

    private void verify(HttpSession s, ResetState st, String otp) {
        otp = otp == null ? "" : otp.replaceAll("\\s", "");
        if (st.otpHash == null) {
            flash(s, "fpError", "Mã đã bị hủy do nhập sai quá nhiều lần. Vui lòng bấm \"Gửi lại mã\".");
            return;
        }
        if (System.currentTimeMillis() > st.expiresAt) {
            st.otpHash = null;
            flash(s, "fpError", "Mã đã hết hạn (quá " + OTP_MINUTES + " phút). Vui lòng bấm \"Gửi lại mã\".");
            return;
        }
        if (!otp.matches("\\d{6}")) {
            flash(s, "fpError", "Mã xác nhận gồm đúng 6 chữ số.");
            return;
        }
        boolean ok = st.userId != null && MessageDigest.isEqual(
                hash(otp).getBytes(StandardCharsets.US_ASCII), st.otpHash.getBytes(StandardCharsets.US_ASCII));
        if (!ok) {
            st.attempts++;
            int left = MAX_ATTEMPTS - st.attempts;
            if (left <= 0) {
                st.otpHash = null;
                flash(s, "fpError", "Bạn đã nhập sai " + MAX_ATTEMPTS + " lần, mã này đã bị hủy. Vui lòng bấm \"Gửi lại mã\".");
            } else {
                flash(s, "fpError", "Mã xác nhận không đúng. Bạn còn " + left + " lần thử.");
            }
            s.setAttribute(SESSION_KEY, st);   // ghi lại để session (nếu được lưu) nhận số lần thử mới
            return;
        }
        st.otpHash = null;   // dùng một lần
        st.verified = true;
        st.verifiedAt = System.currentTimeMillis();
        s.setAttribute(SESSION_KEY, st);
        flash(s, "fpOk", "Xác thực thành công. Hãy đặt mật khẩu mới cho tài khoản " + mask(st.email) + ".");
    }

    /** true = đã đổi xong (đã đặt thông báo cho trang đăng nhập) */
    private boolean reset(HttpServletRequest req, HttpSession s, ResetState st) {
        if (System.currentTimeMillis() - st.verifiedAt > VERIFIED_TTL) {
            s.removeAttribute(SESSION_KEY);
            flash(s, "fpError", "Phiên đặt lại mật khẩu đã hết hạn. Vui lòng làm lại.");
            return false;
        }
        String pw = req.getParameter("password"), confirm = req.getParameter("confirmPassword");
        String err = PasswordUtil.policyError(pw);
        if (err != null) { flash(s, "fpError", err); return false; }
        if (!pw.equals(confirm)) { flash(s, "fpError", "Mật khẩu xác nhận không khớp."); return false; }
        User u = userDAO.getUserById(st.userId);
        if (u == null) { s.removeAttribute(SESSION_KEY); flash(s, "fpError", "Tài khoản không còn tồn tại."); return false; }
        if (PasswordUtil.verifyPassword(pw, u.getPasswordHash())) {
            flash(s, "fpError", "Mật khẩu mới không được trùng với mật khẩu cũ.");
            return false;
        }
        userDAO.updatePasswordHash(u.getUserId(), PasswordUtil.hashPassword(pw));
        RealtimeHub.closeUser(u.getUserId());   // các tab đang mở ở nơi khác mất kết nối realtime ngay
        try {
            NotificationService.account(u.getUserId(),
                    "Mật khẩu của bạn vừa được đặt lại bằng mã xác nhận gửi qua email (" +
                    AuthController.describeDevice(req.getHeader("User-Agent")) + "). Nếu không phải bạn, hãy liên hệ quản trị viên ngay.",
                    "/settings?tab=account");
        } catch (RuntimeException ignored) { }
        SENT_BY_EMAIL.remove(st.email);
        s.removeAttribute(SESSION_KEY);
        s.setAttribute("loginSuccess", "Đặt lại mật khẩu thành công. Hãy đăng nhập bằng mật khẩu mới.");
        s.setAttribute("loginEmail", u.getEmail());
        return true;
    }

    // ============================================================
    //  Helpers
    // ============================================================

    private static void flash(HttpSession s, String key, String msg) { s.setAttribute(key, msg); }

    private static String hash(String otp) {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(otp.getBytes(StandardCharsets.US_ASCII));
            StringBuilder sb = new StringBuilder();
            for (byte b : d) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    /** Còn được gửi không: số lần trong 1 giờ qua < max */
    private static boolean allow(Map<String, Deque<Long>> map, String key, int max) {
        Deque<Long> q = map.get(key);
        if (q == null) return true;
        synchronized (q) {
            long cutoff = System.currentTimeMillis() - 3_600_000L;
            while (!q.isEmpty() && q.peekFirst() < cutoff) q.pollFirst();
            return q.size() < max;
        }
    }

    private static long lastSent(Map<String, Deque<Long>> map, String key) {
        Deque<Long> q = map.get(key);
        if (q == null) return 0;
        synchronized (q) { return q.isEmpty() ? 0 : q.peekLast(); }
    }

    private static void unrecord(Map<String, Deque<Long>> map, String key) {
        Deque<Long> q = map.get(key);
        if (q != null) synchronized (q) { q.pollLast(); }
    }

    private static void record(Map<String, Deque<Long>> map, String key, long t) {
        Deque<Long> q = map.computeIfAbsent(key, k -> new ArrayDeque<>());
        synchronized (q) { q.addLast(t); }
        if (map.size() > 10_000) map.clear();   // phòng tràn bộ nhớ khi bị dò hàng loạt
    }

    /** "ng*****@gmail.com" — hiện email đã che bớt */
    static String mask(String email) {
        if (email == null) return "";
        int at = email.indexOf('@');
        if (at <= 0) return email;
        String name = email.substring(0, at);
        String shown = name.length() <= 2 ? name.substring(0, 1) : name.substring(0, 2);
        return shown + "*****" + email.substring(at);
    }
}
