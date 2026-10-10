package com.uterspace.util;

import javax.mail.Message;
import javax.mail.PasswordAuthentication;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * MailUtil — gửi email (mã OTP quên mật khẩu) qua SMTP bằng JavaMail.
 *
 * KHÔNG ghi tài khoản / mật khẩu email vào mã nguồn. Cấu hình đọc theo thứ tự ưu tiên:
 *   1. Biến môi trường  UTERSPACE_MAIL_USERNAME, UTERSPACE_MAIL_PASSWORD (tùy chọn UTERSPACE_MAIL_HOST, _PORT, _FROM_NAME)
 *   2. File ${catalina.base}/conf/uterspace-mail.properties (nằm NGOÀI project, không bị commit):
 *        mail.username=ten@gmail.com
 *        mail.password=<App Password 16 ký tự của Google>
 *        # tùy chọn: mail.host=smtp.gmail.com  mail.port=587  mail.fromName=UTErSpace  mail.starttls=true
 *      Mẫu: db/uterspace-mail.properties.example
 *
 * Chưa cấu hình → CHẾ ĐỘ PHÁT TRIỂN: không gửi mail, in mã OTP ra log của Tomcat để test trên máy cá nhân.
 */
public final class MailUtil {

    private static final Logger LOG = Logger.getLogger(MailUtil.class.getName());

    /** Kết quả gửi: SENT = đã gửi qua SMTP, DEV_LOGGED = chưa cấu hình, mã in ra log, FAILED = lỗi SMTP */
    public enum Result { SENT, DEV_LOGGED, FAILED }

    private static volatile Properties config;

    private MailUtil() { }

    /** Đã cấu hình SMTP chưa (false = chế độ phát triển) */
    public static boolean isConfigured() {
        Properties c = config();
        return !c.getProperty("mail.username", "").isEmpty() && !c.getProperty("mail.password", "").isEmpty();
    }

    private static Properties config() {
        Properties c = config;
        if (c != null) return c;
        c = new Properties();
        String base = System.getProperty("catalina.base");
        if (base != null) {
            File f = new File(base, "conf/uterspace-mail.properties");
            if (f.isFile()) {
                try (InputStream in = new FileInputStream(f)) {
                    c.load(new InputStreamReader(in, StandardCharsets.UTF_8));
                } catch (Exception e) {
                    LOG.log(Level.WARNING, "Không đọc được " + f + ": " + e.getMessage());
                }
            }
        }
        env(c, "mail.username", "UTERSPACE_MAIL_USERNAME");
        env(c, "mail.password", "UTERSPACE_MAIL_PASSWORD");
        env(c, "mail.host", "UTERSPACE_MAIL_HOST");
        env(c, "mail.port", "UTERSPACE_MAIL_PORT");
        env(c, "mail.fromName", "UTERSPACE_MAIL_FROM_NAME");
        env(c, "mail.starttls", "UTERSPACE_MAIL_STARTTLS");
        // App Password Google hiển thị dạng "abcd efgh ijkl mnop" — bỏ khoảng trắng nếu dán nguyên
        c.setProperty("mail.password", c.getProperty("mail.password", "").replace(" ", "").trim());
        c.setProperty("mail.username", c.getProperty("mail.username", "").trim());
        config = c;
        if (c.getProperty("mail.username").isEmpty() || c.getProperty("mail.password").isEmpty()) {
            LOG.warning("[MailUtil] Chưa cấu hình email gửi đi — CHẾ ĐỘ PHÁT TRIỂN: mã OTP sẽ in ra log thay vì gửi mail. " +
                        "Xem hướng dẫn trong db/uterspace-mail.properties.example");
        }
        return c;
    }

    private static void env(Properties c, String key, String var) {
        String v = System.getenv(var);
        if (v != null && !v.trim().isEmpty()) c.setProperty(key, v.trim());
    }

    /** Gửi email chứa mã OTP đặt lại mật khẩu (HTML + bản chữ thuần) */
    public static Result sendResetOtp(String recipient, String displayName, String otp, int validMinutes) {
        if (!isConfigured()) {
            LOG.warning("[MailUtil][DEV] Mã OTP đặt lại mật khẩu cho " + recipient + ": " + otp + " (hiệu lực " + validMinutes + " phút)");
            return Result.DEV_LOGGED;
        }
        Properties c = config();
        String user = c.getProperty("mail.username");
        Properties props = new Properties();
        props.put("mail.smtp.auth", "true");
        // STARTTLS bắt buộc (Gmail). Chỉ tắt (mail.starttls=false) khi thử với máy chủ SMTP giả trên máy cá nhân
        boolean tls = !"false".equalsIgnoreCase(c.getProperty("mail.starttls", "true"));
        props.put("mail.smtp.starttls.enable", String.valueOf(tls));
        props.put("mail.smtp.starttls.required", String.valueOf(tls));
        props.put("mail.smtp.host", c.getProperty("mail.host", "smtp.gmail.com"));
        props.put("mail.smtp.port", c.getProperty("mail.port", "587"));
        props.put("mail.smtp.ssl.protocols", "TLSv1.2 TLSv1.3");
        props.put("mail.smtp.connectiontimeout", "10000");   // không để request treo khi SMTP chậm
        props.put("mail.smtp.timeout", "10000");
        props.put("mail.smtp.writetimeout", "10000");

        Session session = Session.getInstance(props, new javax.mail.Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(user, c.getProperty("mail.password"));
            }
        });
        try {
            MimeMessage m = new MimeMessage(session);
            m.setFrom(new InternetAddress(user, c.getProperty("mail.fromName", "UTErSpace"), "UTF-8"));
            m.setRecipients(Message.RecipientType.TO, InternetAddress.parse(recipient));
            m.setSubject("[UTErSpace] Mã xác nhận đặt lại mật khẩu: " + otp, "UTF-8");

            javax.mail.internet.MimeMultipart body = new javax.mail.internet.MimeMultipart("alternative");
            javax.mail.internet.MimeBodyPart text = new javax.mail.internet.MimeBodyPart();
            text.setText("Xin chào " + displayName + ",\n\nMã xác nhận đặt lại mật khẩu UTErSpace của bạn là: " + otp +
                         "\nMã có hiệu lực trong " + validMinutes + " phút. Không chia sẻ mã này cho bất kỳ ai.\n\n" +
                         "Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này — mật khẩu của bạn vẫn giữ nguyên.\n\n" +
                         "Đội ngũ UTErSpace", "UTF-8");
            javax.mail.internet.MimeBodyPart html = new javax.mail.internet.MimeBodyPart();
            html.setContent(otpHtml(escape(displayName), otp, validMinutes), "text/html; charset=UTF-8");
            body.addBodyPart(text);
            body.addBodyPart(html);
            m.setContent(body);
            Transport.send(m);
            LOG.info("[MailUtil] Đã gửi OTP đặt lại mật khẩu tới " + recipient);
            return Result.SENT;
        } catch (Exception | LinkageError e) {   // LinkageError: thiếu / trùng thư viện mail → báo lỗi thân thiện thay vì 500
            LOG.log(Level.WARNING, "[MailUtil] Gửi email OTP tới " + recipient + " thất bại: " + e, e);
            return Result.FAILED;
        }
    }

    private static String otpHtml(String name, String otp, int minutes) {
        return "<div style=\"font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:auto;padding:24px;" +
               "border:1px solid #e5e7eb;border-radius:12px;color:#111827\">" +
               "<h2 style=\"margin:0 0 16px;color:#0A3D8F;text-align:center\">UTEr<span style=\"color:#C81D3A\">Space</span></h2>" +
               "<p>Xin chào <b>" + name + "</b>,</p>" +
               "<p>Bạn vừa yêu cầu đặt lại mật khẩu. Nhập mã dưới đây để tiếp tục:</p>" +
               "<div style=\"text-align:center;margin:24px 0\"><span style=\"display:inline-block;font-size:28px;font-weight:700;" +
               "letter-spacing:8px;background:#f3f4f6;padding:12px 24px;border-radius:8px\">" + otp + "</span></div>" +
               "<p style=\"font-size:14px\">Mã có hiệu lực trong <b>" + minutes + " phút</b> và chỉ dùng được một lần.</p>" +
               "<p style=\"font-size:13px;color:#C81D3A\">Không chia sẻ mã này cho bất kỳ ai, kể cả người tự nhận là quản trị viên.</p>" +
               "<p style=\"font-size:13px;color:#6b7280\">Nếu bạn không yêu cầu, hãy bỏ qua email này — mật khẩu của bạn vẫn giữ nguyên.</p>" +
               "<p style=\"margin-top:24px\">Trân trọng,<br>Đội ngũ UTErSpace</p></div>";
    }

    private static String escape(String s) {
        return s == null ? "" : s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }
}
