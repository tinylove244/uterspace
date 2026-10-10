package com.uterspace.util;

/**
 * MediaUrl — đổi đường dẫn media lưu trong DB thành URL tính từ context path.
 * JSP dùng qua getter của entity: ${ctx}${user.avatarUrl}, ${ctx}${post.imageUrl}...
 *
 * DB đang có 4 kiểu giá trị (dữ liệu cũ + mới), gom về một chỗ để JSP không tự nối chuỗi:
 *   "avatar_duchuy.jpg", "users/x.jpg"   → ảnh có sẵn trong webapp  → /assets/images/...
 *   "/assets/images/posts/x.jpg"          → đường dẫn tuyệt đối cũ   → giữ nguyên
 *   "uploads/videos/x.mp4"                → file upload cũ (ngoài webapp, xem META-INF/context.xml) → /uploads/...
 *   "https://res.cloudinary.com/..."      → file trên Cloudinary (UploadUtil lưu secure_url) → /cdn/...
 *
 * URL Cloudinary cũng phải tính từ context path vì JSP / JS / JSON đều nối ctx phía trước
 * (${ctx}${post.videoUrl}, CTX + data.avatar...) — trả nguyên "https://..." sẽ thành "/uterspacehttps://...".
 * /cdn/... được CloudMediaController chuyển hướng 301 sang https://res.cloudinary.com/...
 */
public final class MediaUrl {

    public static final String CLOUDINARY_HOST = "res.cloudinary.com";
    public static final String CDN_PREFIX      = "/cdn/";

    private MediaUrl() { }

    public static String of(String stored) {
        if (stored == null) return null;
        String s = stored.trim();
        if (s.isEmpty()) return null;
        if (s.startsWith("http://") || s.startsWith("https://")) {
            String host = s.substring(s.indexOf("://") + 3);
            if (host.startsWith(CLOUDINARY_HOST + "/")) return CDN_PREFIX + host.substring(CLOUDINARY_HOST.length() + 1);
            return s;
        }
        if (s.startsWith("/")) return s;
        if (s.startsWith(UploadUtil.STORED_PREFIX)) return "/" + s;
        return "/assets/images/" + s;
    }
}
