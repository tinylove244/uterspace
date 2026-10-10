package com.uterspace.dao;

import com.uterspace.model.Notification;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * NotificationDAO — thông báo.
 * Tạo thông báo từ Controller nên đi qua NotificationService (kiểm tùy chọn người nhận, chặn, đẩy realtime);
 * DAO chỉ đọc / ghi dữ liệu.
 */
public interface NotificationDAO {

    /** Lấy tất cả thông báo của user (mới nhất trước), kèm actor (User) */
    List<Notification> getNotificationsFor(int userId);

    /**
     * Một trang thông báo, mới nhất trước.
     * @param types  chỉ lấy các loại này (null = mọi loại)
     * @param unreadOnly chỉ thông báo chưa đọc
     */
    List<Notification> getPage(int userId, List<String> types, boolean unreadOnly, int offset, int limit);

    int count(int userId, List<String> types, boolean unreadOnly);

    /** Số thông báo chưa đọc của user */
    int getUnreadNotificationCount(int userId);

    /** Số chưa đọc theo từng loại (type → n) — trang Thông báo gom thành nhóm chức năng */
    Map<String, Integer> unreadByType(int userId);

    Notification getById(int userId, int notificationId);

    /** Đánh dấu tất cả thông báo của user là đã đọc */
    void markAllAsRead(int userId);

    /** Đánh dấu đã đọc / chưa đọc một thông báo (chỉ thông báo của chính userId) */
    boolean setRead(int userId, int notificationId, boolean read);

    /** Đánh dấu đã đọc các thông báo có ref_key (vd: mở hội thoại → thông báo tin nhắn của hội thoại đó) */
    int markReadByRef(int userId, String refKey);

    boolean delete(int userId, int notificationId);

    /** Xóa mọi thông báo ĐÃ ĐỌC của user */
    int deleteRead(int userId);

    /** Gỡ thông báo theo ref_key (vd: người gửi thu hồi lời mời kết bạn) */
    int deleteByRef(int userId, String refKey);

    /** Đã có thông báo với ref_key này được tạo sau mốc since chưa (đọc hay chưa đều tính) */
    boolean existsSince(int userId, String refKey, LocalDateTime since);

    /** Thông báo CHƯA ĐỌC có ref_key này (để gộp), null nếu không có */
    Notification findUnreadByRef(int userId, String refKey);

    /** Cập nhật thông báo gộp: người gây ra mới nhất, nội dung, đưa lên đầu (created_at = at) */
    void refreshAggregated(int notificationId, int actorId, String content, LocalDateTime at);

    /** Tạo thông báo mới (gọi khi có sự kiện like/comment/friend request...) */
    void createNotification(Notification notification);

    /** Gửi cùng một thông báo cho nhiều người trong MỘT transaction (vd: bài mới trong nhóm) */
    void notifyUsers(List<Integer> userIds, int actorId, String type, String content, String targetUrl);
}
