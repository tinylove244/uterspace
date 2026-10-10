package com.uterspace.util;

import javax.persistence.EntityManager;
import javax.persistence.EntityManagerFactory;
import javax.persistence.Persistence;
import java.util.logging.Logger;

/**
 * JPAUtil - Quản lý EntityManagerFactory dùng chung cho toàn bộ dự án.
 * Dự án hiện tại đã được đồng bộ 100% với SQL Server trên Cloud (SmarterASP).
 * Thông tin kết nối nằm cố định tại: src/main/resources/META-INF/persistence.xml
 */
public class JPAUtil {

    private static final Logger LOG = Logger.getLogger(JPAUtil.class.getName());
    private static EntityManagerFactory factory;

    // Khởi tạo EntityManagerFactory (được gọi bởi AppContextListener khi web server start)
    public static synchronized void init() {
        if (factory == null) {
            factory = Persistence.createEntityManagerFactory("uterspacePU");
            LOG.info("[JPAUtil] Database: Đã kết nối thành công tới SQL Server Cloud qua persistence.xml");
        }
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
