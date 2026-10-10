package com.uterspace.security;

import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Arrays;

/**
 * DidKey — danh tính số phi tập trung theo phương thức did:key (W3C DID, khóa Ed25519).
 *
 *   did:key:z<base58btc( 0xED 0x01 || khóa công khai Ed25519 32 byte )>
 *
 * DID tự chứa khóa công khai → ai cũng kiểm tra được chữ ký của chủ DID mà KHÔNG cần máy chủ trung tâm hay blockchain
 * (did:key là phương thức "tự xác thực"; có thể chuyển sang did:ion / did:ethr để neo lên blockchain mà không đổi luồng ký).
 * Khóa riêng nằm trong trình duyệt của người dùng; UTErSpace chỉ lưu khóa công khai.
 */
public final class DidKey {

    private static final String ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    private static final byte[] ED25519_MULTICODEC = {(byte) 0xED, 0x01};
    /** Tiền tố ASN.1 của SubjectPublicKeyInfo cho Ed25519 (OID 1.3.101.112) — nối thêm 32 byte khóa thô */
    private static final byte[] ED25519_SPKI_PREFIX = {0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00};

    private DidKey() { }

    /** Khóa công khai Ed25519 thô (32 byte) → did:key */
    public static String fromPublicKey(byte[] raw) {
        byte[] b = new byte[2 + raw.length];
        System.arraycopy(ED25519_MULTICODEC, 0, b, 0, 2);
        System.arraycopy(raw, 0, b, 2, raw.length);
        return "did:key:z" + base58(b);
    }

    /** did:key → khóa công khai Ed25519 thô; null nếu không phải did:key Ed25519 hợp lệ */
    public static byte[] publicKeyOf(String did) {
        if (did == null || !did.startsWith("did:key:z") || did.length() > 120) return null;
        byte[] b = unbase58(did.substring("did:key:z".length()));
        if (b == null || b.length != 34 || b[0] != ED25519_MULTICODEC[0] || b[1] != ED25519_MULTICODEC[1]) return null;
        return Arrays.copyOfRange(b, 2, 34);
    }

    /** Kiểm tra chữ ký Ed25519 (64 byte) của thông điệp UTF-8 bằng khóa công khai của DID */
    public static boolean verify(String did, String message, byte[] signature) {
        byte[] raw = publicKeyOf(did);
        if (raw == null || signature == null || signature.length != 64) return false;
        try {
            byte[] spki = new byte[ED25519_SPKI_PREFIX.length + 32];
            System.arraycopy(ED25519_SPKI_PREFIX, 0, spki, 0, ED25519_SPKI_PREFIX.length);
            System.arraycopy(raw, 0, spki, ED25519_SPKI_PREFIX.length, 32);
            PublicKey key = KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(spki));
            Signature v = Signature.getInstance("Ed25519");
            v.initVerify(key);
            v.update(message.getBytes(StandardCharsets.UTF_8));
            return v.verify(signature);
        } catch (GeneralSecurityException e) {
            return false;
        }
    }

    /** Thông điệp người dùng ký khi đăng nhập / liên kết — gắn tên miền để chữ ký không dùng lại được ở trang khác */
    public static String challengeMessage(String purpose, String host, String nonce) {
        return "UTErSpace DID " + purpose + "\nhost: " + host + "\nnonce: " + nonce;
    }

    // ---------- base58btc ----------

    static String base58(byte[] input) {
        BigInteger n = new BigInteger(1, input);
        StringBuilder sb = new StringBuilder();
        BigInteger base = BigInteger.valueOf(58);
        while (n.signum() > 0) {
            BigInteger[] qr = n.divideAndRemainder(base);
            sb.append(ALPHABET.charAt(qr[1].intValue()));
            n = qr[0];
        }
        for (byte b : input) { if (b == 0) sb.append('1'); else break; }
        return sb.reverse().toString();
    }

    static byte[] unbase58(String s) {
        BigInteger n = BigInteger.ZERO;
        BigInteger base = BigInteger.valueOf(58);
        for (char c : s.toCharArray()) {
            int d = ALPHABET.indexOf(c);
            if (d < 0) return null;
            n = n.multiply(base).add(BigInteger.valueOf(d));
        }
        byte[] bytes = n.toByteArray();
        if (bytes.length > 1 && bytes[0] == 0) bytes = Arrays.copyOfRange(bytes, 1, bytes.length);   // bỏ byte dấu
        int zeros = 0;
        while (zeros < s.length() && s.charAt(zeros) == '1') zeros++;
        byte[] out = new byte[zeros + bytes.length];
        System.arraycopy(bytes, 0, out, zeros, bytes.length);
        return out;
    }
}
