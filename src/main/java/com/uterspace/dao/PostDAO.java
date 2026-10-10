package com.uterspace.dao;

import com.uterspace.model.Post;
import com.uterspace.model.Comment;
import java.util.List;

/**
 * PostDAO — Interface cho các thao tác dữ liệu liên quan đến Post.
 */
public interface PostDAO {

    /** Lấy tất cả bài viết, kèm author (User) */
    List<Post> getAllPosts();

    /**
     * Lấy feed của user: bài của bản thân + bài của bạn bè, mới nhất trước.
     * Kèm author và trạng thái likedByCurrentUser.
     */
    List<Post> getFeedPosts(int userId);

    /**
     * Bài trên trang cá nhân của profileUserId.
     * Chính chủ xem: thấy cả bài tự ẩn / bị admin ẩn (trừ bài admin đã xóa mềm).
     * Người khác xem: chỉ bài được phép thấy theo quy tắc VISIBLE.
     */
    List<Post> getProfilePosts(int profileUserId, int viewerId);

    /** Số bài của user (không tính bài admin đã xóa mềm) — thẻ hồ sơ ở sidebar */
    int countPostsByUser(int userId);

    /**
     * Bài của một nhóm (trang nhóm). KHÔNG dùng quy tắc VISIBLE vì người ngoài được xem nhóm công khai —
     * Controller phải kiểm GroupPermission.canViewPosts trước khi gọi.
     */
    List<Post> getGroupPosts(int groupId);

    /** Gắn tên nhóm (transient groupName) cho các bài thuộc nhóm — nhãn trên post card */
    void attachGroupNames(List<Post> posts);

    /**
     * Bài video người xem được phép thấy (quy tắc VISIBLE), mới nhất trước, phân trang (page bắt đầu từ 1).
     * friendsOnly = true: chỉ video của bạn bè.
     */
    List<Post> getVideoPosts(int viewerId, boolean friendsOnly, int page, int pageSize);

    int countVideoPosts(int viewerId, boolean friendsOnly);

    /** Lấy 1 bài viết theo ID — KHÔNG lọc quyền xem, chỉ dùng để kiểm tra quyền sở hữu */
    Post getPostById(int postId);

    /** Người xem có được thấy bài này không (quy tắc VISIBLE) — chặn IDOR ở like/bình luận/chia sẻ/lưu */
    boolean canView(int postId, int viewerId);

    /**
     * Tạo bài viết mới.
     * @return Post với postId thật từ IDENTITY(1,1)
     */
    Post createPost(Post post);

    /**
     * Xóa bài viết theo postId.
     * Controller phải kiểm tra quyền sở hữu trước khi gọi.
     */
    void deletePost(int postId);

    /**
     * Cập nhật nội dung (content) và visibility của bài viết.
     * @return Post sau khi merge
     */
    Post updatePost(int postId, String content, String visibility);

    // ---------- Chia sẻ kèm bình luận (Quote Share) ----------

    /**
     * Tạo bài chia sẻ trỏ tới bài gốc và tăng share_count của bài gốc (1 transaction).
     * Controller phải tự chuyển bài chia sẻ về bài gốc và kiểm tra quyền trước khi gọi.
     * @param content bình luận kèm theo, có thể rỗng
     */
    Post sharePost(int userId, int originalPostId, String content, String visibility, boolean hiddenByOwner);

    /**
     * Nạp bài gốc (kèm author) cho các bài chia sẻ trong danh sách, gán vào Post.sharedPost.
     * Bài gốc đã xoá hoặc người xem không có quyền xem → sharedPost để null.
     */
    void attachSharedPosts(List<Post> posts, int viewerId);

    // ---------- Hashtag ----------

    /**
     * Các bài viết chứa #tag mà người xem được phép xem, mới nhất trước.
     * @param tag tên thẻ không có '#' (đã qua HashtagUtil.normalize)
     */
    List<Post> getPostsByHashtag(String tag, int viewerId);

    /** Nội dung các bài viết gần đây người xem được phép xem — dùng để tính hashtag thịnh hành */
    List<String> getRecentContentsVisibleTo(int viewerId, int limit);

    // ---------- Ẩn bài / kiểm duyệt (plan mục 6) ----------

    /**
     * Chủ bài tự ẩn / hiện lại bài của mình. Chỉ cập nhật khi ownerId đúng là tác giả.
     * @return true nếu cập nhật được
     */
    boolean setHiddenByOwner(int postId, int ownerId, boolean hidden);

    /** Admin đổi moderation_status: ACTIVE (khôi phục) | HIDDEN (ẩn) | DELETED (xóa mềm) */
    boolean setModerationStatus(int postId, String status);

    /**
     * Danh sách bài cho trang admin, mới nhất trước, phân trang.
     * filter: all | active | hidden | deleted | owner-hidden | reported; query tìm trong nội dung/tên/email tác giả.
     */
    List<Post> adminSearch(String query, String filter, int page, int pageSize);

    int countAdminSearch(String query, String filter);

    /** Tổng số bài chưa bị xóa mềm */
    int countPosts();

    /** Thời điểm tạo các bài từ mốc since — biểu đồ dashboard */
    List<java.time.LocalDateTime> getCreatedSince(java.time.LocalDateTime since);
}
