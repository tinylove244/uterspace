package com.uterspace.dao;

import com.uterspace.model.ChatMessage;

import java.util.List;

/**
 * MessageDAO — tin nhắn.
 * Mọi hàm đọc theo "người xem" (viewerId) đã bỏ: tin trước mốc "Xóa cuộc trò chuyện" của người đó và
 * tin người đó đã "Xóa ở phía tôi". Kiểm quyền thành viên nằm ở ChatService.
 */
public interface MessageDAO {

    /** limit tin mới nhất (trả về theo thứ tự cũ → mới) */
    List<ChatMessage> getRecent(int conversationId, int viewerId, int limit);

    /** Tin có id > afterId (đồng bộ bù sau khi mất kết nối / poll dự phòng), tối đa 200 */
    List<ChatMessage> getAfter(int conversationId, int viewerId, int afterId);

    /** limit tin ngay trước beforeId (cuộn lên xem lịch sử), cũ → mới */
    List<ChatMessage> getBefore(int conversationId, int viewerId, int beforeId, int limit);

    /** Khoảng tin quanh messageId (nhảy tới kết quả tìm kiếm / tin được trả lời), cũ → mới */
    List<ChatMessage> getAround(int conversationId, int viewerId, int messageId, int half);

    /** Một tin kèm người gửi và hội thoại, null nếu không có */
    ChatMessage getById(int messageId);

    /**
     * Lưu tin mới + đẩy hội thoại lên đầu + người gửi "đã xem" tin của chính mình — MỘT transaction.
     * Nếu draft.clientId đã tồn tại (trình duyệt gửi lại sau lỗi mạng) → trả lại tin cũ, không tạo bản trùng.
     */
    ChatMessage send(int conversationId, int senderId, ChatMessage draft);

    /** Tin hệ thống trong nhóm ("A đã thêm B vào nhóm") */
    ChatMessage system(int conversationId, int actorId, String text);

    boolean edit(int messageId, String content);

    /** Thu hồi với mọi người: xóa nội dung + file. Trả đường dẫn file cũ (để xóa khỏi đĩa) hoặc null. */
    String recall(int messageId);

    /** "Xóa ở phía tôi" */
    void hide(int messageId, int userId);

    /**
     * Thả / đổi / gỡ cảm xúc: chưa có → thêm; khác → đổi; trùng → gỡ.
     * @return cảm xúc hiện tại của người này với tin (null = đã gỡ)
     */
    String react(int messageId, int userId, String emoji);

    /** Ghim (pinnedBy != null) hoặc bỏ ghim (pinnedBy == null) */
    boolean setPinned(int messageId, Integer pinnedBy);

    /** Tin đang ghim mà người xem còn thấy, mới ghim nhất trước */
    List<ChatMessage> getPinned(int conversationId, int viewerId);

    /** Tìm trong nội dung / tên file của hội thoại, không phân biệt dấu, mới nhất trước */
    List<ChatMessage> search(int conversationId, int viewerId, String query, int limit);

    /** Nạp cảm xúc (kèm tên người thả) và tin được trả lời cho danh sách */
    void attachExtras(List<ChatMessage> messages);

    /** Tổng số tin chưa đọc của người dùng ở mọi hội thoại (huy hiệu Tin nhắn) */
    int getUnreadMessageCount(int userId);

    /** Số tin chưa đọc của người dùng trong một hội thoại */
    int unreadIn(int conversationId, int userId);

    /** Id tin lớn nhất của hội thoại (0 nếu chưa có tin) */
    int maxMessageId(int conversationId);
}
