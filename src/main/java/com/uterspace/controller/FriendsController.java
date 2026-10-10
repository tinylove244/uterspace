package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.realtime.Presence;
import com.uterspace.service.RelationService;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.LayoutSupport;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.*;

/**
 * FriendsController — Bạn bè.
 *
 * GET  /friends?tab=requests|sent|suggestions|friends   trang Bạn bè (4 tab)
 * GET  /friends/status?userId=                          trạng thái quan hệ (JSON) — làm mới nút sau sự kiện realtime
 * POST /friends/request   {userId}   gửi lời mời (/friends/add: tên cũ, giữ tương thích)
 * POST /friends/accept    {userId}   chấp nhận lời mời của userId
 * POST /friends/decline   {userId}   từ chối lời mời của userId
 * POST /friends/cancel    {userId}   thu hồi lời mời đã gửi cho userId
 * POST /friends/unfriend  {userId}   hủy kết bạn
 * POST /friends/block     {userId}   chặn · /friends/unblock bỏ chặn
 *
 * Mọi hành động trả JSON {success, status, message} — status là trạng thái MỚI nhìn từ người gọi
 * (NONE | SENT | RECEIVED | FRIEND | BLOCKED | BLOCKED_BY) để giao diện vẽ lại đúng nút.
 * Logic + thông báo + realtime nằm ở RelationService.
 */
@WebServlet(urlPatterns = {"/friends", "/friends/*"})
public class FriendsController extends HttpServlet {

    private final FriendshipDAO   friendshipDAO = new FriendshipDAOImpl();
    private final UserSettingsDAO settingsDAO   = new UserSettingsDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        String action = action(req);
        if ("status".equals(action)) {
            Integer other = parse(req.getParameter("userId"));
            if (other == null) { JsonUtil.error(resp, 400, "Thiếu userId."); return; }
            writeStatus(resp, me, other, RelationService.statusOf(me.getUserId(), other), null);
            return;
        }
        if (!action.isEmpty()) { resp.sendError(404); return; }
        showPage(req, resp, me);
    }

    private void showPage(HttpServletRequest req, HttpServletResponse resp, User me) throws ServletException, IOException {
        int uid = me.getUserId();

        // Lời mời nhận được
        List<PersonCard> requests = new ArrayList<>();
        for (Friendship f : friendshipDAO.getPendingRequestsFor(uid)) {
            PersonCard p = new PersonCard(f.getRequester());
            p.setStatus("RECEIVED");
            p.setSince(f.getCreatedAt());
            requests.add(p);
        }
        // Lời mời đã gửi
        List<PersonCard> sent = new ArrayList<>();
        for (Friendship f : friendshipDAO.getSentRequests(uid)) {
            PersonCard p = new PersonCard(f.getReceiver());
            p.setStatus("SENT");
            p.setSince(f.getCreatedAt());
            sent.add(p);
        }
        // Gợi ý
        List<PersonCard> suggestions = new ArrayList<>();
        for (FriendSuggestion s : com.uterspace.service.RecommendationService.friendSuggestions(uid, 24)) {
            PersonCard p = new PersonCard(s.getUser());
            p.setMutualCount(s.getMutualCount());
            p.setReason(s.getReason());
            suggestions.add(p);
        }
        // Bạn bè (kèm "bạn bè từ", trạng thái hoạt động)
        List<PersonCard> friends = new ArrayList<>();
        for (Friendship f : friendshipDAO.getFriendships(uid)) {
            User other = f.getRequester().getUserId() == uid ? f.getReceiver() : f.getRequester();
            PersonCard p = new PersonCard(other);
            p.setStatus("FRIEND");
            p.setSince(f.getAcceptedAt() != null ? f.getAcceptedAt() : f.getCreatedAt());
            friends.add(p);
        }

        // Số bạn chung cho lời mời / đã gửi / bạn bè; trạng thái hoạt động cho mọi thẻ
        List<PersonCard> all = new ArrayList<>(requests);
        all.addAll(sent);
        all.addAll(friends);
        List<Integer> ids = new ArrayList<>();
        for (PersonCard p : all) ids.add(p.getUser().getUserId());
        Map<Integer, Integer> mutual = friendshipDAO.mutualCounts(uid, ids);
        for (PersonCard p : all) p.setMutualCount(mutual.getOrDefault(p.getUser().getUserId(), 0));
        all.addAll(suggestions);
        ids.clear();
        for (PersonCard p : all) ids.add(p.getUser().getUserId());
        Map<Integer, UserSettings> settings = settingsDAO.getMany(ids);
        for (PersonCard p : all) {
            UserSettings s = settings.get(p.getUser().getUserId());
            boolean show = s == null || s.isShowOnline();
            p.setOnline(Presence.isOnline(p.getUser(), show));
            p.setPresence(Presence.label(p.getUser(), show));
        }
        friends.sort(Comparator.comparing((PersonCard p) -> p.getUser().getFirstName(), String.CASE_INSENSITIVE_ORDER)
                               .thenComparing(p -> p.getUser().getLastName(), String.CASE_INSENSITIVE_ORDER));

        String tab = req.getParameter("tab");
        if (!Arrays.asList("requests", "sent", "suggestions", "friends").contains(tab)) {
            tab = requests.isEmpty() ? "friends" : "requests";
        }
        long onlineCount = friends.stream().filter(PersonCard::isOnline).count();

        req.setAttribute("requests",    requests);
        req.setAttribute("sentList",    sent);
        req.setAttribute("suggestions", suggestions);
        req.setAttribute("friendCards", friends);
        req.setAttribute("onlineCount", onlineCount);
        req.setAttribute("activeTab",   tab);
        req.setAttribute("currentPage", "friends");
        req.setAttribute("pageTitle",   "Bạn bè");
        LayoutSupport.populate(req, me);
        req.getRequestDispatcher("/WEB-INF/views/friends/friends.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        req.setCharacterEncoding("UTF-8");
        User me = (User) req.getSession().getAttribute("currentUser");
        Integer other = parse(req.getParameter("userId"));
        String action = action(req);

        // Tìm bạn từ danh bạ: emails (mỗi dòng / dấu phẩy một email) → tài khoản đã đăng ký. Không lưu danh bạ.
        if ("contacts".equals(action)) {
            String raw = req.getParameter("emails") == null ? "" : req.getParameter("emails");
            List<User> found = com.uterspace.service.RecommendationService.matchContacts(me.getUserId(),
                    Arrays.asList(raw.split("[\\s,;]+")));
            Map<Integer, RelationService.Status> st = RelationService.statusOf(me.getUserId(),
                    found.stream().map(User::getUserId).collect(java.util.stream.Collectors.toList()));
            StringBuilder sb = new StringBuilder("{\"people\":[");
            for (int i = 0; i < found.size(); i++) {
                User u = found.get(i);
                sb.append(i > 0 ? "," : "").append("{\"id\":").append(u.getUserId())
                  .append(",\"name\":").append(JsonUtil.str(u.getFullName()))
                  .append(",\"firstName\":").append(JsonUtil.str(u.getFirstName()))
                  .append(",\"initials\":").append(JsonUtil.str(u.getInitials()))
                  .append(",\"avatar\":").append(JsonUtil.str(u.getAvatar() == null ? null : req.getContextPath() + u.getAvatarUrl()))
                  .append(",\"status\":").append(JsonUtil.str(String.valueOf(st.getOrDefault(u.getUserId(), RelationService.Status.NONE))))
                  .append('}');
            }
            JsonUtil.write(resp, sb.append("]}").toString());
            return;
        }

        // Tương thích nút cũ gửi fsId (id dòng friendships) cho chấp nhận / từ chối
        if (other == null && req.getParameter("fsId") != null) {
            Integer fsId = parse(req.getParameter("fsId"));
            Friendship f = fsId != null ? friendshipDAO.getFriendshipById(fsId) : null;
            if (f != null && f.getReceiver().getUserId() == me.getUserId()) other = f.getRequester().getUserId();
        }
        if (other == null) { JsonUtil.error(resp, 400, "Thiếu userId."); return; }

        RelationService.Result r;
        switch (action) {
            case "add":
            case "request":  r = RelationService.request(me, other);  break;
            case "accept":   r = RelationService.accept(me, other);   break;
            case "decline":  r = RelationService.decline(me, other);  break;
            case "cancel":   r = RelationService.cancel(me, other);   break;
            case "unfriend": r = RelationService.unfriend(me, other); break;
            case "block":    r = RelationService.block(me, other);    break;
            case "unblock":  r = RelationService.unblock(me, other);  break;
            default:         resp.sendError(404); return;
        }
        if (!r.ok()) resp.setStatus(r.error);
        writeStatus(resp, me, other, r.status, r);
    }

    /** {success, status, canRequest, message|error} */
    private void writeStatus(HttpServletResponse resp, User me, int other, RelationService.Status status,
                             RelationService.Result r) throws IOException {
        boolean canRequest = status == RelationService.Status.NONE
                && RelationService.requestDeniedReason(me.getUserId(), other) == null;
        StringBuilder sb = new StringBuilder("{\"success\":").append(r == null || r.ok())
            .append(",\"userId\":").append(other)
            .append(",\"status\":").append(JsonUtil.str(status.name()))
            .append(",\"canRequest\":").append(canRequest);
        if (r != null) sb.append(r.ok() ? ",\"message\":" : ",\"error\":").append(JsonUtil.str(r.message));
        JsonUtil.write(resp, sb.append('}').toString());
    }

    private static String action(HttpServletRequest req) {
        String info = req.getPathInfo();
        return info == null || info.equals("/") ? "" : info.substring(1);
    }

    private static Integer parse(String s) {
        if (s == null) return null;
        try { return Integer.parseInt(s.trim()); } catch (NumberFormatException e) { return null; }
    }
}
