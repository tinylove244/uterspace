package com.uterspace.model;

/** FriendSuggestion — một gợi ý kết bạn: người được gợi ý + số bạn chung + lý do hiển thị. Không phải entity. */
public class FriendSuggestion {

    private final User user;
    private final int mutualCount;
    private final String reason;

    public FriendSuggestion(User user, int mutualCount, String reason) {
        this.user = user;
        this.mutualCount = mutualCount;
        this.reason = reason;
    }

    public User getUser() { return user; }
    public int getMutualCount() { return mutualCount; }
    public String getReason() { return reason; }
}
