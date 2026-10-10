package com.uterspace.util;

import com.uterspace.dao.GroupDAO;
import com.uterspace.dao.GroupDAOImpl;
import com.uterspace.model.Group;
import com.uterspace.model.GroupMember;

/**
 * GroupPermission — kiểm quyền nhóm TẬP TRUNG (plan mục 4.1, 4.4).
 * Vai trò luôn đọc lại từ DB ở mỗi request; Controller không bao giờ tin groupId/vai trò do client gửi.
 *
 *   Hành động                                  Chủ nhóm  Thành viên  Người ngoài
 *   Xem thông tin nhóm                            ✓          ✓          ✓
 *   Xem bài trong nhóm                            ✓          ✓       công khai ✓ / kín ✗
 *   Đăng bài, bình luận, thích                    ✓          ✓          ✗
 *   Xóa bài người khác, duyệt/xóa thành viên,
 *   sửa nhóm, chuyển quyền, xóa nhóm              ✓          ✗          ✗
 */
public final class GroupPermission {

    private static final GroupDAO GROUP_DAO = new GroupDAOImpl();

    private GroupPermission() { }

    /** Quan hệ hiện tại (đọc DB), null nếu không liên quan */
    public static GroupMember membershipOf(int groupId, int userId) {
        return GROUP_DAO.getMembership(groupId, userId);
    }

    public static boolean isMember(GroupMember m) {
        return m != null && m.isActive();
    }

    public static boolean isOwner(GroupMember m) {
        return m != null && m.isOwner();
    }

    public static boolean canViewPosts(Group group, GroupMember m) {
        return group != null && (!group.isPrivateGroup() || isMember(m));
    }

    /** Đăng bài / bình luận / thích trong nhóm */
    public static boolean canPost(int groupId, int userId) {
        return isMember(membershipOf(groupId, userId));
    }

    /** Chủ nhóm của nhóm chứa bài (được xóa bài người khác trong nhóm) */
    public static boolean isOwnerOf(int groupId, int userId) {
        return isOwner(membershipOf(groupId, userId));
    }
}
