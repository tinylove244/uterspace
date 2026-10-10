package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity: User
 * Ánh xạ sang bảng users trong Database.
 */
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private int userId;

    @Column(name = "first_name")
    private String firstName;

    @Column(name = "last_name")
    private String lastName;

    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    private String avatar;       // tên file ảnh trong assets/images/, null nếu dùng initials

    private String role;         // "USER" | "ADMIN"

    @Column(name = "created_at")
    private LocalDateTime createdAt;


    private String bio;          // Giới thiệu bản thân
    private String location;     // Nơi ở / Thành phố
    private String website;      // Link cá nhân (portfolio, LinkedIn, ...)

    @Column(name = "cover_image")
    private String coverImage;   // ảnh bìa, null nếu dùng gradient mặc định

    private String status = STATUS_ACTIVE;   // "ACTIVE" | "LOCKED"

    @Column(name = "locked_reason")
    private String lockedReason;

    /** Lần hoạt động gần nhất (migration 060) — trạng thái online / "hoạt động x phút trước" */
    @Column(name = "last_active_at")
    private LocalDateTime lastActiveAt;

    public LocalDateTime getLastActiveAt() { return lastActiveAt; }
    public void setLastActiveAt(LocalDateTime lastActiveAt) { this.lastActiveAt = lastActiveAt; }

    public static final String STATUS_ACTIVE = "ACTIVE";
    public static final String STATUS_LOCKED = "LOCKED";
    public static final String ROLE_USER  = "USER";
    public static final String ROLE_ADMIN = "ADMIN";

    public User() {}

    public User(int userId, String firstName, String lastName, String email,
                String role, LocalDateTime createdAt) {
        this.userId = userId;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.role = role;
        this.createdAt = createdAt;
    }

    // ---------- Helpers ----------

    public String getFormattedJoinDate() {
        if (createdAt == null) return "";
        return String.format("%02d/%d", createdAt.getMonthValue(), createdAt.getYear());
    }

    /** Tên đầy đủ */
    public String getFullName() {
        return firstName + " " + lastName;
    }

    /** 2 chữ cái viết tắt để hiển thị avatar initials */
    public String getInitials() {
        String f = (firstName != null && !firstName.isEmpty()) ? firstName.substring(0, 1) : "";
        String l = (lastName  != null && !lastName.isEmpty())  ? lastName.substring(0, 1)  : "";
        return (f + l).toUpperCase();
    }

    /** Kiểm tra có phải Admin không */
    public boolean isAdmin() {
        return "ADMIN".equalsIgnoreCase(role);
    }

    /** Tài khoản bị khóa (JSP: ${u.locked}) */
    public boolean isLocked() {
        return STATUS_LOCKED.equals(status);
    }

    /** Đường dẫn ảnh đại diện (tính từ context path) — JSP: ${ctx}${u.avatarUrl} */
    public String getAvatarUrl() {
        return com.uterspace.util.MediaUrl.of(avatar);
    }

    /** Đường dẫn ảnh bìa (tính từ context path), null nếu dùng gradient mặc định */
    public String getCoverUrl() {
        return com.uterspace.util.MediaUrl.of(coverImage);
    }

    // ---------- Getters & Setters ----------

    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }

    public String getFirstName() { return firstName; }
    public void setFirstName(String firstName) { this.firstName = firstName; }

    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { this.lastName = lastName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }

    public String getAvatar() { return avatar; }
    public void setAvatar(String avatar) { this.avatar = avatar; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public String getBio() { return bio; }
    public void setBio(String bio) { this.bio = bio; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public String getWebsite() { return website; }
    public void setWebsite(String website) { this.website = website; }

    public String getCoverImage() { return coverImage; }
    public void setCoverImage(String coverImage) { this.coverImage = coverImage; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getLockedReason() { return lockedReason; }
    public void setLockedReason(String lockedReason) { this.lockedReason = lockedReason; }
}

