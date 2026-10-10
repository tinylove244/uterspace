package com.uterspace.util;

import com.uterspace.dao.*;
import com.uterspace.model.User;

import javax.servlet.http.HttpServletRequest;

/**
 * LayoutSupport — nạp dữ liệu cho khung giao diện dùng chung (app-shell).
 *
 * Cột trái (common/app-sidebar.jsp) và thanh công cụ (common/app-topbar.jsp)
 * xuất hiện trên mọi trang sau đăng nhập, nên mọi controller đều cần cùng một
 * bộ thuộc tính. Gom vào đây để không lặp lại ở 7 controller.
 *
 * Cách dùng trong doGet:  LayoutSupport.populate(req, currentUser);
 */
public final class LayoutSupport {

    private static final PostDAO         POST_DAO   = new PostDAOImpl();
    private static final FriendshipDAO   FRIEND_DAO = new FriendshipDAOImpl();
    private static final SavedPostDAO    SAVED_DAO  = new SavedPostDAOImpl();
    private static final NotificationDAO NOTIF_DAO  = new NotificationDAOImpl();
    private static final MessageDAO      MSG_DAO    = new MessageDAOImpl();
    private static final UserSettingsDAO SETTINGS_DAO = new UserSettingsDAO();

    private LayoutSupport() { }

    /**
     * Gán các thuộc tính mà cột trái + thanh công cụ cần:
     * myPostCount, myFriendCount, mySavedCount, unreadNotifCount, unreadChatCount, friendRequestCount.
     */
    public static void populate(HttpServletRequest req, User currentUser) {
        if (currentUser == null) return;
        int uid = currentUser.getUserId();

        req.setAttribute("myPostCount",      POST_DAO.countPostsByUser(uid));
        req.setAttribute("myFriendCount",    FRIEND_DAO.countFriends(uid));
        req.setAttribute("friendRequestCount", FRIEND_DAO.countPendingFor(uid));
        req.setAttribute("mySavedCount",     SAVED_DAO.getSavedPosts(uid).size());
        req.setAttribute("unreadNotifCount", NOTIF_DAO.getUnreadNotificationCount(uid));
        req.setAttribute("unreadChatCount",  MSG_DAO.getUnreadMessageCount(uid));
        // Bộ lọc nội dung cá nhân: danh sách từ khóa cho JS thu gọn bình luận (post-support.jsp)
        if (req.getAttribute("filterTermsJson") == null) {
            req.setAttribute("filterTermsJson", ContentFilter.of(SETTINGS_DAO.get(uid)).termsJson());
        }
    }
}
