package com.uterspace.service;

import com.uterspace.ai.SentimentAnalyzer;
import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.util.HashtagUtil;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * RecommendationService — Gợi ý & cá nhân hóa (Recommendation & Personalization).
 *
 * 1) Hồ sơ sở thích (InterestProfile) dựng từ LỊCH SỬ TƯƠNG TÁC của người xem:
 *      - độ thân thiết với từng tác giả: thích bài (×1), bình luận (×2), nhắn tin 1-1 trong 30 ngày (×0.3/tin, tối đa 6)
 *      - chủ đề quan tâm (hashtag): bài đã thích (×1), đã bình luận (×2), tự đăng (×1.5)
 *      - thói quen tìm kiếm: 30 từ khóa gần nhất (search_history)
 * 2) Bảng tin thông minh (Smart Feed) — điểm mỗi bài:
 *      3.0·độ mới (giảm dần theo e^(-giờ/36)) + 1.2·ln(1+thân thiết) + 0.8·ln(1+tương tác của bài)
 *      + 1.0·khớp chủ đề + 0.6·đang thịnh hành + 0.3 nếu là bài trong nhóm của mình;
 *      bài của mình vừa đăng (< 2 giờ) được đẩy lên; mỗi bài tiếp theo của CÙNG tác giả bị nhân 0.85 (đa dạng nguồn).
 *      Mỗi bài kèm lý do ngắn ("Vì bạn hay tương tác với An") để người dùng hiểu vì sao thấy bài.
 * 3) Gợi ý kết bạn thông minh: bạn chung (×3) + nhóm chung (×2) + cùng sở thích (hashtag trùng, ×1.5) + cùng khu vực (×1),
 *    trên tập ứng viên đã lọc quyền riêng tư / chặn của FriendshipDAO; thêm tìm bạn từ DANH BẠ (email).
 * 4) Gợi ý nhóm / hashtag / video theo sở thích + thói quen tìm kiếm + bạn bè.
 * Mọi tính toán chạy trên máy chủ, vài truy vấn gộp mỗi trang — không gọi API ngoài.
 */
public final class RecommendationService {

    private static final FriendshipDAO FRIENDS = new FriendshipDAOImpl();
    private static final PostDAO       POSTS   = new PostDAOImpl();

    private RecommendationService() { }

    // ============================================================ Hồ sơ sở thích

    public static final class InterestProfile {
        final Map<Integer, Double> affinity = new HashMap<>();     // tác giả → điểm thân thiết
        final Map<String, Double>  tags = new HashMap<>();         // hashtag (chữ thường) → trọng số
        final Set<String>          ownTags = new HashSet<>();      // hashtag chính mình đã đăng
        final List<String>         searches = new ArrayList<>();   // từ khóa tìm kiếm (đã bỏ dấu, chữ thường)
        final Set<Integer>         friendIds = new HashSet<>();
        final Map<Integer, String> names = new HashMap<>();        // tác giả → tên (để viết lý do)

        /** Hashtag quan tâm nhiều nhất (để hiển thị "Sở thích của bạn") */
        public List<String> topTags(int n) {
            return tags.entrySet().stream().sorted((a, b) -> Double.compare(b.getValue(), a.getValue()))
                       .limit(n).map(Map.Entry::getKey).collect(Collectors.toList());
        }
        public boolean isEmpty() { return affinity.isEmpty() && tags.isEmpty() && searches.isEmpty(); }
    }

    public static InterestProfile profile(int me) {
        InterestProfile p = new InterestProfile();
        p.friendIds.addAll(FRIENDS.getFriendIds(me));
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // Bài đã thích
            for (Object[] r : rows(em, "SELECT TOP 400 p.user_id, p.content, u.first_name FROM likes l JOIN posts p ON p.post_id = l.post_id " +
                                       "JOIN users u ON u.user_id = p.user_id WHERE l.user_id = :me AND p.user_id <> :me ORDER BY l.created_at DESC", me)) {
                bump(p, r, 1.0);
            }
            // Bài đã bình luận
            for (Object[] r : rows(em, "SELECT TOP 300 p.user_id, p.content, u.first_name FROM comments c JOIN posts p ON p.post_id = c.post_id " +
                                       "JOIN users u ON u.user_id = p.user_id WHERE c.user_id = :me AND p.user_id <> :me ORDER BY c.created_at DESC", me)) {
                bump(p, r, 2.0);
            }
            // Bài tự đăng → chủ đề của chính mình
            for (Object[] r : rows(em, "SELECT TOP 100 user_id, content FROM posts WHERE user_id = :me AND moderation_status <> 'DELETED' ORDER BY created_at DESC", me)) {
                for (String t : HashtagUtil.extract((String) r[1])) {
                    String k = t.toLowerCase(Locale.ROOT);
                    p.tags.merge(k, 1.5, Double::sum);
                    p.ownTags.add(k);
                }
            }
            // Nhắn tin 1-1 trong 30 ngày
            @SuppressWarnings("unchecked")
            List<Object[]> msgs = em.createNativeQuery(
                    // SQL Server không GROUP BY được biểu thức chứa tham số → gom trong truy vấn con
                    "SELECT other, COUNT(*) FROM (SELECT CASE WHEN c.user_a_id = :me THEN c.user_b_id ELSE c.user_a_id END AS other " +
                    "FROM chat_messages m JOIN conversations c ON c.conversation_id = m.conversation_id " +
                    "WHERE c.is_group = 0 AND m.sender_id = :me AND m.sent_at > :since) x GROUP BY other")
                .setParameter("me", me).setParameter("since", Timestamp.valueOf(LocalDateTime.now().minusDays(30)))
                .getResultList();
            for (Object[] r : msgs) {
                p.affinity.merge(((Number) r[0]).intValue(), Math.min(6.0, ((Number) r[1]).doubleValue() * 0.3), Double::sum);
            }
            // Từ khóa đã tìm (search_history, migration 090)
            try {
                for (Object[] r : rows(em, "SELECT TOP 30 query, 0 FROM search_history WHERE user_id = :me ORDER BY created_at DESC", me)) {
                    String q = SentimentAnalyzer.fold(String.valueOf(r[0])).replace("#", "").trim();
                    if (q.length() >= 2 && !p.searches.contains(q)) p.searches.add(q);
                    String tag = HashtagUtil.normalize(String.valueOf(r[0]));
                    if (String.valueOf(r[0]).trim().startsWith("#") && tag != null) p.tags.merge(tag.toLowerCase(Locale.ROOT), 1.0, Double::sum);
                }
            } catch (RuntimeException ignored) { /* chưa chạy migration 090 */ }
        } finally {
            em.close();
        }
        return p;
    }

    private static void bump(InterestProfile p, Object[] r, double w) {
        int author = ((Number) r[0]).intValue();
        p.affinity.merge(author, w, Double::sum);
        if (r.length > 2 && r[2] != null) p.names.putIfAbsent(author, (String) r[2]);
        for (String t : HashtagUtil.extract((String) r[1])) p.tags.merge(t.toLowerCase(Locale.ROOT), w, Double::sum);
    }

    @SuppressWarnings("unchecked")
    private static List<Object[]> rows(EntityManager em, String sql, int me) {
        return em.createNativeQuery(sql).setParameter("me", me).getResultList();
    }

    // ============================================================ Smart Feed

    /**
     * Sắp xếp bảng tin theo mức độ quan tâm (thay vì chỉ theo thời gian) và gắn lý do hiển thị.
     * @param trending hashtag (chữ thường) → số bài gần đây
     */
    public static void rankFeed(List<Post> posts, int me, InterestProfile prof, Map<String, Integer> trending) {
        if (posts.size() < 2) return;
        LocalDateTime now = LocalDateTime.now();
        int maxTrend = trending.values().stream().max(Integer::compare).orElse(1);
        Map<Post, Double> score = new HashMap<>();
        for (Post p : posts) {
            int author = p.getUserId();
            double hours = p.getCreatedAt() == null ? 999 : Math.max(0, Duration.between(p.getCreatedAt(), now).toMinutes() / 60.0);
            double recency = Math.exp(-hours / 36.0);
            double aff = prof.affinity.getOrDefault(author, 0.0) + (prof.friendIds.contains(author) ? 1.0 : 0.0);
            double engage = p.getLikeCount() + 2.0 * p.getCommentCount() + 3.0 * p.getShareCount();

            double interest = 0, trend = 0;
            String bestTag = null;
            double bestTagW = 0;
            for (String t : HashtagUtil.extract(p.getContent())) {
                String k = t.toLowerCase(Locale.ROOT);
                double w = prof.tags.getOrDefault(k, 0.0);
                interest += w;
                if (w > bestTagW) { bestTagW = w; bestTag = t; }
                Integer tc = trending.get(k);
                if (tc != null) trend = Math.max(trend, tc / (double) maxTrend);
            }
            interest = Math.min(3.0, Math.log1p(interest));
            String folded = p.getContent() == null ? "" : SentimentAnalyzer.fold(p.getContent());
            String searchHit = null;
            for (String q : prof.searches) {
                if (q.length() >= 3 && folded.contains(q)) { interest += 0.6; searchHit = q; break; }
            }

            double s = 3.0 * recency + 1.2 * Math.log1p(aff) + 0.8 * Math.log1p(engage) + 1.0 * interest + 0.6 * trend
                     + (p.getGroupId() != null ? 0.3 : 0);
            if (author == me && hours < 2) s += 4;   // vừa đăng → luôn thấy bài của mình ở đầu
            score.put(p, s);

            // Lý do (thành phần nổi bật nhất)
            String reason;
            if (author == me) reason = null;
            else if (aff >= 3 && prof.names.containsKey(author)) reason = "Vì bạn hay tương tác với " + prof.names.get(author);
            else if (bestTag != null && bestTagW >= 1) reason = "Chủ đề bạn quan tâm: #" + bestTag;
            else if (searchHit != null) reason = "Liên quan tới tìm kiếm \"" + searchHit + "\"";
            else if (trend >= 0.5) reason = "Đang thịnh hành";
            else if (engage >= 8) reason = "Được nhiều người tương tác";
            else if (hours < 6) reason = "Bài mới";
            else reason = null;
            p.setFeedReason(reason);
        }
        posts.sort((a, b) -> Double.compare(score.get(b), score.get(a)));

        // Đa dạng nguồn: bài thứ k của cùng tác giả ×0.85^k rồi xếp lại
        Map<Integer, Integer> seen = new HashMap<>();
        Map<Post, Double> adjusted = new HashMap<>();
        for (Post p : posts) {
            int k = seen.merge(p.getUserId(), 1, Integer::sum) - 1;
            adjusted.put(p, score.get(p) * Math.pow(0.85, k));
        }
        posts.sort((a, b) -> Double.compare(adjusted.get(b), adjusted.get(a)));
    }

    // ============================================================ Gợi ý kết bạn

    /** Gợi ý kết bạn thông minh — dùng chung cho Bảng tin và trang Bạn bè */
    public static List<FriendSuggestion> friendSuggestions(int me, int limit) {
        List<FriendSuggestion> base = FRIENDS.getSuggestions(me, 200);   // đã lọc chặn / quyền riêng tư, có bạn chung + khu vực
        if (base.isEmpty()) return base;
        List<Integer> ids = base.stream().map(s -> s.getUser().getUserId()).collect(Collectors.toList());
        InterestProfile prof = profile(me);

        Map<Integer, Integer> sharedGroups = new HashMap<>();
        Map<Integer, String>  sharedGroupName = new HashMap<>();
        Map<Integer, String>  commonTag = new HashMap<>();
        Map<Integer, Double>  tagSim = new HashMap<>();
        EntityManager em = JPAUtil.getEntityManager();
        try {
            @SuppressWarnings("unchecked")
            List<Object[]> g = em.createNativeQuery(
                    "SELECT gm2.user_id, g.name FROM group_members gm1 " +
                    "JOIN group_members gm2 ON gm2.group_id = gm1.group_id AND gm2.status = 'ACTIVE' " +
                    "JOIN groups_tbl g ON g.group_id = gm1.group_id " +
                    "WHERE gm1.user_id = :me AND gm1.status = 'ACTIVE' AND gm2.user_id IN (:ids)")
                .setParameter("me", me).setParameter("ids", ids).getResultList();
            for (Object[] r : g) {
                int uid = ((Number) r[0]).intValue();
                sharedGroups.merge(uid, 1, Integer::sum);
                sharedGroupName.putIfAbsent(uid, (String) r[1]);
            }
            // Sở thích của ứng viên: hashtag trong bài công khai / bạn bè gần đây của họ
            if (!prof.tags.isEmpty()) {
                @SuppressWarnings("unchecked")
                List<Object[]> posts = em.createNativeQuery(
                        "SELECT user_id, content FROM posts WHERE user_id IN (:ids) AND moderation_status = 'ACTIVE' " +
                        "AND is_hidden_by_owner = 0 AND group_id IS NULL AND created_at > :since")
                    .setParameter("ids", ids).setParameter("since", Timestamp.valueOf(LocalDateTime.now().minusDays(180)))
                    .getResultList();
                for (Object[] r : posts) {
                    int uid = ((Number) r[0]).intValue();
                    for (String t : HashtagUtil.extract((String) r[1])) {
                        Double w = prof.tags.get(t.toLowerCase(Locale.ROOT));
                        if (w == null) continue;
                        tagSim.merge(uid, w, Double::sum);
                        commonTag.putIfAbsent(uid, t);
                    }
                }
            }
        } finally {
            em.close();
        }

        List<Object[]> scored = new ArrayList<>();
        for (FriendSuggestion s : base) {
            int uid = s.getUser().getUserId();
            int m = s.getMutualCount(), sg = sharedGroups.getOrDefault(uid, 0);
            double sim = Math.min(3.0, Math.log1p(tagSim.getOrDefault(uid, 0.0)));
            boolean sameArea = "Cùng khu vực".equals(s.getReason());
            double score = 3.0 * m + 2.0 * sg + 1.5 * sim + (sameArea ? 1.0 : 0) + 0.2 * Math.min(1, prof.affinity.getOrDefault(uid, 0.0));
            String reason;
            if (m > 0 && sg > 0) reason = m + " bạn chung · cùng nhóm " + sharedGroupName.get(uid);
            else if (m > 0)      reason = m + " bạn chung";
            else if (sg > 0)     reason = "Cùng nhóm " + sharedGroupName.get(uid);
            else if (sim > 0)    reason = "Cùng quan tâm #" + commonTag.get(uid);
            else if (sameArea)   reason = "Cùng khu vực";
            else                 reason = "Thành viên UTErSpace";
            scored.add(new Object[]{ new FriendSuggestion(s.getUser(), m, reason), score });
        }
        scored.sort((a, b) -> Double.compare((Double) b[1], (Double) a[1]));   // sort ổn định: hòa điểm giữ thứ tự cũ
        List<FriendSuggestion> out = new ArrayList<>();
        for (Object[] o : scored) { if (out.size() >= limit) break; out.add((FriendSuggestion) o[0]); }
        return out;
    }

    /**
     * Tìm bạn từ DANH BẠ: danh sách email người dùng tự nhập / chọn (Contact Picker) → tài khoản đã đăng ký.
     * Email chỉ dùng để đối chiếu trong request này, KHÔNG lưu lại.
     */
    public static List<User> matchContacts(int me, Collection<String> emails) {
        Set<String> clean = new LinkedHashSet<>();
        for (String e : emails) {
            String x = e == null ? "" : e.trim().toLowerCase(Locale.ROOT);
            if (x.matches("[^@\\s]+@[^@\\s]+\\.[^@\\s]+") && x.length() <= 254) clean.add(x);
            if (clean.size() >= 500) break;
        }
        if (clean.isEmpty()) return new ArrayList<>();
        Set<Integer> blocked = new BlockDAO().blockedEitherWay(me);
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT u FROM User u WHERE LOWER(u.email) IN :emails AND u.userId <> :me AND u.status = 'ACTIVE'", User.class)
                     .setParameter("emails", clean).setParameter("me", me).getResultList()
                     .stream().filter(u -> !blocked.contains(u.getUserId())).collect(Collectors.toList());
        } finally {
            em.close();
        }
    }

    // ============================================================ Gợi ý nhóm / hashtag / video

    /** Một gợi ý nội dung: đối tượng + lý do hiển thị */
    public static final class Suggestion<T> {
        private final T item;
        private final String reason;
        Suggestion(T item, String reason) { this.item = item; this.reason = reason; }
        public T getItem() { return item; }
        public String getReason() { return reason; }
    }

    public static List<Suggestion<Group>> suggestGroups(int me, InterestProfile prof, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Group> candidates = em.createQuery(
                    "SELECT g FROM Group g WHERE g.groupId NOT IN " +
                    "(SELECT gm.group.groupId FROM GroupMember gm WHERE gm.user.userId = :me)", Group.class)
                .setParameter("me", me).setMaxResults(200).getResultList();
            if (candidates.isEmpty()) return new ArrayList<>();
            List<Integer> gids = candidates.stream().map(Group::getGroupId).collect(Collectors.toList());

            Map<Integer, Integer> friendsIn = new HashMap<>();
            if (!prof.friendIds.isEmpty()) {
                @SuppressWarnings("unchecked")
                List<Object[]> r = em.createNativeQuery(
                        "SELECT group_id, COUNT(*) FROM group_members WHERE status = 'ACTIVE' AND group_id IN (:g) AND user_id IN (:f) GROUP BY group_id")
                    .setParameter("g", gids).setParameter("f", new ArrayList<>(prof.friendIds)).getResultList();
                for (Object[] x : r) friendsIn.put(((Number) x[0]).intValue(), ((Number) x[1]).intValue());
            }
            // Chủ đề của nhóm công khai = hashtag trong bài của nhóm (nhóm kín không lộ nội dung để gợi ý)
            Map<Integer, Set<String>> groupTags = new HashMap<>();
            List<Integer> publicIds = candidates.stream().filter(g -> !g.isPrivateGroup()).map(Group::getGroupId).collect(Collectors.toList());
            if (!publicIds.isEmpty()) {
                @SuppressWarnings("unchecked")
                List<Object[]> r = em.createNativeQuery(
                        "SELECT group_id, content FROM posts WHERE group_id IN (:g) AND moderation_status = 'ACTIVE' AND is_hidden_by_owner = 0")
                    .setParameter("g", publicIds).getResultList();
                for (Object[] x : r) {
                    Set<String> set = groupTags.computeIfAbsent(((Number) x[0]).intValue(), k -> new HashSet<>());
                    for (String t : HashtagUtil.extract((String) x[1])) set.add(t.toLowerCase(Locale.ROOT));
                }
            }

            List<Object[]> scored = new ArrayList<>();
            for (Group g : candidates) {
                String text = SentimentAnalyzer.fold((g.getName() == null ? "" : g.getName()) + " " + (g.getDescription() == null ? "" : g.getDescription()));
                double interest = 0;
                String why = null;
                for (Map.Entry<String, Double> t : prof.tags.entrySet()) {
                    String ft = SentimentAnalyzer.fold(t.getKey());
                    boolean hit = (ft.length() >= 3 && text.contains(ft)) || groupTags.getOrDefault(g.getGroupId(), Collections.emptySet()).contains(t.getKey());
                    if (hit) { interest += t.getValue(); if (why == null) why = "Hợp sở thích #" + t.getKey(); }
                }
                for (String q : prof.searches) {
                    if (q.length() >= 3 && text.contains(q)) { interest += 1.5; if (why == null) why = "Bạn từng tìm \"" + q + "\""; }
                }
                int f = friendsIn.getOrDefault(g.getGroupId(), 0);
                double score = 2.0 * f + 2.0 * Math.log1p(interest) + 0.3 * Math.log1p(g.getMemberCount());
                if (f > 0 && (why == null || f >= 2)) why = f + " bạn bè đã tham gia";
                if (why == null) why = g.getMemberCount() + " thành viên";
                scored.add(new Object[]{ new Suggestion<>(g, why), score });
            }
            scored.sort((a, b) -> Double.compare((Double) b[1], (Double) a[1]));
            List<Suggestion<Group>> out = new ArrayList<>();
            for (Object[] o : scored) {
                if (out.size() >= limit) break;
                @SuppressWarnings("unchecked") Suggestion<Group> s = (Suggestion<Group>) o[0];
                out.add(s);
            }
            return out;
        } finally {
            em.close();
        }
    }

    /** Hashtag nên theo dõi: hay đi cùng chủ đề của bạn, hoặc đang thịnh hành — bỏ những thẻ bạn đã tự dùng */
    public static List<Suggestion<String>> suggestHashtags(int me, InterestProfile prof, List<String> recentContents, int limit) {
        Map<String, Double> score = new HashMap<>();
        Map<String, String> why = new HashMap<>();
        Map<String, String> display = new HashMap<>();
        for (String c : recentContents) {
            List<String> tags = HashtagUtil.extract(c);
            if (tags.isEmpty()) continue;
            String anchor = null;
            for (String t : tags) if (prof.tags.containsKey(t.toLowerCase(Locale.ROOT))) { anchor = t; break; }
            for (String t : tags) {
                String k = t.toLowerCase(Locale.ROOT);
                display.putIfAbsent(k, t);
                score.merge(k, 0.5, Double::sum);                      // thịnh hành
                if (anchor != null && !anchor.equalsIgnoreCase(t)) {   // đi cùng chủ đề quan tâm
                    score.merge(k, 2.0, Double::sum);
                    why.putIfAbsent(k, "Hay đi cùng #" + anchor);
                }
            }
        }
        for (String q : prof.searches) {
            for (String k : score.keySet()) if (q.length() >= 3 && SentimentAnalyzer.fold(k).contains(q.replace(" ", ""))) {
                score.merge(k, 2.0, Double::sum);
                why.putIfAbsent(k, "Bạn từng tìm \"" + q + "\"");
            }
        }
        return score.entrySet().stream()
                .filter(e -> !prof.ownTags.contains(e.getKey()))
                .sorted((a, b) -> Double.compare(b.getValue(), a.getValue()))
                .limit(limit)
                .map(e -> new Suggestion<>(display.get(e.getKey()), why.getOrDefault(e.getKey(), "Đang thịnh hành")))
                .collect(Collectors.toList());
    }

    /** Video nên xem: của người thân thiết / đúng chủ đề / nhiều tương tác, chưa phải của mình */
    public static List<Suggestion<Post>> suggestVideos(int me, InterestProfile prof, int limit) {
        List<Post> videos = POSTS.getVideoPosts(me, false, 1, 60);
        LocalDateTime now = LocalDateTime.now();
        List<Object[]> scored = new ArrayList<>();
        for (Post v : videos) {
            if (v.getUserId() == me) continue;
            double interest = 0;
            String why = null;
            for (String t : HashtagUtil.extract(v.getContent())) {
                double w = prof.tags.getOrDefault(t.toLowerCase(Locale.ROOT), 0.0);
                if (w > 0) { interest += w; if (why == null) why = "Chủ đề #" + t; }
            }
            double aff = prof.affinity.getOrDefault(v.getUserId(), 0.0) + (prof.friendIds.contains(v.getUserId()) ? 1 : 0);
            if (aff >= 2 && why == null) why = "Từ " + v.getAuthor().getFirstName() + " — người bạn hay tương tác";
            double days = v.getCreatedAt() == null ? 30 : Duration.between(v.getCreatedAt(), now).toHours() / 24.0;
            double score = 1.5 * Math.log1p(interest) + 1.2 * Math.log1p(aff)
                         + 0.6 * Math.log1p(v.getLikeCount() + 2.0 * v.getCommentCount()) + Math.exp(-days / 14.0);
            if (why == null) why = v.getLikeCount() > 0 ? v.getLikeCount() + " lượt thích" : "Video mới";
            scored.add(new Object[]{ new Suggestion<>(v, why), score });
        }
        scored.sort((a, b) -> Double.compare((Double) b[1], (Double) a[1]));
        List<Suggestion<Post>> out = new ArrayList<>();
        for (Object[] o : scored) {
            if (out.size() >= limit) break;
            @SuppressWarnings("unchecked") Suggestion<Post> s = (Suggestion<Post>) o[0];
            out.add(s);
        }
        return out;
    }

    // ============================================================ Lịch sử tìm kiếm

    /** Ghi từ khóa tìm kiếm (bỏ qua nếu trùng từ khóa ngay trước đó) */
    public static void recordSearch(int me, String query) {
        if (query == null) return;
        String q = query.trim();
        if (q.length() < 2) return;
        if (q.length() > 200) q = q.substring(0, 200);
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            em.createNativeQuery("INSERT INTO search_history (user_id, query, created_at) SELECT :me, :q, :at " +
                                 "WHERE NOT EXISTS (SELECT 1 FROM (SELECT TOP 1 query FROM search_history WHERE user_id = :me " +
                                 "ORDER BY created_at DESC) last WHERE last.query = :q)")
              .setParameter("me", me).setParameter("q", q).setParameter("at", Timestamp.valueOf(LocalDateTime.now()))
              .executeUpdate();
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();   // chưa có bảng → bỏ qua, không làm hỏng trang tìm kiếm
        } finally {
            em.close();
        }
    }
}
