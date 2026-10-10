package com.uterspace.model;

import javax.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity: Friendship
 * Quan hệ kết bạn giữa 2 User.
 * status: "pending" | "accepted" | "rejected"
 */
@Entity
@Table(name = "friendships")
public class Friendship {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "friendship_id")
    private int friendshipId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_id")
    private User requester;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "receiver_id")
    private User receiver;

    @Transient
    private int requesterId;   // người gửi lời mời
    
    @Transient
    private int receiverId;    // người nhận lời mời

    private String status;     // "pending" | "accepted" | "rejected"
    
    @Column(name = "created_at")
    private LocalDateTime createdAt;

    /** Thời điểm hai người trở thành bạn bè (migration 060) — hiện "Bạn bè từ 09/2026" */
    @Column(name = "accepted_at")
    private LocalDateTime acceptedAt;

    public LocalDateTime getAcceptedAt() { return acceptedAt; }
    public void setAcceptedAt(LocalDateTime acceptedAt) { this.acceptedAt = acceptedAt; }

    public Friendship() {}

    public Friendship(int friendshipId, int requesterId, int receiverId,
                      String status, LocalDateTime createdAt) {
        this.friendshipId = friendshipId;
        this.requesterId = requesterId;
        this.receiverId = receiverId;
        this.status = status;
        this.createdAt = createdAt;
    }

    // ---------- Helpers ----------

    public boolean isPending()  { return "pending".equalsIgnoreCase(status); }
    public boolean isAccepted() { return "accepted".equalsIgnoreCase(status); }

    // ---------- Getters & Setters ----------

    public int getFriendshipId() { return friendshipId; }
    public void setFriendshipId(int friendshipId) { this.friendshipId = friendshipId; }

    public int getRequesterId() { 
        if (requester != null) return requester.getUserId();
        return requesterId; 
    }
    public void setRequesterId(int requesterId) { this.requesterId = requesterId; }

    public int getReceiverId() { 
        if (receiver != null) return receiver.getUserId();
        return receiverId; 
    }
    public void setReceiverId(int receiverId) { this.receiverId = receiverId; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public User getRequester() { return requester; }
    public void setRequester(User requester) { this.requester = requester; }

    public User getReceiver() { return receiver; }
    public void setReceiver(User receiver) { this.receiver = receiver; }
}
