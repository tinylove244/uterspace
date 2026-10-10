package com.uterspace.security;

import javax.servlet.http.HttpSession;

/**
 * StepUp — "xác thực lại" trước hành động nhạy cảm (đổi mật khẩu, mở Album ẩn, xóa passkey).
 *
 * Người đã đăng ký passkey: phải quét vân tay / khuôn mặt (WebAuthn) trong 5 phút gần nhất.
 * Người chưa có passkey: hành động nào cần sẽ hỏi lại mật khẩu (SecurityController /security/unlock).
 * Mốc xác thực lưu trong phiên — đăng xuất / đổi phiên là mất.
 */
public final class StepUp {

    public static final long WINDOW_MS = 5 * 60 * 1000L;
    private static final String ATTR = "stepUpAt";
    private static final String ATTR_METHOD = "stepUpMethod";

    private StepUp() { }

    public static void mark(HttpSession session, String method) {
        session.setAttribute(ATTR, System.currentTimeMillis());
        session.setAttribute(ATTR_METHOD, method);
    }

    /** Đã xác thực lại trong 5 phút qua (bằng bất kỳ cách nào) */
    public static boolean recent(HttpSession session) {
        Object at = session.getAttribute(ATTR);
        return at instanceof Long && System.currentTimeMillis() - (Long) at <= WINDOW_MS;
    }

    /** Đã xác thực lại bằng SINH TRẮC HỌC trong 5 phút qua */
    public static boolean recentBiometric(HttpSession session) {
        return recent(session) && "biometric".equals(session.getAttribute(ATTR_METHOD));
    }

    /** Đủ điều kiện cho hành động nhạy cảm: có passkey → cần sinh trắc học; chưa có → cần xác thực lại bất kỳ */
    public static boolean satisfied(HttpSession session, int userId) {
        boolean hasPasskey = new WebAuthnDAO().countFor(userId) > 0;
        return hasPasskey ? recentBiometric(session) : recent(session);
    }
}
