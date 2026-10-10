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
import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;

public final class UploadUtil {

    public static final String STORED_PREFIX = "uploads/";
    public static final String DIR_AVATARS     = "avatars";
    public static final String DIR_COVERS      = "covers";
    public static final String DIR_POSTS       = "posts";
    public static final String DIR_GROUPS      = "groups";
    public static final String DIR_VIDEOS      = "videos";
    public static final String DIR_STORIES     = "stories";
    public static final String DIR_MODELS      = "models";
    public static final long   MAX_MODEL_BYTES = 1024L * 1024 * 20;

    // Cloudinary setup
    private static final Cloudinary cloudinary;
    static {
        cloudinary = new Cloudinary(ObjectUtils.asMap(
            "cloud_name", "yjjoybu5",
            "api_key", "121991863298958",
            "api_secret", "0dfgTCjQyl7hsip2Bv_7NMkpiVU",
            "secure", true
        ));
    }

    private UploadUtil() { }

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

    private static String uploadToCloudinary(Part part, String subdir) throws IOException {
        File temp = File.createTempFile("upl_", ".tmp");
        try {
            try (InputStream in = part.getInputStream()) {
                Files.copy(in, temp.toPath(), StandardCopyOption.REPLACE_EXISTING);
            }
            Map params = ObjectUtils.asMap(
                "folder", "uterspace_uploads/" + subdir,
                "resource_type", "auto"
            );
            Map result = cloudinary.uploader().upload(temp, params);
            return (String) result.get("secure_url");
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

    public static void delete(ServletContext ctx, String stored) {
        if (stored == null) return;
        if (stored.startsWith("http://") || stored.startsWith("https://")) {
            // Ignore Cloudinary deletion for simplicity/safety in this project
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
