package com.uterspace.util;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;

/**
 * DbParallel — chạy song song các truy vấn ĐỘC LẬP trong cùng một request.
 * DB cloud ở Las Vegas: mỗi truy vấn mất ~0,25 giây chủ yếu do đường truyền, nên 6 câu đếm của thanh bên chạy
 * nối tiếp mất ~1,5 giây, chạy song song chỉ ~0,3 giây. Mỗi tác vụ dùng EntityManager / kết nối riêng (DAO tự mở),
 * nên chỉ dùng cho lời gọi DAO chỉ đọc, không phụ thuộc request / session.
 *
 * Cách dùng:  CompletableFuture<Integer> a = DbParallel.async(() -> dao.countX(uid));  ...  int x = DbParallel.get(a);
 */
public final class DbParallel {

    /** Nhỏ hơn số kết nối tối đa của pool (10, persistence.xml) để request khác vẫn còn kết nối dùng */
    private static final int THREADS = 6;
    private static final AtomicInteger SEQ = new AtomicInteger();
    private static final ExecutorService POOL = Executors.newFixedThreadPool(THREADS, r -> {
        Thread t = new Thread(r, "db-parallel-" + SEQ.incrementAndGet());
        t.setDaemon(true);
        return t;
    });

    private DbParallel() { }

    public static <T> CompletableFuture<T> async(Supplier<T> task) {
        return CompletableFuture.supplyAsync(task, POOL);
    }

    /** Chờ kết quả; lỗi trong tác vụ được ném lại nguyên dạng (RuntimeException) như khi gọi trực tiếp */
    public static <T> T get(CompletableFuture<T> f) {
        try {
            return f.join();
        } catch (CompletionException e) {
            Throwable c = e.getCause();
            if (c instanceof RuntimeException) throw (RuntimeException) c;
            if (c instanceof Error) throw (Error) c;
            throw e;
        }
    }

    /** AppContextListener.contextDestroyed */
    public static void shutdown() {
        POOL.shutdownNow();
        try { POOL.awaitTermination(2, TimeUnit.SECONDS); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
    }
}
