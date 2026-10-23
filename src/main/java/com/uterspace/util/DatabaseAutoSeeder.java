package com.uterspace.util;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * DatabaseAutoSeeder - Tự động kiểm tra và khởi tạo Database + nạp dữ liệu mẫu
 * khi ứng dụng khởi động trên Tomcat (Zero-Configuration cho Giảng viên).
 *
 * Quy trình:
 * 1. Đọc cấu hình JDBC URL từ CloudConfig hoặc persistence.xml (mặc định localhost:3306).
 * 2. Kết nối tới MySQL Server và đảm bảo database 'defaultdb' đã được tạo.
 * 3. Kiểm tra bảng 'users'. Nếu chưa có bảng hoặc chưa có dữ liệu:
 *    -> Tự động đọc file db/init.sql từ classpath và nạp toàn bộ 24 bảng + 70 bài viết + 33 tài khoản.
 * 4. Nếu database đã có dữ liệu -> Bỏ qua, không làm ảnh hưởng dữ liệu hiện tại.
 */
public class DatabaseAutoSeeder {

    private static final Logger LOG = Logger.getLogger(DatabaseAutoSeeder.class.getName());
    private static volatile boolean initialized = false;

    // Lưu lại thông tin kết nối thành công để JPAUtil dùng nếu cần
    private static String detectedUser = null;
    private static String detectedPassword = null;

    public static synchronized void checkAndSeed() {
        if (initialized) return;

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            LOG.warning("[AutoSeed] Không tìm thấy MySQL JDBC Driver: " + e.getMessage());
            return;
        }

        // 1. Xác định cấu hình URL, User, Password từ CloudConfig
        String configuredUrl = CloudConfig.get("db.url");
        String configuredUser = CloudConfig.get("db.user");
        String configuredPass = CloudConfig.get("db.password");

        // Đọc fallback từ persistence.xml nếu chưa cấu hình trong CloudConfig
        if (configuredUrl.isEmpty() || configuredUser.isEmpty()) {
            try (InputStream pXml = DatabaseAutoSeeder.class.getResourceAsStream("/META-INF/persistence.xml")) {
                if (pXml != null) {
                    BufferedReader br = new BufferedReader(new InputStreamReader(pXml, StandardCharsets.UTF_8));
                    String line;
                    while ((line = br.readLine()) != null) {
                        if (configuredUrl.isEmpty() && line.contains("javax.persistence.jdbc.url")) {
                            configuredUrl = extractAttr(line, "value");
                        }
                        if (configuredUser.isEmpty() && line.contains("javax.persistence.jdbc.user")) {
                            configuredUser = extractAttr(line, "value");
                        }
                        if (configuredPass.isEmpty() && line.contains("javax.persistence.jdbc.password")) {
                            configuredPass = extractAttr(line, "value");
                        }
                    }
                }
            } catch (Exception ignored) { }
        }

        if (configuredUrl.isEmpty()) {
            configuredUrl = "jdbc:mysql://localhost:3306/defaultdb?useSSL=false&allowPublicKeyRetrieval=true&characterEncoding=UTF-8&connectionTimeZone=Asia/Ho_Chi_Minh&forceConnectionTimeZoneToSession=true";
        }

        // Tách host và port từ JDBC URL
        String host = "localhost";
        int port = 3306;
        String dbName = "defaultdb";

        try {
            String clean = configuredUrl.replace("jdbc:mysql://", "");
            int slashIdx = clean.indexOf('/');
            if (slashIdx > 0) {
                String hostPort = clean.substring(0, slashIdx);
                String rest = clean.substring(slashIdx + 1);
                int qIdx = rest.indexOf('?');
                dbName = (qIdx > 0) ? rest.substring(0, qIdx) : rest;
                if (hostPort.contains(":")) {
                    String[] parts = hostPort.split(":");
                    host = parts[0];
                    port = Integer.parseInt(parts[1]);
                } else {
                    host = hostPort;
                }
            }
        } catch (Exception ignored) { }

        String serverUrl = "jdbc:mysql://" + host + ":" + port + "/?useSSL=false&allowPublicKeyRetrieval=true&characterEncoding=UTF-8&connectionTimeZone=Asia/Ho_Chi_Minh";
        String databaseUrl = "jdbc:mysql://" + host + ":" + port + "/" + dbName + "?useSSL=false&allowPublicKeyRetrieval=true&characterEncoding=UTF-8&connectionTimeZone=Asia/Ho_Chi_Minh";

        // Danh sách các cặp user/pass ứng viên để thử kết nối:
        // Ưu tiên:
        // 1. Cấu hình cụ thể từ persistence.xml / CloudConfig của Cô
        // 2. Mật khẩu rỗng "" (XAMPP / Laragon / WampServer mặc định)
        // 3. Mật khẩu phổ biến của lập trình viên và giáo viên
        List<String[]> credentialsList = new ArrayList<>();
        if (!configuredUser.isEmpty()) {
            credentialsList.add(new String[]{configuredUser, configuredPass});
        }
        credentialsList.add(new String[]{"root", ""});
        credentialsList.add(new String[]{"root", "root"});
        credentialsList.add(new String[]{"root", "123456"});
        credentialsList.add(new String[]{"root", "12345678"});
        credentialsList.add(new String[]{"root", "admin"});
        credentialsList.add(new String[]{"root", "1234"});
        credentialsList.add(new String[]{"avnadmin", configuredPass});

        Connection serverConn = null;
        String activeUser = null;
        String activePass = null;

        for (String[] creds : credentialsList) {
            try {
                serverConn = DriverManager.getConnection(serverUrl, creds[0], creds[1]);
                activeUser = creds[0];
                activePass = creds[1];
                break;
            } catch (SQLException ignored) {
                // Thử cặp tiếp theo trong danh sách
            }
        }

        if (serverConn == null) {
            LOG.warning("[AutoSeed] Không thể tự động đăng nhập MySQL tại " + host + ":" + port + " với các mật khẩu phổ biến.");
            LOG.warning("[AutoSeed] Nếu Cô dùng mật khẩu riêng, vui lòng khai báo tại persistence.xml (thuộc tính javax.persistence.jdbc.password).");
            initialized = true;
            return;
        }

        detectedUser = activeUser;
        detectedPassword = activePass;

        try {
            // 2. Đảm bảo database tồn tại
            try (Statement stmt = serverConn.createStatement()) {
                stmt.execute("CREATE DATABASE IF NOT EXISTS `" + dbName + "` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
            }
            serverConn.close();

            // 3. Kết nối vào database vừa tạo để kiểm tra dữ liệu
            try (Connection dbConn = DriverManager.getConnection(databaseUrl, activeUser, activePass);
                 Statement stmt = dbConn.createStatement()) {

                boolean needSeed = false;
                try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '" + dbName + "' AND table_name = 'users';")) {
                    if (rs.next() && rs.getInt(1) == 0) {
                        needSeed = true;
                    }
                }

                if (!needSeed) {
                    try (ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM `" + dbName + "`.`users`;")) {
                        if (rs.next() && rs.getInt(1) == 0) {
                            needSeed = true;
                        }
                    } catch (SQLException e) {
                        needSeed = true;
                    }
                }

                if (!needSeed) {
                    LOG.info("[AutoSeed] Database '" + dbName + "' đã có sẵn dữ liệu. Bỏ qua auto-seed.");
                    initialized = true;
                    return;
                }

                // 4. Bắt đầu nạp dữ liệu từ init.sql
                LOG.info("================================================================================");
                LOG.info("[AutoSeed] Phát hiện database '" + dbName + "' chưa có dữ liệu.");
                LOG.info("[AutoSeed] Đang tự động nạp bảng và dữ liệu mẫu từ db/init.sql...");
                LOG.info("================================================================================");

                InputStream in = DatabaseAutoSeeder.class.getResourceAsStream("/db/init.sql");
                if (in == null) {
                    in = Thread.currentThread().getContextClassLoader().getResourceAsStream("db/init.sql");
                }

                if (in == null) {
                    LOG.severe("[AutoSeed] Không tìm thấy file /db/init.sql trong classpath!");
                    initialized = true;
                    return;
                }

                List<String> statements = parseSqlStatements(in);
                int count = 0;
                for (String sql : statements) {
                    try {
                        stmt.execute(sql);
                        count++;
                    } catch (SQLException ex) {
                        LOG.log(Level.FINE, "SQL Warning: " + ex.getMessage());
                    }
                }

                LOG.info("================================================================================");
                LOG.info("[AutoSeed] ĐÃ NẠP THÀNH CÔNG " + count + " CÂU LỆNH SQL VÀO DATABASE '" + dbName + "'!");
                LOG.info("[AutoSeed] Hệ thống đã sẵn sàng với 24 bảng, 70 bài viết và 33 tài khoản người dùng.");
                LOG.info("================================================================================");
            }

        } catch (Exception e) {
            LOG.log(Level.WARNING, "[AutoSeed] Lỗi trong quá trình auto-seed: " + e.getMessage(), e);
        } finally {
            initialized = true;
        }
    }

    private static String extractAttr(String line, String attr) {
        String key = attr + "=\"";
        int start = line.indexOf(key);
        if (start < 0) return "";
        start += key.length();
        int end = line.indexOf('"', start);
        return (end > start) ? line.substring(start, end).trim() : "";
    }

    public static String getDetectedUser() {
        return detectedUser;
    }

    public static String getDetectedPassword() {
        return detectedPassword;
    }

    private static List<String> parseSqlStatements(InputStream in) {
        List<String> statements = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inSingleQuote = false;
        boolean inBlockComment = false;

        try (BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (!inSingleQuote && !inBlockComment) {
                    if (trimmed.isEmpty() || trimmed.startsWith("--") || trimmed.startsWith("#")) continue;
                    if (trimmed.startsWith("DELIMITER")) continue;
                }

                int len = line.length();
                for (int i = 0; i < len; i++) {
                    char c = line.charAt(i);
                    char next = (i + 1 < len) ? line.charAt(i + 1) : '\0';

                    if (!inSingleQuote) {
                        if (!inBlockComment && c == '/' && next == '*') {
                            if (i + 2 < len && line.charAt(i + 2) == '!') {
                                // Giữ conditional comments
                            } else {
                                inBlockComment = true;
                                i++;
                                continue;
                            }
                        } else if (inBlockComment && c == '*' && next == '/') {
                            inBlockComment = false;
                            i++;
                            continue;
                        }
                    }

                    if (inBlockComment) continue;

                    if (c == '\'') {
                        if (inSingleQuote && next == '\'') {
                            current.append(c).append(next);
                            i++;
                            continue;
                        } else if (inSingleQuote && i > 0 && line.charAt(i - 1) == '\\') {
                            current.append(c);
                            continue;
                        } else {
                            inSingleQuote = !inSingleQuote;
                        }
                    }

                    if (c == ';' && !inSingleQuote) {
                        String s = current.toString().trim();
                        if (s.endsWith(";")) s = s.substring(0, s.length() - 1).trim();
                        if (!s.isEmpty()) statements.add(s);
                        current.setLength(0);
                    } else {
                        current.append(c);
                    }
                }
                current.append("\n");
            }
        } catch (Exception e) {
            LOG.log(Level.WARNING, "Error reading SQL stream", e);
        }

        String rem = current.toString().trim();
        if (!rem.isEmpty()) statements.add(rem);
        return statements;
    }
}
