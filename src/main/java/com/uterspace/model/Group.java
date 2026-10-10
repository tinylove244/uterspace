package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Entity: Group (Nhóm học tập / Câu lạc bộ)
 * category: "STUDY" | "CLUB"      privacy: "PUBLIC" | "PRIVATE"
 * Chủ nhóm xác định bằng GroupMember.role = "OWNER" (xem 030_migration_groups.sql).
 */
@Entity
@Table(name = "groups_tbl")
public class Group {

    public static final String PUBLIC  = "PUBLIC";
    public static final String PRIVATE = "PRIVATE";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "group_id")
    private int groupId;

    private String name;
    private String description;

    private String category = "STUDY";     // "STUDY" | "CLUB"

    private String privacy = PUBLIC;        // "PUBLIC" | "PRIVATE"

    @Column(name = "cover_icon")
    private String coverIcon;    // emoji đại diện nhóm

    @Column(name = "cover_image")
    private String coverImage;   // ảnh bìa (uploads/groups/...), null = gradient

    @Column(name = "member_count")
    private int memberCount;     // số thành viên ACTIVE — chỉ đổi bằng UPDATE nguyên tử trong GroupDAO

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    // Transient: quan hệ của người đang xem với nhóm (null = chưa tham gia)
    @Transient
    private GroupMember myMembership;

    // Transient: số yêu cầu tham gia đang chờ (chỉ nạp cho chủ nhóm)
    @Transient
    private int pendingCount;

    // Transient: chủ nhóm (chỉ nạp ở trang quản trị)
    @Transient
    private User owner;

    public Group() {}

    public Group(int groupId, String name, String description, String category,
                 String coverIcon, int memberCount, LocalDateTime createdAt) {
        this.groupId     = groupId;
        this.name        = name;
        this.description = description;
        this.category    = category;
        this.coverIcon   = coverIcon;
        this.memberCount = memberCount;
        this.createdAt   = createdAt;
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }

    // ---------- Helpers ----------

    public String getCategoryLabel() {
        return "STUDY".equalsIgnoreCase(category) ? "Học tập" : "Câu lạc bộ";
    }

    public String getCategoryClass() {
        return "STUDY".equalsIgnoreCase(category) ? "study" : "club";
    }

    private static final java.util.Map<String, String> ICON_NAMES = new java.util.HashMap<>();
    static {
        ICON_NAMES.put("laptop", "💻"); ICON_NAMES.put("robot", "🤖"); ICON_NAMES.put("shield", "🛡️");
        ICON_NAMES.put("globe", "🌏");  ICON_NAMES.put("house", "🏠"); ICON_NAMES.put("camera", "📷");
        ICON_NAMES.put("book", "📚");   ICON_NAMES.put("music", "🎵"); ICON_NAMES.put("code", "💻");
    }

    /**
     * Biểu tượng để hiển thị. Dữ liệu mẫu cũ lưu tên chữ ("laptop", "robot"...) hoặc emoji bị hỏng thành "?"
     * (chèn thiếu tiền tố N'') → đổi sang emoji, không rõ thì dùng biểu tượng theo loại nhóm.
     */
    public String getIconDisplay() {
        String icon = coverIcon == null ? "" : coverIcon.trim();
        if (icon.isEmpty() || icon.matches("[?]+")) return "STUDY".equalsIgnoreCase(category) ? "📚" : "🎯";
        if (icon.matches("[A-Za-z_-]+")) return ICON_NAMES.getOrDefault(icon.toLowerCase(), "🏷️");
        return icon;
    }

    public boolean isPrivateGroup() {
        return PRIVATE.equals(privacy);
    }

    public String getPrivacyLabel() {
        return isPrivateGroup() ? "Nhóm kín" : "Công khai";
    }

    /** Đường dẫn ảnh bìa (tính từ context path), null nếu dùng gradient */
    public String getCoverUrl() {
        return com.uterspace.util.MediaUrl.of(coverImage);
    }

    public String getFormattedCreatedAt() {
        return createdAt == null ? "" : createdAt.format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
    }

    // ---------- Getters & Setters ----------

    public int getGroupId() { return groupId; }
    public void setGroupId(int groupId) { this.groupId = groupId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public String getPrivacy() { return privacy; }
    public void setPrivacy(String privacy) { this.privacy = privacy; }

    public String getCoverIcon() { return coverIcon; }
    public void setCoverIcon(String coverIcon) { this.coverIcon = coverIcon; }

    public String getCoverImage() { return coverImage; }
    public void setCoverImage(String coverImage) { this.coverImage = coverImage; }

    public int getMemberCount() { return memberCount; }
    public void setMemberCount(int memberCount) { this.memberCount = memberCount; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public GroupMember getMyMembership() { return myMembership; }
    public void setMyMembership(GroupMember myMembership) { this.myMembership = myMembership; }

    public int getPendingCount() { return pendingCount; }
    public User getOwner() { return owner; }
    public void setOwner(User owner) { this.owner = owner; }
    public void setPendingCount(int pendingCount) { this.pendingCount = pendingCount; }
}
