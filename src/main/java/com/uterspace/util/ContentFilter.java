package com.uterspace.util;

import com.uterspace.ai.SentimentAnalyzer;
import com.uterspace.model.Post;
import com.uterspace.model.UserSettings;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * ContentFilter — Bộ lọc nội dung cá nhân (Advanced Content Control).
 * Người dùng tự đặt từ khóa / cụm từ / emoji không muốn thấy (Cài đặt → Bảng tin & bộ lọc).
 * So khớp KHÔNG phân biệt hoa thường và dấu ("thi rot" khớp "Thi rớt"); từ chữ cái khớp nguyên từ
 * ("ngu" không khớp "Nguyễn"), emoji / ký hiệu khớp ở bất kỳ đâu.
 * Chỉ ảnh hưởng tới màn hình của chính người đặt — bài bị khớp được THU GỌN (bấm để xem), không bị xóa.
 */
public final class ContentFilter {

    private final List<String> terms = new ArrayList<>();
    private final List<Pattern> patterns = new ArrayList<>();
    private final boolean hideNegative;

    private ContentFilter(UserSettings s) {
        this.hideNegative = s != null && s.isHideNegative();
        if (s == null) return;
        for (String t : s.getFilterTerms()) {
            String f = SentimentAnalyzer.fold(t);
            boolean wordy = f.codePoints().anyMatch(Character::isLetterOrDigit);
            terms.add(t);
            patterns.add(wordy
                    ? Pattern.compile("(?<![\\p{L}\\p{N}])" + Pattern.quote(f) + "(?![\\p{L}\\p{N}])")
                    : Pattern.compile(Pattern.quote(t)));
        }
    }

    public static ContentFilter of(UserSettings s) { return new ContentFilter(s); }

    public boolean isEmpty() { return terms.isEmpty() && !hideNegative; }

    /** Từ khóa (dạng người dùng nhập) đầu tiên xuất hiện trong văn bản, hoặc null */
    public String match(String text) {
        if (text == null || terms.isEmpty()) return null;
        String folded = SentimentAnalyzer.fold(text);
        for (int i = 0; i < terms.size(); i++) {
            Pattern p = patterns.get(i);
            if (p.matcher(folded).find() || p.matcher(text).find()) return terms.get(i);
        }
        return null;
    }

    /** Gắn lý do thu gọn (Post.filteredBy) cho các bài KHÔNG phải của người xem */
    public void apply(List<Post> posts, int viewerId) {
        if (isEmpty()) return;
        for (Post p : posts) {
            if (p.getUserId() == viewerId) continue;
            String hit = match(p.getContent());
            if (hit == null && p.getSharedPost() != null) hit = match(p.getSharedPost().getContent());
            if (hit != null) p.setFilteredBy("từ khóa “" + hit + "”");
            else if (hideNegative && (p.isNegative() || (p.getSharedPost() != null && p.getSharedPost().isNegative()))) {
                p.setFilteredBy("nội dung tiêu cực");
            }
        }
    }

    /** Danh sách từ khóa dạng JSON — trình duyệt dùng để thu gọn bình luận */
    public String termsJson() {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < terms.size(); i++) sb.append(i > 0 ? "," : "").append(JsonUtil.str(terms.get(i)));
        return sb.append(']').toString();
    }
}
