package com.uterspace.util;

/**
 * MediaUrl â€” Ä‘á»•i Ä‘Æ°á»ng dáº«n media lÆ°u trong DB thÃ nh URL tÃ­nh tá»« context path.
 * JSP dÃ¹ng qua getter cá»§a entity: ${ctx}${user.avatarUrl}, ${ctx}${post.imageUrl}...
 *
 * DB Ä‘ang cÃ³ 3 kiá»ƒu giÃ¡ trá»‹ (dá»¯ liá»‡u cÅ© + má»›i), gom vá» má»™t chá»— Ä‘á»ƒ JSP khÃ´ng tá»± ná»‘i chuá»—i:
 *   "avatar_duchuy.jpg", "users/x.jpg"  â†’ áº£nh cÃ³ sáºµn trong webapp  â†’ /assets/images/...
 *   "/assets/images/posts/x.jpg"         â†’ Ä‘Æ°á»ng dáº«n tuyá»‡t Ä‘á»‘i cÅ©   â†’ giá»¯ nguyÃªn
 *   "uploads/videos/x.mp4"               â†’ file upload (ngoÃ i webapp, xem META-INF/context.xml) â†’ /uploads/...
 */
public final class MediaUrl {

    private MediaUrl() { }

        public static String of(String stored) {
        if (stored == null) return null;
        String s = stored.trim();
        if (s.isEmpty()) return null;
        if (s.startsWith("http://") || s.startsWith("https://")) return s;
        if (s.startsWith("/")) return s;
        if (s.startsWith(UploadUtil.STORED_PREFIX)) return "/" + s;
        return "/assets/images/" + s;
    }
}

