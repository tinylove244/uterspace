package com.uterspace.util;

import javax.persistence.EntityManager;
import javax.persistence.EntityManagerFactory;
import javax.persistence.Persistence;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Logger;

/**
 * JPAUtil - Quản lý EntityManagerFactory dùng chung cho toàn bộ dự án.
 * Dự án hiện tại đã được đồng bộ 100% với MySQL 8 trên Cloud (Aiven).
 * Địa chỉ DB mặc định nằm trong src/main/resources/META-INF/persistence.xml; tài khoản + mật khẩu đọc từ
 * CloudConfig (file conf/uterspace-cloud.properties của Tomcat hoặc biến môi trường) — không ghi trong code.
 */
public class JPAUtil {

    private static final Logger LOG = Logger.getLogger(JPAUtil.class.getName());
    private static EntityManagerFactory factory;

    // Khởi tạo EntityManagerFactory (được gọi bởi AppContextListener khi web server start)
    public static synchronized void init() {
        if (factory == null) {
            // HikariCP mặc định kiểm tra (1 lượt mạng ~100 ms tới DB cloud) mọi kết nối rảnh quá 0,5 giây trước khi
            // cho mượn → trong lúc đang duyệt (kết nối vừa dùng xong) bỏ qua bước này tới 10 giây.
            // Không để lâu hơn: máy ngủ / Windows tạm dừng tiến trình thì luồng ping nền (keepaliveTime) không chạy,
            // máy chủ cắt kết nối → kết nối rảnh lâu PHẢI được kiểm tra, nếu không request sẽ lỗi "Connection reset".
            // Đặt trước khi lớp HikariCP được nạp (giá trị đọc một lần khi nạp lớp).
            System.setProperty("com.zaxxer.hikari.aliveBypassWindowMs", "10000");
            factory = Persistence.createEntityManagerFactory("uterspacePU", overrides());
            LOG.info("[JPAUtil] Database: Đã kết nối tới " + factory.getProperties().get("javax.persistence.jdbc.url"));
        }
    }

    /** Tài khoản DB và địa chỉ / số kết nối ghi đè lên persistence.xml (nếu có khai báo trong CloudConfig hoặc auto-detected) */
    static Map<String, Object> overrides() {
        Map<String, Object> props = new HashMap<>();
        String user = CloudConfig.get("db.user");
        if (!user.isEmpty()) {
            props.put("javax.persistence.jdbc.user", user);
        } else if (DatabaseAutoSeeder.getDetectedUser() != null) {
            props.put("javax.persistence.jdbc.user", DatabaseAutoSeeder.getDetectedUser());
        }

        String password = CloudConfig.get("db.password");
        if (!password.isEmpty()) {
            props.put("javax.persistence.jdbc.password", password);
        } else if (DatabaseAutoSeeder.getDetectedPassword() != null) {
            props.put("javax.persistence.jdbc.password", DatabaseAutoSeeder.getDetectedPassword());
        }

        String url = CloudConfig.get("db.url");
        if (!url.isEmpty()) props.put("javax.persistence.jdbc.url", url);
        String pool = CloudConfig.get("db.poolSize");
        if (!pool.isEmpty()) props.put("hibernate.hikari.maximumPoolSize", pool);
        return props;
    }

    // Lấy EntityManager để thao tác với Database
    public static EntityManager getEntityManager() {
        if (factory == null) {
            init(); // Fallback nếu chưa init
        }
        return factory.createEntityManager();
    }

    // Đóng EntityManagerFactory (khi web server shutdown)
    public static void shutdown() {
        if (factory != null && factory.isOpen()) {
            factory.close();
        }
    }
}
