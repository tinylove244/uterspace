package com.uterspace.dao;

import com.uterspace.model.User;
import java.util.List;

/**
 * UserDAO — Interface cho các thao tác dữ liệu liên quan đến User.
 * Chữ ký method khớp với MockDataUtil để Controller không cần đổi cấu trúc.
 */
public interface UserDAO {

    /** Lấy tất cả user trong hệ thống */
    List<User> getAllUsers();

    /** Lấy user theo ID, trả null nếu không tồn tại */
    User getUserById(int userId);

    /**
     * Tìm user theo email — dùng cho login và kiểm tra email đã tồn tại.
     * @param email Email người dùng nhập vào
     * @return User tìm được hoặc null
     */
    User findByEmail(String email);

    /**
     * Tạo user mới trong DB.
     * password_hash phải được set trước khi gọi (dùng PasswordUtil.hashPassword).
     * @return User với userId thật được sinh bởi IDENTITY(1,1)
     */
    User createUser(User user);

    /**
     * Cập nhật thông tin profile của user.
     * @return true nếu UPDATE thành công
     */
    boolean updateProfile(int userId, String bio, String website, String location);

    /**
     * Cập nhật ảnh đại diện (avatar)
     */
    boolean updateAvatar(int userId, String avatarPath);

    /**
     * Cập nhật ảnh bìa (cover_image)
     */
    boolean updateCover(int userId, String coverPath);

    // ---------- Quản trị (plan mục 6) ----------

    /**
     * Tìm người dùng theo tên/email, lọc theo filter: all | active | locked | admin. Phân trang (page từ 1).
     */
    List<User> searchUsers(String query, String filter, int page, int pageSize);

    int countSearchUsers(String query, String filter);

    /** Khóa / mở khóa tài khoản. reason chỉ dùng khi khóa. */
    boolean setStatus(int userId, String status, String reason);

    /** Đổi vai trò USER ↔ ADMIN */
    boolean setRole(int userId, String role);

    /** Số admin đang hoạt động (chặn hạ/khóa admin cuối cùng) */
    int countActiveAdmins();

    int countUsers();

    /** Thời điểm đăng ký của các tài khoản tạo từ mốc since — Controller gom theo ngày (biểu đồ dashboard) */
    List<java.time.LocalDateTime> getCreatedSince(java.time.LocalDateTime since);

    /** Người dùng đăng ký gần nhất */
    List<User> getNewest(int limit);

    /** Ghi users.last_active_at = bây giờ (Presence gọi, có giới hạn tần suất) */
    void touchLastActive(int userId);

    /** Đổi mật khẩu (passwordHash đã băm bằng PasswordUtil) */
    boolean updatePasswordHash(int userId, String passwordHash);
}
