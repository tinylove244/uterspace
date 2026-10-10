package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity: UserSettings — quyền riêng tư + tùy chọn thông báo của một người (bảng user_settings, migration 060).
 * Chưa có dòng trong DB = dùng mặc định của constructor (UserSettingsDAO.get trả object mặc định, chỉ lưu khi người dùng bấm Lưu).
 */
@Entity
@Table(name = "user_settings")
public class UserSettings {

    // Ai được gửi lời mời kết bạn
    public static final String FR_EVERYONE           = "EVERYONE";
    public static final String FR_FRIENDS_OF_FRIENDS = "FRIENDS_OF_FRIENDS";
    public static final String FR_NOBODY             = "NOBODY";
    // Ai được nhắn tin
    public static final String MSG_EVERYONE = "EVERYONE";
    public static final String MSG_FRIENDS  = "FRIENDS";

    // Nhóm thông báo (dùng cho tùy chọn + tab ở trang Thông báo)
    public static final String CAT_FRIEND      = "friend";
    public static final String CAT_INTERACTION = "interaction";
    public static final String CAT_GROUP       = "group";
    public static final String CAT_MESSAGE     = "message";
    public static final String CAT_ACCOUNT     = "account";

    @Id
    @Column(name = "user_id")
    private int userId;

    @Column(name = "friend_request_policy") private String friendRequestPolicy = FR_EVERYONE;
    @Column(name = "message_policy")        private String messagePolicy = MSG_EVERYONE;
    @Column(name = "show_online")           private boolean showOnline = true;

    @Column(name = "notif_friend")      private boolean notifFriend = true;
    @Column(name = "notif_interaction") private boolean notifInteraction = true;
    @Column(name = "notif_group")       private boolean notifGroup = true;
    @Column(name = "notif_message")     private boolean notifMessage = true;

    @Column(name = "push_friend")      private boolean pushFriend = true;
    @Column(name = "push_interaction") private boolean pushInteraction = false;
    @Column(name = "push_group")       private boolean pushGroup = false;
    @Column(name = "push_message")     private boolean pushMessage = true;
    @Column(name = "push_account")     private boolean pushAccount = true;

    // Migration 090: lưu trữ tin · bảng tin cá nhân hóa · ẩn bài tiêu cực · bộ lọc từ khóa
    public static final String FEED_SMART  = "SMART";
    public static final String FEED_LATEST = "LATEST";
    /** Bộ lọc nội dung: tối đa ngần này mục, mỗi mục tối đa 50 ký tự */
    public static final int FILTER_MAX_ITEMS = 100;

    @Column(name = "archive_stories") private boolean archiveStories = true;
    @Column(name = "feed_mode")       private String feedMode = FEED_SMART;
    @Column(name = "hide_negative")   private boolean hideNegative;
    @Column(name = "content_filter")  private String contentFilter;   // mỗi dòng một từ khóa / cụm từ / emoji

    @Column(name = "updated_at") private LocalDateTime updatedAt;

    public UserSettings() { }
    public UserSettings(int userId) { this.userId = userId; }

    /** Nhóm chức năng của một loại thông báo */
    public static String categoryOf(String type) {
        if (type == null) return CAT_ACCOUNT;
        switch (type) {
            case "FRIEND_REQUEST": case "FRIEND_ACCEPT":                       return CAT_FRIEND;
            case "LIKE": case "COMMENT": case "SHARE": case "STORY_REACT":      return CAT_INTERACTION;
            case "GROUP_INVITE": case "GROUP_JOIN_REQUEST": case "GROUP_APPROVED": case "GROUP_POST":
                                                                                return CAT_GROUP;
            case "MESSAGE":                                                     return CAT_MESSAGE;
            default:                                                            return CAT_ACCOUNT;   // ACCOUNT, SYSTEM
        }
    }

    /** Có tạo thông báo trong ứng dụng cho nhóm này không (nhóm Tài khoản luôn bật vì lý do bảo mật) */
    public boolean wantsInApp(String category) {
        switch (category) {
            case CAT_FRIEND:      return notifFriend;
            case CAT_INTERACTION: return notifInteraction;
            case CAT_GROUP:       return notifGroup;
            case CAT_MESSAGE:     return notifMessage;
            default:              return true;
        }
    }

    /** Có hiện thông báo đẩy trên màn hình cho nhóm này không */
    public boolean wantsPush(String category) {
        switch (category) {
            case CAT_FRIEND:      return pushFriend;
            case CAT_INTERACTION: return pushInteraction;
            case CAT_GROUP:       return pushGroup;
            case CAT_MESSAGE:     return pushMessage;
            default:              return pushAccount;
        }
    }

    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }
    public String getFriendRequestPolicy() { return friendRequestPolicy; }
    public void setFriendRequestPolicy(String v) { this.friendRequestPolicy = v; }
    public String getMessagePolicy() { return messagePolicy; }
    public void setMessagePolicy(String v) { this.messagePolicy = v; }
    public boolean isShowOnline() { return showOnline; }
    public void setShowOnline(boolean v) { this.showOnline = v; }
    public boolean isNotifFriend() { return notifFriend; }
    public void setNotifFriend(boolean v) { this.notifFriend = v; }
    public boolean isNotifInteraction() { return notifInteraction; }
    public void setNotifInteraction(boolean v) { this.notifInteraction = v; }
    public boolean isNotifGroup() { return notifGroup; }
    public void setNotifGroup(boolean v) { this.notifGroup = v; }
    public boolean isNotifMessage() { return notifMessage; }
    public void setNotifMessage(boolean v) { this.notifMessage = v; }
    public boolean isPushFriend() { return pushFriend; }
    public void setPushFriend(boolean v) { this.pushFriend = v; }
    public boolean isPushInteraction() { return pushInteraction; }
    public void setPushInteraction(boolean v) { this.pushInteraction = v; }
    public boolean isPushGroup() { return pushGroup; }
    public void setPushGroup(boolean v) { this.pushGroup = v; }
    public boolean isPushMessage() { return pushMessage; }
    public void setPushMessage(boolean v) { this.pushMessage = v; }
    public boolean isPushAccount() { return pushAccount; }
    public void setPushAccount(boolean v) { this.pushAccount = v; }
    public boolean isArchiveStories() { return archiveStories; }
    public void setArchiveStories(boolean v) { this.archiveStories = v; }
    public String getFeedMode() { return feedMode; }
    public void setFeedMode(String v) { this.feedMode = v; }
    public boolean isSmartFeed() { return !FEED_LATEST.equals(feedMode); }
    public boolean isHideNegative() { return hideNegative; }
    public void setHideNegative(boolean v) { this.hideNegative = v; }
    public String getContentFilter() { return contentFilter; }
    public void setContentFilter(String v) { this.contentFilter = v; }

    /** Danh sách từ khóa của bộ lọc (đã bỏ dòng trống, không trùng, giữ thứ tự) */
    public java.util.List<String> getFilterTerms() {
        java.util.LinkedHashSet<String> terms = new java.util.LinkedHashSet<>();
        if (contentFilter != null) {
            for (String line : contentFilter.split("\r?\n")) {
                String t = line.trim();
                if (!t.isEmpty()) terms.add(t);
            }
        }
        return new java.util.ArrayList<>(terms);
    }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
