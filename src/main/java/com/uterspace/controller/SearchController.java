package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.Group;
import com.uterspace.model.Post;
import com.uterspace.model.User;
import com.uterspace.util.HashtagUtil;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.LayoutSupport;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.net.URLEncoder;
import java.util.*;

/**
 * SearchController — thanh tìm kiếm toàn trang.
 *
 * GET /search?q=&tab=all|people|posts|groups|tags  → trang kết quả chia tab (search/search.jsp)
 *     q bắt đầu bằng '#' và là một thẻ hợp lệ → chuyển sang /hashtag?tag= (giữ hành vi cũ)
 * GET /api/search/suggest?q=                        → JSON gợi ý khi đang gõ (dropdown ở thanh tìm kiếm)
 *
 * Tìm không phân biệt dấu, kết quả bài viết đã lọc theo quyền xem (xem SearchDAO).
 */
@WebServlet(urlPatterns = {"/search", "/api/search/suggest"})
public class SearchController extends HttpServlet {

    static final int MAX_QUERY = 100;
    private static final int LIMIT_PEOPLE = 30, LIMIT_POSTS = 30, LIMIT_GROUPS = 20, LIMIT_TAGS = 40;
    private static final List<String> TABS = Arrays.asList("all", "people", "posts", "groups", "tags");

    private final SearchDAO     searchDAO  = new SearchDAO();
    private final PostDAO       postDAO    = new PostDAOImpl();
    private final CommentDAO    commentDAO = new CommentDAOImpl();
    private final LikeDAO       likeDAO    = new LikeDAOImpl();
    private final SavedPostDAO  savedDAO   = new SavedPostDAOImpl();
    private final GroupDAO      groupDAO   = new GroupDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        String q = clean(req.getParameter("q"));

        if ("/api/search/suggest".equals(req.getServletPath())) {
            suggest(resp, me, q);
            return;
        }

        // "#tag" → trang hashtag (lọc đúng thẻ, giống trước đây)
        if (q.startsWith("#") && HashtagUtil.normalize(q) != null && !"tags".equals(req.getParameter("tab"))) {
            resp.sendRedirect(req.getContextPath() + "/hashtag?tag=" + URLEncoder.encode(HashtagUtil.normalize(q), "UTF-8"));
            return;
        }

        String tab = TABS.contains(req.getParameter("tab")) ? req.getParameter("tab") : "all";
        int uid = me.getUserId();
        // Thói quen tìm kiếm → gợi ý nhóm / hashtag / video và xếp hạng bảng tin (RecommendationService)
        if (!q.isEmpty() && req.getParameter("page") == null) com.uterspace.service.RecommendationService.recordSearch(uid, q);
        List<String> recent = postDAO.getRecentContentsVisibleTo(uid, 500);

        if (!q.isEmpty()) {
            List<User> people = searchDAO.searchUsers(q, LIMIT_PEOPLE, uid);
            List<Integer> peopleIds = new ArrayList<>();
            for (User u : people) peopleIds.add(u.getUserId());

            List<Group> groups = searchDAO.searchGroups(q, LIMIT_GROUPS);
            for (Group g : groups) g.setMyMembership(groupDAO.getMembership(g.getGroupId(), uid));

            List<Post> posts = searchDAO.searchPosts(q, uid, LIMIT_POSTS);
            for (Post p : posts) {
                p.setComments(commentDAO.getCommentsByPostId(p.getPostId()));
                p.setLikedByCurrentUser(likeDAO.isLikedBy(p.getPostId(), uid));
            }
            postDAO.attachSharedPosts(posts, uid);
            postDAO.attachGroupNames(posts);
            com.uterspace.util.ContentFilter.of(new com.uterspace.dao.UserSettingsDAO().get(uid)).apply(posts, uid);

            Set<Integer> savedIds = new HashSet<>();
            for (Post sp : savedDAO.getSavedPosts(uid)) savedIds.add(sp.getPostId());

            req.setAttribute("people",       people);
            // Khóa kiểu String: EL so khớp map theo Long nên Map<Integer,...> sẽ không tra được trong JSP
            Map<String, String> friendStatus = new HashMap<>();
            com.uterspace.service.RelationService.statusOf(uid, peopleIds).forEach((k, v) -> friendStatus.put(String.valueOf(k), v.name()));
            req.setAttribute("friendStatus", friendStatus);
            req.setAttribute("groups",       groups);
            req.setAttribute("posts",        posts);
            req.setAttribute("tags",         searchDAO.searchHashtags(q, recent, LIMIT_TAGS));
            req.setAttribute("savedPostIds", savedIds);
            req.setAttribute("limitPeople",  LIMIT_PEOPLE);
            req.setAttribute("limitPosts",   LIMIT_POSTS);
            req.setAttribute("limitGroups",  LIMIT_GROUPS);
        }
        // Chưa gõ gì: gợi ý hashtag thịnh hành để bấm thử
        req.setAttribute("trending", HashtagUtil.topHashtags(recent, 10));

        LayoutSupport.populate(req, me);
        req.setAttribute("q",         q);
        req.setAttribute("tab",       tab);
        req.setAttribute("pageTitle", q.isEmpty() ? "Tìm kiếm" : "Tìm kiếm: " + q);
        req.getRequestDispatcher("/WEB-INF/views/search/search.jsp").forward(req, resp);
    }

    /** Gợi ý nhanh: tối đa 5 người, 3 nhóm, 4 hashtag */
    private void suggest(HttpServletResponse resp, User me, String q) throws IOException {
        StringBuilder sb = new StringBuilder("{\"q\":").append(JsonUtil.str(q));
        if (q.isEmpty()) { JsonUtil.write(resp, sb.append(",\"users\":[],\"groups\":[],\"tags\":[]}").toString()); return; }

        sb.append(",\"users\":[");
        String sep = "";
        for (User u : searchDAO.searchUsers(q, 5, me.getUserId())) {
            sb.append(sep).append("{\"id\":").append(u.getUserId())
              .append(",\"name\":").append(JsonUtil.str(u.getFullName()))
              .append(",\"initials\":").append(JsonUtil.str(u.getInitials()))
              .append(",\"avatar\":").append(JsonUtil.str(u.getAvatar() == null ? null : u.getAvatarUrl()))
              .append(",\"sub\":").append(JsonUtil.str(u.getLocation() != null && !u.getLocation().isEmpty() ? u.getLocation() : u.getEmail()))
              .append('}');
            sep = ",";
        }
        sb.append("],\"groups\":[");
        sep = "";
        for (Group g : searchDAO.searchGroups(q, 3)) {
            sb.append(sep).append("{\"id\":").append(g.getGroupId())
              .append(",\"name\":").append(JsonUtil.str(g.getName()))
              .append(",\"icon\":").append(JsonUtil.str(g.getIconDisplay()))
              .append(",\"sub\":").append(JsonUtil.str(g.getPrivacyLabel() + " · " + g.getMemberCount() + " thành viên"))
              .append('}');
            sep = ",";
        }
        sb.append("],\"tags\":[");
        sep = "";
        for (Map.Entry<String, Integer> t : searchDAO.searchHashtags(q, postDAO.getRecentContentsVisibleTo(me.getUserId(), 500), 4)) {
            sb.append(sep).append("{\"tag\":").append(JsonUtil.str(t.getKey()))
              .append(",\"count\":").append(t.getValue()).append('}');
            sep = ",";
        }
        JsonUtil.write(resp, sb.append("]}").toString());
    }

    /** Cắt khoảng trắng thừa, giới hạn độ dài từ khóa */
    private static String clean(String raw) {
        if (raw == null) return "";
        String q = raw.trim().replaceAll("\\s+", " ");
        return q.length() > MAX_QUERY ? q.substring(0, MAX_QUERY) : q;
    }
}
