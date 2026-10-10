package com.uterspace.controller;

import com.uterspace.dao.ConversationDAO;
import com.uterspace.dao.ConversationDAOImpl;
import com.uterspace.dao.StoryDAO;
import com.uterspace.dao.StoryDAOImpl;
import com.uterspace.model.ChatMessage;
import com.uterspace.model.Conversation;
import com.uterspace.model.Story;
import com.uterspace.service.ChatService;
import com.uterspace.service.NotificationService;
import com.uterspace.service.RelationService;
import com.uterspace.model.User;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.UploadUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;

/**
 * StoryController — Tin (Stories): đăng ảnh hoặc video, tự hết hạn sau 24 giờ.
 *
 * POST /stories/create   (multipart) media = ảnh ≤ 10 MB hoặc video MP4/WEBM ≤ 50 MB, ≤ 60 giây; caption ≤ 200 ký tự
 * GET  /stories/user?id= → JSON các tin còn hạn của một người (chính chủ hoặc bạn bè mới xem được)
 * POST /stories/view     → ghi nhận đã xem (vòng tròn chuyển xám, chủ tin thấy trong danh sách người xem)
 * GET  /stories/viewers?id= → JSON người đã xem (chỉ chủ tin)
 * POST /stories/delete   → chủ tin xóa tin (xóa luôn file; dùng được cả cho tin trong kho lưu trữ)
 * POST /stories/react    → thả / bỏ tim tin của bạn bè (chủ tin nhận thông báo STORY_REACT)
 * POST /stories/reply    {id, content} → trả lời tin = gửi tin nhắn riêng tới chủ tin (kèm trích chú thích tin)
 * GET  /stories/archive?page= → JSON kho lưu trữ: tin đã hết hạn của chính mình (Cài đặt → Kho lưu trữ tin)
 */
@WebServlet(urlPatterns = {"/stories/create", "/stories/user", "/stories/view", "/stories/viewers", "/stories/delete",
                           "/stories/react", "/stories/reply", "/stories/archive"})
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,
    maxFileSize       = StoryController.MAX_VIDEO_BYTES,
    maxRequestSize    = StoryController.MAX_VIDEO_BYTES + 1024 * 1024
)
public class StoryController extends HttpServlet {

    static final long MAX_IMAGE_BYTES = 1024L * 1024 * 10;
    static final long MAX_VIDEO_BYTES = 1024L * 1024 * 50;
    static final int  MAX_VIDEO_SEC   = 60;
    static final int  MAX_CAPTION     = 200;
    /** Mỗi người tối đa ngần này tin còn hạn cùng lúc (chống spam) */
    static final int  MAX_ACTIVE      = 15;

    static final int  MAX_REPLY       = 500;
    static final int  ARCHIVE_PAGE    = 24;

    private final StoryDAO storyDAO = new StoryDAOImpl();
    private final ConversationDAO conversationDAO = new ConversationDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        if ("/stories/archive".equals(req.getServletPath())) { archive(req, resp, me); return; }
        Integer id = parseId(req.getParameter("id"));
        if (id == null) { JsonUtil.error(resp, 400, "Thiếu tham số id."); return; }

        if ("/stories/user".equals(req.getServletPath())) {
            List<Story> stories = storyDAO.getActiveStoriesOf(id, me.getUserId());
            if (stories == null) { JsonUtil.error(resp, 403, "Bạn cần là bạn bè để xem tin của người này."); return; }
            writeStories(req, resp, stories, id == me.getUserId());
        } else {
            // /stories/viewers — chỉ chủ tin
            Story s = storyDAO.getActiveStory(id);
            if (s == null || s.getAuthor().getUserId() != me.getUserId()) {
                JsonUtil.error(resp, 403, "Chỉ chủ tin mới xem được danh sách người xem."); return;
            }
            StringBuilder sb = new StringBuilder("{\"viewers\":[");
            String sep = "";
            for (Object[] row : storyDAO.getViewers(id)) {
                User u = (User) row[0];
                sb.append(sep).append("{\"id\":").append(u.getUserId())
                  .append(",\"name\":").append(JsonUtil.str(u.getFullName()))
                  .append(",\"initials\":").append(JsonUtil.str(u.getInitials()))
                  .append(",\"avatar\":").append(JsonUtil.str(u.getAvatar() == null ? null : u.getAvatarUrl()))
                  .append(",\"viewedAt\":").append(JsonUtil.str(row[1].toString()))
                  .append(",\"liked\":").append(row.length > 2 && Boolean.TRUE.equals(row[2]))
                  .append('}');
                sep = ",";
            }
            JsonUtil.write(resp, sb.append("]}").toString());
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException, ServletException {
        req.setCharacterEncoding("UTF-8");
        User me = (User) req.getSession().getAttribute("currentUser");
        switch (req.getServletPath()) {
            case "/stories/create":
                try {
                    create(req, resp, me);
                } catch (IllegalStateException e) {
                    // Vượt maxFileSize/maxRequestSize: Tomcat ném khi đọc multipart
                    JsonUtil.error(resp, 413, "File quá lớn — ảnh tối đa 10 MB, video tối đa 50 MB.");
                }
                break;
            case "/stories/view": {
                Integer id = parseId(req.getParameter("id"));
                if (id == null) { JsonUtil.error(resp, 400, "Thiếu id."); return; }
                boolean added = storyDAO.markViewed(id, me.getUserId());
                JsonUtil.write(resp, "{\"success\":true,\"added\":" + added + "}");
                break;
            }
            case "/stories/react": {
                Integer id = parseId(req.getParameter("id"));
                Boolean liked = id == null ? null : storyDAO.toggleReaction(id, me.getUserId());
                if (liked == null) { JsonUtil.error(resp, 403, "Tin không còn hoặc bạn không xem được tin này."); return; }
                Story s = storyDAO.getActiveStory(id);
                if (s != null) {
                    String ref = "story-react:" + id + ":" + me.getUserId();
                    if (liked) {
                        NotificationService.notify(s.getAuthor().getUserId(), me.getUserId(), "STORY_REACT",
                                "đã thả ❤️ tin của bạn" + (s.getCaption() != null ? ": \"" + clip(s.getCaption(), 60) + "\"" : "."),
                                "/feed?story=" + s.getAuthor().getUserId(), ref);
                    } else {
                        NotificationService.removeByRef(s.getAuthor().getUserId(), ref);
                    }
                }
                JsonUtil.write(resp, "{\"success\":true,\"liked\":" + liked + "}");
                break;
            }
            case "/stories/reply":
                reply(req, resp, me);
                break;
            case "/stories/delete": {
                Integer id = parseId(req.getParameter("id"));
                String path = id == null ? null : storyDAO.delete(id, me.getUserId());
                if (path == null) { JsonUtil.error(resp, 403, "Bạn chỉ có thể xóa tin của chính mình."); return; }
                UploadUtil.delete(req.getServletContext(), path);
                JsonUtil.write(resp, "{\"success\":true}");
                break;
            }
            default:
                resp.sendError(404);
        }
    }

    /** Trả lời tin → tin nhắn 1-1 tới chủ tin (theo quyền nhắn tin của họ), mở sẵn hội thoại nếu chưa có */
    private void reply(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        Integer id = parseId(req.getParameter("id"));
        String content = req.getParameter("content");
        content = content == null ? "" : content.trim();
        if (id == null || content.isEmpty()) { JsonUtil.error(resp, 400, "Hãy nhập nội dung trả lời."); return; }
        if (content.length() > MAX_REPLY) { JsonUtil.error(resp, 400, "Trả lời tối đa " + MAX_REPLY + " ký tự."); return; }
        Story s = storyDAO.getActiveStory(id);
        if (s == null || !storyDAO.canViewStoriesOf(s.getAuthor().getUserId(), me.getUserId())) {
            JsonUtil.error(resp, 404, "Tin đã hết hạn hoặc bạn không xem được tin này."); return;
        }
        int ownerId = s.getAuthor().getUserId();
        if (ownerId == me.getUserId()) { JsonUtil.error(resp, 400, "Bạn không thể trả lời tin của chính mình."); return; }

        String denied = RelationService.messageDeniedReason(me.getUserId(), ownerId);
        Conversation c = conversationDAO.findDirect(me.getUserId(), ownerId);
        if (c == null) {
            if (denied != null) { JsonUtil.error(resp, 403, denied); return; }
            c = conversationDAO.getOrCreateConversation(me.getUserId(), ownerId);
        }
        c = conversationDAO.getForMember(c.getConversationId(), me.getUserId());

        ChatMessage draft = new ChatMessage();
        String quote = s.getCaption() != null ? " \u201c" + clip(s.getCaption(), 80) + "\u201d" : (s.isVideo() ? " (video)" : " (ảnh)");
        draft.setContent("↩️ Trả lời tin của bạn" + quote + ":\n" + content);
        try {
            ChatService.send(me, c, draft);
        } catch (ChatService.ChatException e) {
            JsonUtil.error(resp, e.status, e.getMessage()); return;
        }
        JsonUtil.write(resp, "{\"success\":true,\"conversationId\":" + c.getConversationId() + "}");
    }

    /** Kho lưu trữ: tin đã hết hạn của chính mình (chỉ chủ tin) */
    private void archive(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        Integer page = parseId(req.getParameter("page"));
        int p = page == null || page < 1 ? 1 : page;
        int total = storyDAO.countArchive(me.getUserId());
        List<Story> stories = storyDAO.getArchive(me.getUserId(), (p - 1) * ARCHIVE_PAGE, ARCHIVE_PAGE);
        String ctx = req.getContextPath();
        StringBuilder sb = new StringBuilder("{\"total\":").append(total).append(",\"page\":").append(p)
                .append(",\"hasMore\":").append(p * ARCHIVE_PAGE < total).append(",\"stories\":[");
        String sep = "";
        for (Story s : stories) {
            sb.append(sep).append("{\"id\":").append(s.getStoryId())
              .append(",\"type\":").append(JsonUtil.str(s.getMediaType()))
              .append(",\"url\":").append(JsonUtil.str(ctx + s.getMediaUrl()))
              .append(",\"caption\":").append(JsonUtil.str(s.getCaption()))
              .append(",\"createdAt\":").append(JsonUtil.str(s.getCreatedAt().toString()))
              .append(",\"date\":").append(JsonUtil.str(s.getFormattedCreatedAt()))
              .append(",\"views\":").append(s.getViewCount())
              .append(",\"reactions\":").append(s.getReactionCount())
              .append('}');
            sep = ",";
        }
        JsonUtil.write(resp, sb.append("]}").toString());
    }

    private static String clip(String s, int max) { return s.length() > max ? s.substring(0, max - 1) + "…" : s; }

    private void create(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ServletException {
        Part media = req.getPart("media");
        if (media == null || media.getSize() == 0) { JsonUtil.error(resp, 400, "Hãy chọn một ảnh hoặc video."); return; }

        String caption = req.getParameter("caption");
        caption = caption == null ? null : caption.trim();
        if (caption != null && caption.isEmpty()) caption = null;
        if (caption != null && caption.length() > MAX_CAPTION) {
            JsonUtil.error(resp, 400, "Chú thích tối đa " + MAX_CAPTION + " ký tự."); return;
        }
        if (storyDAO.countActive(me.getUserId()) >= MAX_ACTIVE) {
            JsonUtil.error(resp, 429, "Bạn đã có " + MAX_ACTIVE + " tin trong 24 giờ qua — hãy xóa bớt tin cũ."); return;
        }

        // Loại file xác định bằng magic bytes, không tin Content-Type / đuôi file do trình duyệt gửi
        boolean isVideo = UploadUtil.looksLikeVideo(media);
        Integer duration = null;
        if (isVideo) {
            duration = parseId(req.getParameter("duration"));
            if (duration != null && duration > MAX_VIDEO_SEC) {
                JsonUtil.error(resp, 400, "Video tin tối đa " + MAX_VIDEO_SEC + " giây."); return;
            }
        } else if (media.getSize() > MAX_IMAGE_BYTES) {
            JsonUtil.error(resp, 413, "Ảnh tối đa 10 MB."); return;
        }

        String path;
        try {
            path = isVideo ? UploadUtil.saveVideo(req.getServletContext(), media, UploadUtil.DIR_STORIES)
                           : UploadUtil.saveImage(req.getServletContext(), media, UploadUtil.DIR_STORIES);
        } catch (UploadUtil.UploadException e) {
            JsonUtil.error(resp, 400, isVideo ? e.getMessage() : "Chỉ chấp nhận ảnh JPG, PNG, GIF, WEBP hoặc video MP4, WEBM.");
            return;
        }

        Story s;
        try {
            s = storyDAO.create(me.getUserId(), path, isVideo ? Story.TYPE_VIDEO : Story.TYPE_IMAGE, caption, duration);
        } catch (RuntimeException e) {
            UploadUtil.delete(req.getServletContext(), path);   // INSERT lỗi → không để file mồ côi
            throw e;
        }
        JsonUtil.write(resp, "{\"success\":true,\"storyId\":" + s.getStoryId() + "}");
    }

    private void writeStories(HttpServletRequest req, HttpServletResponse resp, List<Story> stories, boolean own) throws IOException {
        String ctx = req.getContextPath();
        StringBuilder sb = new StringBuilder("{\"own\":").append(own).append(",\"stories\":[");
        String sep = "";
        for (Story s : stories) {
            User a = s.getAuthor();
            sb.append(sep).append("{\"id\":").append(s.getStoryId())
              .append(",\"type\":").append(JsonUtil.str(s.getMediaType()))
              .append(",\"url\":").append(JsonUtil.str(ctx + s.getMediaUrl()))
              .append(",\"caption\":").append(JsonUtil.str(s.getCaption()))
              .append(",\"duration\":").append(s.getDurationSec() == null ? "null" : s.getDurationSec())
              .append(",\"createdAt\":").append(JsonUtil.str(s.getCreatedAt().toString()))
              .append(",\"seen\":").append(s.isSeen())
              .append(",\"views\":").append(own ? s.getViewCount() : 0)
              .append(",\"reactions\":").append(own ? s.getReactionCount() : 0)
              .append(",\"liked\":").append(s.isLiked())
              .append(",\"author\":{\"id\":").append(a.getUserId())
              .append(",\"name\":").append(JsonUtil.str(a.getFullName()))
              .append(",\"initials\":").append(JsonUtil.str(a.getInitials()))
              .append(",\"avatar\":").append(JsonUtil.str(a.getAvatar() == null ? null : ctx + a.getAvatarUrl()))
              .append("}}");
            sep = ",";
        }
        JsonUtil.write(resp, sb.append("],\"now\":").append(JsonUtil.str(LocalDateTime.now().toString())).append('}').toString());
    }

    private static Integer parseId(String s) {
        try { return s == null ? null : Integer.valueOf(s.trim()); }
        catch (NumberFormatException e) { return null; }
    }
}
