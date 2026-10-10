package com.uterspace.ai;

import java.text.Normalizer;
import java.util.*;

/**
 * SentimentAnalyzer — phân tích cảm xúc tiếng Việt OFFLINE bằng từ điển (không cần mạng, không tốn phí).
 *
 * Cách tính (phỏng theo VADER, chỉnh cho tiếng Việt):
 *   - Từ điển cụm từ 1–3 âm tiết có trọng số (+3 .. -3), khớp cụm dài trước ("thất vọng" trước "thất").
 *   - Viết KHÔNG dấu ("buon qua", "met moi") vẫn nhận ra: nếu văn bản không có dấu thì so khớp trên bản bỏ dấu.
 *     Khi bỏ dấu, từ MỘT âm tiết rất dễ trùng ("do" = dở / đồ, "chan" = chán / chân, "on" = ổn / ơn) → chỉ dùng
 *     cụm từ nhiều âm tiết + một danh sách nhỏ từ đơn không nhập nhằng (FOLDED_SINGLE_OK).
 *   - Phủ định trong 2 âm tiết đứng trước, CÙNG mệnh đề ("không vui", "chẳng tốt", "ko thích") → đảo dấu, giảm 20%.
 *     Dấu câu (. , ! ? ;) cắt mệnh đề: "có mở cửa không? Cảm ơn!" không bị hiểu thành "không cảm ơn".
 *   - Từ nhấn mạnh trước/sau ("rất", "quá", "lắm", "cực kỳ", "vãi") → nhân 1.5.
 *   - Emoji có điểm riêng; dấu "!!!" khuếch đại nhẹ.
 *   - Tổng điểm s chuẩn hóa về [-1, 1]: s / sqrt(s² + 4).
 * Ngưỡng: ≥ 0.25 tích cực, ≤ -0.25 tiêu cực, còn lại trung tính.
 */
public final class SentimentAnalyzer {

    public static final double THRESHOLD = 0.25;

    /** Kết quả phân tích */
    public static final class Result {
        public final String label;     // POSITIVE | NEUTRAL | NEGATIVE
        public final double score;     // -1 .. 1
        public final String source;    // LEXICON | AI
        public final List<String> cues;  // các từ / emoji đã ảnh hưởng tới điểm (giải thích cho người dùng)
        public Result(String label, double score, String source, List<String> cues) {
            this.label = label; this.score = score; this.source = source; this.cues = cues;
        }
    }

    private static final Map<String, Double> LEXICON = new HashMap<>();
    private static final Map<String, Double> LEXICON_FOLDED = new HashMap<>();
    private static final Map<String, Double> EMOJI = new LinkedHashMap<>();
    private static final Set<String> NEGATORS = new HashSet<>(Arrays.asList(
            "không", "chẳng", "chả", "chưa", "đừng", "ko", "k", "hông", "hổng", "khỏi", "kh", "khong", "chang", "chua"));
    private static final Set<String> BOOSTERS = new HashSet<>(Arrays.asList(
            "rất", "quá", "lắm", "cực", "cực kỳ", "siêu", "vô cùng", "thật sự", "thực sự", "vãi", "cực kì", "hết sức", "cùng cực",
            "rat", "qua", "lam", "cuc", "sieu", "vai"));
    private static final int MAX_PHRASE = 3;
    /** Từ đơn vẫn đủ rõ nghĩa khi viết không dấu */
    private static final Set<String> FOLDED_SINGLE_OK = new HashSet<>(Arrays.asList(
            "vui", "buon", "thich", "ghet", "met", "gioi", "dep", "ngon", "tot", "khoc", "xau", "xui", "toang", "nan",
            "tuyet", "chill", "stress", "xin", "dinh", "deadline", "phien"));

    static {
        // ---------- Tích cực ----------
        put(3, "tuyệt vời", "xuất sắc", "hạnh phúc", "tuyệt cú mèo", "quá đỉnh", "đỉnh của chóp", "yêu thương", "chúc mừng",
               "tự hào", "thành công", "hoan hô", "biết ơn", "học bổng", "đỗ rồi", "đậu rồi", "qua môn", "tốt nghiệp");
        put(2, "sung sướng", "sướng", "đã quá", "quá đã", "vui", "vui vẻ", "vui quá", "tuyệt", "tốt", "giỏi", "đẹp", "ngon", "thích", "yêu", "cảm ơn", "cám ơn", "hài lòng",
               "may mắn", "hào hứng", "phấn khởi", "xịn", "đỉnh", "ấm áp", "ý nghĩa", "bổ ích", "hữu ích", "tiến bộ", "hoàn thành",
               "thú vị", "đáng yêu", "dễ thương", "mãn nguyện", "lạc quan", "nhiệt tình", "tận tâm", "ủng hộ", "khen", "mong chờ",
               "hay quá", "rất hay", "tuyệt quá", "ổn áp", "chill", "thoải mái", "hạnh phúc quá", "đáng nhớ", "truyền cảm hứng",
               "an tâm", "yên tâm", "trân trọng", "vinh dự", "xinh", "dễ hiểu", "nhanh gọn", "chất lượng", "chuyên nghiệp");
        put(1, "ổn", "được", "cố lên", "hy vọng", "hi vọng", "mong", "chúc", "hay ho", "mới", "vui lòng", "đầy đủ", "rõ ràng",
               "thân thiện", "tiện", "tiện lợi", "bình yên", "nhẹ nhàng", "sẵn sàng");
        // ---------- Tiêu cực ----------
        put(-3, "tuyệt vọng", "trầm cảm", "muốn chết", "chán đời", "khốn nạn", "lừa đảo", "thảm họa", "kinh khủng", "khủng khiếp",
                "tồi tệ", "đáng ghét", "phẫn nộ", "tức điên", "bắt nạt", "xúc phạm", "căm ghét", "ghê tởm", "đồ ngu", "vô học",
                "đau khổ", "bất công", "dối trá", "tự tử", "cút");
        put(-2, "buồn", "chán", "mệt", "tệ", "dở", "ghét", "giận", "tức", "bực", "bực mình", "thất vọng", "thất bại", "rớt môn",
                "trượt", "nợ môn", "lo lắng", "áp lực", "căng thẳng", "stress", "sợ", "đau", "khóc", "cô đơn", "ngu", "ngốc", "đần",
                "vô dụng", "kém", "tồi", "xấu", "lừa", "tức giận", "chán nản", "mệt mỏi", "kiệt sức", "bế tắc", "xui", "xui xẻo",
                "toang", "tủi thân", "khó chịu", "phiền", "vô lý", "cay cú", "cạn lời", "thô lỗ", "thua", "hỏng", "rác", "sập",
                "chậm chạp", "thất hứa", "bỏ rơi", "nhục", "xấu hổ", "hối hận", "tiếc", "đuối", "nản", "khổ", "khổ sở", "thảm",
                "chán ghét", "lo âu", "hoang mang", "bất mãn", "tệ hại", "dở tệ", "nguy hiểm", "độc hại");
        put(-0.5, "deadline");
        put(-1, "khó", "mệt nhỉ", "hơi buồn", "lo", "chán ghê", "trễ", "muộn", "thiếu", "mất ngủ", "ốm", "bệnh", "đắt",
                "ồn", "kẹt xe", "tắc đường", "chờ mãi", "tiếc quá");
        // ---------- Emoji ----------
        for (String e : new String[]{"😀", "😁", "😂", "🤣", "😊", "😍", "😘", "😎", "🥳", "🎉", "❤️", "❤", "💯", "✅", "👍", "👏",
                                     "🙏", "💪", "🔥", "✨", "🌟", "😄", "😃", "🥰", "🤩", "💖", "💕", "🌸", "☺️", "😇", "🤗"}) EMOJI.put(e, 1.5);
        for (String e : new String[]{"😢", "😭", "😞", "😔", "😟", "😩", "😫", "💔", "👎", "😥", "😰", "😱", "😓", "🥺", "😿"}) EMOJI.put(e, -1.5);
        for (String e : new String[]{"😡", "😠", "🤬", "😤", "🖕", "💢"}) EMOJI.put(e, -2.5);
    }

    private static void put(double w, String... phrases) {
        for (String p : phrases) {
            LEXICON.put(p, w);
            String f = fold(p);
            if (f.indexOf(' ') > 0 || FOLDED_SINGLE_OK.contains(f)) LEXICON_FOLDED.putIfAbsent(f, w);
        }
    }

    private SentimentAnalyzer() { }

    /** Bỏ dấu tiếng Việt + chữ thường */
    public static String fold(String s) {
        String n = Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
        return n.replace('đ', 'd').replace('Đ', 'D').toLowerCase(Locale.ROOT);
    }

    private static boolean hasVietnameseMarks(String s) {
        return !Normalizer.normalize(s, Normalizer.Form.NFD).equals(s) || s.indexOf('đ') >= 0 || s.indexOf('Đ') >= 0;
    }

    public static Result analyze(String text) {
        if (text == null || text.trim().isEmpty()) return new Result("NEUTRAL", 0, "LEXICON", Collections.emptyList());
        String lower = Normalizer.normalize(text, Normalizer.Form.NFC).toLowerCase(new Locale("vi"));
        boolean marked = hasVietnameseMarks(lower);
        Map<String, Double> lex = marked ? LEXICON : LEXICON_FOLDED;
        String body = marked ? lower : fold(lower);

        double sum = 0;
        List<String> cues = new ArrayList<>();

        // Emoji (đếm mọi lần xuất hiện, tối đa 3 lần mỗi loại)
        for (Map.Entry<String, Double> e : EMOJI.entrySet()) {
            int idx = 0, n = 0;
            while ((idx = text.indexOf(e.getKey(), idx)) >= 0 && n < 3) { n++; idx += e.getKey().length(); }
            if (n > 0) { sum += e.getValue() * n; cues.add(e.getKey()); }
        }

        Set<String> boosters = marked ? BOOSTERS : foldAll(BOOSTERS);
        Set<String> negators = marked ? NEGATORS : foldAll(NEGATORS);
        // Mỗi mệnh đề xử lý riêng (phủ định không lan qua dấu câu); trong mệnh đề tách âm tiết (chữ + số, giữ dấu)
        for (String clause : body.split("[.,!?;:\\n…]+")) {
          String[] tokens = clause.replaceAll("[^\\p{L}\\p{N}]+", " ").trim().split("\\s+");
          if (tokens.length == 1 && tokens[0].isEmpty()) continue;
          for (int i = 0; i < tokens.length; ) {
            String matched = null;
            double w = 0;
            int len = 0;
            for (int k = Math.min(MAX_PHRASE, tokens.length - i); k >= 1; k--) {
                String phrase = String.join(" ", Arrays.copyOfRange(tokens, i, i + k));
                Double v = lex.get(phrase);
                if (v != null) { matched = phrase; w = v; len = k; break; }
            }
            if (matched == null) { i++; continue; }

            // Phủ định trong 2 âm tiết trước ("không vui", "không còn vui")
            boolean negated = false;
            for (int j = Math.max(0, i - 2); j < i; j++) if (negators.contains(tokens[j])) negated = true;
            // Nhấn mạnh trước hoặc ngay sau
            boolean boosted = (i > 0 && boosters.contains(tokens[i - 1]))
                    || (i + len < tokens.length && boosters.contains(tokens[i + len]));
            if (boosted) w *= 1.5;
            if (negated) w *= -0.8;
            sum += w;
            cues.add((negated ? "không " : "") + matched);
            i += len;
          }
        }

        // "!!!" khuếch đại theo chiều cảm xúc hiện có
        long bangs = text.chars().filter(c -> c == '!').count();
        if (sum != 0 && bangs > 0) sum += Math.signum(sum) * Math.min(bangs, 4) * 0.25;

        double score = sum / Math.sqrt(sum * sum + 4);
        score = Math.round(score * 1000) / 1000.0;
        String label = score >= THRESHOLD ? "POSITIVE" : score <= -THRESHOLD ? "NEGATIVE" : "NEUTRAL";
        return new Result(label, score, "LEXICON", cues.size() > 8 ? cues.subList(0, 8) : cues);
    }

    private static Set<String> foldAll(Set<String> words) {
        Set<String> r = new HashSet<>();
        for (String w : words) r.add(fold(w));
        return r;
    }
}
