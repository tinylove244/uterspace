package com.uterspace.ai;

import com.uterspace.util.HashtagUtil;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * AiService — các tính năng AI của UTErSpace. Mỗi hàm thử AI trước (Google Gemini hoặc Claude, xem AiConfig),
 * lỗi / chưa cấu hình thì dùng thuật toán OFFLINE — giao diện luôn có kết quả để hiển thị.
 *
 *   sentiment()   phân loại cảm xúc bài viết (Gemini / Claude, hoặc SentimentAnalyzer)
 *   caption()     viết chú thích bài đăng theo giọng văn, có thể nhìn ảnh đính kèm
 *   summarize()   tóm tắt bài dài (offline: trích các câu quan trọng nhất)
 *   translate()   dịch đa ngôn ngữ (offline: trả null → trình duyệt dùng Translator API có sẵn của Chrome)
 *
 * Phân tích cảm xúc chạy NỀN (analyzePostAsync) để đăng bài không phải chờ AI.
 */
public final class AiService {

    private static final Logger LOG = Logger.getLogger(AiService.class.getName());

    /** Kết quả chữ kèm nguồn tạo ra: "AI" (Gemini / Claude) hoặc "OFFLINE" */
    public static final class TextResult {
        public final String text;
        public final String source;
        public TextResult(String text, String source) { this.text = text; this.source = source; }
    }

    /** Luồng nền phân tích cảm xúc bài mới + quét bài cũ chưa có nhãn khi khởi động */
    private static final ExecutorService WORKER = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "ai-sentiment");
        t.setDaemon(true);
        return t;
    });

    public static final Map<String, String> LANGUAGES;
    static {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("vi", "tiếng Việt");
        m.put("en", "tiếng Anh");
        m.put("ja", "tiếng Nhật");
        m.put("ko", "tiếng Hàn");
        m.put("zh", "tiếng Trung (giản thể)");
        m.put("fr", "tiếng Pháp");
        LANGUAGES = Collections.unmodifiableMap(m);
    }

    public static final Map<String, String> TONES;
    static {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("friendly", "vui vẻ, thân thiện");
        m.put("inspiring", "truyền cảm hứng, tích cực");
        m.put("funny", "hài hước, dí dỏm kiểu Gen Z");
        m.put("professional", "chuyên nghiệp, lịch sự");
        m.put("short", "thật ngắn gọn, một câu");
        TONES = Collections.unmodifiableMap(m);
    }

    private AiService() { }

    public static boolean aiAvailable() { return AiConfig.isEnabled(); }

    /** Kiểm tra kết nối AI thật (GET /ai/status?ping=1): null = tốt, ngược lại là lỗi */
    public static String ping() { return LlmClient.ping(); }

    public static String model() { return LlmClient.activeModel(); }

    /** "Gemini" | "Claude" — hiển thị nguồn kết quả trên giao diện */
    public static String providerLabel() { return AiConfig.providerLabel(); }

    // ============================================================ Cảm xúc

    private static final Pattern JSON_LABEL = Pattern.compile("\"label\"\\s*:\\s*\"(POSITIVE|NEUTRAL|NEGATIVE)\"");
    private static final Pattern JSON_SCORE = Pattern.compile("\"score\"\\s*:\\s*(-?[0-9]*\\.?[0-9]+)");

    /** Phân loại cảm xúc; useAi = false → luôn dùng từ điển (nhanh, miễn phí) */
    public static SentimentAnalyzer.Result sentiment(String text, boolean useAi) {
        SentimentAnalyzer.Result offline = SentimentAnalyzer.analyze(text);
        if (!useAi || text == null || text.trim().length() < 3) return offline;
        String reply = LlmClient.ask(
                "Bạn là bộ phân loại cảm xúc cho bài đăng mạng xã hội của sinh viên Việt Nam (có thể viết không dấu, tiếng lóng, emoji). " +
                "Đánh giá cảm xúc chung của người viết. Bài kể chuyện buồn nhưng kết thúc lạc quan → theo cảm xúc chủ đạo. " +
                "Chỉ trả về đúng một dòng JSON: {\"label\":\"POSITIVE|NEUTRAL|NEGATIVE\",\"score\":<số từ -1 đến 1>}",
                "Bài viết:\n\"\"\"\n" + clip(text, 4000) + "\n\"\"\"", null, true, 200);
        if (reply == null) return offline;
        Matcher lm = JSON_LABEL.matcher(reply), sm = JSON_SCORE.matcher(reply);
        if (!lm.find()) return offline;
        double score = sm.find() ? Math.max(-1, Math.min(1, Double.parseDouble(sm.group(1)))) : offline.score;
        return new SentimentAnalyzer.Result(lm.group(1), score, "AI", offline.cues);
    }

    /** Phân tích nền rồi ghi vào posts.sentiment* — gọi ngay sau khi tạo / sửa bài */
    public static void analyzePostAsync(int postId, String text) {
        WORKER.submit(() -> {
            try {
                SentimentAnalyzer.Result r = sentiment(text, AiConfig.sentimentByAi());
                saveSentiment(postId, r);
            } catch (RuntimeException e) {
                LOG.warning("[AI] Phân tích cảm xúc bài " + postId + " lỗi: " + e.getMessage());
            }
        });
    }

    /**
     * Khởi động: gắn nhãn bằng từ điển cho bài chưa phân tích + làm mới nhãn từ điển cũ (từ điển có thể vừa được bổ sung).
     * Không gọi API hàng loạt để không tốn phí; nhãn do AI gắn (source = AI) được giữ nguyên.
     */
    public static void backfillAsync() {
        WORKER.submit(() -> {
            EntityManager em = JPAUtil.getEntityManager();
            List<Object[]> rows;
            try {
                @SuppressWarnings("unchecked")
                List<Object[]> r = em.createNativeQuery(
                        "SELECT post_id, content, sentiment, sentiment_score FROM posts WHERE sentiment IS NULL OR sentiment_source = 'LEXICON'").getResultList();
                rows = r;
            } catch (RuntimeException e) {
                LOG.warning("[AI] Không quét được bài chưa phân tích (đã chạy migration 090 chưa?): " + e.getMessage());
                return;
            } finally {
                em.close();
            }
            // Chỉ ghi bài có nhãn thay đổi — mỗi UPDATE lên DB cloud mất ~0,5 giây, ghi lại cả bảng mỗi lần
            // khởi động làm chậm mọi request trong khoảng nửa phút đầu
            int changed = 0;
            for (Object[] row : rows) {
                SentimentAnalyzer.Result res = SentimentAnalyzer.analyze((String) row[1]);
                Number oldScore = (Number) row[3];
                boolean same = res.label.equals(row[2]) && oldScore != null && Math.abs(oldScore.doubleValue() - res.score) < 1e-6;
                if (same) continue;
                saveSentiment(((Number) row[0]).intValue(), res);
                changed++;
            }
            if (changed > 0) LOG.info("[AI] Đã gắn / làm mới nhãn cảm xúc (từ điển) cho " + changed + " bài viết.");
        });
    }

    private static void saveSentiment(int postId, SentimentAnalyzer.Result r) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            em.createNativeQuery("UPDATE posts SET sentiment = :l, sentiment_score = :s, sentiment_source = :src WHERE post_id = :id")
              .setParameter("l", r.label).setParameter("s", r.score).setParameter("src", r.source).setParameter("id", postId)
              .executeUpdate();
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    // ============================================================ Viết chú thích

    /**
     * Viết chú thích cho bài đăng.
     * @param draft  nội dung / ý tưởng người dùng đã gõ (có thể rỗng nếu có ảnh)
     * @param tone   khóa trong TONES
     * @param image  ảnh đính kèm (null nếu không có) — AI nhìn ảnh để mô tả
     */
    public static TextResult caption(String draft, String tone, byte[] image, String imageMime) {
        String toneDesc = TONES.getOrDefault(tone, TONES.get("friendly"));
        String d = draft == null ? "" : draft.trim();
        String reply = LlmClient.ask(
                "Bạn là trợ lý viết bài cho UTErSpace — mạng xã hội của sinh viên HCMUTE. " +
                "Viết MỘT chú thích tiếng Việt có dấu, giọng " + toneDesc + ", tối đa 60 từ, có thể kèm 1–3 emoji phù hợp " +
                "và 1–3 hashtag viết liền không dấu ở cuối (ví dụ #HCMUTE #SinhVien). " +
                "Giữ đúng ý và sự kiện người dùng cung cấp, không bịa thêm tên người, địa điểm, con số. " +
                "Chỉ trả về chú thích, không giải thích, không đặt trong dấu ngoặc kép.",
                (d.isEmpty() ? "Người dùng chưa viết gì — hãy viết chú thích dựa trên bức ảnh."
                             : "Ý tưởng / bản nháp của người dùng:\n\"\"\"\n" + clip(d, 3000) + "\n\"\"\""),
                image == null ? null : new ClaudeClient.Image(image, imageMime), false, 600);
        if (reply != null) return new TextResult(stripQuotes(reply), "AI");
        return new TextResult(offlineCaption(d, tone), "OFFLINE");
    }

    private static String offlineCaption(String draft, String tone) {
        SentimentAnalyzer.Result s = SentimentAnalyzer.analyze(draft);
        List<String> tags = keywordTags(draft, 2);
        String core = draft.isEmpty() ? "Một khoảnh khắc đáng nhớ" : firstSentence(draft);
        String emoji = "NEGATIVE".equals(s.label) ? "🫂" : "POSITIVE".equals(s.label) ? "✨" : "📌";
        String text;
        switch (tone == null ? "friendly" : tone) {
            case "inspiring":    text = core + " — mỗi ngày một bước, rồi sẽ tới đích! 💪"; break;
            case "funny":        text = core + " 😂 Ai hiểu thì hiểu, ai không hiểu thì… cũng thả tim giùm nha!"; break;
            case "professional": text = core + ". Rất mong nhận được góp ý từ mọi người."; break;
            case "short":        text = core + " " + emoji; break;
            default:             text = core + " " + emoji + " Cùng chia sẻ với mình nhé!";
        }
        StringBuilder sb = new StringBuilder(text);
        if (!tags.contains("HCMUTE")) tags.add("HCMUTE");
        for (String t : tags) sb.append(" #").append(t);
        return sb.toString();
    }

    // ============================================================ Tóm tắt

    public static TextResult summarize(String text) {
        String t = text == null ? "" : text.trim();
        if (t.length() < 80) return new TextResult(t, "OFFLINE");
        String reply = LlmClient.ask(
                "Bạn tóm tắt bài đăng mạng xã hội. Viết bằng ngôn ngữ của bài gốc, 1–3 câu, tối đa 50 từ, giữ ý chính và các con số quan trọng. " +
                "Chỉ trả về đoạn tóm tắt.",
                "Bài viết:\n\"\"\"\n" + clip(t, 12000) + "\n\"\"\"", null, true, 400);
        if (reply != null) return new TextResult(stripQuotes(reply), "AI");
        return new TextResult(extractiveSummary(t, 2), "OFFLINE");
    }

    /** Tóm tắt trích xuất: chấm điểm câu theo tần suất từ khóa (bỏ từ dừng), lấy n câu cao nhất theo thứ tự gốc */
    static String extractiveSummary(String text, int n) {
        String[] sentences = text.replaceAll("\\s+", " ").split("(?<=[.!?…])\\s+|\\n+");
        if (sentences.length <= n) return text.trim();
        Map<String, Integer> freq = new HashMap<>();
        for (String w : words(text)) freq.merge(w, 1, Integer::sum);
        double[] score = new double[sentences.length];
        for (int i = 0; i < sentences.length; i++) {
            List<String> ws = words(sentences[i]);
            for (String w : ws) score[i] += freq.getOrDefault(w, 0);
            score[i] = ws.isEmpty() ? 0 : score[i] / Math.sqrt(ws.size());
            if (i == 0) score[i] *= 1.2;   // câu mở đầu thường nêu chủ đề
        }
        Integer[] idx = new Integer[sentences.length];
        for (int i = 0; i < idx.length; i++) idx[i] = i;
        Arrays.sort(idx, (a, b) -> Double.compare(score[b], score[a]));
        Integer[] pick = Arrays.copyOf(idx, n);
        Arrays.sort(pick);
        StringBuilder sb = new StringBuilder();
        for (int i : pick) sb.append(sentences[i].trim()).append(' ');
        return sb.toString().trim();
    }

    // ============================================================ Dịch

    /** Dịch sang ngôn ngữ đích (mã trong LANGUAGES). null = không dịch được trên máy chủ → trình duyệt tự dịch */
    public static TextResult translate(String text, String target) {
        String lang = LANGUAGES.get(target);
        if (lang == null || text == null || text.trim().isEmpty()) return null;
        String reply = LlmClient.ask(
                "Bạn là phiên dịch viên. Dịch đoạn văn sang " + lang + ", giữ nguyên giọng văn, emoji, hashtag, @tên người và đường dẫn. " +
                "Nếu đoạn văn đã ở " + lang + " thì trả lại nguyên văn. Chỉ trả về bản dịch.",
                clip(text.trim(), 12000), null, true, 2000);
        return reply == null ? null : new TextResult(stripQuotes(reply), "AI");
    }

    // ============================================================ Tiện ích

    private static final Set<String> STOP = new HashSet<>(Arrays.asList(
            "và", "là", "của", "có", "cho", "các", "những", "một", "được", "trong", "với", "này", "đã", "thì", "mà", "để", "khi",
            "không", "cũng", "như", "người", "mình", "bạn", "tôi", "nhé", "nha", "ạ", "lại", "rồi", "sẽ", "đang", "từ", "ra", "vào",
            "the", "a", "an", "and", "of", "to", "in", "is", "for", "on", "at", "with", "it", "this", "that"));

    private static List<String> words(String s) {
        List<String> out = new ArrayList<>();
        for (String w : s.toLowerCase(new Locale("vi")).replaceAll("[^\\p{L}\\p{N}]+", " ").trim().split("\\s+")) {
            if (w.length() > 1 && !STOP.contains(w)) out.add(w);
        }
        return out;
    }

    /** Chủ đề quen thuộc của sinh viên: cụm từ (đã bỏ dấu) → hashtag */
    private static final String[][] TOPICS = {
        {"do an", "DoAn"}, {"iot", "IoT"}, {"tri tue nhan tao", "AI"}, {" ai ", "AI"}, {"lap trinh", "LapTrinh"},
        {"hoc bong", "HocBong"}, {"seminar", "Seminar"}, {"hoi thao", "HoiThao"}, {"robot", "Robotics"},
        {"web", "WebDev"}, {"java", "Java"}, {"python", "Python"}, {"du lich", "DuLich"}, {"ca phe", "CaPhe"},
        {"cafe", "CaPhe"}, {"bong da", "BongDa"}, {"the thao", "TheThao"}, {"am nhac", "AmNhac"}, {"tinh nguyen", "TinhNguyen"},
        {"thuc tap", "ThucTap"}, {"tot nghiep", "TotNghiep"}, {"sinh vien", "SinhVien"}, {"mua thi", "MuaThi"},
        {"thi cuoi ky", "MuaThi"}, {"thi giua ky", "MuaThi"}, {"thu vien", "ThuVien"}, {"tieng anh", "TiengAnh"},
        {"ielts", "IELTS"}, {"toeic", "TOEIC"}, {"khoi nghiep", "KhoiNghiep"}, {"clb", "CLB"}, {"cau lac bo", "CLB"},
        {"demo", "Demo"}, {"deadline", "Deadline"}, {"nhom", "TeamWork"}, {"thiet ke", "Design"}, {"chup anh", "Photography"}
    };

    /** Gợi ý hashtag offline: hashtag sẵn có trong bài → chủ đề nhận ra từ từ điển → từ viết tắt / tên riêng viết hoa (IoT, HCMUTE) */
    static List<String> keywordTags(String text, int max) {
        LinkedHashSet<String> tags = new LinkedHashSet<>(HashtagUtil.extract(text));
        String folded = " " + SentimentAnalyzer.fold(text == null ? "" : text).replaceAll("[^a-z0-9]+", " ") + " ";
        for (String[] t : TOPICS) {
            if (tags.size() >= max) break;
            if (folded.contains(t[0].startsWith(" ") ? t[0] : " " + t[0])) tags.add(t[1]);
        }
        if (tags.size() < max && text != null) {
            Matcher m = Pattern.compile("\\b([A-Z][A-Za-z0-9]*[A-Z0-9][A-Za-z0-9]*)\\b").matcher(text);   // IoT, HCMUTE, UI
            while (m.find() && tags.size() < max) if (m.group(1).length() >= 2) tags.add(m.group(1));
        }
        List<String> out = new ArrayList<>(tags);
        return out.size() > max ? new ArrayList<>(out.subList(0, max)) : out;
    }

    private static String firstSentence(String s) {
        String t = s.replaceAll("\\s+", " ").trim();
        int cut = -1;
        for (char c : new char[]{'.', '!', '?', '\n'}) {
            int i = t.indexOf(c);
            if (i > 10 && (cut < 0 || i < cut)) cut = i;
        }
        if (cut > 0) t = t.substring(0, cut);
        return t.length() > 140 ? t.substring(0, 137) + "…" : t;
    }

    private static String clip(String s, int max) { return s.length() > max ? s.substring(0, max) : s; }

    private static String stripQuotes(String s) {
        String t = s.trim();
        if (t.length() > 1 && (t.startsWith("\"") && t.endsWith("\"") || t.startsWith("“") && t.endsWith("”"))) {
            t = t.substring(1, t.length() - 1).trim();
        }
        return t;
    }

    /** Gọi từ AppContextListener khi undeploy */
    public static void shutdown() {
        WORKER.shutdownNow();
        try { WORKER.awaitTermination(2, TimeUnit.SECONDS); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
        ClaudeClient.shutdown();   // Gemini dùng HttpClient của JDK — không cần đóng
    }
}
