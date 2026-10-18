package com.uterspace.controller;

import com.uterspace.service.NotificationService;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.service.RecommendationService;
import com.uterspace.util.ContentFilter;
import com.uterspace.util.DbParallel;
import com.uterspace.util.GroupPermission;
import com.uterspace.util.HashtagUtil;
import com.uterspace.util.LayoutSupport;
import com.uterspace.util.UploadUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.*;
import java.util.concurrent.CompletableFuture;

/**
 * FeedController — Xử lý trang Bảng tin (/feed).
 * GET /feed          → load posts từ DB → forward newsfeed.jsp
 *                      ?mode=smart|latest đổi cách sắp xếp (lưu luôn vào cài đặt): "Dành cho bạn" (RecommendationService)
 *                      hoặc "Mới nhất". Bộ lọc từ khóa / ẩn bài tiêu cực của người xem được áp dụng (ContentFilter).
 * GET /hashtag?tag=X → mọi bài có #X (dùng lại giao diện newsfeed.jsp)
 * POST /feed/like    → toggle like, trả JSON
 * POST /feed/comment → thêm comment, trả JSON
 * POST /feed/share   → chia sẻ kèm bình luận, trả JSON
 * POST /feed/hide    → chủ bài tự ẩn / hiện lại bài (hidden=true|false), trả JSON
 */
@WebServlet(urlPatterns = {"/feed", "/hashtag", "/feed/like", "/feed/comment", "/feed/create",
                           "/feed/delete", "/feed/edit", "/feed/share", "/feed/hide"})
@MultipartConfig(                              // plan mục 5.1: video tối đa 100 MB
    fileSizeThreshold = 1024 * 1024,           // > 1 MB thì ghi tạm ra đĩa, không giữ trong RAM
    maxFileSize = 1024L * 1024 * 100,
    maxRequestSize = 1024L * 1024 * 105
)
public class FeedController extends HttpServlet {

    /** Ảnh vẫn giới hạn 10 MB — giới hạn 100 MB ở trên chỉ dành cho video */
    private static final long MAX_IMAGE_BYTES = 1024L * 1024 * 10;

    private final PostDAO         postDAO         = new PostDAOImpl();
    private final CommentDAO      commentDAO      = new CommentDAOImpl();
    private final LikeDAO         likeDAO         = new LikeDAOImpl();
    private final FriendshipDAO   friendshipDAO   = new FriendshipDAOImpl();
    private final NotificationDAO notifDAO        = new NotificationDAOImpl();
    private final MessageDAO      messageDAO      = new MessageDAOImpl();
    private final SavedPostDAO    savedDAO        = new SavedPostDAOImpl();
    private final GroupDAO        groupDAO        = new GroupDAOImpl();
    private final StoryDAO        storyDAO        = new StoryDAOImpl();
    private final UserSettingsDAO settingsDAO     = new UserSettingsDAO();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        HttpSession session = req.getSession(false);
        User currentUser = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (currentUser == null) { resp.sendRedirect(req.getContextPath() + "/login"); return; }

        int uid = currentUser.getUserId();

        if ("/hashtag".equals(req.getServletPath())) {
            showHashtagPage(req, resp, currentUser);
            return;
        }

        // Ô tìm kiếm gửi /feed?q=#tag (khi JS searchHashtag() không chặn được) → trang hashtag
        String q = req.getParameter("q");
        if (q != null && q.trim().startsWith("#")) {
            String tag = HashtagUtil.normalize(q);
            if (tag != null) {
                resp.sendRedirect(req.getContextPath() + "/hashtag?tag=" + java.net.URLEncoder.encode(tag, "UTF-8"));
                return;
            }
        }

        // Cách sắp xếp: tham số ?mode= (đổi bằng nút trên bảng tin) được lưu làm mặc định của người dùng
        UserSettings settings = settingsDAO.get(uid);
        String mode = req.getParameter("mode");
        if ("latest".equals(mode) || "smart".equals(mode)) {
            String want = "latest".equals(mode) ? UserSettings.FEED_LATEST : UserSettings.FEED_SMART;
            if (!want.equals(settings.getFeedMode())) { settings.setFeedMode(want); settingsDAO.save(settings); }
        }

        // Các khối độc lập chạy song song (DB cloud ~0,1 giây mỗi truy vấn, chủ yếu do đường truyền):
        //   bài viết (+ bình luận, đã thích, bài gốc, tên nhóm) | hồ sơ sở thích | bài gần đây | thanh Tin
        CompletableFuture<List<Post>> fPosts = DbParallel.async(() -> {
            List<Post> list = postDAO.getFeedPosts(uid);
            preparePosts(list, uid);
            return list;
        });
        // Hồ sơ sở thích (lịch sử tương tác + tìm kiếm) → xếp bảng tin + gợi ý nội dung
        CompletableFuture<RecommendationService.InterestProfile> fProfile = DbParallel.async(() -> RecommendationService.profile(uid));
        CompletableFuture<List<String>> fRecent = DbParallel.async(() -> postDAO.getRecentContentsVisibleTo(uid, 300));
        // Thanh "Tin": tin còn hạn của mình + bạn bè (StoryDAO)
        CompletableFuture<List<StoryRing>> fRings = DbParallel.async(() -> storyDAO.getRings(uid));

        // Gợi ý kết bạn thông minh (bạn chung, nhóm chung, sở thích, khu vực) + nhóm / hashtag / video nên xem — cần hồ sơ sở thích
        RecommendationService.InterestProfile profile = DbParallel.get(fProfile);
        CompletableFuture<List<FriendSuggestion>> fFriends = DbParallel.async(() -> RecommendationService.friendSuggestions(uid, profile, 12));
        CompletableFuture<?> fGroups = DbParallel.async(() -> RecommendationService.suggestGroups(uid, profile, 6));
        CompletableFuture<?> fVideos = DbParallel.async(() -> RecommendationService.suggestVideos(uid, profile, 6));
        List<String> recent = DbParallel.get(fRecent);
        CompletableFuture<?> fTags = DbParallel.async(() -> RecommendationService.suggestHashtags(uid, profile, recent, 8));

        List<Post> posts = DbParallel.get(fPosts);
        ContentFilter.of(settings).apply(posts, uid);
        if (settings.isSmartFeed()) {
            Map<String, Integer> trending = new HashMap<>();
            for (Map.Entry<String, Integer> e : HashtagUtil.topHashtags(recent, 12)) trending.put(e.getKey().toLowerCase(), e.getValue());
            RecommendationService.rankFeed(posts, uid, profile, trending);
        }

        // Vòng Tin của mình tách riêng
        List<StoryRing> rings = DbParallel.get(fRings);
        StoryRing myRing = null;
        if (!rings.isEmpty() && rings.get(0).getUser().getUserId() == uid) myRing = rings.remove(0);

        req.setAttribute("smartFeed",         settings.isSmartFeed());
        req.setAttribute("hideNegativeOn",    settings.isHideNegative());
        req.setAttribute("interestTags",      profile.topTags(5));
        req.setAttribute("suggestedGroups",   DbParallel.get(fGroups));
        req.setAttribute("suggestedTags",     DbParallel.get(fTags));
        req.setAttribute("suggestedVideos",   DbParallel.get(fVideos));
        List<FriendSuggestion> suggestedFriends = DbParallel.get(fFriends);
        req.setAttribute("storyRings",        rings);
        req.setAttribute("myStoryRing",       myRing);
        req.setAttribute("suggestedFriends",  suggestedFriends);
        req.setAttribute("pageTitle",         "Bảng tin");
        // Cài đặt đã đọc ở trên → LayoutSupport không đọc lại
        req.setAttribute("filterTermsJson",   ContentFilter.of(settings).termsJson());
        forwardToFeedView(req, resp, currentUser, posts, recent);
    }

    // ---- Trang tổng hợp hashtag: GET /hashtag?tag=DoAnCuoiKy ----
    private void showHashtagPage(HttpServletRequest req, HttpServletResponse resp, User currentUser)
            throws ServletException, IOException {
        String tag = HashtagUtil.normalize(req.getParameter("tag"));
        if (tag == null) { resp.sendRedirect(req.getContextPath() + "/feed"); return; }

        int uid = currentUser.getUserId();
        List<Post> posts = postDAO.getPostsByHashtag(tag, uid);
        preparePosts(posts, uid);
        ContentFilter filter = ContentFilter.of(settingsDAO.get(uid));
        filter.apply(posts, uid);

        req.setAttribute("hashtag",   tag);
        req.setAttribute("pageTitle", "#" + tag);
        req.setAttribute("filterTermsJson", filter.termsJson());
        forwardToFeedView(req, resp, currentUser, posts, null);
    }

    /** Gắn comments, trạng thái đã thích và bài gốc (nếu là bài chia sẻ) cho từng bài — mỗi loại 1 truy vấn cho cả trang */
    private void preparePosts(List<Post> posts, int uid) {
        commentDAO.attachComments(posts);
        likeDAO.markLikedBy(posts, uid);
        postDAO.attachSharedPosts(posts, uid);
        postDAO.attachGroupNames(posts);
    }

    /**
     * Thuộc tính dùng chung cho /feed và /hashtag rồi forward tới newsfeed.jsp.
     * @param recent nội dung bài gần đây đã đọc ở /feed (null thì tự đọc) — mỗi truy vấn tới DB cloud ~0,3 giây
     */
    private void forwardToFeedView(HttpServletRequest req, HttpServletResponse resp,
                                   User currentUser, List<Post> posts, List<String> recent)
            throws ServletException, IOException {
        int uid = currentUser.getUserId();

        // Đánh dấu bài đã lưu
        List<Post> savedPosts = savedDAO.getSavedPosts(uid);
        Set<Integer> savedPostIds = new HashSet<>();
        for (Post sp : savedPosts) savedPostIds.add(sp.getPostId());

        // Hashtag thịnh hành: đếm thật trên các bài gần đây người dùng được xem
        if (recent == null) recent = postDAO.getRecentContentsVisibleTo(uid, 300);
        List<Map<String, String>> trendingTopics = new ArrayList<>();
        for (Map.Entry<String, Integer> e : HashtagUtil.topHashtags(recent, 6)) {
            trendingTopics.add(buildTrend(e.getKey(), e.getValue()));
        }

        req.setAttribute("posts",          posts);
        req.setAttribute("savedPostIds",   savedPostIds);
        req.setAttribute("mySavedCount",   savedPosts.size());   // LayoutSupport không đọc lại danh sách đã lưu
        req.setAttribute("trendingTopics", trendingTopics);
        req.setAttribute("currentPage",    "feed");
        LayoutSupport.populate(req, currentUser);

        req.getRequestDispatcher("/WEB-INF/views/feed/newsfeed.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        req.setCharacterEncoding("UTF-8");
        HttpSession session = req.getSession(false);
        User currentUser = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (currentUser == null) { resp.setStatus(HttpServletResponse.SC_UNAUTHORIZED); return; }

        String path = req.getServletPath();

        if ("/feed/like".equals(path)) {
            handleLike(req, resp, currentUser);
        } else if ("/feed/comment".equals(path)) {
            handleComment(req, resp, currentUser);
        } else if ("/feed/create".equals(path)) {
            try {
                handleCreatePost(req, resp, currentUser);
            } catch (IllegalStateException e) {
                // Vượt maxFileSize/maxRequestSize: Tomcat ném khi đọc multipart
                writeError(resp, 413, "File quá lớn — video tối đa 100 MB, ảnh tối đa 10 MB.");
            }
        } else if ("/feed/delete".equals(path)) {
            handleDeletePost(req, resp, currentUser);
        } else if ("/feed/edit".equals(path)) {
            handleEditPost(req, resp, currentUser);
        } else if ("/feed/share".equals(path)) {
            handleSharePost(req, resp, currentUser);
        } else if ("/feed/hide".equals(path)) {
            handleHidePost(req, resp, currentUser);
        }
    }

    // ---- Like toggle ----
    private void handleLike(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException {
        String postIdStr = req.getParameter("postId");
        if (postIdStr == null) { resp.setStatus(400); return; }
        int postId = Integer.parseInt(postIdStr);
        // Không cho thích bài mình không được xem (đổi postId trên request)
        if (!postDAO.canView(postId, user.getUserId())) { resp.setStatus(403); return; }

        boolean nowLiked = likeDAO.toggleLike(postId, user.getUserId());
        int newCount = likeDAO.getLikeCount(postId);

        // Notify post owner if liked
        if (nowLiked) {
            Post post = postDAO.getPostById(postId);
            if (post != null && post.getAuthor() != null && post.getAuthor().getUserId() != user.getUserId()) {
                Notification notif = new Notification();
                notif.setUserId(post.getAuthor().getUserId());
                notif.setActor(user);
                notif.setType("LIKE");
                notif.setContent("đã thích bài viết của bạn.");
                notif.setTargetUrl("/feed#post-" + postId);
                NotificationService.notify(notif.getUserId(), notif.getActor().getUserId(), notif.getType(), notif.getContent(), notif.getTargetUrl(), null);
            }
        }

        resp.setContentType("application/json;charset=UTF-8");
        resp.getWriter().write("{\"liked\":" + nowLiked + ",\"likeCount\":" + newCount + "}");
    }

    // ---- Add comment ----
    private void handleComment(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException {
        String postIdStr = req.getParameter("postId");
        String content   = req.getParameter("content");
        if (postIdStr == null || content == null || content.trim().isEmpty()) {
            resp.setStatus(400); return;
        }
        int postId = Integer.parseInt(postIdStr);
        if (!postDAO.canView(postId, user.getUserId())) { resp.setStatus(403); return; }
        Comment comment = commentDAO.addComment(postId, user.getUserId(), content.trim());

        // Notify post owner
        Post post = postDAO.getPostById(postId);
        if (post != null && post.getAuthor() != null && post.getAuthor().getUserId() != user.getUserId()) {
            Notification notif = new Notification();
            notif.setUserId(post.getAuthor().getUserId());
            notif.setActor(user);
            notif.setType("COMMENT");
            // Do not use escapeJson for DB content, it will show backslashes in HTML
            notif.setContent("đã bình luận vào bài viết của bạn: \"" + content.trim() + "\"");
            notif.setTargetUrl("/feed#post-" + postId);
            NotificationService.notify(notif.getUserId(), notif.getActor().getUserId(), notif.getType(), notif.getContent(), notif.getTargetUrl(), null);
        }

        resp.setContentType("application/json;charset=UTF-8");
        resp.getWriter().write(
            "{\"commentId\":" + comment.getCommentId() +
            ",\"content\":\"" + escapeJson(comment.getContent()) + "\"" +
            ",\"authorName\":\"" + escapeJson(user.getFullName()) + "\"" +
            ",\"time\":\"" + (comment.getCreatedAt() != null ?
                comment.getCreatedAt().format(java.time.format.DateTimeFormatter.ofPattern("HH:mm")) : "") + "\"}"
        );
    }

    // ---- Create post ----
    private void handleCreatePost(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException, ServletException {
        resp.setContentType("application/json;charset=UTF-8");
        String content    = req.getParameter("content");
        String visibility = "friends".equals(req.getParameter("visibility")) ? "friends" : "public";
        // Chế độ "Chỉ mình tôi": đăng ở trạng thái chủ bài tự ẩn (is_hidden_by_owner = 1) — plan 6.2
        boolean hidden    = "true".equals(req.getParameter("hidden"));
        Part imagePart    = req.getPart("image");
        Part videoPart    = req.getPart("video");
        Part modelPart    = req.getPart("model");                 // vật thể 3D .glb (tùy chọn, ảnh = poster)
        String mediaMode  = req.getParameter("mediaMode");        // PANORAMA | DEPTH | MODEL3D
        String captions   = req.getParameter("captionsVtt");      // phụ đề WebVTT do trình duyệt nhận dạng giọng nói

        if (content == null || content.trim().isEmpty()) {
            writeError(resp, 400, "Vui lòng nhập nội dung bài viết.");
            return;
        }

        // Đăng vào nhóm: chỉ thành viên ACTIVE (đọc DB, không tin groupId từ client)
        Integer groupId = null;
        Group group = null;
        String groupIdStr = req.getParameter("groupId");
        if (groupIdStr != null && !groupIdStr.isEmpty()) {
            try { groupId = Integer.parseInt(groupIdStr); }
            catch (NumberFormatException e) { writeError(resp, 400, "Nhóm không hợp lệ."); return; }
            group = groupDAO.getGroupById(groupId);
            if (group == null || !GroupPermission.canPost(groupId, user.getUserId())) {
                writeError(resp, 403, "Bạn cần là thành viên của nhóm để đăng bài.");
                return;
            }
        }

        // Mỗi bài chỉ một media: ảnh HOẶC video (khớp cột media_type đơn)
        boolean hasImage = imagePart != null && imagePart.getSize() > 0;
        boolean hasVideo = videoPart != null && videoPart.getSize() > 0;
        boolean hasModel = modelPart != null && modelPart.getSize() > 0;
        if (hasImage && hasVideo) { writeError(resp, 400, "Mỗi bài chỉ đính kèm ảnh hoặc video, không cả hai."); return; }
        if (hasModel && hasVideo) { writeError(resp, 400, "Bài có mô hình 3D không kèm video được."); return; }
        if (mediaMode != null && !mediaMode.isEmpty()) {
            boolean ok = (Post.MODE_MODEL3D.equals(mediaMode) && hasModel)
                      || ((Post.MODE_PANORAMA.equals(mediaMode) || Post.MODE_DEPTH.equals(mediaMode)) && hasImage);
            if (!ok) { writeError(resp, 400, "Chế độ media không khớp với file đính kèm."); return; }
        } else {
            mediaMode = hasModel ? Post.MODE_MODEL3D : null;
        }
        if (captions != null && (captions.length() > 200_000 || !captions.trim().startsWith("WEBVTT") || !hasVideo)) captions = null;
        if (hasImage && imagePart.getSize() > MAX_IMAGE_BYTES) { writeError(resp, 413, "Ảnh tối đa 10 MB."); return; }

        String imagePath = null, videoPath = null, modelPath = null;
        try {
            if (hasModel) modelPath = UploadUtil.saveModel(req.getServletContext(), modelPart);
            // Lưu ra thư mục upload ngoài webapp — UUID + đuôi suy ra từ magic bytes (xem UploadUtil).
            // Ghi file TRƯỚC, INSERT bài SAU; INSERT lỗi thì xóa file vừa ghi.
            if (hasImage) imagePath = UploadUtil.saveImage(req.getServletContext(), imagePart, UploadUtil.DIR_POSTS);
            if (hasVideo) videoPath = UploadUtil.saveVideo(req.getServletContext(), videoPart);
        } catch (UploadUtil.UploadException e) {
            UploadUtil.delete(req.getServletContext(), modelPath);   // mô hình đã ghi nhưng ảnh / video lỗi → không để file mồ côi
            UploadUtil.delete(req.getServletContext(), imagePath);
            writeError(resp, 400, e.getMessage());
            return;
        }

        Post p = new Post();
        p.setUserId(user.getUserId());
        p.setContent(content.trim());
        p.setVisibility(visibility);
        p.setImagePath(imagePath);
        p.setGroupId(groupId);
        p.setHiddenByOwner(hidden && groupId == null);   // bài trong nhóm không có chế độ ẩn
        p.setMediaMode(mediaMode);
        p.setModelPath(modelPath);
        p.setCaptionsVtt(captions == null ? null : captions.trim());
        if (videoPath != null) {
            p.setMediaType("VIDEO");
            p.setVideoPath(videoPath);
            // Thời lượng đọc ở trình duyệt (loadedmetadata) — không cần ffmpeg trên server
            p.setVideoDurationSec(parseDuration(req.getParameter("videoDuration")));
        } else {
            p.setMediaType(imagePath == null ? null : "IMAGE");
        }

        Post saved;
        try {
            saved = postDAO.createPost(p);
        } catch (RuntimeException e) {
            UploadUtil.delete(req.getServletContext(), imagePath);   // INSERT lỗi → không để file mồ côi
            UploadUtil.delete(req.getServletContext(), videoPath);
            UploadUtil.delete(req.getServletContext(), modelPath);
            throw e;
        }

        // Phân tích cảm xúc chạy nền (Claude hoặc từ điển) — không bắt người đăng phải chờ
        com.uterspace.ai.AiService.analyzePostAsync(saved.getPostId(), saved.getContent());

        // Báo cho các thành viên khác trong nhóm
        if (group != null && !saved.isHiddenByOwner()) {
            List<Integer> memberIds = new ArrayList<>();
            for (GroupMember m : groupDAO.getMembers(groupId, GroupMember.STATUS_ACTIVE)) {
                if (m.getUserId() != user.getUserId() && memberIds.size() < 200) memberIds.add(m.getUserId());
            }
            NotificationService.notifyMany(memberIds, user.getUserId(), "GROUP_POST",
                    "đã đăng bài trong nhóm " + group.getName() + ".",
                    "/groups/view?id=" + groupId + "#post-" + saved.getPostId());
        }

        resp.getWriter().write("{\"success\":true, \"postId\":" + saved.getPostId() + ", \"hidden\":" + saved.isHiddenByOwner() + "}");
    }

    // ---- Delete post ----
    private void handleDeletePost(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        String postIdStr = req.getParameter("postId");
        if (postIdStr == null) { resp.setStatus(400); resp.getWriter().write("{\"error\":\"missing postId\"}"); return; }

        int postId;
        try { postId = Integer.parseInt(postIdStr); }
        catch (NumberFormatException e) { resp.setStatus(400); resp.getWriter().write("{\"error\":\"invalid postId\"}"); return; }

        // Kiểm tra quyền sở hữu
        Post post = postDAO.getPostById(postId);
        if (post == null) { resp.setStatus(404); resp.getWriter().write("{\"error\":\"not found\"}"); return; }
        boolean isAuthor = post.getAuthor() != null && post.getAuthor().getUserId() == user.getUserId();
        boolean isGroupOwner = post.getGroupId() != null && GroupPermission.isOwnerOf(post.getGroupId(), user.getUserId());
        if (!isAuthor && !isGroupOwner) {
            resp.setStatus(403); resp.getWriter().write("{\"error\":\"forbidden\"}"); return;
        }

        // Bài admin đang ẩn: giữ lại làm bằng chứng cho báo cáo, chủ bài không tự xóa được
        if (post.isHiddenByAdmin()) {
            writeError(resp, 409, "Bài viết đang bị ẩn do vi phạm nên không thể xóa."); return;
        }

        postDAO.deletePost(postId);
        UploadUtil.delete(req.getServletContext(), post.getImagePath());
        UploadUtil.delete(req.getServletContext(), post.getVideoPath());
        UploadUtil.delete(req.getServletContext(), post.getModelPath());
        resp.getWriter().write("{\"success\":true}");
    }

    // ---- Edit post ----
    private void handleEditPost(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        String postIdStr  = req.getParameter("postId");
        String content    = req.getParameter("content");
        String visibility = req.getParameter("visibility");

        if (postIdStr == null || content == null) {
            resp.setStatus(400); resp.getWriter().write("{\"error\":\"missing params\"}"); return;
        }

        int postId;
        try { postId = Integer.parseInt(postIdStr); }
        catch (NumberFormatException e) { resp.setStatus(400); resp.getWriter().write("{\"error\":\"invalid postId\"}"); return; }

        // Kiểm tra quyền sở hữu
        Post post = postDAO.getPostById(postId);
        if (post == null) { resp.setStatus(404); resp.getWriter().write("{\"error\":\"not found\"}"); return; }
        if (post.getAuthor() == null || post.getAuthor().getUserId() != user.getUserId()) {
            resp.setStatus(403); resp.getWriter().write("{\"error\":\"forbidden\"}"); return;
        }
        if (post.isHiddenByAdmin()) {
            writeError(resp, 409, "Bài viết đang bị ẩn do vi phạm nên không thể chỉnh sửa."); return;
        }
        // Bài chia sẻ được phép để trống bình luận, bài thường thì không
        if (content.trim().isEmpty() && !post.isShare()) {
            resp.setStatus(400); resp.getWriter().write("{\"error\":\"missing params\"}"); return;
        }

        Post updated = postDAO.updatePost(postId, content.trim(), visibility);
        com.uterspace.ai.AiService.analyzePostAsync(postId, updated.getContent());
        // Hộp thoại sửa bài có lựa chọn "Chỉ mình tôi" → đổi cờ tự ẩn (không gửi tham số = giữ nguyên)
        String hiddenParam = req.getParameter("hidden");
        boolean hidden = post.isHiddenByOwner();
        if (hiddenParam != null && post.getGroupId() == null) {
            hidden = "true".equals(hiddenParam);
            postDAO.setHiddenByOwner(postId, user.getUserId(), hidden);
        }
        resp.getWriter().write(
            "{\"success\":true" +
            ",\"content\":\"" + escapeJson(updated.getContent()) + "\"" +
            ",\"visibility\":\"" + escapeJson(updated.getVisibility()) + "\"" +
            ",\"visibilityLabel\":\"" + escapeJson(updated.getVisibilityLabel()) + "\"" +
            ",\"hidden\":" + hidden + "}"
        );
    }

    // ---- Chủ bài tự ẩn / hiện lại (plan 6.2: cờ is_hidden_by_owner chỉ chủ bài đổi) ----
    private void handleHidePost(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        int postId;
        try { postId = Integer.parseInt(req.getParameter("postId")); }
        catch (NumberFormatException e) { writeError(resp, 400, "Bài viết không hợp lệ."); return; }
        boolean hidden = "true".equals(req.getParameter("hidden"));

        // UPDATE có điều kiện author = user → không cần đọc trước, người khác gửi id cũng không đổi được
        if (!postDAO.setHiddenByOwner(postId, user.getUserId(), hidden)) {
            writeError(resp, 403, "Bạn chỉ có thể ẩn bài viết của chính mình."); return;
        }
        resp.getWriter().write("{\"success\":true,\"hidden\":" + hidden + "}");
    }

    // ---- Chia sẻ kèm bình luận (Quote Share) ----
    private void handleSharePost(HttpServletRequest req, HttpServletResponse resp, User user)
            throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        String postIdStr  = req.getParameter("postId");
        String content    = req.getParameter("content");
        String visibility = "friends".equals(req.getParameter("visibility")) ? "friends" : "public";
        // "Chỉ mình tôi": bài chia sẻ ở trạng thái chủ bài tự ẩn (is_hidden_by_owner = 1), giống khi đăng bài
        boolean hidden    = "true".equals(req.getParameter("hidden"));

        int postId;
        try { postId = Integer.parseInt(postIdStr); }
        catch (NumberFormatException e) { writeError(resp, 400, "Bài viết không hợp lệ."); return; }

        Post target = postDAO.getPostById(postId);
        if (target == null || !postDAO.canView(postId, user.getUserId())) {
            writeError(resp, 404, "Bài viết không còn tồn tại."); return;
        }

        // Chia sẻ lại 1 bài chia sẻ → luôn chia sẻ BÀI GỐC, nên bài lồng chỉ sâu đúng 1 cấp
        // (JSP không phải render đệ quy post-trong-post-trong-post).
        Post original = target.isShare() ? postDAO.getPostById(target.getSharedPostId()) : target;
        if (original == null || !postDAO.canView(original.getPostId(), user.getUserId())) {
            writeError(resp, 410, "Bài viết gốc đã bị xóa, không thể chia sẻ."); return;
        }

        // Bài trong nhóm không được mang ra ngoài nhóm (nhất là nhóm kín)
        if (original.getGroupId() != null) {
            writeError(resp, 403, "Bài viết trong nhóm không thể chia sẻ ra ngoài nhóm.");
            return;
        }

        // Bài chỉ dành cho bạn bè thì chỉ chính tác giả được chia sẻ, tránh lộ ra ngoài vòng bạn bè
        boolean isOwner = original.getAuthor() != null && original.getAuthor().getUserId() == user.getUserId();
        if ("friends".equals(original.getVisibility()) && !isOwner) {
            writeError(resp, 403, "Bài viết này chỉ hiển thị với bạn bè nên không thể chia sẻ.");
            return;
        }

        Post share = postDAO.sharePost(user.getUserId(), original.getPostId(),
                                       content != null ? content.trim() : "", visibility, hidden);
        com.uterspace.ai.AiService.analyzePostAsync(share.getPostId(), share.getContent());

        // Báo cho tác giả bài gốc (bài chia sẻ "Chỉ mình tôi" thì không báo — tác giả gốc cũng không xem được)
        if (!isOwner && !hidden && original.getAuthor() != null) {
            Notification notif = new Notification();
            notif.setUserId(original.getAuthor().getUserId());
            notif.setActor(user);
            notif.setType("SHARE");
            notif.setContent("đã chia sẻ bài viết của bạn.");
            // Trang cá nhân luôn hiện bài của người chia sẻ (bảng tin chỉ hiện nếu là bạn bè)
            notif.setTargetUrl("/profile?userId=" + user.getUserId() + "#profile-post-" + share.getPostId());
            NotificationService.notify(notif.getUserId(), notif.getActor().getUserId(), notif.getType(), notif.getContent(), notif.getTargetUrl(), null);
        }

        resp.getWriter().write(
            "{\"success\":true" +
            ",\"postId\":" + share.getPostId() +
            ",\"originalId\":" + original.getPostId() +
            ",\"hidden\":" + hidden +
            ",\"shareCount\":" + (original.getShareCount() + 1) + "}"
        );
    }

    /** Thời lượng video (giây) do trình duyệt đọc được; giá trị lạ → 0 */
    private static int parseDuration(String s) {
        try {
            double d = Double.parseDouble(s);
            return (d > 0 && d < 6 * 3600) ? (int) Math.round(d) : 0;
        } catch (NumberFormatException | NullPointerException e) {
            return 0;
        }
    }

    private void writeError(HttpServletResponse resp, int status, String message) throws IOException {
        resp.setStatus(status);
        resp.getWriter().write("{\"error\":\"" + escapeJson(message) + "\"}");
    }

    private String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "");
    }

    /** Chip "Thịnh hành": name = tên thẻ (không '#') để dựng link /hashtag?tag= */
    private Map<String, String> buildTrend(String name, int postCount) {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("name",  name);
        m.put("tag",   "#" + name);
        m.put("count", postCount + " bài viết");
        return m;
    }
}
