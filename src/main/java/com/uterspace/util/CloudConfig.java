package com.uterspace.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * CloudConfig — tài khoản SQL Server cloud (SmarterASP) và Cloudinary. KHÔNG ghi mật khẩu / API secret vào code.
 * Thứ tự ưu tiên (giống AiConfig, MailUtil):
 *   1. Biến môi trường: UTERSPACE_DB_URL, UTERSPACE_DB_USER, UTERSPACE_DB_PASSWORD, UTERSPACE_DB_POOL_SIZE,
 *                       CLOUDINARY_URL (dạng cloudinary://API_KEY:API_SECRET@CLOUD_NAME)
 *   2. File ${catalina.base}/conf/uterspace-cloud.properties   (mẫu: db/uterspace-cloud.properties.example)
 * File thật nằm NGOÀI project → không bị commit. Nạp một lần khi khởi động: sửa xong phải khởi động lại Tomcat.
 */
public final class CloudConfig {

    private static final Logger LOG = Logger.getLogger(CloudConfig.class.getName());
    public static final String FILE_NAME = "uterspace-cloud.properties";

    private static volatile Properties config;

    private CloudConfig() { }

    /** Giá trị đã trim, "" nếu chưa cấu hình */
    public static String get(String key) {
        return config().getProperty(key, "").trim();
    }

    /** Đường dẫn file cấu hình — in vào thông báo lỗi để người chạy biết tạo file ở đâu */
    public static String location() {
        File f = file();
        return f == null ? "<thư mục Tomcat>/conf/" + FILE_NAME : f.getAbsolutePath();
    }

    private static File file() {
        String base = System.getProperty("catalina.base");
        return base == null ? null : new File(base, "conf/" + FILE_NAME);
    }

    private static synchronized Properties config() {
        if (config != null) return config;
        Properties c = new Properties();
        File f = file();
        if (f != null && f.isFile()) {
            try (InputStream in = new FileInputStream(f)) {
                c.load(new InputStreamReader(in, StandardCharsets.UTF_8));
            } catch (Exception e) {
                LOG.log(Level.WARNING, "Không đọc được " + f + ": " + e.getMessage());
            }
        }
        env(c, "db.url", "UTERSPACE_DB_URL");
        env(c, "db.user", "UTERSPACE_DB_USER");
        env(c, "db.password", "UTERSPACE_DB_PASSWORD");
        env(c, "db.poolSize", "UTERSPACE_DB_POOL_SIZE");
        env(c, "cloudinary.url", "CLOUDINARY_URL");
        config = c;
        return c;
    }

    private static void env(Properties c, String prop, String var) {
        String v = System.getenv(var);
        if (v != null && !v.trim().isEmpty()) c.setProperty(prop, v.trim());
    }
}
