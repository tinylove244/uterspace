package com.uterspace.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.logging.Logger;

/**
 * GeminiClient — gọi Google Gemini API (Google AI Studio, REST generateContent) bằng java.net.http.
 *
 * Google thường xuyên đổi / ngừng model và hay báo 503 "high demand" lúc cao điểm, nên mỗi yêu cầu thử lần lượt
 * một CHUỖI model: model cấu hình (ai.model, nếu có) → gemini-flash-latest → gemini-3.5-flash → gemini-flash-lite-latest.
 * Lỗi 503 / 429 / 500 / 404 → chuyển model kế tiếp; model chạy được gần nhất được ưu tiên ở lần sau.
 * Mọi lỗi cuối cùng trả null → AiService dùng thuật toán offline, người dùng không gặp lỗi 500.
 */
final class GeminiClient {

    private static final Logger LOG = Logger.getLogger(GeminiClient.class.getName());
    private static final String BASE = "https://generativelanguage.googleapis.com/v1beta/models/";
    static final String[] DEFAULT_MODELS = { "gemini-flash-latest", "gemini-3.5-flash", "gemini-flash-lite-latest" };

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final HttpClient HTTP = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    /** Model trả lời thành công gần nhất — thử trước ở lần gọi sau */
    private static volatile String lastGood;

    private GeminiClient() { }

    /** Kết quả một lần gọi: chữ trả về hoặc mô tả lỗi */
    static final class Reply {
        final String text, error, model;
        Reply(String text, String error, String model) { this.text = text; this.error = error; this.model = model; }
    }

    static String ask(String system, String userText, ClaudeClient.Image image, boolean lowEffort, long maxTokens) {
        Reply r = call(system, userText, image, maxTokens);
        if (r.error != null) LOG.warning("[AI] Gemini lỗi: " + r.error + " — dùng thuật toán offline.");
        return r.text;
    }

    /** Kiểm tra key / model: null = tốt (kèm tên model trong log), ngược lại là mô tả lỗi */
    static String ping() {
        Reply r = call(null, "Trả lời đúng một từ: OK", null, 256);
        return r.error == null ? null : r.error;
    }

    static String lastModel() { return lastGood; }

    private static List<String> chain() {
        Set<String> s = new LinkedHashSet<>();
        if (lastGood != null) s.add(lastGood);
        String configured = AiConfig.configuredModel();
        if (configured != null && !configured.isEmpty()) s.add(configured);
        for (String m : DEFAULT_MODELS) s.add(m);
        return new ArrayList<>(s);
    }

    private static Reply call(String system, String userText, ClaudeClient.Image image, long maxTokens) {
        String key = AiConfig.apiKey();
        if (key.isEmpty()) return new Reply(null, "Chưa có ai.apiKey trong conf/uterspace-ai.properties.", null);
        String body;
        try {
            body = JSON.writeValueAsString(request(system, userText, image, maxTokens));
        } catch (Exception e) {
            return new Reply(null, "Không dựng được yêu cầu: " + e.getMessage(), null);
        }
        StringBuilder errors = new StringBuilder();
        for (String model : chain()) {
            try {
                HttpRequest req = HttpRequest.newBuilder(URI.create(BASE + model + ":generateContent"))
                        .timeout(Duration.ofSeconds(60))
                        .header("Content-Type", "application/json")
                        .header("x-goog-api-key", key)
                        .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
                        .build();
                HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                JsonNode d = JSON.readTree(resp.body());
                if (resp.statusCode() != 200) {
                    String msg = d.path("error").path("message").asText("HTTP " + resp.statusCode());
                    int sc = resp.statusCode();
                    if (sc == 400 && msg.toLowerCase().contains("api key")) return new Reply(null, "API key không hợp lệ: " + msg, model);
                    if (sc == 401 || sc == 403) return new Reply(null, "Key không có quyền dùng Gemini API (HTTP " + sc + "): " + msg, model);
                    errors.append(model).append(" → HTTP ").append(sc).append(' ').append(clip(msg, 90)).append("; ");
                    continue;   // 404 (model ngừng), 429 (hết hạn mức phút), 5xx (quá tải) → thử model kế
                }
                String block = d.path("promptFeedback").path("blockReason").asText("");
                if (!block.isEmpty()) return new Reply(null, "Gemini chặn nội dung (" + block + ").", model);
                JsonNode cand = d.path("candidates").path(0);
                StringBuilder text = new StringBuilder();
                for (JsonNode p : cand.path("content").path("parts")) {
                    if (p.path("thought").asBoolean(false)) continue;   // bỏ phần "suy nghĩ" nếu model trả về
                    text.append(p.path("text").asText(""));
                }
                String out = text.toString().trim();
                if (out.isEmpty()) {
                    errors.append(model).append(" → không có nội dung (").append(cand.path("finishReason").asText("?")).append("); ");
                    continue;
                }
                lastGood = model;
                return new Reply(out, null, model);
            } catch (Exception e) {
                errors.append(model).append(" → ").append(clip(String.valueOf(e.getMessage()), 90)).append("; ");
            }
        }
        return new Reply(null, "Tất cả model Gemini đều lỗi: " + errors, null);
    }

    private static ObjectNode request(String system, String userText, ClaudeClient.Image image, long maxTokens) {
        ObjectNode root = JSON.createObjectNode();
        if (system != null) root.putObject("systemInstruction").putArray("parts").addObject().put("text", system);
        ObjectNode content = root.putArray("contents").addObject();
        content.put("role", "user");
        ArrayNode parts = content.putArray("parts");
        if (image != null) {
            ObjectNode inline = parts.addObject().putObject("inline_data");
            inline.put("mime_type", image.mime);
            inline.put("data", Base64.getEncoder().encodeToString(image.data));
        }
        parts.addObject().put("text", userText);
        // Model "thinking" tính cả token suy nghĩ vào giới hạn → để dư (tối thiểu 2048) cho câu trả lời không bị cắt
        root.putObject("generationConfig").put("maxOutputTokens", Math.max(2048, maxTokens * 4)).put("temperature", 0.7);
        return root;
    }

    private static String clip(String s, int n) { return s.length() > n ? s.substring(0, n) + "…" : s; }
}
