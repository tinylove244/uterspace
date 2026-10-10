package com.uterspace.util;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * HashtagUtil — tách và so khớp #hashtag trong nội dung bài viết.
 *
 * Không có bảng hashtag riêng: thẻ được parse bằng regex từ posts.content.
 * Một thẻ gồm chữ (kể cả tiếng Việt có dấu), số và dấu gạch dưới; ký tự '#'
 * phải đứng đầu chuỗi hoặc sau khoảng trắng/dấu câu (tránh bắt nhầm "abc#1" hay
 * "http://x.com/#muc"). Regex này khớp với linkifyHashtags() trong footer.jsp.
 */
public final class HashtagUtil {

    private static final String TAG_CHARS = "[\\p{L}\\p{M}\\p{N}_]";

    private static final Pattern HASHTAG =
        Pattern.compile("(?<![\\p{L}\\p{M}\\p{N}_&/])#(" + TAG_CHARS + "+)");

    private static final Pattern VALID_TAG = Pattern.compile(TAG_CHARS + "{1,100}");

    private HashtagUtil() { }

    /**
     * Chuẩn hoá tham số ?tag= từ URL: bỏ '#' ở đầu, cắt khoảng trắng.
     * @return tên thẻ không có '#', hoặc null nếu không hợp lệ
     */
    public static String normalize(String raw) {
        if (raw == null) return null;
        String tag = raw.trim();
        while (tag.startsWith("#")) tag = tag.substring(1);
        return VALID_TAG.matcher(tag).matches() ? tag : null;
    }

    /** Danh sách thẻ (không có '#') xuất hiện trong nội dung, theo thứ tự xuất hiện */
    public static List<String> extract(String content) {
        List<String> tags = new ArrayList<>();
        if (content == null) return tags;
        Matcher m = HASHTAG.matcher(content);
        while (m.find()) tags.add(m.group(1));
        return tags;
    }

    /**
     * Nội dung có chứa ĐÚNG thẻ này không (không phân biệt hoa thường).
     * Dùng để lọc lại kết quả LIKE '%#tag%', vì LIKE '%#IoT%' cũng khớp "#IoTProject".
     */
    public static boolean containsTag(String content, String tag) {
        for (String t : extract(content)) {
            if (t.equalsIgnoreCase(tag)) return true;
        }
        return false;
    }

    /**
     * Thẻ xuất hiện trong nhiều bài viết nhất.
     * Mỗi bài chỉ tính 1 lần cho mỗi thẻ; gộp hoa/thường, giữ cách viết gặp đầu tiên.
     * @return danh sách [tên thẻ không có '#', số bài viết], giảm dần theo số bài
     */
    public static List<Map.Entry<String, Integer>> topHashtags(List<String> contents, int limit) {
        Map<String, String>  display = new HashMap<>();
        Map<String, Integer> counts  = new HashMap<>();
        for (String content : contents) {
            Set<String> seenInPost = new HashSet<>();
            for (String tag : extract(content)) {
                String key = tag.toLowerCase(Locale.ROOT);
                if (!seenInPost.add(key)) continue;
                display.putIfAbsent(key, tag);
                counts.merge(key, 1, Integer::sum);
            }
        }

        List<Map.Entry<String, Integer>> result = new ArrayList<>();
        counts.entrySet().stream()
              .sorted(Map.Entry.<String, Integer>comparingByValue().reversed()
                      .thenComparing(Map.Entry.comparingByKey()))
              .limit(limit)
              .forEach(e -> result.add(new AbstractMap.SimpleEntry<>(display.get(e.getKey()), e.getValue())));
        return result;
    }
}
