package com.uterspace.util;

import javax.servlet.ServletContext;
import javax.servlet.http.Part;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.UUID;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.logging.Level;
import java.util.logging.Logger;
import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;

public final class UploadUtil {

    private static final Logger LOG = Logger.getLogger(UploadUtil.class.getName());

    public static final String STORED_PREFIX = "uploads/";
    public static final String DIR_AVATARS     = "avatars";
    public static final String DIR_COVERS      = "covers";
    public static final String DIR_POSTS       = "posts";
    public static final String DIR_GROUPS      = "groups";
    public static final String DIR_VIDEOS      = "videos";
    public static final String DIR_STORIES     = "stories";
    public static final String DIR_MODELS      = "models";
    public static final long   MAX_MODEL_BYTES = 1024L * 1024 * 20;

    /** Thư mục gốc trên Cloudinary; file do app upload nằm ở uterspace_uploads/<thư mục>/<id ngẫu nhiên> */
    public static final String CLOUD_FOLDER = "uterspace_uploads";

    /**
     * URL file do app upload: https://res.cloudinary.com/<cloud>/<image|video|raw>/upload/v123/uterspace_uploads/<thư mục>/<tên>.
     * File dữ liệu mẫu nằm thẳng ở gốc (uterspace_uploads/avatar_1.jpg, db/all_migrations_cloud.sql mục 100)
     * KHÔNG khớp → không bao giờ bị xóa, chạy lại script dựng DB vẫn còn ảnh.
     */
    private static final Pattern CLOUD_UPLOAD_URL = Pattern.compile(
        "https://res\\.cloudinary\\.com/([^/]+)/(image|video|raw)/upload/v\\d+/(" + CLOUD_FOLDER + "/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+)");

    // Tài khoản đọc từ CloudConfig (conf/uterspace-cloud.properties hoặc biến môi trường) — không ghi trong code
    private static volatile Cloudinary cloudinary;

    /** Xóa file trên Cloudinary chạy nền: không bắt người dùng chờ, xóa nhóm nhiều ảnh không làm chậm request */
    private static final ExecutorService CLOUD_CLEANER = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "cloudinary-cleaner");
        t.setDaemon(true);
        return t;
    });

    private UploadUtil() { }

    /** null nếu chưa cấu hình (thiếu cloud name / API key / API secret) */
    private static Cloudinary cloudinary() {
        Cloudinary c = cloudinary;
        if (c != null) return c;
        synchronized (UploadUtil.class) {
            if (cloudinary != null) return cloudinary;
            String url = CloudConfig.get("cloudinary.url");
            String name = CloudConfig.get("cloudinary.cloudName");
            String key = CloudConfig.get("cloudinary.apiKey");
            String secret = CloudConfig.get("cloudinary.apiSecret");
            if (!url.isEmpty()) {
                c = new Cloudinary(url);
            } else if (!name.isEmpty() && !key.isEmpty() && !secret.isEmpty()) {
                c = new Cloudinary(ObjectUtils.asMap("cloud_name", name, "api_key", key, "api_secret", secret));
            } else {
                LOG.severe("[Cloudinary] Chưa cấu hình: điền cloudinary.cloudName / apiKey / apiSecret vào " + CloudConfig.location()
                         + " (mẫu: db/uterspace-cloud.properties.example) hoặc đặt biến môi trường CLOUDINARY_URL, rồi khởi động lại Tomcat.");
                return null;
            }
            c.config.secure = true;
            cloudinary = c;
            return c;
        }
    }

    /** Dừng luồng xóa file nền (AppContextListener.contextDestroyed) */
    public static void shutdown() {
        CLOUD_CLEANER.shutdown();
        try { CLOUD_CLEANER.awaitTermination(5, TimeUnit.SECONDS); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
    }

    public static class UploadException extends Exception {
        public UploadException(String message) { super(message); }
    }

    public static File uploadRoot(ServletContext ctx) {
        String real = ctx.getRealPath("/" + STORED_PREFIX);
        File root = (real != null)
                ? new File(real)
                : new File(System.getProperty("java.io.tmpdir"), "uterspace-uploads");
        if (!root.isDirectory()) root.mkdirs();
        return root;
    }

    private static String uploadToCloudinary(Part part, String subdir) throws UploadException, IOException {
        File temp = File.createTempFile("upl_", ".tmp");
        try {
            try (InputStream in = part.getInputStream()) {
                Files.copy(in, temp.toPath(), StandardCopyOption.REPLACE_EXISTING);
            }
            Map params = ObjectUtils.asMap(
                "folder", CLOUD_FOLDER + "/" + subdir,
                "resource_type", "auto"
            );
            Cloudinary c = cloudinary();
            if (c == null) throw new UploadException("Máy chủ chưa cấu hình kho lưu trữ đám mây, vui lòng báo quản trị viên.");
            Map result;
            try {
                result = c.uploader().upload(temp, params);
            } catch (IOException | RuntimeException e) {
                // SDK ném RuntimeException khi Cloudinary trả lỗi (vượt giới hạn gói, sai định dạng...),
                // IOException khi mất mạng → đổi thành thông báo cho người dùng thay vì trang lỗi 500
                LOG.log(Level.WARNING, "[Cloudinary] Upload thất bại (" + subdir + ", " + part.getSize() + " bytes)", e);
                String msg = String.valueOf(e.getMessage());
                if (msg.contains("File size too large")) {
                    throw new UploadException("File vượt giới hạn dung lượng của kho lưu trữ (ảnh tối đa 10 MB, video tối đa 100 MB).");
                }
                if (msg.contains("Unsupported") || msg.contains("Invalid image file")) {
                    throw new UploadException("File bị hỏng hoặc không đúng định dạng — hãy chọn ảnh JPG/PNG hoặc video MP4 (H.264) / WEBM khác.");
                }
                throw new UploadException("Không tải được file lên kho lưu trữ đám mây, vui lòng thử lại sau.");
            }
            String url = (String) result.get("secure_url");
            if (url == null) throw new UploadException("Kho lưu trữ đám mây không trả về đường dẫn file, vui lòng thử lại.");
            return url;
        } finally {
            Files.deleteIfExists(temp.toPath());
        }
    }

    public static String saveImage(ServletContext ctx, Part part, String subdir) throws UploadException, IOException {
        if (part == null || part.getSize() == 0) throw new UploadException("Chưa chọn ảnh.");
        String ext = detectImageExtension(part);
        if (ext == null) throw new UploadException("Chỉ chấp nhận ảnh JPG, PNG, GIF hoặc WEBP.");
        return uploadToCloudinary(part, subdir);
    }

    public static String saveVideo(ServletContext ctx, Part part) throws UploadException, IOException {
        return saveVideo(ctx, part, DIR_VIDEOS);
    }

    public static String saveVideo(ServletContext ctx, Part part, String subdir) throws UploadException, IOException {
        if (part == null || part.getSize() == 0) throw new UploadException("Chưa chọn video.");
        String ext = detectVideoExtension(part);
        if (ext == null) throw new UploadException("Chỉ chấp nhận video MP4 hoặc WEBM.");
        return uploadToCloudinary(part, subdir);
    }

    public static String saveModel(ServletContext ctx, Part part) throws UploadException, IOException {
        if (part == null || part.getSize() == 0) throw new UploadException("Chưa chọn mô hình 3D.");
        if (part.getSize() > MAX_MODEL_BYTES) throw new UploadException("Mô hình 3D tối đa 20 MB.");
        byte[] b = head(part, 8);
        if (b.length < 8 || b[0] != 'g' || b[1] != 'l' || b[2] != 'T' || b[3] != 'F' || b[4] != 2) {
            throw new UploadException("Chỉ nhận mô hình 3D định dạng .glb (glTF 2.0 nhị phân).");
        }
        return uploadToCloudinary(part, DIR_MODELS);
    }

    public static boolean looksLikeVideo(Part part) throws IOException {
        return part != null && part.getSize() > 0 && detectVideoExtension(part) != null;
    }

    /**
     * Xóa file của bản ghi vừa xóa / vừa thay (bài viết, ảnh đại diện, ảnh bìa, tin...). Gọi SAU khi đã cập nhật DB.
     * File Cloudinary: xóa nền qua Admin API; file local cũ (uploads/...): xóa trên đĩa.
     */
    public static void delete(ServletContext ctx, String stored) {
        if (stored == null) return;
        if (stored.startsWith("http://") || stored.startsWith("https://")) {
            deleteFromCloudinary(stored.trim());
            return;
        }
        if (!stored.startsWith(STORED_PREFIX)) return;
        File root = uploadRoot(ctx);
        File file = new File(root, stored.substring(STORED_PREFIX.length()));
        try {
            if (file.getCanonicalPath().startsWith(root.getCanonicalPath() + File.separator)) {
                Files.deleteIfExists(file.toPath());
            }
        } catch (IOException ignored) { }
    }

    /**
     * {resource_type, public_id} của file do app upload lên tài khoản Cloudinary đang cấu hình; null nếu không phải
     * (file mẫu ở gốc uterspace_uploads/, file của tài khoản khác, URL lạ). public_id của image/video không có đuôi, raw thì có.
     */
    static String[] cloudinaryAsset(String url, String cloudName) {
        Matcher m = CLOUD_UPLOAD_URL.matcher(url);
        if (!m.matches() || !m.group(1).equals(cloudName)) return null;
        String type = m.group(2);
        String publicId = m.group(3);
        int dot = publicId.lastIndexOf('.');
        if (!"raw".equals(type) && dot > publicId.lastIndexOf('/')) publicId = publicId.substring(0, dot);
        return new String[] { type, publicId };
    }

    private static void deleteFromCloudinary(String url) {
        Cloudinary c = cloudinary();
        if (c == null) return;
        String[] asset = cloudinaryAsset(url, c.config.cloudName);
        if (asset == null) return;
        try {
            CLOUD_CLEANER.execute(() -> {
                try {
                    Map result = c.uploader().destroy(asset[1], ObjectUtils.asMap("resource_type", asset[0], "invalidate", true));
                    Object status = result.get("result");
                    if (!"ok".equals(status)) LOG.warning("[Cloudinary] Xóa " + asset[1] + ": " + status);
                } catch (Exception e) {
                    LOG.log(Level.WARNING, "[Cloudinary] Không xóa được " + asset[1] + " (" + asset[0] + ")", e);
                }
            });
        } catch (RejectedExecutionException e) {
            LOG.warning("[Cloudinary] Ứng dụng đang dừng, bỏ qua xóa " + asset[1]);
        }
    }

    private static String write(ServletContext ctx, Part part, String subdir, String ext) throws IOException {
        File dir = new File(uploadRoot(ctx), subdir);
        if (!dir.isDirectory()) dir.mkdirs();
        String fileName = UUID.randomUUID() + "." + ext;
        try (InputStream in = part.getInputStream()) {
            Files.copy(in, new File(dir, fileName).toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
        return STORED_PREFIX + subdir + "/" + fileName;
    }

    private static byte[] head(Part part, int n) throws IOException {
        try (InputStream in = part.getInputStream()) {
            byte[] buf = new byte[n];
            int read = 0;
            while (read < n) {
                int r = in.read(buf, read, n - read);
                if (r < 0) break;
                read += r;
            }
            return read == n ? buf : java.util.Arrays.copyOf(buf, read);
        }
    }

    // ============================================================
    //  File đính kèm tin nhắn (Local/Private) - DO NOT TOUCH
    // ============================================================

    public static final String DIR_CHAT = "chat";
    public static final long MAX_CHAT_IMAGE_BYTES = 1024L * 1024 * 10;
    public static final long MAX_CHAT_FILE_BYTES  = 1024L * 1024 * 20;

    private static final java.util.Set<String> DOC_EXTENSIONS = new java.util.HashSet<>(java.util.Arrays.asList(
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "zip", "rar", "7z", "md", "json", "sql", "java"));

    public static final class StoredFile {
        public final String path, type, name;
        public final long size;
        StoredFile(String path, String type, String name, long size) { this.path = path; this.type = type; this.name = name; this.size = size; }
    }

    public static File privateRoot(ServletContext ctx) {
        File root = new File(uploadRoot(ctx).getParentFile(), "uterspace-private");
        if (!root.isDirectory()) root.mkdirs();
        return root;
    }

    public static StoredFile saveChatFile(ServletContext ctx, Part part) throws UploadException, IOException {
        if (part == null || part.getSize() == 0) throw new UploadException("File trống.");
        String original = cleanFileName(part.getSubmittedFileName());
        String imageExt = detectImageExtension(part);
        String type, ext;
        if (imageExt != null) {
            if (part.getSize() > MAX_CHAT_IMAGE_BYTES) throw new UploadException("Ảnh tối đa 10 MB.");
            type = "IMAGE";
            ext = imageExt;
        } else {
            if (part.getSize() > MAX_CHAT_FILE_BYTES) throw new UploadException("Tệp tối đa 20 MB.");
            int dot = original.lastIndexOf('.');
            ext = dot >= 0 ? original.substring(dot + 1).toLowerCase(java.util.Locale.ROOT) : "";
            if (!DOC_EXTENSIONS.contains(ext)) {
                throw new UploadException("Chỉ gửi được ảnh hoặc tài liệu định dạng chuẩn.");
            }
            byte[] b = head(part, 4);
            boolean executable = (b.length >= 2 && b[0] == 'M' && b[1] == 'Z')
                              || (b.length >= 4 && b[0] == 0x7F && b[1] == 'E' && b[2] == 'L' && b[3] == 'F');
            if (executable) throw new UploadException("Không được gửi file chương trình.");
            type = "FILE";
        }
        File dir = new File(privateRoot(ctx), DIR_CHAT);
        if (!dir.isDirectory()) dir.mkdirs();
        String fileName = UUID.randomUUID() + "." + ext;
        try (InputStream in = part.getInputStream()) {
            Files.copy(in, new File(dir, fileName).toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
        if (original.isEmpty()) original = "tep-dinh-kem." + ext;
        return new StoredFile(DIR_CHAT + "/" + fileName, type, original, part.getSize());
    }

    public static File resolvePrivate(ServletContext ctx, String stored) {
        if (stored == null || stored.isEmpty()) return null;
        File root = privateRoot(ctx);
        File f = new File(root, stored);
        try {
            if (!f.getCanonicalPath().startsWith(root.getCanonicalPath() + File.separator)) return null;
        } catch (IOException e) {
            return null;
        }
        return f.isFile() ? f : null;
    }

    public static void deletePrivate(ServletContext ctx, String stored) {
        File f = resolvePrivate(ctx, stored);
        if (f != null) {
            try { Files.deleteIfExists(f.toPath()); } catch (IOException ignored) { }
        }
    }

    private static String cleanFileName(String name) {
        if (name == null) return "";
        String n = name.replace('\\', '/');
        n = n.substring(n.lastIndexOf('/') + 1).replaceAll("[\\p{Cntrl}\"<>|*?:]", "_").trim();
        return n.length() > 200 ? n.substring(n.length() - 200) : n;
    }

    private static String detectImageExtension(Part part) throws IOException {
        byte[] b = head(part, 12);
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) return "jpg";
        if (b.length >= 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') return "png";
        if (b.length >= 4 && b[0] == 'G' && b[1] == 'I' && b[2] == 'F' && b[3] == '8') return "gif";
        if (b.length >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') return "webp";
        return null;
    }

    private static String detectVideoExtension(Part part) throws IOException {
        byte[] b = head(part, 12);
        if (b.length >= 8 && b[4] == 'f' && b[5] == 't' && b[6] == 'y' && b[7] == 'p') return "mp4";
        if (b.length >= 4 && (b[0] & 0xFF) == 0x1A && (b[1] & 0xFF) == 0x45
                && (b[2] & 0xFF) == 0xDF && (b[3] & 0xFF) == 0xA3) return "webm";
        return null;
    }
}
