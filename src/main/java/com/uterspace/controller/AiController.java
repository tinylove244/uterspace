package com.uterspace.controller;

import com.uterspace.ai.AiService;
import com.uterspace.ai.SentimentAnalyzer;
import com.uterspace.dao.PostDAO;
import com.uterspace.dao.PostDAOImpl;
import com.uterspace.model.Post;
import com.uterspace.model.User;
import com.uterspace.util.JsonUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayDeque;
import java.util.Deque;

/**
 * AiController — Trợ lý AI (Google Gemini hoặc Claude, thuật toán offline khi chưa cấu hình — xem AiService).
 *
 * GET  /ai/status[?ping=1]              → {ai, provider, model, ping?, tones, languages} — ping=1 gọi thử AI thật
 * POST /ai/caption   (multipart) draft, tone, image?  → viết chú thích bài đăng (có ảnh thì AI nhìn ảnh)
 * POST /ai/summarize text | postId      → tóm tắt
 * POST /ai/translate text | postId, to  → dịch; {offline:true} = máy chủ không dịch được, trình duyệt tự dịch
 * POST /ai/sentiment text               → nhãn cảm xúc để cảnh báo trước khi đăng (luôn dùng từ điển — tức thì, miễn phí)
 *
 * Giới hạn: mỗi người 40 yêu cầu AI / 10 phút (chống lạm dụng hạn mức API). Cần đăng nhập + CSRF (web.xml).
 */
@WebServlet(urlPatterns = {"/ai/*"})
@MultipartConfig(fileSizeThreshold = 1024 * 1024, maxFileSize = AiController.MAX_IMAGE, maxRequestSize = AiController.MAX_IMAGE + 64 * 1024)
public class AiController extends HttpServlet {

    static final long MAX_IMAGE = 5L * 1024 * 1024;
    private static final int  LIMIT = 40;
    private static final long WINDOW_MS = 10 * 60 * 1000L;
    private static final int  MAX_TEXT = 20000;

    private final PostDAO postDAO = new PostDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        if (!"/status".equals(req.getPathInfo())) { resp.sendError(404); return; }
        StringBuilder sb = new StringBuilder("{\"ai\":").append(AiService.aiAvailable())
                .append(",\"provider\":").append(JsonUtil.str(AiService.providerLabel()));
        if ("1".equals(req.getParameter("ping"))) {
            String err = AiService.ping();
            sb.append(",\"ping\":").append(JsonUtil.str(err == null ? "OK — " + AiService.providerLabel() + " API hoạt động" : err));
        }
        sb.append(",\"model\":").append(JsonUtil.str(AiService.model()));
        sb.append(",\"tones\":{");
        String sep = "";
        for (java.util.Map.Entry<String, String> e : AiService.TONES.entrySet()) {
            sb.append(sep).append(JsonUtil.str(e.getKey())).append(':').append(JsonUtil.str(e.getValue())); sep = ",";
        }
        sb.append("},\"languages\":{");
        sep = "";
        for (java.util.Map.Entry<String, String> e : AiService.LANGUAGES.entrySet()) {
            sb.append(sep).append(JsonUtil.str(e.getKey())).append(':').append(JsonUtil.str(e.getValue())); sep = ",";
        }
        JsonUtil.write(resp, sb.append("}}").toString());
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException, ServletException {
        req.setCharacterEncoding("UTF-8");
        User me = (User) req.getSession().getAttribute("currentUser");
        String path = req.getPathInfo() == null ? "" : req.getPathInfo();

        if ("/sentiment".equals(path)) {
            SentimentAnalyzer.Result r = SentimentAnalyzer.analyze(limit(req.getParameter("text")));
            StringBuilder cues = new StringBuilder("[");
            for (int i = 0; i < r.cues.size(); i++) cues.append(i > 0 ? "," : "").append(JsonUtil.str(r.cues.get(i)));
            JsonUtil.write(resp, "{\"label\":" + JsonUtil.str(r.label) + ",\"score\":" + r.score + ",\"cues\":" + cues.append(']') + "}");
            return;
        }

        if (!allow(req.getSession())) {
            JsonUtil.error(resp, 429, "Bạn dùng trợ lý AI hơi nhiều — thử lại sau vài phút nhé.");
            return;
        }

        switch (path) {
            case "/caption": {
                byte[] img = null;
                String mime = null;
                try {
                    Part part = req.getPart("image");
                    if (part != null && part.getSize() > 0) {
                        try (InputStream in = part.getInputStream()) { img = readAll(in); }
                        mime = sniffImage(img);
                        if (mime == null) { JsonUtil.error(resp, 400, "Ảnh phải là JPG, PNG, GIF hoặc WEBP."); return; }
                    }
                } catch (IllegalStateException e) {
                    JsonUtil.error(resp, 413, "Ảnh gửi cho AI tối đa 5 MB."); return;
                }
                String draft = limit(req.getParameter("draft"));
                if ((draft == null || draft.trim().isEmpty()) && img == null) {
                    JsonUtil.error(resp, 400, "Hãy gõ vài ý hoặc chọn ảnh để AI viết chú thích."); return;
                }
                AiService.TextResult r = AiService.caption(draft, req.getParameter("tone"), img, mime);
                writeText(resp, r);
                return;
            }
            case "/summarize": {
                String text = textOrPost(req, resp, me);
                if (text == null) return;
                writeText(resp, AiService.summarize(text));
                return;
            }
            case "/translate": {
                String to = req.getParameter("to");
                if (!AiService.LANGUAGES.containsKey(to)) { JsonUtil.error(resp, 400, "Ngôn ngữ không được hỗ trợ."); return; }
                String text = textOrPost(req, resp, me);
                if (text == null) return;
                AiService.TextResult r = AiService.translate(text, to);
                if (r == null) {
                    // Không có AI trên máy chủ → trình duyệt thử Translator API cục bộ (Chrome 138+)
                    JsonUtil.write(resp, "{\"offline\":true,\"text\":" + JsonUtil.str(text) + "}");
                    return;
                }
                writeText(resp, r);
                return;
            }
            default:
                resp.sendError(404);
        }
    }

    /** Lấy văn bản từ tham số text, hoặc nội dung bài postId (chỉ khi người xem được phép xem bài) */
    private String textOrPost(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        String pid = req.getParameter("postId");
        if (pid != null && !pid.isEmpty()) {
            int postId;
            try { postId = Integer.parseInt(pid); } catch (NumberFormatException e) { JsonUtil.error(resp, 400, "Bài viết không hợp lệ."); return null; }
            Post p = postDAO.getPostById(postId);
            boolean own = p != null && p.getAuthor() != null && p.getAuthor().getUserId() == me.getUserId();
            if (p == null || (!own && !postDAO.canView(postId, me.getUserId()))) { JsonUtil.error(resp, 404, "Không tìm thấy bài viết."); return null; }
            if (p.getContent() == null || p.getContent().trim().isEmpty()) { JsonUtil.error(resp, 400, "Bài viết không có chữ."); return null; }
            return p.getContent();
        }
        String text = limit(req.getParameter("text"));
        if (text == null || text.trim().isEmpty()) { JsonUtil.error(resp, 400, "Chưa có nội dung."); return null; }
        return text;
    }

    private static void writeText(HttpServletResponse resp, AiService.TextResult r) throws IOException {
        JsonUtil.write(resp, "{\"text\":" + JsonUtil.str(r.text) + ",\"source\":" + JsonUtil.str(r.source) +
                             ",\"provider\":" + JsonUtil.str(AiService.providerLabel()) + "}");
    }

    private static String limit(String s) { return s != null && s.length() > MAX_TEXT ? s.substring(0, MAX_TEXT) : s; }

    /** Cửa sổ trượt 10 phút, lưu trong phiên */
    @SuppressWarnings("unchecked")
    private static boolean allow(HttpSession session) {
        synchronized (session) {
            Deque<Long> q = (Deque<Long>) session.getAttribute("aiCalls");
            if (q == null) { q = new ArrayDeque<>(); session.setAttribute("aiCalls", q); }
            long now = System.currentTimeMillis();
            while (!q.isEmpty() && now - q.peekFirst() > WINDOW_MS) q.pollFirst();
            if (q.size() >= LIMIT) return false;
            q.addLast(now);
            return true;
        }
    }

    private static byte[] readAll(InputStream in) throws IOException {
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) {
            out.write(buf, 0, n);
            if (out.size() > MAX_IMAGE) throw new IllegalStateException("too large");
        }
        return out.toByteArray();
    }

    /** Xác định loại ảnh bằng magic bytes (không tin Content-Type của trình duyệt) */
    private static String sniffImage(byte[] b) {
        if (b == null || b.length < 12) return null;
        if ((b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8) return "image/jpeg";
        if ((b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') return "image/png";
        if (b[0] == 'G' && b[1] == 'I' && b[2] == 'F') return "image/gif";
        if (b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') return "image/webp";
        return null;
    }
}
