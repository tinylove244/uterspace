package com.uterspace.dao;

import com.uterspace.model.FriendSuggestion;
import com.uterspace.model.Friendship;
import com.uterspace.model.User;

import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * FriendshipDAO — quan hệ bạn bè.
 *
 * Quy tắc (migration 060): MỖI CẶP NGƯỜI CHỈ CÓ TỐI ĐA MỘT DÒNG trong friendships (UNIQUE trên cặp không phân biệt chiều).
 *   pending  = requester đã gửi lời mời, receiver chưa trả lời
 *   accepted = đã là bạn bè
 * Từ chối / thu hồi lời mời / hủy kết bạn đều XÓA dòng, nên sau đó gửi lại được bình thường.
 * Kiểm tra chặn và quyền riêng tư nằm ở RelationService (tầng trên), DAO chỉ lo dữ liệu nhất quán.
 */
public interface FriendshipDAO {

    /** Kết quả gửi lời mời */
    enum RequestResult { SENT, AUTO_ACCEPTED, ALREADY_SENT, ALREADY_FRIENDS }

    // ---------- Đọc ----------

    /** Danh sách bạn bè (đã accepted) của userId */
    List<User> getFriendsOf(int userId);

    /** Id bạn bè của userId */
    List<Integer> getFriendIds(int userId);

    int countFriends(int userId);

    /** Các quan hệ đã accepted của userId (kèm cả hai người) — để biết "bạn bè từ" */
    List<Friendship> getFriendships(int userId);

    /** Lời mời đang chờ GỬI TỚI userId (mới nhất trước) */
    List<Friendship> getPendingRequestsFor(int userId);

    int countPendingFor(int userId);

    /** Lời mời userId ĐÃ GỬI đang chờ người khác trả lời */
    List<Friendship> getSentRequests(int userId);

    /** Dòng quan hệ giữa hai người (bất kể chiều), null nếu chưa có gì */
    Friendship findBetween(int a, int b);

    boolean areFriends(int userId1, int userId2);

    Friendship getFriendshipById(int fsId);

    /** Số bạn chung giữa userId và từng người trong others */
    Map<Integer, Integer> mutualCounts(int userId, Collection<Integer> others);

    /**
     * Gợi ý kết bạn: bạn của bạn (nhiều bạn chung xếp trước), sau đó người cùng khu vực / thành viên mới.
     * Đã loại: chính mình, bạn bè, người đang có lời mời hai chiều, người bị chặn / chặn mình, tài khoản bị khóa,
     * người đặt "Không ai được gửi lời mời", người đặt "Chỉ bạn của bạn bè" mà không có bạn chung.
     */
    List<FriendSuggestion> getSuggestions(int userId, int limit);

    /** Giữ tương thích code cũ: danh sách người trong getSuggestions */
    List<User> getSuggestedFriends(int userId);

    // ---------- Ghi (mỗi hàm là một transaction, an toàn khi gửi trùng / gửi đồng thời) ----------

    /**
     * Gửi lời mời from → to.
     * Nếu to ĐÃ gửi lời mời cho from trước đó → tự chấp nhận luôn (AUTO_ACCEPTED), không tạo dòng thứ hai.
     */
    RequestResult sendRequest(int from, int to);

    /** receiver chấp nhận lời mời của requester. false nếu không có lời mời đang chờ đúng chiều. */
    boolean accept(int receiverId, int requesterId);

    /** receiver từ chối lời mời của requester (xóa dòng pending) */
    boolean decline(int receiverId, int requesterId);

    /** requester thu hồi lời mời đã gửi cho receiver (xóa dòng pending) */
    boolean cancel(int requesterId, int receiverId);

    /** Hủy kết bạn (xóa dòng accepted, bất kể ai là người gửi lời mời ban đầu) */
    boolean unfriend(int a, int b);
}
