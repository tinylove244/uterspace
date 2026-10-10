package com.uterspace.ai;

/**
 * LlmClient — chọn nhà cung cấp AI theo cấu hình (AiConfig.provider): Google Gemini hoặc Anthropic Claude.
 * Cả hai trả null khi lỗi để AiService chuyển sang thuật toán offline.
 */
final class LlmClient {

    private LlmClient() { }

    static String ask(String system, String userText, ClaudeClient.Image image, boolean lowEffort, long maxTokens) {
        if (!AiConfig.isEnabled()) return null;
        return AiConfig.CLAUDE.equals(AiConfig.provider())
                ? ClaudeClient.ask(system, userText, image, lowEffort, maxTokens)
                : GeminiClient.ask(system, userText, image, lowEffort, maxTokens);
    }

    /** null = kết nối tốt, ngược lại là mô tả lỗi */
    static String ping() {
        return AiConfig.CLAUDE.equals(AiConfig.provider()) ? ClaudeClient.ping() : GeminiClient.ping();
    }

    /** Model thực sự đang dùng (Gemini: model trả lời thành công gần nhất) */
    static String activeModel() {
        if (AiConfig.CLAUDE.equals(AiConfig.provider())) return AiConfig.model();
        String m = GeminiClient.lastModel();
        if (m != null) return m;
        String c = AiConfig.configuredModel();
        return c.isEmpty() ? GeminiClient.DEFAULT_MODELS[0] : c;
    }
}
