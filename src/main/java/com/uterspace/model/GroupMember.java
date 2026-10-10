package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Entity: GroupMember — Quan hệ nhiều-nhiều giữa User và Group
 * role:   "OWNER" (đúng 1 người/nhóm) | "ADMIN" (để dành cho phó nhóm) | "MEMBER"
 * status: "ACTIVE" | "PENDING" (chờ chủ nhóm duyệt) | "BANNED" (bị xóa khỏi nhóm, không vào lại được)
 */
@Entity
@Table(name = "group_members")
@IdClass(GroupMemberId.class)
public class GroupMember {

    public static final String ROLE_OWNER  = "OWNER";
    public static final String ROLE_ADMIN  = "ADMIN";
    public static final String ROLE_MEMBER = "MEMBER";

    public static final String STATUS_ACTIVE  = "ACTIVE";
    public static final String STATUS_PENDING = "PENDING";
    public static final String STATUS_BANNED  = "BANNED";

    @Id
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_id")
    private Group group;

    @Id
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Transient
    private int groupId;

    @Transient
    private int userId;

    private String role = ROLE_MEMBER;

    private String status = STATUS_ACTIVE;

    @Column(name = "joined_at")
    private LocalDateTime joinedAt;

    public GroupMember() {}

    public GroupMember(int groupId, int userId, String role, LocalDateTime joinedAt) {
        this.groupId  = groupId;
        this.userId   = userId;
        this.role     = role;
        this.joinedAt = joinedAt;
    }

    @PrePersist
    void onCreate() {
        if (joinedAt == null) joinedAt = LocalDateTime.now();
    }

    // ---------- Helpers ----------

    public boolean isAdmin()   { return ROLE_ADMIN.equalsIgnoreCase(role); }
    public boolean isOwner()   { return ROLE_OWNER.equals(role) && isActive(); }
    public boolean isActive()  { return STATUS_ACTIVE.equals(status); }
    public boolean isPending() { return STATUS_PENDING.equals(status); }
    public boolean isBanned()  { return STATUS_BANNED.equals(status); }

    public String getRoleLabel() {
        if (ROLE_OWNER.equals(role)) return "Chủ nhóm";
        if (ROLE_ADMIN.equals(role)) return "Phó nhóm";
        return "Thành viên";
    }

    public String getFormattedJoinedAt() {
        return joinedAt == null ? "" : joinedAt.format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
    }

    // ---------- Getters & Setters ----------

    public int getGroupId() {
        if (group != null) return group.getGroupId();
        return groupId;
    }
    public void setGroupId(int groupId) { this.groupId = groupId; }

    public int getUserId() {
        if (user != null) return user.getUserId();
        return userId;
    }
    public void setUserId(int userId) { this.userId = userId; }

    public Group getGroup() { return group; }
    public void setGroup(Group group) { this.group = group; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getJoinedAt() { return joinedAt; }
    public void setJoinedAt(LocalDateTime joinedAt) { this.joinedAt = joinedAt; }
}
