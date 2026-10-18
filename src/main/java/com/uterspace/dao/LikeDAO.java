package com.uterspace.dao;

/** LikeDAO — Interface cho thao tác Like */
public interface LikeDAO {

    /** Kiểm tra user đã like bài viết chưa */
    boolean isLikedBy(int postId, int userId);

    /** Đặt likedByCurrentUser cho cả danh sách bài bằng 1 truy vấn — thay vòng lặp isLikedBy từng bài */
    void markLikedBy(java.util.List<com.uterspace.model.Post> posts, int userId);

    /**
     * Toggle like: nếu chưa like → INSERT (tăng like_count),
     * nếu đã like → DELETE (giảm like_count).
     * @return true nếu kết quả là "đã like", false nếu "đã unlike"
     */
    boolean toggleLike(int postId, int userId);

    /** Lấy số like hiện tại của bài viết (đọc trực tiếp từ cột like_count) */
    int getLikeCount(int postId);
}
