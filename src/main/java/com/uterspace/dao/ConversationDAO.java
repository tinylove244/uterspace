package com.uterspace.dao;

import com.uterspace.model.Conversation;
import com.uterspace.model.ConversationMember;

import java.util.List;
import java.util.Map;

/**
 * ConversationDAO — cuộc trò chuyện 1-1 và nhóm chat, thành viên và các mốc đã nhận / đã xem.
 * Kiểm quyền (thành viên, chặn, quyền riêng tư) nằm ở ChatService; DAO chỉ đảm bảo dữ liệu nhất quán.
 */
public interface ConversationDAO {

    /**
     * Mọi hội thoại người dùng là thành viên, mới hoạt động nhất trước; đã nạp: thành viên (kèm User),
     * người kia (1-1), tin cuối (bỏ tin đã xóa phía mình), số tin chưa đọc.
     */
    List<Conversation> getConversationsFor(int userId);

    /** Hội thoại 1-1 giữa hai người, tạo nếu chưa có (an toàn khi hai người mở cùng lúc) */
    Conversation getOrCreateConversation(int userAId, int userBId);

    /** Hội thoại 1-1 đã có giữa hai người (không tạo mới), null nếu chưa có */
    Conversation findDirect(int userAId, int userBId);

    /** Hội thoại theo id (chưa nạp thành viên) */
    Conversation getConversationById(int conversationId);

    /** Hội thoại + thành viên, CHỈ KHI userId là thành viên; ngược lại null (chặn IDOR) */
    Conversation getForMember(int conversationId, int userId);

    boolean isMember(int conversationId, int userId);

    List<Integer> getMemberIds(int conversationId);

    /** Thành viên kèm User, chủ nhóm trước */
    List<ConversationMember> getMembers(int conversationId);

    ConversationMember getMember(int conversationId, int userId);

    // ---------- Nhóm chat ----------

    /** Tạo nhóm: người tạo là OWNER, memberIds là MEMBER (một transaction) */
    Conversation createGroup(int creatorId, String title, List<Integer> memberIds);

    /** Thêm thành viên (bỏ qua người đã có). Trả id những người thực sự được thêm. */
    List<Integer> addMembers(int conversationId, List<Integer> userIds);

    /** Gỡ thành viên. Nếu là chủ nhóm rời đi → chuyển chủ cho người vào sớm nhất; nhóm hết người → xóa nhóm. */
    boolean removeMember(int conversationId, int userId);

    boolean rename(int conversationId, String title);

    // ---------- Mốc đọc / nhận / xóa lịch sử ----------

    /** Đã xem tới upToId (chỉ tăng, không lùi). Đã xem thì cũng đã nhận. Trả mốc mới (hoặc -1 nếu không đổi). */
    int markRead(int conversationId, int userId, int upToId);

    /** Đã nhận tới upToId (chỉ tăng). Trả mốc mới, -1 nếu không đổi. */
    int markDelivered(int conversationId, int userId, int upToId);

    /**
     * Thiết bị của userId vừa trực tuyến: "đã nhận" mọi tin hiện có ở mọi hội thoại.
     * @return conversationId → mốc đã nhận mới (chỉ những hội thoại có thay đổi)
     */
    Map<Integer, Integer> deliverAll(int userId);

    /** Đánh dấu chưa đọc: lùi mốc đã xem về trước tin cuối cùng của người khác */
    boolean markUnread(int conversationId, int userId);

    /** "Xóa cuộc trò chuyện" phía mình: ẩn mọi tin hiện có (người khác vẫn còn) */
    void clearHistory(int conversationId, int userId);

    /** Cập nhật last_message_at (tin mới đẩy hội thoại lên đầu danh sách) */
    void touch(int conversationId);
}
