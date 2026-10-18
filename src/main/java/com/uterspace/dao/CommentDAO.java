package com.uterspace.dao;

import com.uterspace.model.Comment;
import com.uterspace.model.Post;
import java.util.List;

/** CommentDAO — Interface cho thao tác Comment */
public interface CommentDAO {

    /** Lấy tất cả comment của 1 bài viết, kèm author */
    List<Comment> getCommentsByPostId(int postId);

    /** Gắn bình luận (kèm author) cho cả danh sách bài bằng 1 truy vấn — thay vòng lặp getCommentsByPostId từng bài */
    void attachComments(List<Post> posts);

    /**
     * Thêm comment mới vào bài viết.
     * Đồng thời tăng comment_count trong bảng posts.
     * @return Comment với commentId thật
     */
    Comment addComment(int postId, int userId, String content);

    /** Lấy 1 bình luận kèm tác giả và bài viết, null nếu không có */
    Comment getCommentById(int commentId);

    /** Xóa bình luận (admin xử lý báo cáo) và giảm comment_count của bài */
    boolean deleteComment(int commentId);
}
