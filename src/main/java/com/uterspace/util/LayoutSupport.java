package com.uterspace.util;

import com.uterspace.dao.*;
import com.uterspace.model.User;

import javax.servlet.http.HttpServletRequest;
import java.util.concurrent.CompletableFuture;

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

        // Các câu đếm độc lập → chạy song song (DB cloud: mỗi câu ~0,25 giây đường truyền).
        // Controller đã có sẵn số liệu thì đặt attribute trước, ở đây không đọc lại.
        CompletableFuture<Integer> posts    = DbParallel.async(() -> POST_DAO.countPostsByUser(uid));
        CompletableFuture<Integer> friends  = DbParallel.async(() -> FRIEND_DAO.countFriends(uid));
        CompletableFuture<Integer> requests = DbParallel.async(() -> FRIEND_DAO.countPendingFor(uid));
        CompletableFuture<Integer> saved    = req.getAttribute("mySavedCount") != null ? null
                                            : DbParallel.async(() -> SAVED_DAO.getSavedPosts(uid).size());
        CompletableFuture<Integer> notifs   = DbParallel.async(() -> NOTIF_DAO.getUnreadNotificationCount(uid));
        CompletableFuture<Integer> chats    = DbParallel.async(() -> MSG_DAO.getUnreadMessageCount(uid));
        // Bộ lọc nội dung cá nhân: danh sách từ khóa cho JS thu gọn bình luận (post-support.jsp)
        CompletableFuture<String> terms     = req.getAttribute("filterTermsJson") != null ? null
                                            : DbParallel.async(() -> ContentFilter.of(SETTINGS_DAO.get(uid)).termsJson());

        req.setAttribute("myPostCount",        DbParallel.get(posts));
        req.setAttribute("myFriendCount",      DbParallel.get(friends));
        req.setAttribute("friendRequestCount", DbParallel.get(requests));
        if (saved != null) req.setAttribute("mySavedCount", DbParallel.get(saved));
        req.setAttribute("unreadNotifCount",   DbParallel.get(notifs));
        req.setAttribute("unreadChatCount",    DbParallel.get(chats));
        if (terms != null) req.setAttribute("filterTermsJson", DbParallel.get(terms));
    }
}
