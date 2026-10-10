package com.uterspace.util;

import at.favre.lib.crypto.bcrypt.BCrypt;

/**
 * PasswordUtil — Tiện ích mã hóa mật khẩu dùng BCrypt.
 *
 * Dùng thư viện at.favre.lib:bcrypt (thêm vào pom.xml).
 * BCrypt tự sinh salt ngẫu nhiên mỗi lần hash → hash của cùng 1 password
 * sẽ khác nhau mỗi lần gọi — đây là hành vi bình thường và đúng.
 */
public class PasswordUtil {

    // Cost factor: 12 là mức khuyến nghị — đủ chậm để brute-force khó, đủ nhanh để UX tốt
    private static final int BCRYPT_COST = 12;

    /**
     * Băm mật khẩu văn bản thuần thành chuỗi BCrypt để lưu DB.
     *
     * @param plainPassword Mật khẩu người dùng nhập vào
     * @return Chuỗi hash BCrypt (60 ký tự) để lưu vào cột password_hash
     */
    public static String hashPassword(String plainPassword) {
        return BCrypt.withDefaults().hashToString(BCRYPT_COST, plainPassword.toCharArray());
    }

    /**
     * So khớp mật khẩu nhập vào với hash đã lưu trong DB.
     *
     * @param plainPassword Mật khẩu người dùng vừa nhập
     * @param hashedPassword Chuỗi hash BCrypt lấy từ DB
     * @return true nếu khớp, false nếu sai
     */
    public static boolean verifyPassword(String plainPassword, String hashedPassword) {
        if (plainPassword == null || hashedPassword == null) return false;
        BCrypt.Result result = BCrypt.verifyer().verify(plainPassword.toCharArray(), hashedPassword);
        return result.verified;
    }

    /** Câu mô tả luật mật khẩu — dùng chung cho thông báo lỗi và gợi ý trên form */
    public static final String POLICY_TEXT = "Mật khẩu phải có ít nhất 8 ký tự, 1 chữ hoa và 1 ký tự đặc biệt.";

    /**
     * Luật mật khẩu chung cho Đăng ký, Đổi mật khẩu (Cài đặt) và Quên mật khẩu:
     * 8–64 ký tự, ít nhất 1 chữ hoa và 1 ký tự đặc biệt (không phải chữ / số).
     * Giới hạn 64 vì BCrypt chỉ dùng 72 byte đầu (chữ tiếng Việt có dấu chiếm 2–3 byte).
     *
     * @return null nếu hợp lệ, ngược lại là câu báo lỗi tiếng Việt
     */
    public static String policyError(String pw) {
        if (pw == null || pw.length() < 8 || !pw.matches(".*\\p{Lu}.*") || !pw.matches("(?s).*[^\\p{L}\\p{N}].*")) {
            return POLICY_TEXT;
        }
        if (pw.length() > 64) return "Mật khẩu tối đa 64 ký tự.";
        return null;
    }
}
