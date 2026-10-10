package com.uterspace.ai;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * AiConfig — cấu hình Trợ lý AI. Cùng cách làm với MailUtil: KHÔNG ghi key vào mã nguồn.
 * Hỗ trợ 2 nhà cung cấp:
 *   - Google Gemini (Google AI Studio) — key dạng "AIza…" hoặc "AQ.…"
 *   - Anthropic Claude                 — key dạng "sk-ant-…"
 * Nhà cung cấp tự nhận theo dạng key; muốn chỉ định rõ thì đặt ai.provider=gemini | claude.
 *
 * Thứ tự ưu tiên:
 *   1. Biến môi trường GEMINI_API_KEY / ANTHROPIC_API_KEY, UTERSPACE_AI_MODEL, UTERSPACE_AI_PROVIDER
 *   2. File ${catalina.base}/conf/uterspace-ai.properties   (mẫu: db/uterspace-ai.properties.example)
 * File được tự nạp lại khi sửa (không cần khởi động lại Tomcat). Không có key → chế độ OFFLINE (xem AiService).
 */
public final class AiConfig {

    private static final Logger LOG = Logger.getLogger(AiConfig.class.getName());

    public static final String GEMINI = "gemini";
    public static final String CLAUDE = "claude";
    public static final String DEFAULT_CLAUDE_MODEL = "claude-opus-5-5";

    private static volatile Properties config;
    /** Mốc sửa đổi của file cấu hình lúc nạp — file đổi thì tự nạp lại, không cần khởi động lại Tomcat */
    private static volatile long loadedStamp = Long.MIN_VALUE;
    private static volatile long lastCheck;

    private AiConfig() { }

    /** Có gọi được AI không (đã có key và không bị tắt) */
    public static boolean isEnabled() {
        Properties c = config();
        return !c.getProperty("ai.apiKey", "").isEmpty() && !"false".equalsIgnoreCase(c.getProperty("ai.enabled", "true"));
    }

    /** Bài mới có được phân tích cảm xúc bằng AI không (mặc định có, khi AI đang bật) */
    public static boolean sentimentByAi() {
        return isEnabled() && !"false".equalsIgnoreCase(config().getProperty("ai.sentiment", "true"));
    }

    public static String apiKey() { return config().getProperty("ai.apiKey", ""); }

    /** gemini | claude — theo ai.provider, nếu không có thì đoán theo dạng key */
    public static String provider() {
        String p = config().getProperty("ai.provider", "").trim().toLowerCase();
        if (GEMINI.equals(p) || CLAUDE.equals(p)) return p;
        return apiKey().startsWith("sk-ant-") ? CLAUDE : GEMINI;
    }

    /** Tên hiển thị trên giao diện */
    public static String providerLabel() { return CLAUDE.equals(provider()) ? "Claude" : "Gemini"; }

    /** Model người dùng tự đặt (ai.model), có thể rỗng */
    public static String configuredModel() { return config().getProperty("ai.model", "").trim(); }

    /** Model dùng cho Claude (mặc định claude-opus-5-5) */
    public static String model() {
        String m = configuredModel();
        return m.isEmpty() || m.startsWith("gemini") ? DEFAULT_CLAUDE_MODEL : m;
    }

    private static File file() {
        String base = System.getProperty("catalina.base");
        return base == null ? null : new File(base, "conf/uterspace-ai.properties");
    }

    private static synchronized Properties config() {
        Properties c = config;
        long now = System.currentTimeMillis();
        if (c != null && now - lastCheck < 2000) return c;   // kiểm tra file tối đa 2 giây / lần
        lastCheck = now;
        File f = file();
        long stamp = f != null && f.isFile() ? f.lastModified() : -1;
        if (c != null && stamp == loadedStamp) return c;
        loadedStamp = stamp;
        c = new Properties();
        if (f != null && f.isFile()) {
            try (InputStream in = new FileInputStream(f)) {
                c.load(new InputStreamReader(in, StandardCharsets.UTF_8));
            } catch (Exception e) {
                LOG.log(Level.WARNING, "Không đọc được " + f + ": " + e.getMessage());
            }
        }
        env(c, "ai.apiKey", "GEMINI_API_KEY");
        env(c, "ai.apiKey", "ANTHROPIC_API_KEY");
        env(c, "ai.model", "UTERSPACE_AI_MODEL");
        env(c, "ai.provider", "UTERSPACE_AI_PROVIDER");
        // Dán key kèm dấu nháy / khoảng trắng cũng được
        c.setProperty("ai.apiKey", c.getProperty("ai.apiKey", "").trim().replaceAll("^[\"']|[\"']$", ""));
        config = c;
        String key = c.getProperty("ai.apiKey");
        LOG.info(key.isEmpty()
                 ? "[AI] Chưa cấu hình API key — chạy CHẾ ĐỘ OFFLINE (xem db/uterspace-ai.properties.example)."
                 : "[AI] Đã nạp cấu hình AI — nhà cung cấp: " + providerLabel());
        return c;
    }

    private static void env(Properties c, String prop, String var) {
        String v = System.getenv(var);
        if (v != null && !v.trim().isEmpty()) c.setProperty(prop, v.trim());
    }
}
