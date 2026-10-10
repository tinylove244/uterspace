package com.uterspace.dao;

import com.uterspace.model.Group;
import com.uterspace.model.Post;
import com.uterspace.model.User;
import com.uterspace.util.HashtagUtil;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.text.Normalizer;
import java.util.*;

/**
 * SearchDAO — tìm kiếm toàn trang: người dùng, bài viết, nhóm, hashtag (trang /search và gợi ý ở thanh tìm kiếm).
 *
 * Tìm KHÔNG PHÂN BIỆT DẤU: gõ "duc" ra "Đức", "minh ha" ra "Minh Hà". Cột NVARCHAR dùng collation có dấu
 * (CI_AS) nên phần lọc theo chữ dùng truy vấn SQL gốc với COLLATE Latin1_General_100_CI_AI — collation này
 * coi "đ" = "d" (Vietnamese_CI_AI thì không). Đây là chỗ DUY NHẤT phụ thuộc SQL Server:
 * khi đổi sang PostgreSQL chỉ cần thay biểu thức ACCENT_INSENSITIVE bằng unaccent(...) ILIKE (plan 8.2).
 *
 * Quyền xem bài KHÔNG viết lại ở đây: SQL gốc chỉ lấy id ứng viên, sau đó lọc bằng JPQL với
 * PostDAOImpl.VISIBLE — vẫn một quy tắc duy nhất cho "ai được thấy bài nào" (plan 2.2).
 * Lớp chỉ đọc, không tách interface (giống AdminLogDAO).
 */
public class SearchDAO {

    private static final String AI = " COLLATE Latin1_General_100_CI_AI ";

    /** Số bài ứng viên tối đa lấy từ bước lọc chữ, trước khi lọc quyền xem */
    private static final int POST_CANDIDATES = 300;

    /** Chuỗi người dùng gõ → mẫu LIKE "%...%", thoát ký tự đặc biệt % _ [ bằng '!' */
    static String likePattern(String q) {
        return "%" + q.replace("!", "!!").replace("%", "!%").replace("_", "!_").replace("[", "![") + "%";
    }

    /** Bỏ dấu tiếng Việt + chữ thường — dùng để so khớp hashtag trong Java */
    public static String fold(String s) {
        if (s == null) return "";
        String n = Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
        return n.replace('đ', 'd').replace('Đ', 'D').toLowerCase(Locale.ROOT);
    }

    // ---------------------------------------------------------------- Người dùng

    /** Người dùng có họ tên (cả 2 thứ tự) hoặc email khớp; bỏ tài khoản đang bị khóa. Khớp đầu tên xếp trước. */
    public List<User> searchUsers(String q, int limit, int viewerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            String full = "(first_name + N' ' + last_name)";
            @SuppressWarnings("unchecked")
            List<Number> ids = em.createNativeQuery(
                    "SELECT user_id FROM users WHERE status = 'ACTIVE' " +
                    // bỏ người có quan hệ CHẶN với người tìm (bất kể chiều)
                    "AND user_id NOT IN (SELECT blocked_id FROM user_blocks WHERE blocker_id = :me) " +
                    "AND user_id NOT IN (SELECT blocker_id FROM user_blocks WHERE blocked_id = :me) AND (" +
                    full + AI + "LIKE :p ESCAPE '!' OR (last_name + N' ' + first_name)" + AI + "LIKE :p ESCAPE '!'" +
                    " OR email" + AI + "LIKE :p ESCAPE '!') " +
                    "ORDER BY CASE WHEN " + full + AI + "LIKE :prefix ESCAPE '!' THEN 0 ELSE 1 END, first_name, last_name")
                .setParameter("p", likePattern(q))
                .setParameter("prefix", likePattern(q).substring(1))
                .setParameter("me", viewerId)
                .setMaxResults(limit)
                .getResultList();
            return loadInOrder(em, User.class, "userId", ids);
        } finally {
            em.close();
        }
    }

    // ---------------------------------------------------------------- Bài viết

    /** Bài viết người xem ĐƯỢC PHÉP thấy có nội dung khớp từ khóa, mới nhất trước */
    public List<Post> searchPosts(String q, int viewerId, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // B1: lọc chữ (không dấu) bằng SQL gốc → id ứng viên, đã bỏ sẵn bài bị ẩn / xóa mềm
            @SuppressWarnings("unchecked")
            List<Number> raw = em.createNativeQuery(
                    "SELECT post_id FROM posts WHERE content" + AI + "LIKE :p ESCAPE '!' " +
                    "AND moderation_status = 'ACTIVE' AND is_hidden_by_owner = 0 " +
                    "ORDER BY created_at DESC, post_id DESC")
                .setParameter("p", likePattern(q))
                .setMaxResults(POST_CANDIDATES)
                .getResultList();
            if (raw.isEmpty()) return new ArrayList<>();
            List<Integer> ids = new ArrayList<>();
            for (Number n : raw) ids.add(n.intValue());

            // B2: lọc quyền xem bằng quy tắc VISIBLE dùng chung
            return em.createQuery("SELECT p FROM Post p JOIN FETCH p.author WHERE p.postId IN :ids AND " +
                                  PostDAOImpl.VISIBLE + "ORDER BY p.createdAt DESC, p.postId DESC", Post.class)
                     .setParameter("ids", ids).setParameter("me", viewerId)
                     .setMaxResults(limit)
                     .getResultList();
        } finally {
            em.close();
        }
    }

    // ---------------------------------------------------------------- Nhóm

    /** Nhóm có tên hoặc mô tả khớp (nhóm kín vẫn hiện tên — chỉ bài trong nhóm mới bị giới hạn). Khớp tên xếp trước. */
    public List<Group> searchGroups(String q, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            @SuppressWarnings("unchecked")
            List<Number> ids = em.createNativeQuery(
                    "SELECT group_id FROM groups_tbl WHERE name" + AI + "LIKE :p ESCAPE '!' " +
                    "OR description" + AI + "LIKE :p ESCAPE '!' " +
                    "ORDER BY CASE WHEN name" + AI + "LIKE :p ESCAPE '!' THEN 0 ELSE 1 END, member_count DESC")
                .setParameter("p", likePattern(q))
                .setMaxResults(limit)
                .getResultList();
            return loadInOrder(em, Group.class, "groupId", ids);
        } finally {
            em.close();
        }
    }

    // ---------------------------------------------------------------- Hashtag

    /**
     * Hashtag (trong các bài gần đây người xem được thấy) có tên chứa từ khóa, kèm số bài.
     * Từ khóa có thể gõ kèm '#'. Thẻ bắt đầu bằng từ khóa xếp trước, sau đó theo số bài.
     */
    public List<Map.Entry<String, Integer>> searchHashtags(String q, List<String> recentContents, int limit) {
        String needle = fold(q.replaceAll("^#+", "").trim());
        List<Map.Entry<String, Integer>> all = HashtagUtil.topHashtags(recentContents, Integer.MAX_VALUE);
        List<Map.Entry<String, Integer>> hits = new ArrayList<>();
        for (Map.Entry<String, Integer> e : all) {
            if (!needle.isEmpty() && fold(e.getKey()).contains(needle)) hits.add(e);
        }
        hits.sort((a, b) -> {
            boolean pa = fold(a.getKey()).startsWith(needle), pb = fold(b.getKey()).startsWith(needle);
            if (pa != pb) return pa ? -1 : 1;
            return Integer.compare(b.getValue(), a.getValue());
        });
        return hits.size() > limit ? hits.subList(0, limit) : hits;
    }

    // ---------------------------------------------------------------- Tiện ích

    /** Nạp entity theo danh sách id và GIỮ thứ tự của danh sách (thứ tự xếp hạng từ SQL gốc) */
    private static <T> List<T> loadInOrder(EntityManager em, Class<T> type, String idField, List<Number> rawIds) {
        if (rawIds.isEmpty()) return new ArrayList<>();
        List<Integer> ids = new ArrayList<>();
        for (Number n : rawIds) ids.add(n.intValue());
        List<T> rows = em.createQuery("SELECT e FROM " + type.getSimpleName() + " e WHERE e." + idField + " IN :ids", type)
                         .setParameter("ids", ids).getResultList();
        Map<Integer, T> byId = new HashMap<>();
        for (T row : rows) {
            Object id = em.getEntityManagerFactory().getPersistenceUnitUtil().getIdentifier(row);
            byId.put((Integer) id, row);
        }
        List<T> ordered = new ArrayList<>();
        for (Integer id : ids) if (byId.containsKey(id)) ordered.add(byId.get(id));
        return ordered;
    }
}
