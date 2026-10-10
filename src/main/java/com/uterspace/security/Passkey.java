package com.uterspace.security;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/** Passkey — một khóa WebAuthn (vân tay / khuôn mặt / PIN của thiết bị) đã đăng ký cho tài khoản. Không phải entity. */
public class Passkey {

    private int id;
    private int userId;
    private String credentialId;   // base64url
    private byte[] publicKey;      // SubjectPublicKeyInfo (DER)
    private int alg;               // COSE: -7 ES256, -257 RS256
    private long signCount;
    private String label;
    private LocalDateTime createdAt;
    private LocalDateTime lastUsedAt;

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy");

    public String getFormattedCreatedAt()  { return createdAt == null ? "" : createdAt.format(FMT); }
    public String getFormattedLastUsedAt() { return lastUsedAt == null ? "Chưa dùng" : lastUsedAt.format(FMT); }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }
    public String getCredentialId() { return credentialId; }
    public void setCredentialId(String credentialId) { this.credentialId = credentialId; }
    public byte[] getPublicKey() { return publicKey; }
    public void setPublicKey(byte[] publicKey) { this.publicKey = publicKey; }
    public int getAlg() { return alg; }
    public void setAlg(int alg) { this.alg = alg; }
    public long getSignCount() { return signCount; }
    public void setSignCount(long signCount) { this.signCount = signCount; }
    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getLastUsedAt() { return lastUsedAt; }
    public void setLastUsedAt(LocalDateTime lastUsedAt) { this.lastUsedAt = lastUsedAt; }
}
