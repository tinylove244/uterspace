package com.uterspace.dao;

import com.uterspace.model.Story;
import com.uterspace.model.StoryRing;

import java.time.LocalDateTime;
import java.util.List;

/**
 * StoryDAO — Tin (Stories) 24 giờ.
 * Quy tắc xem: chủ tin + bạn bè đã chấp nhận; tin hết hạn (expires_at <= bây giờ) coi như không tồn tại.
 */
public interface StoryDAO {

    /** Tạo tin mới, hết hạn sau Story.LIFETIME_HOURS giờ */
    Story create(int userId, String mediaPath, String mediaType, String caption, Integer durationSec);

    /** Số tin còn hạn của một người (giới hạn số tin đăng trong 24 giờ) */
    int countActive(int userId);

    /**
     * Các vòng tin trên thanh "Tin" của người xem: của chính mình (đứng đầu) + bạn bè có tin còn hạn.
     * Thứ tự: mình → bạn bè còn tin chưa xem (mới nhất trước) → bạn bè đã xem hết.
     */
    List<StoryRing> getRings(int viewerId);

    /**
     * Tin còn hạn của ownerId theo thứ tự đăng (cũ → mới), đã gắn seen theo viewer;
     * chủ tin xem thì gắn thêm viewCount. Trả null nếu viewer không có quyền xem.
     */
    List<Story> getActiveStoriesOf(int ownerId, int viewerId);

    /** Lấy tin (kèm tác giả) còn hạn, null nếu không có / đã hết hạn */
    Story getActiveStory(int storyId);

    /** Người xem có được xem tin của ownerId không (chính chủ hoặc bạn bè) */
    boolean canViewStoriesOf(int ownerId, int viewerId);

    /** Ghi nhận lượt xem (mỗi người một lần, bỏ qua chủ tin). Trả true nếu là lượt xem mới. */
    boolean markViewed(int storyId, int viewerId);

    /** Người đã xem một tin (người thả tim trước, rồi mới nhất trước): mỗi dòng [User, LocalDateTime viewedAt, Boolean đã thả tim] */
    List<Object[]> getViewers(int storyId);

    // ---------- Thả tim (migration 090) ----------

    /**
     * Thả / bỏ tim một tin còn hạn (người xem có quyền, không phải chủ tin).
     * @return true = vừa thả tim, false = vừa bỏ tim, null = không có quyền / tin không còn
     */
    Boolean toggleReaction(int storyId, int userId);

    // ---------- Kho lưu trữ (migration 090) ----------

    /** Tin ĐÃ HẾT HẠN của chính chủ (mới nhất trước), kèm viewCount + reactionCount */
    List<Story> getArchive(int ownerId, int offset, int limit);

    /** Số tin trong kho lưu trữ */
    int countArchive(int ownerId);

    /**
     * Xóa tin của chính chủ.
     * @return đường dẫn file để Controller xóa, hoặc null nếu tin không tồn tại / không phải của ownerId
     */
    String delete(int storyId, int ownerId);

    /** Xóa các tin hết hạn trước mốc before (kèm lượt xem). Trả về đường dẫn file để xóa khỏi đĩa. */
    List<String> purgeExpired(LocalDateTime before);
}
