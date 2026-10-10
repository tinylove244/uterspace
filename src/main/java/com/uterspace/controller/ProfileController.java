package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.util.LayoutSupport;
import com.uterspace.util.UploadUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.List;

/**
 * ProfileController — Xử lý trang Cá nhân (/profile?userId=...).
 * POST cập nhật bio/website/location, avatar và cover.
 */
@WebServlet(urlPatterns = {"/profile", "/profile/avatar", "/profile/cover"})
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,
    maxFileSize = 1024 * 1024 * 5,
    maxRequestSize = 1024 * 1024 * 10
)
public class ProfileController extends HttpServlet {

    private final UserDAO       userDAO       = new UserDAOImpl();
    private final PostDAO       postDAO       = new PostDAOImpl();
    private final LikeDAO       likeDAO       = new LikeDAOImpl();
    private final FriendshipDAO friendshipDAO = new FriendshipDAOImpl();
    private final NotificationDAO notifDAO    = new NotificationDAOImpl();
    private final MessageDAO    messageDAO    = new MessageDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String path = req.getServletPath();
        if (!"/profile".equals(path)) {
            resp.sendError(404);
            return;
        }

        HttpSession session  = req.getSession(false);
        User currentUser     = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (currentUser == null) { resp.sendRedirect(req.getContextPath() + "/login"); return; }

        String userIdParam = req.getParameter("userId");
        int targetUserId;
        try {
            targetUserId = (userIdParam != null) ? Integer.parseInt(userIdParam) : currentUser.getUserId();
        } catch (NumberFormatException e) {
            targetUserId = currentUser.getUserId();
        }

        User profileUser = userDAO.getUserById(targetUserId);
        if (profileUser == null) {
            resp.sendRedirect(req.getContextPath() + "/profile?userId=" + currentUser.getUserId());
            return;
        }

        // Quan hệ với người xem (RelationService): quyết định nút ở đầu trang và việc có được xem nội dung không
        com.uterspace.service.RelationService.Status relation =
                com.uterspace.service.RelationService.statusOf(currentUser.getUserId(), targetUserId);
        boolean self = targetUserId == currentUser.getUserId();
        // Bị người này chặn, hoặc tài khoản đang bị khóa → trang "không khả dụng"; mình chặn họ → chỉ hiện đầu trang + Bỏ chặn
        boolean unavailable = !self && (relation == com.uterspace.service.RelationService.Status.BLOCKED_BY
                                        || profileUser.isLocked());
        boolean hideContent = unavailable || relation == com.uterspace.service.RelationService.Status.BLOCKED;

        List<Post> userPosts = hideContent ? new java.util.ArrayList<>()
                                           : postDAO.getProfilePosts(targetUserId, currentUser.getUserId());
        CommentDAO commentDAO = new CommentDAOImpl();
        for (Post p : userPosts) {
            p.setLikedByCurrentUser(likeDAO.isLikedBy(p.getPostId(), currentUser.getUserId()));
            p.setComments(commentDAO.getCommentsByPostId(p.getPostId()));
        }
        postDAO.attachSharedPosts(userPosts, currentUser.getUserId());
        postDAO.attachGroupNames(userPosts);

        List<User> friends = hideContent ? new java.util.ArrayList<>() : friendshipDAO.getFriendsOf(targetUserId);
        com.uterspace.model.UserSettings targetSettings = new com.uterspace.dao.UserSettingsDAO().get(targetUserId);
        int mutual = self ? 0 : friendshipDAO.mutualCounts(currentUser.getUserId(),
                java.util.Collections.singletonList(targetUserId)).getOrDefault(targetUserId, 0);

        req.setAttribute("profileUser",      profileUser);
        req.setAttribute("userPosts",        userPosts);
        req.setAttribute("friends",          friends);
        req.setAttribute("relationStatus",   relation.name());
        req.setAttribute("isFriend",         relation == com.uterspace.service.RelationService.Status.FRIEND);
        req.setAttribute("canRequest",       relation == com.uterspace.service.RelationService.Status.NONE
                && com.uterspace.service.RelationService.requestDeniedReason(currentUser.getUserId(), targetUserId) == null);
        req.setAttribute("profileUnavailable", unavailable);
        req.setAttribute("profileHidden",    hideContent);
        req.setAttribute("mutualCount",      mutual);
        req.setAttribute("profileDid",       unavailable ? null : new com.uterspace.security.DidDAO().findByUser(targetUserId));
        req.setAttribute("presenceLabel",    hideContent ? "" : com.uterspace.realtime.Presence.label(profileUser, targetSettings.isShowOnline()));
        req.setAttribute("profileOnline",    !hideContent && com.uterspace.realtime.Presence.isOnline(profileUser, targetSettings.isShowOnline()));
        req.setAttribute("pageTitle",        profileUser.getFullName());
        req.setAttribute("currentPage",      "profile");
        LayoutSupport.populate(req, currentUser);

        req.getRequestDispatcher("/WEB-INF/views/profile/profile.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");
        HttpSession session  = req.getSession(false);
        User currentUser     = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (currentUser == null) {
            resp.sendRedirect(req.getContextPath() + "/login");
            return;
        }

        String path = req.getServletPath();
        if ("/profile/avatar".equals(path)) {
            handleUpload(req, resp, currentUser, "avatar");
        } else if ("/profile/cover".equals(path)) {
            handleUpload(req, resp, currentUser, "cover");
        } else {
            String bio      = req.getParameter("bio");
            String website  = req.getParameter("website");
            String location = req.getParameter("location");

            userDAO.updateProfile(currentUser.getUserId(),
                    bio      != null ? bio.trim()      : currentUser.getBio(),
                    website  != null ? website.trim()  : currentUser.getWebsite(),
                    location != null ? location.trim() : currentUser.getLocation());

            User updated = userDAO.getUserById(currentUser.getUserId());
            if (updated != null) session.setAttribute("currentUser", updated);
            resp.sendRedirect(req.getContextPath() + "/profile?userId=" + currentUser.getUserId() + "&updated=true");
        }
    }

    private void handleUpload(HttpServletRequest req, HttpServletResponse resp, User user, String type)
            throws IOException, ServletException {
        String imagePath;
        try {
            // Lưu ra thư mục upload ngoài webapp (UUID + đuôi theo magic bytes), xem UploadUtil
            imagePath = UploadUtil.saveImage(req.getServletContext(), req.getPart(type),
                    "avatar".equals(type) ? UploadUtil.DIR_AVATARS : UploadUtil.DIR_COVERS);
        } catch (UploadUtil.UploadException e) {
            resp.setStatus(400);
            return;
        }

        User before = userDAO.getUserById(user.getUserId());
        if ("avatar".equals(type)) {
            userDAO.updateAvatar(user.getUserId(), imagePath);
            if (before != null) UploadUtil.delete(req.getServletContext(), before.getAvatar());
        } else {
            userDAO.updateCover(user.getUserId(), imagePath);
            if (before != null) UploadUtil.delete(req.getServletContext(), before.getCoverImage());
        }

        User updated = userDAO.getUserById(user.getUserId());
        if (updated != null) req.getSession().setAttribute("currentUser", updated);
        resp.sendRedirect(req.getContextPath() + "/profile?userId=" + user.getUserId());
    }

}
