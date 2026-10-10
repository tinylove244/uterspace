package com.uterspace.dao;

import com.uterspace.model.Post;
import java.util.List;

/**
 * SavedPostDAO — Interface cho thao tác bài viết đã lưu.
 * Trả List<Post> (giống MockDataUtil) nhưng mỗi Post.savedAt được set từ DB.
 */
public interface SavedPostDAO {

    /**
     * Lấy danh sách bài viết đã lưu của user.
     * Mỗi Post trong kết quả có post.getSavedAt() != null.
     */
    List<Post> getSavedPosts(int userId);

    /** Kiểm tra user đã lưu bài viết chưa */
    boolean isSaved(int postId, int userId);

    /** Lưu bài viết (INSERT vào saved_posts) */
    void savePost(int postId, int userId);

    /** Bỏ lưu bài viết (DELETE từ saved_posts) */
    void unsavePost(int postId, int userId);
}
