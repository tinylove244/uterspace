package com.uterspace.util;

import com.uterspace.dao.StoryDAOImpl;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

@WebListener
public class AppContextListener implements ServletContextListener {

    /** Luồng nền dọn Tin (Stories) đã hết hạn — 1 luồng daemon, chạy mỗi 30 phút */
    private java.util.concurrent.ScheduledExecutorService storyCleaner;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        // Tự động kiểm tra và khởi tạo Database + nạp dữ liệu mẫu nếu DB chưa có
        DatabaseAutoSeeder.checkAndSeed();

        // Khởi tạo Hibernate/JPA khi server start để tránh bị chậm ở request đầu tiên
        JPAUtil.init();
        System.out.println("JPA EntityManagerFactory initialized.");

        // Cache-busting cho CSS/JS.
        // EncodingFilter gắn Cache-Control: max-age=604800 (7 ngày) cho static asset,
        // nên sau khi redeploy trình duyệt vẫn dùng file cũ trong cache và giao diện vỡ.
        // Mốc thời gian khởi động được gắn vào URL (?v=...) làm cache key mới,
        // buộc trình duyệt tải lại đúng một lần sau mỗi lần deploy.
        long assetVersion = System.currentTimeMillis();
        sce.getServletContext().setAttribute("assetVersion", assetVersion);
        System.out.println("assetVersion = " + assetVersion);

        // Thư mục upload ngoài webapp (META-INF/context.xml) — in ra để dễ kiểm tra khi deploy
        System.out.println("Upload dir = " + UploadUtil.uploadRoot(sce.getServletContext()).getAbsolutePath());

        // Gắn nhãn cảm xúc cho các bài cũ chưa phân tích (luồng nền, bằng từ điển — không gọi API hàng loạt)
        com.uterspace.ai.AiService.backfillAsync();

        // Tin hết hạn (quá 24 giờ) đã bị ẩn ngay trong truy vấn. Người bật "Lưu trữ tin" (mặc định) giữ lại trong
        // kho lưu trữ; người tắt lưu trữ thì xóa hẳn bản ghi + file trên đĩa (StoryDAO.purgeExpired).
        // Chừa 1 giờ sau hạn để người đang mở tin không bị mất file giữa chừng.
        ServletContext ctx = sce.getServletContext();
        storyCleaner = java.util.concurrent.Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "story-cleaner");
            t.setDaemon(true);
            return t;
        });
        storyCleaner.scheduleWithFixedDelay(() -> {
            try {
                java.util.List<String> paths = new StoryDAOImpl().purgeExpired(java.time.LocalDateTime.now().minusHours(1));
                for (String p : paths) UploadUtil.delete(ctx, p);
                if (!paths.isEmpty()) System.out.println("Story cleaner: removed " + paths.size() + " expired stories");
            } catch (RuntimeException e) {
                System.err.println("Story cleaner error: " + e.getMessage());
            }
        }, 1, 30, java.util.concurrent.TimeUnit.MINUTES);
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        // Mỗi bước bọc riêng: khi redeploy nóng (WAR bị thay giữa chừng), một bước nạp class lỗi không được
        // làm bỏ qua các bước sau — nhất là đóng pool kết nối DB cloud (gói Aiven giới hạn số kết nối)
        if (storyCleaner != null) storyCleaner.shutdownNow();
        stop("AiService", () -> com.uterspace.ai.AiService.shutdown());
        // Chờ các lệnh xóa file Cloudinary đang xếp hàng chạy xong rồi dừng luồng nền
        stop("UploadUtil", () -> UploadUtil.shutdown());
        stop("DbParallel", () -> DbParallel.shutdown());
        // Dừng các luồng gửi sự kiện WebSocket — không để luồng "mồ côi" sau mỗi lần redeploy
        stop("RealtimeHub", () -> com.uterspace.realtime.RealtimeHub.shutdown());
        // Đóng Hibernate an toàn để giải phóng resources
        stop("JPAUtil", () -> JPAUtil.shutdown());
        System.out.println("JPA EntityManagerFactory closed.");
    }

    private static void stop(String name, Runnable step) {
        try {
            step.run();
        } catch (RuntimeException | LinkageError e) {
            System.err.println("Shutdown " + name + " error: " + e);
        }
    }
}
