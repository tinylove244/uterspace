package com.uterspace.security;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.spec.X509EncodedKeySpec;
import java.util.Arrays;
import java.util.Base64;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * WebAuthnService — xác thực sinh trắc học bằng chuẩn W3C WebAuthn (passkey), KHÔNG cần thư viện ngoài.
 *
 * Đăng ký: trình duyệt gọi navigator.credentials.create() → thiết bị kiểm tra vân tay / khuôn mặt / PIN →
 *          gửi về khóa công khai (response.getPublicKey(), dạng SPKI DER) + clientDataJSON.
 *          Máy chủ kiểm tra type = "webauthn.create", challenge khớp phiên, origin cùng máy chủ rồi lưu khóa công khai.
 * Xác thực: navigator.credentials.get() → thiết bị ký (authenticatorData || SHA-256(clientDataJSON)) bằng khóa riêng
 *          nằm trong chip bảo mật. Máy chủ kiểm tra: challenge, origin, rpIdHash = SHA-256(tên miền),
 *          cờ UP (có người chạm) + UV (đã xác minh sinh trắc học / PIN), bộ đếm chữ ký, rồi verify chữ ký.
 * Dữ liệu sinh trắc học không bao giờ rời khỏi thiết bị.
 */
public final class WebAuthnService {

    public static final int ALG_ES256 = -7;
    public static final int ALG_RS256 = -257;

    private static final String SESSION_CHALLENGE = "webauthn.challenge";
    private static final long CHALLENGE_TTL_MS = 5 * 60 * 1000L;
    private static final SecureRandom RANDOM = new SecureRandom();

    /** Lỗi xác thực — message hiển thị được cho người dùng */
    public static final class WebAuthnException extends Exception {
        public WebAuthnException(String message) { super(message); }
    }

    private WebAuthnService() { }

    // ============================================================ Challenge

    /** Tạo challenge ngẫu nhiên 32 byte, lưu vào phiên (dùng một lần, hết hạn sau 5 phút) */
    public static String newChallenge(HttpSession session, String purpose) {
        byte[] b = new byte[32];
        RANDOM.nextBytes(b);
        String c = b64(b);
        session.setAttribute(SESSION_CHALLENGE, new String[]{ c, purpose, String.valueOf(System.currentTimeMillis()) });
        return c;
    }

    private static void consumeChallenge(HttpSession session, String received, String purpose) throws WebAuthnException {
        String[] saved = (String[]) session.getAttribute(SESSION_CHALLENGE);
        session.removeAttribute(SESSION_CHALLENGE);
        if (saved == null || !saved[1].equals(purpose)
                || System.currentTimeMillis() - Long.parseLong(saved[2]) > CHALLENGE_TTL_MS
                || !MessageDigest.isEqual(saved[0].getBytes(StandardCharsets.US_ASCII), received.getBytes(StandardCharsets.US_ASCII))) {
            throw new WebAuthnException("Phiên xác thực đã hết hạn hoặc không hợp lệ — vui lòng thử lại.");
        }
    }

    /** rpId = tên miền đang truy cập (localhost, tên máy Tailscale…) */
    public static String rpId(HttpServletRequest req) { return req.getServerName(); }

    // ============================================================ Đăng ký

    /**
     * Kiểm tra dữ liệu đăng ký passkey. Trả về khóa công khai (SPKI) đã kiểm tra dùng được.
     * @param clientDataB64 clientDataJSON (base64url)
     * @param publicKeyB64  response.getPublicKey() (base64url, SPKI DER)
     */
    public static byte[] verifyRegistration(HttpServletRequest req, String clientDataB64, String publicKeyB64, int alg)
            throws WebAuthnException {
        byte[] clientData = unb64(clientDataB64, "clientDataJSON");
        checkClientData(req, clientData, "webauthn.create", "register");
        if (alg != ALG_ES256 && alg != ALG_RS256) throw new WebAuthnException("Thiết bị dùng thuật toán khóa chưa được hỗ trợ.");
        byte[] spki = unb64(publicKeyB64, "publicKey");
        loadKey(spki, alg);   // ném lỗi nếu khóa hỏng
        return spki;
    }

    // ============================================================ Xác thực

    /** Kiểm tra một lần xác thực sinh trắc học; trả về bộ đếm chữ ký mới để lưu */
    public static long verifyAssertion(HttpServletRequest req, Passkey key, String clientDataB64, String authDataB64, String signatureB64)
            throws WebAuthnException {
        byte[] clientData = unb64(clientDataB64, "clientDataJSON");
        byte[] authData   = unb64(authDataB64, "authenticatorData");
        byte[] signature  = unb64(signatureB64, "signature");
        checkClientData(req, clientData, "webauthn.get", "authenticate");

        if (authData.length < 37) throw new WebAuthnException("Dữ liệu xác thực không hợp lệ.");
        byte[] rpHash = sha256(rpId(req).getBytes(StandardCharsets.UTF_8));
        if (!MessageDigest.isEqual(rpHash, Arrays.copyOfRange(authData, 0, 32))) {
            throw new WebAuthnException("Passkey này không thuộc về trang web hiện tại.");
        }
        int flags = authData[32] & 0xFF;
        if ((flags & 0x01) == 0) throw new WebAuthnException("Thiết bị chưa xác nhận có người dùng.");
        if ((flags & 0x04) == 0) throw new WebAuthnException("Thiết bị chưa xác minh vân tay / khuôn mặt / mã PIN.");
        long counter = ((authData[33] & 0xFFL) << 24) | ((authData[34] & 0xFFL) << 16) | ((authData[35] & 0xFFL) << 8) | (authData[36] & 0xFFL);
        // Nhiều passkey đồng bộ (Windows Hello, iCloud…) luôn trả 0; chỉ chặn khi bộ đếm có dùng mà bị lùi (dấu hiệu khóa bị sao chép)
        if (counter != 0 && counter <= key.getSignCount()) throw new WebAuthnException("Bộ đếm chữ ký bất thường — passkey có thể đã bị sao chép.");

        byte[] signed = new byte[authData.length + 32];
        System.arraycopy(authData, 0, signed, 0, authData.length);
        System.arraycopy(sha256(clientData), 0, signed, authData.length, 32);
        try {
            Signature v = Signature.getInstance(key.getAlg() == ALG_RS256 ? "SHA256withRSA" : "SHA256withECDSA");
            v.initVerify(loadKey(key.getPublicKey(), key.getAlg()));
            v.update(signed);
            if (!v.verify(signature)) throw new WebAuthnException("Chữ ký sinh trắc học không hợp lệ.");
        } catch (GeneralSecurityException e) {
            throw new WebAuthnException("Không kiểm tra được chữ ký: " + e.getMessage());
        }
        return counter;
    }

    // ============================================================ Tiện ích

    private static final Pattern P_TYPE      = Pattern.compile("\"type\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern P_CHALLENGE = Pattern.compile("\"challenge\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern P_ORIGIN    = Pattern.compile("\"origin\"\\s*:\\s*\"([^\"]+)\"");

    private static void checkClientData(HttpServletRequest req, byte[] clientData, String type, String purpose) throws WebAuthnException {
        String json = new String(clientData, StandardCharsets.UTF_8);
        if (!type.equals(find(P_TYPE, json))) throw new WebAuthnException("Loại yêu cầu WebAuthn không đúng.");
        consumeChallenge(req.getSession(), find(P_CHALLENGE, json), purpose);
        String origin = find(P_ORIGIN, json);
        String host;
        try { host = new java.net.URI(origin).getHost(); } catch (Exception e) { host = null; }
        if (host == null || !host.equalsIgnoreCase(rpId(req))) throw new WebAuthnException("Nguồn gốc yêu cầu (origin) không khớp trang web.");
    }

    private static String find(Pattern p, String s) throws WebAuthnException {
        Matcher m = p.matcher(s);
        if (!m.find()) throw new WebAuthnException("clientDataJSON thiếu trường bắt buộc.");
        return m.group(1);
    }

    private static PublicKey loadKey(byte[] spki, int alg) throws WebAuthnException {
        try {
            return KeyFactory.getInstance(alg == ALG_RS256 ? "RSA" : "EC").generatePublic(new X509EncodedKeySpec(spki));
        } catch (GeneralSecurityException e) {
            throw new WebAuthnException("Khóa công khai của passkey không hợp lệ.");
        }
    }

    static byte[] sha256(byte[] data) {
        try { return MessageDigest.getInstance("SHA-256").digest(data); }
        catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    public static String b64(byte[] b) { return Base64.getUrlEncoder().withoutPadding().encodeToString(b); }

    static byte[] unb64(String s, String field) throws WebAuthnException {
        if (s == null || s.isEmpty()) throw new WebAuthnException("Thiếu dữ liệu " + field + ".");
        try { return Base64.getUrlDecoder().decode(s.replace('+', '-').replace('/', '_').replace("=", "")); }
        catch (IllegalArgumentException e) { throw new WebAuthnException("Dữ liệu " + field + " không hợp lệ."); }
    }
}
