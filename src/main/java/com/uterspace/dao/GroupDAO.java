package com.uterspace.dao;

import com.uterspace.model.Group;
import com.uterspace.model.GroupMember;
import java.util.List;

/**
 * GroupDAO — Nhóm (bảng groups_tbl + group_members), plan mục 4.
 * DAO KHÔNG kiểm quyền — Controller kiểm bằng GroupPermission trước khi gọi.
 */
public interface GroupDAO {

    Group getGroupById(int groupId);

    /** Quan hệ của user với nhóm (role, status), null nếu chưa từng tham gia/xin vào */
    GroupMember getMembership(int groupId, int userId);

    /** Nhóm user đang là thành viên ACTIVE (kèm myMembership), chủ nhóm trước */
    List<Group> getGroupsOf(int userId);

    /** Nhóm user đã gửi yêu cầu, đang chờ duyệt */
    List<Group> getPendingGroupsOf(int userId);

    /** Khám phá: nhóm user chưa là thành viên ACTIVE, tìm theo tên/mô tả, phân trang (page bắt đầu từ 1) */
    List<Group> explore(int userId, String query, int page, int pageSize);
    int countExplore(int userId, String query);

    /** Thành viên theo trạng thái (kèm user), chủ nhóm đứng đầu */
    List<GroupMember> getMembers(int groupId, String status);

    /** Tạo nhóm + người tạo là OWNER trong MỘT transaction */
    Group createGroup(Group group, int ownerId);

    /**
     * Xin tham gia: nhóm công khai → ACTIVE ngay, nhóm kín → PENDING.
     * @return trạng thái sau cùng; null nếu đã có hàng (đang là thành viên / đang chờ / bị chặn)
     */
    String join(int groupId, int userId, boolean privateGroup);

    /** Rời nhóm hoặc hủy yêu cầu đang chờ (xóa hàng). Không dùng cho chủ nhóm. */
    boolean leave(int groupId, int userId);

    /** Duyệt yêu cầu: PENDING → ACTIVE */
    boolean approve(int groupId, int userId);

    /** Từ chối yêu cầu: xóa hàng PENDING */
    boolean reject(int groupId, int userId);

    /** Xóa thành viên ACTIVE khỏi nhóm và chặn vào lại (→ BANNED) */
    boolean kick(int groupId, int userId);

    /** Bỏ chặn: xóa hàng BANNED để người đó xin vào lại được */
    boolean unban(int groupId, int userId);

    /** Chuyển quyền chủ nhóm trong MỘT transaction: chủ cũ → MEMBER, người nhận (ACTIVE) → OWNER */
    boolean transferOwnership(int groupId, int fromUserId, int toUserId);

    /** Sửa thông tin nhóm. Nhóm kín chuyển sang công khai thì duyệt luôn các yêu cầu đang chờ. */
    void updateGroup(int groupId, String name, String description, String category, String privacy, String coverIcon);

    void updateCover(int groupId, String coverPath);

    /**
     * Xóa nhóm trong MỘT transaction, đúng thứ tự khóa ngoại:
     * bình luận của bài nhóm → lượt thích → bài đã lưu → bài của nhóm → thành viên → nhóm.
     * @return đường dẫn ảnh/video của các bài đã xóa, để Controller xóa file trên đĩa
     */
    List<String> deleteGroup(int groupId);

    /** Số nhóm (dashboard admin) */
    int countGroups();

    /** Mọi nhóm cho trang quản trị (tìm theo tên / mô tả), mới nhất trước, kèm chủ nhóm */
    List<Group> adminList(String query, int page, int pageSize);

    int countAdminList(String query);
}
