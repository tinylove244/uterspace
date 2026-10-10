package com.uterspace.ai;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.core.JsonValue;
import com.anthropic.errors.AnthropicServiceException;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.ImageBlockParam;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.OutputConfig;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.TextBlockParam;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.stream.Collectors;

/**
 * ClaudeClient — gọi Claude Messages API qua SDK chính thức (anthropic-java).
 * Một client dùng chung cho cả ứng dụng (thread-safe, tái sử dụng kết nối).
 *
 * Mọi lỗi (mạng, hết hạn mức, bị từ chối) đều trả null — AiService khi đó chuyển sang thuật toán offline,
 * người dùng không bao giờ gặp lỗi 500 chỉ vì AI.
 *
 * Bật sẵn "fallbacks: default" (beta server-side-fallback-2026-07-01): nếu bộ lọc an toàn của model chính
 * từ chối một yêu cầu bình thường, máy chủ Anthropic tự chạy lại trên model dự phòng phù hợp.
 */
final class ClaudeClient {

    private static final Logger LOG = Logger.getLogger(ClaudeClient.class.getName());

    private static volatile AnthropicClient client;
    private static volatile String clientKey;   // key đã dùng để tạo client — đổi key trong file cấu hình thì tạo lại

    private ClaudeClient() { }

    private static AnthropicClient client() {
        AnthropicClient c = client;
        String key = AiConfig.apiKey();
        if (c == null || !key.equals(clientKey)) {
            synchronized (ClaudeClient.class) {
                c = client;
                if (c == null || !key.equals(clientKey)) {
                    if (c != null) { try { c.close(); } catch (RuntimeException ignored) { } }
                    c = AnthropicOkHttpClient.builder()
                            .apiKey(key)
                            .timeout(Duration.ofSeconds(45))
                            .maxRetries(1)
                            .build();
                    client = c;
                    clientKey = key;
                }
            }
        }
        return c;
    }

    /** Ảnh đính kèm yêu cầu (JPEG/PNG/GIF/WEBP) */
    static final class Image {
        final byte[] data;
        final String mime;
        Image(byte[] data, String mime) { this.data = data; this.mime = mime; }
    }

    /**
     * Gửi một lượt hỏi, trả về toàn bộ chữ trong câu trả lời (đã trim), hoặc null nếu lỗi / bị từ chối.
     * @param lowEffort true cho việc ngắn, rõ ràng (phân loại, dịch) — nhanh và rẻ hơn
     */
    static String ask(String system, String userText, Image image, boolean lowEffort, long maxTokens) {
        if (!AiConfig.isEnabled()) return null;
        try {
            List<ContentBlockParam> blocks = new ArrayList<>();
            if (image != null) {
                blocks.add(ContentBlockParam.ofImage(ImageBlockParam.builder()
                        .source(Base64ImageSource.builder()
                                .mediaType(mediaType(image.mime))
                                .data(Base64.getEncoder().encodeToString(image.data))
                                .build())
                        .build()));
            }
            blocks.add(ContentBlockParam.ofText(TextBlockParam.builder().text(userText).build()));

            MessageCreateParams params = MessageCreateParams.builder()
                    .model(AiConfig.model())
                    .maxTokens(maxTokens)
                    .system(system)
                    .outputConfig(OutputConfig.builder()
                            .effort(lowEffort ? OutputConfig.Effort.LOW : OutputConfig.Effort.MEDIUM)
                            .build())
                    .addUserMessageOfBlockParams(blocks)
                    .putAdditionalHeader("anthropic-beta", "server-side-fallback-2026-07-01")
                    .putAdditionalBodyProperty("fallbacks", JsonValue.from("default"))
                    .build();

            Message response = client().messages().create(params);
            // Bị từ chối (kể cả sau khi đã thử model dự phòng): không đọc nội dung, để AiService dùng offline
            if (response.stopReason().map(r -> r.equals(StopReason.REFUSAL)).orElse(false)) {
                LOG.info("[AI] Claude từ chối yêu cầu — dùng thuật toán offline.");
                return null;
            }
            String text = response.content().stream()
                    .flatMap(b -> b.text().stream())
                    .map(t -> t.text())
                    .collect(Collectors.joining("\n"))
                    .trim();
            return text.isEmpty() ? null : text;
        } catch (AnthropicServiceException e) {
            LOG.log(Level.WARNING, "[AI] Claude API lỗi HTTP " + e.statusCode() + ": " + e.getMessage());
            return null;
        } catch (RuntimeException e) {
            LOG.log(Level.WARNING, "[AI] Không gọi được Claude API: " + e.getMessage());
            return null;
        }
    }

    /** Gửi một câu hỏi rất ngắn để kiểm tra key / mạng / model. Trả null nếu chạy tốt, ngược lại là mô tả lỗi. */
    static String ping() {
        if (AiConfig.apiKey().isEmpty()) return "Chưa có ai.apiKey trong conf/uterspace-ai.properties.";
        try {
            Message r = client().messages().create(MessageCreateParams.builder()
                    .model(AiConfig.model()).maxTokens(64L)
                    .outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.LOW).build())
                    .addUserMessage("Trả lời đúng một từ: OK").build());
            return r.content().isEmpty() ? "Claude không trả nội dung (stop_reason = " + r.stopReason().orElse(null) + ")." : null;
        } catch (AnthropicServiceException e) {
            return "Claude API báo lỗi HTTP " + e.statusCode() + (e.statusCode() == 401 ? " — API key không đúng." :
                   e.statusCode() == 403 ? " — key không có quyền dùng model này." :
                   e.statusCode() == 404 ? " — sai tên model (ai.model)." :
                   e.statusCode() == 429 ? " — vượt hạn mức / hết credit." : "") + " " + e.getMessage();
        } catch (RuntimeException e) {
            return "Không kết nối được api.anthropic.com: " + e.getMessage();
        }
    }

    private static Base64ImageSource.MediaType mediaType(String mime) {
        if ("image/png".equals(mime))  return Base64ImageSource.MediaType.IMAGE_PNG;
        if ("image/gif".equals(mime))  return Base64ImageSource.MediaType.IMAGE_GIF;
        if ("image/webp".equals(mime)) return Base64ImageSource.MediaType.IMAGE_WEBP;
        return Base64ImageSource.MediaType.IMAGE_JPEG;
    }

    /** Đóng kết nối khi undeploy (gọi từ AppContextListener) */
    static void shutdown() {
        AnthropicClient c = client;
        client = null;
        if (c != null) {
            try { c.close(); } catch (RuntimeException ignored) { }
        }
    }
}
