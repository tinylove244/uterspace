package com.uterspace.service;

import com.uterspace.dao.*;
import com.uterspace.model.Friendship;
import com.uterspace.model.User;
import com.uterspace.model.UserSettings;
import com.uterspace.realtime.Live;

import java.util.*;

/**
 * RelationService — quan hệ giữa hai người dùng: trạng thái, quyền, và các hành động
 * (gửi / chấp nhận / từ chối / thu hồi lời mời, hủy kết bạn, chặn / bỏ chặn).
 *
 * Mỗi hành động: kiểm tra quyền → ghi DB (FriendshipDAO / BlockDAO, mỗi việc một transaction) →
 * tạo / gỡ thông báo → đẩy sự kiện "friend" + huy hiệu tới CẢ HAI người (mọi tab đang mở) để
 * nút trạng thái ở trang cá nhân, tìm kiếm, trang Bạn bè... luôn khớp nhau mà không cần tải lại.
 */
public final class RelationService {

    /** Trạng thái nhìn từ phía người xem */
    public enum Status {
        SELF,        // chính mình
        NONE,        // chưa có quan hệ
        SENT,        // mình đã gửi lời mời, đang chờ
        RECEIVED,    // người kia đã gửi lời mời cho mình
        FRIEND,      // bạn bè
        BLOCKED,     // mình đã chặn người kia
        BLOCKED_BY   // người kia đã chặn mình (hiển thị như "không khả dụng")
    }

    /** Kết quả một hành động: trạng thái mới + thông điệp cho người dùng (+ mã lỗi HTTP nếu thất bại) */
    public static final class Result {
        public final Status status;
        public final String message;
        public final int error;   // 0 = thành công
        Result(Status status, String message, int error) { this.status = status; this.message = message; this.error = error; }
        public boolean ok() { return error == 0; }
    }

    private static final FriendshipDAO   FRIENDS  = new FriendshipDAOImpl();
    private static final BlockDAO        BLOCKS   = new BlockDAO();
    private static final UserSettingsDAO SETTINGS = new UserSettingsDAO();
    private static final UserDAO         USERS    = new UserDAOImpl();

    private RelationService() { }

    // ============================================================ Trạng thái

    public static Status statusOf(int viewer, int other) {
        if (viewer == other) return Status.SELF;
        if (BLOCKS.hasBlocked(viewer, other)) return Status.BLOCKED;
        if (BLOCKS.hasBlocked(other, viewer)) return Status.BLOCKED_BY;
        Friendship f = FRIENDS.findBetween(viewer, other);
        if (f == null) return Status.NONE;
        if (f.isAccepted()) return Status.FRIEND;
        return f.getRequester().getUserId() == viewer ? Status.SENT : Status.RECEIVED;
    }

    /** Trạng thái với nhiều người cùng lúc (danh sách tìm kiếm / gợi ý) — ít truy vấn */
    public static Map<Integer, Status> statusOf(int viewer, Collection<Integer> others) {
        Map<Integer, Status> map = new HashMap<>();
        Set<Integer> friends = new HashSet<>(FRIENDS.getFriendIds(viewer));
        Set<Integer> blocked = BLOCKS.blockedEitherWay(viewer);
        Map<Integer, Status> pending = new HashMap<>();
        for (Friendship f : FRIENDS.getSentRequests(viewer))      pending.put(f.getReceiver().getUserId(), Status.SENT);
        for (Friendship f : FRIENDS.getPendingRequestsFor(viewer)) pending.put(f.getRequester().getUserId(), Status.RECEIVED);
        for (Integer o : others) {
            if (o == viewer) map.put(o, Status.SELF);
            else if (blocked.contains(o)) map.put(o, BLOCKS.hasBlocked(viewer, o) ? Status.BLOCKED : Status.BLOCKED_BY);
            else if (friends.contains(o)) map.put(o, Status.FRIEND);
            else map.put(o, pending.getOrDefault(o, Status.NONE));
        }
        return map;
    }

    /**
     * from có được gửi lời mời cho to không (theo cài đặt quyền riêng tư của to).
     * @return null nếu được, ngược lại là câu giải thích
     */
    public static String requestDeniedReason(int from, int to) {
        String policy = SETTINGS.get(to).getFriendRequestPolicy();
        if (UserSettings.FR_NOBODY.equals(policy)) return "Người này hiện không nhận lời mời kết bạn.";
        if (UserSettings.FR_FRIENDS_OF_FRIENDS.equals(policy)
                && FRIENDS.mutualCounts(from, Collections.singletonList(to)).getOrDefault(to, 0) == 0) {
            return "Người này chỉ nhận lời mời kết bạn từ bạn của bạn bè.";
        }
        return null;
    }

    /**
     * from có được nhắn tin 1-1 cho to không.
     * @return null nếu được, ngược lại là câu giải thích
     */
    public static String messageDeniedReason(int from, int to) {
        if (from == to) return null;
        if (BLOCKS.isBlockedEitherWay(from, to)) return "Bạn không thể nhắn tin cho người này.";
        if (UserSettings.MSG_FRIENDS.equals(SETTINGS.get(to).getMessagePolicy()) && !FRIENDS.areFriends(from, to)) {
            return "Người này chỉ nhận tin nhắn từ bạn bè.";
        }
        return null;
    }

    // ============================================================ Hành động

    public static Result request(User me, int otherId) {
        int uid = me.getUserId();
        User other = USERS.getUserById(otherId);
        if (other == null || otherId == uid || other.isLocked()) return fail(Status.NONE, "Không tìm thấy người dùng.", 404);
        Status st = statusOf(uid, otherId);
        if (st == Status.BLOCKED)    return fail(st, "Bạn đã chặn người này. Bỏ chặn để kết bạn.", 409);
        if (st == Status.BLOCKED_BY) return fail(st, "Không thể gửi lời mời cho người này.", 403);
        if (st == Status.FRIEND)     return ok(st, "Hai bạn đã là bạn bè.");
        if (st == Status.SENT)       return ok(st, "Bạn đã gửi lời mời trước đó.");
        if (st == Status.NONE) {
            String denied = requestDeniedReason(uid, otherId);
            if (denied != null) return fail(st, denied, 403);
        }

        switch (FRIENDS.sendRequest(uid, otherId)) {
            case SENT:
                NotificationService.notify(otherId, uid, "FRIEND_REQUEST", "đã gửi cho bạn lời mời kết bạn.",
                                           "/friends?tab=requests", "fr:" + uid);
                sync(me, otherId, Status.SENT, Status.RECEIVED, "request");
                return ok(Status.SENT, "Đã gửi lời mời kết bạn.");
            case AUTO_ACCEPTED:
                // Người kia đã mời mình trước → gửi lời mời = chấp nhận luôn
                afterAccept(me, otherId);
                return ok(Status.FRIEND, "Hai bạn đã trở thành bạn bè!");
            case ALREADY_FRIENDS:
                return ok(Status.FRIEND, "Hai bạn đã là bạn bè.");
            default:
                return ok(Status.SENT, "Bạn đã gửi lời mời trước đó.");
        }
    }

    public static Result accept(User me, int requesterId) {
        if (!FRIENDS.accept(me.getUserId(), requesterId)) {
            return fail(statusOf(me.getUserId(), requesterId), "Lời mời không còn tồn tại (có thể đã bị thu hồi).", 409);
        }
        afterAccept(me, requesterId);
        return ok(Status.FRIEND, "Đã chấp nhận lời mời kết bạn.");
    }

    private static void afterAccept(User me, int otherId) {
        NotificationService.removeByRef(me.getUserId(), "fr:" + otherId);        // gỡ thông báo lời mời đã trả lời
        NotificationService.notify(otherId, me.getUserId(), "FRIEND_ACCEPT", "đã chấp nhận lời mời kết bạn của bạn.",
                                   "/profile?userId=" + me.getUserId(), "fa:" + me.getUserId());
        sync(me, otherId, Status.FRIEND, Status.FRIEND, "accept");
    }

    public static Result decline(User me, int requesterId) {
        if (!FRIENDS.decline(me.getUserId(), requesterId)) {
            return fail(statusOf(me.getUserId(), requesterId), "Lời mời không còn tồn tại.", 409);
        }
        NotificationService.removeByRef(me.getUserId(), "fr:" + requesterId);
        sync(me, requesterId, Status.NONE, Status.NONE, "decline");
        return ok(Status.NONE, "Đã từ chối lời mời.");
    }

    public static Result cancel(User me, int receiverId) {
        if (!FRIENDS.cancel(me.getUserId(), receiverId)) {
            return fail(statusOf(me.getUserId(), receiverId), "Lời mời không còn tồn tại (có thể người kia vừa trả lời).", 409);
        }
        NotificationService.removeByRef(receiverId, "fr:" + me.getUserId());   // người nhận không còn thấy lời mời
        sync(me, receiverId, Status.NONE, Status.NONE, "cancel");
        return ok(Status.NONE, "Đã thu hồi lời mời kết bạn.");
    }

    public static Result unfriend(User me, int otherId) {
        if (!FRIENDS.unfriend(me.getUserId(), otherId)) {
            return fail(statusOf(me.getUserId(), otherId), "Hai bạn hiện không phải bạn bè.", 409);
        }
        sync(me, otherId, Status.NONE, Status.NONE, "unfriend");
        return ok(Status.NONE, "Đã hủy kết bạn.");
    }

    public static Result block(User me, int otherId) {
        if (otherId == me.getUserId() || USERS.getUserById(otherId) == null) return fail(Status.NONE, "Không tìm thấy người dùng.", 404);
        BLOCKS.block(me.getUserId(), otherId);
        NotificationService.removeByRef(me.getUserId(), "fr:" + otherId);
        NotificationService.removeByRef(otherId, "fr:" + me.getUserId());
        sync(me, otherId, Status.BLOCKED, Status.BLOCKED_BY, "block");
        return ok(Status.BLOCKED, "Đã chặn. Hai bạn sẽ không thấy nội dung và không nhắn tin được cho nhau.");
    }

    public static Result unblock(User me, int otherId) {
        BLOCKS.unblock(me.getUserId(), otherId);
        Status mine = statusOf(me.getUserId(), otherId);
        sync(me, otherId, mine, statusOf(otherId, me.getUserId()), "unblock");
        return ok(mine, "Đã bỏ chặn.");
    }

    // ============================================================ Tiện ích

    /** Đẩy trạng thái mới tới cả hai người (mọi tab) + cập nhật số lời mời trên huy hiệu */
    private static void sync(User me, int otherId, Status mine, Status theirs, String action) {
        Live.friend(me.getUserId(), otherId, mine.name(), action, null);
        // Người bị chặn không nhận tên người chặn (giao diện cũng không hiện toast cho hành động "block")
        Live.friend(otherId, me.getUserId(), theirs.name(), action, "block".equals(action) ? null : me.getFullName());
        Live.badges(me.getUserId());
        Live.badges(otherId);
    }

    private static Result ok(Status s, String msg)            { return new Result(s, msg, 0); }
    private static Result fail(Status s, String msg, int code) { return new Result(s, msg, code); }
}
