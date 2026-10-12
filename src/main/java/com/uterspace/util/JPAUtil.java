package com.uterspace.util;

import javax.persistence.EntityManager;
import javax.persistence.EntityManagerFactory;
import javax.persistence.Persistence;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Logger;

/**
 * JPAUtil - Quản lý EntityManagerFactory dùng chung cho toàn bộ dự án.
 * Dự án hiện tại đã được đồng bộ 100% với SQL Server trên Cloud (SmarterASP).
 * Địa chỉ DB mặc định nằm trong src/main/resources/META-INF/persistence.xml; tài khoản + mật khẩu đọc từ
 * CloudConfig (file conf/uterspace-cloud.properties của Tomcat hoặc biến môi trường) — không ghi trong code.
 */
public class JPAUtil {

    private static final Logger LOG = Logger.getLogger(JPAUtil.class.getName());
    private static EntityManagerFactory factory;

    // Khởi tạo EntityManagerFactory (được gọi bởi AppContextListener khi web server start)
    public static synchronized void init() {
        if (factory == null) {
            // HikariCP mặc định kiểm tra (1 lượt mạng ~200 ms tới DB cloud) mọi kết nối rảnh quá 0,5 giây trước khi
            // cho mượn → trong lúc đang duyệt (kết nối vừa dùng xong) bỏ qua bước này tới 10 giây.
            // Không để lâu hơn: máy ngủ / Windows tạm dừng tiến trình thì luồng ping nền (keepaliveTime) không chạy,
            // máy chủ cắt kết nối → kết nối rảnh lâu PHẢI được kiểm tra, nếu không request sẽ lỗi "Connection reset".
            // Đặt trước khi lớp HikariCP được nạp (giá trị đọc một lần khi nạp lớp).
            System.setProperty("com.zaxxer.hikari.aliveBypassWindowMs", "10000");
            factory = Persistence.createEntityManagerFactory("uterspacePU", overrides());
            LOG.info("[JPAUtil] Database: Đã kết nối tới " + factory.getProperties().get("javax.persistence.jdbc.url"));
        }
    }

    /** Tài khoản DB (bắt buộc) và địa chỉ / số kết nối (tùy chọn) ghi đè lên persistence.xml */
    static Map<String, Object> overrides() {
        String user = CloudConfig.get("db.user");
        String password = CloudConfig.get("db.password");
        if (user.isEmpty() || password.isEmpty()) {
            String msg = "[JPAUtil] Chưa cấu hình tài khoản database. Tạo file " + CloudConfig.location()
                       + " theo mẫu db/uterspace-cloud.properties.example (điền db.user, db.password)"
                       + " hoặc đặt biến môi trường UTERSPACE_DB_USER / UTERSPACE_DB_PASSWORD, rồi khởi động lại Tomcat.";
            LOG.severe(msg);
            throw new IllegalStateException(msg);
        }
        Map<String, Object> props = new HashMap<>();
        props.put("javax.persistence.jdbc.user", user);
        props.put("javax.persistence.jdbc.password", password);
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
