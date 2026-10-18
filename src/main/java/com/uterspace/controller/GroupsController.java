package com.uterspace.controller;

import com.uterspace.service.NotificationService;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.util.GroupPermission;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.LayoutSupport;
import com.uterspace.util.UploadUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.*;

/**
 * GroupsController — Nhóm có chủ nhóm (plan mục 4.3).
 *
 * GET  /groups?tab=mine|explore&q=&page=    Nhóm của tôi / Khám phá (phân trang)
 * GET  /groups/view?id=                     Trang nhóm: Bài viết / Thành viên / Giới thiệu
 * POST /groups/create                       Tạo nhóm (người tạo là OWNER)
 * POST /groups/join, /groups/leave          Tham gia (nhóm kín → PENDING) / rời nhóm hoặc hủy yêu cầu
 * POST /groups/approve, /reject, /kick, /unban    Chủ nhóm quản lý thành viên
 * POST /groups/edit, /cover, /transfer, /delete   Chủ nhóm sửa nhóm, đổi ảnh bìa, chuyển quyền, xóa nhóm
 *
 * Quyền luôn kiểm bằng GroupPermission (đọc DB mỗi request). Mọi POST trả JSON.
 */
@WebServlet(urlPatterns = {"/groups", "/groups/view", "/groups/create", "/groups/join", "/groups/leave",
                           "/groups/approve", "/groups/reject", "/groups/kick", "/groups/unban",
                           "/groups/edit", "/groups/cover", "/groups/transfer", "/groups/delete"})
@MultipartConfig(fileSizeThreshold = 1024 * 1024, maxFileSize = 1024 * 1024 * 5, maxRequestSize = 1024 * 1024 * 10)
public class GroupsController extends HttpServlet {

    private static final int PAGE_SIZE = 12;
    private static final Set<String> CATEGORIES = new HashSet<>(Arrays.asList("STUDY", "CLUB"));

    private final GroupDAO        groupDAO   = new GroupDAOImpl();
    private final PostDAO         postDAO    = new PostDAOImpl();
    private final CommentDAO      commentDAO = new CommentDAOImpl();
    private final LikeDAO         likeDAO    = new LikeDAOImpl();
    private final SavedPostDAO    savedDAO   = new SavedPostDAOImpl();
    private final UserDAO         userDAO    = new UserDAOImpl();
    private final NotificationDAO notifDAO   = new NotificationDAOImpl();

    // ============================================================
    //  GET
    // ============================================================
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User me = currentUser(req);
        if (me == null) { resp.sendRedirect(req.getContextPath() + "/login"); return; }

        if ("/groups/view".equals(req.getServletPath())) showGroup(req, resp, me);
        else showList(req, resp, me);
    }

    private void showList(HttpServletRequest req, HttpServletResponse resp, User me)
            throws ServletException, IOException {
        int uid = me.getUserId();
        String tab = "explore".equals(req.getParameter("tab")) ? "explore" : "mine";
        String q = req.getParameter("q") != null ? req.getParameter("q").trim() : "";
        Integer page = parseInt(req.getParameter("page"));
        int total = groupDAO.countExplore(uid, q);
        int pages = Math.max(1, (total + PAGE_SIZE - 1) / PAGE_SIZE);
        int current = (page == null) ? 1 : Math.min(Math.max(page, 1), pages);

        req.setAttribute("myGroups",       groupDAO.getGroupsOf(uid));
        req.setAttribute("pendingGroups",  groupDAO.getPendingGroupsOf(uid));
        req.setAttribute("exploreGroups",  groupDAO.explore(uid, q, current, PAGE_SIZE));
        req.setAttribute("exploreTotal",   total);
        req.setAttribute("explorePage",    current);
        req.setAttribute("explorePages",   pages);
        req.setAttribute("groupQuery",     q);
        req.setAttribute("activeTab",      tab);
        req.setAttribute("currentPage",    "groups");
        req.setAttribute("pageTitle",      "Nhóm");
        LayoutSupport.populate(req, me);
        req.getRequestDispatcher("/WEB-INF/views/groups/groups.jsp").forward(req, resp);
    }

    private void showGroup(HttpServletRequest req, HttpServletResponse resp, User me)
            throws ServletException, IOException {
        Integer gid = parseInt(req.getParameter("id"));
        Group group = gid == null ? null : groupDAO.getGroupById(gid);
        if (group == null) { resp.sendRedirect(req.getContextPath() + "/groups"); return; }

        int uid = me.getUserId();
        GroupMember membership = GroupPermission.membershipOf(gid, uid);
        group.setMyMembership(membership);
        boolean isMember = GroupPermission.isMember(membership);
        boolean isOwner  = GroupPermission.isOwner(membership);
        boolean canView  = GroupPermission.canViewPosts(group, membership);

        List<Post> posts = new ArrayList<>();
        if (canView) {
            posts = postDAO.getGroupPosts(gid);
            commentDAO.attachComments(posts);
            likeDAO.markLikedBy(posts, uid);
            // Bộ lọc nội dung cá nhân của người xem (từ khóa / ẩn bài tiêu cực)
            com.uterspace.util.ContentFilter.of(new com.uterspace.dao.UserSettingsDAO().get(uid)).apply(posts, uid);
        }
        Set<Integer> savedIds = new HashSet<>();
        for (Post sp : savedDAO.getSavedPosts(uid)) savedIds.add(sp.getPostId());

        List<GroupMember> members = groupDAO.getMembers(gid, GroupMember.STATUS_ACTIVE);
        User owner = null;
        for (GroupMember m : members) if (GroupMember.ROLE_OWNER.equals(m.getRole())) owner = m.getUser();

        req.setAttribute("group",          group);
        req.setAttribute("groupOwnerUser", owner);
        req.setAttribute("isMember",       isMember);
        req.setAttribute("groupOwner",     isOwner);
        req.setAttribute("canViewPosts",   canView);
        req.setAttribute("posts",          posts);
        req.setAttribute("savedPostIds",   savedIds);
        // Nhóm kín: người ngoài chỉ thấy số lượng thành viên, không thấy danh sách
        req.setAttribute("members",        canView ? members : Collections.emptyList());
        req.setAttribute("pendingMembers", isOwner ? groupDAO.getMembers(gid, GroupMember.STATUS_PENDING) : Collections.emptyList());
        req.setAttribute("bannedMembers",  isOwner ? groupDAO.getMembers(gid, GroupMember.STATUS_BANNED)  : Collections.emptyList());
        req.setAttribute("activeTab",      req.getParameter("tab") != null ? req.getParameter("tab") : "posts");
        req.setAttribute("currentPage",    "groups");
        req.setAttribute("pageTitle",      group.getName());
        LayoutSupport.populate(req, me);
        req.getRequestDispatcher("/WEB-INF/views/groups/group-view.jsp").forward(req, resp);
    }

    // ============================================================
    //  POST (JSON)
    // ============================================================
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");
        User me = currentUser(req);
        if (me == null) { JsonUtil.error(resp, 401, "Phiên đăng nhập đã hết hạn."); return; }

        String path = req.getServletPath();
        if ("/groups/create".equals(path)) { create(req, resp, me); return; }

        Integer gid = parseInt(req.getParameter("groupId"));
        Group group = gid == null ? null : groupDAO.getGroupById(gid);
        if (group == null) { JsonUtil.error(resp, 404, "Nhóm không tồn tại."); return; }
        GroupMember mine = GroupPermission.membershipOf(gid, me.getUserId());

        switch (path) {
            case "/groups/join":     join(resp, me, group, mine); return;
            case "/groups/leave":    leave(resp, me, group, mine); return;
            default: break;
        }

        // Các thao tác còn lại chỉ dành cho chủ nhóm
        if (!GroupPermission.isOwner(mine)) { JsonUtil.error(resp, 403, "Chỉ chủ nhóm mới được làm việc này."); return; }

        switch (path) {
            case "/groups/approve":  approve(req, resp, me, group); break;
            case "/groups/reject":   memberAction(req, resp, me, gid, "reject"); break;
            case "/groups/kick":     memberAction(req, resp, me, gid, "kick"); break;
            case "/groups/unban":    memberAction(req, resp, me, gid, "unban"); break;
            case "/groups/transfer": transfer(req, resp, me, group); break;
            case "/groups/edit":     edit(req, resp, group); break;
            case "/groups/cover":    cover(req, resp, group); break;
            case "/groups/delete":   delete(req, resp, group); break;
            default: resp.sendError(404);
        }
    }

    private void create(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        Group g = new Group();
        String error = fillGroup(req, g);
        if (error != null) { JsonUtil.error(resp, 400, error); return; }
        Group created = groupDAO.createGroup(g, me.getUserId());
        JsonUtil.write(resp, "{\"success\":true,\"groupId\":" + created.getGroupId() + "}");
    }

    private void join(HttpServletResponse resp, User me, Group group, GroupMember mine) throws IOException {
        if (mine != null) {
            String msg = mine.isBanned() ? "Bạn đã bị xóa khỏi nhóm này nên không thể tham gia lại."
                       : mine.isPending() ? "Bạn đã gửi yêu cầu, hãy chờ chủ nhóm duyệt." : "Bạn đã là thành viên.";
            JsonUtil.error(resp, 409, msg);
            return;
        }
        String status = groupDAO.join(group.getGroupId(), me.getUserId(), group.isPrivateGroup());
        if (status == null) { JsonUtil.error(resp, 409, "Bạn đã tham gia hoặc đã gửi yêu cầu rồi."); return; }

        if (GroupMember.STATUS_PENDING.equals(status)) {
            User owner = ownerOf(group.getGroupId());
            if (owner != null) {
                NotificationService.notifyMany(Collections.singletonList(owner.getUserId()), me.getUserId(), "GROUP_JOIN_REQUEST",
                        "muốn tham gia nhóm " + group.getName() + ".",
                        "/groups/view?id=" + group.getGroupId() + "&tab=members");
            }
        }
        JsonUtil.write(resp, "{\"success\":true,\"status\":" + JsonUtil.str(status) + "}");
    }

    private void leave(HttpServletResponse resp, User me, Group group, GroupMember mine) throws IOException {
        if (mine == null || mine.isBanned()) { JsonUtil.error(resp, 409, "Bạn không ở trong nhóm này."); return; }
        if (GroupMember.ROLE_OWNER.equals(mine.getRole())) {
            JsonUtil.error(resp, 409, "Chủ nhóm không thể rời nhóm. Hãy chuyển quyền chủ nhóm cho người khác trước, hoặc xóa nhóm.");
            return;
        }
        boolean ok = groupDAO.leave(group.getGroupId(), me.getUserId());
        JsonUtil.write(resp, "{\"success\":" + ok + ",\"wasPending\":" + mine.isPending() + "}");
    }

    private void approve(HttpServletRequest req, HttpServletResponse resp, User me, Group group) throws IOException {
        Integer target = parseInt(req.getParameter("userId"));
        if (target == null || !groupDAO.approve(group.getGroupId(), target)) {
            JsonUtil.error(resp, 409, "Yêu cầu không còn tồn tại."); return;
        }
        NotificationService.notifyMany(Collections.singletonList(target), me.getUserId(), "GROUP_APPROVED",
                "đã duyệt yêu cầu tham gia nhóm " + group.getName() + " của bạn.",
                "/groups/view?id=" + group.getGroupId());
        JsonUtil.write(resp, "{\"success\":true}");
    }

    private void memberAction(HttpServletRequest req, HttpServletResponse resp, User me, int gid, String action)
            throws IOException {
        Integer target = parseInt(req.getParameter("userId"));
        if (target == null || target == me.getUserId()) { JsonUtil.error(resp, 400, "Thành viên không hợp lệ."); return; }
        boolean ok;
        switch (action) {
            case "reject": ok = groupDAO.reject(gid, target); break;
            case "kick":   ok = groupDAO.kick(gid, target);   break;
            default:       ok = groupDAO.unban(gid, target);
        }
        if (!ok) { JsonUtil.error(resp, 409, "Không thực hiện được — trạng thái thành viên đã thay đổi."); return; }
        JsonUtil.write(resp, "{\"success\":true}");
    }

    private void transfer(HttpServletRequest req, HttpServletResponse resp, User me, Group group) throws IOException {
        Integer target = parseInt(req.getParameter("userId"));
        if (target == null || target == me.getUserId()) { JsonUtil.error(resp, 400, "Hãy chọn một thành viên khác."); return; }
        if (!groupDAO.transferOwnership(group.getGroupId(), me.getUserId(), target)) {
            JsonUtil.error(resp, 409, "Người nhận phải là thành viên đang hoạt động của nhóm."); return;
        }
        NotificationService.notifyMany(Collections.singletonList(target), me.getUserId(), "SYSTEM",
                "đã chuyển quyền chủ nhóm " + group.getName() + " cho bạn.",
                "/groups/view?id=" + group.getGroupId());
        JsonUtil.write(resp, "{\"success\":true}");
    }

    private void edit(HttpServletRequest req, HttpServletResponse resp, Group group) throws IOException {
        Group changes = new Group();
        String error = fillGroup(req, changes);
        if (error != null) { JsonUtil.error(resp, 400, error); return; }
        groupDAO.updateGroup(group.getGroupId(), changes.getName(), changes.getDescription(),
                changes.getCategory(), changes.getPrivacy(), changes.getCoverIcon());
        JsonUtil.write(resp, "{\"success\":true}");
    }

    private void cover(HttpServletRequest req, HttpServletResponse resp, Group group) throws IOException, ServletException {
        String path;
        try {
            path = UploadUtil.saveImage(req.getServletContext(), req.getPart("cover"), UploadUtil.DIR_GROUPS);
        } catch (UploadUtil.UploadException e) {
            JsonUtil.error(resp, 400, e.getMessage());
            return;
        }
        groupDAO.updateCover(group.getGroupId(), path);
        UploadUtil.delete(req.getServletContext(), group.getCoverImage());
        JsonUtil.write(resp, "{\"success\":true}");
    }

    private void delete(HttpServletRequest req, HttpServletResponse resp, Group group) throws IOException {
        // Xác nhận bằng cách gõ lại đúng tên nhóm (chống bấm nhầm)
        String confirmName = req.getParameter("confirmName");
        if (confirmName == null || !confirmName.trim().equals(group.getName())) {
            JsonUtil.error(resp, 400, "Tên nhóm nhập lại không khớp."); return;
        }
        List<String> files = groupDAO.deleteGroup(group.getGroupId());
        for (String f : files) UploadUtil.delete(req.getServletContext(), f);
        UploadUtil.delete(req.getServletContext(), group.getCoverImage());
        JsonUtil.write(resp, "{\"success\":true}");
    }

    // ============================================================
    //  Helpers
    // ============================================================

    /** Đọc + kiểm tra form tạo/sửa nhóm vào g; trả về câu báo lỗi hoặc null nếu hợp lệ */
    private static String fillGroup(HttpServletRequest req, Group g) {
        String name = trim(req.getParameter("name"));
        String description = trim(req.getParameter("description"));
        String category = trim(req.getParameter("category"));
        String privacy = trim(req.getParameter("privacy"));
        String icon = trim(req.getParameter("coverIcon"));

        if (name.length() < 3 || name.length() > 100) return "Tên nhóm dài từ 3 đến 100 ký tự.";
        if (description.length() > 500) return "Mô tả tối đa 500 ký tự.";
        if (!CATEGORIES.contains(category)) return "Loại nhóm không hợp lệ.";
        if (!Group.PUBLIC.equals(privacy) && !Group.PRIVATE.equals(privacy)) return "Quyền riêng tư không hợp lệ.";
        if (icon.isEmpty()) icon = "🏷️";
        if (icon.length() > 10) return "Biểu tượng quá dài.";

        g.setName(name);
        g.setDescription(description.isEmpty() ? null : description);
        g.setCategory(category);
        g.setPrivacy(privacy);
        g.setCoverIcon(icon);
        return null;
    }

    private User ownerOf(int groupId) {
        for (GroupMember m : groupDAO.getMembers(groupId, GroupMember.STATUS_ACTIVE)) {
            if (GroupMember.ROLE_OWNER.equals(m.getRole())) return m.getUser();
        }
        return null;
    }

    private static String trim(String s) { return s == null ? "" : s.trim(); }

    private static User currentUser(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        return (session != null) ? (User) session.getAttribute("currentUser") : null;
    }

    private static Integer parseInt(String s) {
        if (s == null) return null;
        try { return Integer.parseInt(s.trim()); } catch (NumberFormatException e) { return null; }
    }
}
