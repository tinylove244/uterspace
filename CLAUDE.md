# CLAUDE.md — Hướng dẫn Kiến trúc & Truy vấn Database UTErSpace cho Claude Code

Tài liệu này cung cấp toàn bộ ngữ cảnh hệ thống **UTErSpace** (Mạng xã hội sinh viên HCMUTE) và công cụ truy vấn Database trực tiếp để **Claude** trên máy thành viên có thể đọc code, chạy SQL kiểm tra dữ liệu bảng, sửa lỗi và kiểm thử ngay lập tức.

---

## 1. Kết nối Database Dùng Chung (MySQL 8.4 trên Máy Chủ qua Tailscale)

Toàn bộ 24 bảng dữ liệu thật từ Aiven Cloud đã được kéo về chạy trên **MySQL 8.4 của Máy Chủ (Host Server)** để giảm độ trễ từ ~150ms xuống **2ms** và mở giới hạn kết nối lên **200 connections**.

- **Host IP Tailscale hiện tại:** `100.119.255.40` *(Máy Chủ `LAPTOP-4TN8K2UN` — có thể đổi bằng `.\set-tailscale-db-ip.ps1 -TailscaleIP <IP_TAILSCALE>`)*.
- **Port:** `3306`
- **Database:** `defaultdb`
- **Username:** `avnadmin` (đã mở full quyền `'avnadmin'@'%'` cho mọi máy trong mạng Tailscale)
- **Password:** Đọc tự động từ `db.password` trong `<Tomcat>/conf/uterspace-cloud.properties` (giống mật khẩu Aiven cũ của nhóm)
- **Múi giờ Server:** `Asia/Ho_Chi_Minh` (`+07:00`)
- **File cấu hình thống nhất:** Địa chỉ JDBC được đặt chung tại [`src/main/resources/META-INF/persistence.xml`](src/main/resources/META-INF/persistence.xml) (dòng 37). Tài khoản/mật khẩu DB và Cloudinary đọc từ `<Tomcat>/conf/uterspace-cloud.properties` qua [`CloudConfig.java`](src/main/java/com/uterspace/util/CloudConfig.java) và [`JPAUtil.java`](src/main/java/com/uterspace/util/JPAUtil.java).

### ⚡ Cách để Claude tự chạy câu lệnh SQL trực tiếp (Không cần cài MySQL CLI)
Khi Claude cần kiểm tra cấu trúc bảng (`DESCRIBE`), xem dữ liệu thật (`SELECT`), hoặc chạy câu lệnh `ALTER`/`INSERT`/`UPDATE` trên Database của Máy Chủ, **hãy chạy công cụ [`run-sql.ps1`](run-sql.ps1) có sẵn ở gốc dự án** (tự động dùng `mysql-connector-j` và đọc URL từ `persistence.xml`):

```powershell
# Xem danh sách 24 bảng trong defaultdb
.\run-sql.ps1 -Query "SHOW TABLES;"

# Xem cấu trúc bảng hoặc kiểm tra dữ liệu
.\run-sql.ps1 -Query "DESCRIBE posts;"
.\run-sql.ps1 -Query "SELECT user_id, first_name, last_name, email, role FROM users LIMIT 5;"

# Chạy một file migration SQL
.\run-sql.ps1 -File "db\aiven_mysql_migration.sql"
```

### 📋 Danh sách 24 Bảng trong Database `defaultdb`
`admin_logs`, `chat_messages`, `comments`, `conversation_members`, `conversations`, `friendships`, `group_members`, `groups_tbl`, `likes`, `message_hidden`, `message_reactions`, `notifications`, `posts`, `reports`, `saved_posts`, `search_history`, `stories`, `story_reactions`, `story_views`, `user_blocks`, `user_dids`, `user_settings`, `users`, `webauthn_credentials`.

---

## 2. Lưu trữ Ảnh / Video (Giữ nguyên 100% trên Cloudinary)

- Toàn bộ ảnh, video, story, avatar, mô hình 3D được đẩy lên **Cloudinary** (`cloudName=yjjoybu5`) qua [`UploadUtil.java`](src/main/java/com/uterspace/util/UploadUtil.java).
- Khi test tính năng đăng bài / đổi avatar / đăng story trên máy chạy Claude (`http://localhost:8080/uterspace`), file được upload lên Cloudinary và link `https://res.cloudinary.com/...` được lưu thẳng vào MySQL trên Máy Chủ → **Máy Chủ nhìn thấy ảnh/video mới ngay lập tức**.

---

## 3. Tech Stack & Ràng buộc Kỹ thuật (BẮT BUỘC TUÂN THỦ)

- **Servlet Container:** **Apache Tomcat 9.x**.
  - ⚠️ **TUYỆT ĐỐI CHỈ DÙNG `javax.servlet.*` và `javax.websocket.*`** (Java EE 8). **KHÔNG** dùng `jakarta.servlet.*` hay `jakarta.websocket.*`.
- **ORM:** Hibernate 5.6.15.Final + HikariCP 4.0.3 (`javax.persistence.*`), Dialect `org.hibernate.dialect.MySQL8Dialect`.
- **Truy vấn song song:** [`DbParallel.java`](src/main/java/com/uterspace/util/DbParallel.java) hỗ trợ chạy song song các tác vụ độc lập trong [`FeedController.java`](src/main/java/com/uterspace/controller/FeedController.java).
- **WebSocket Real-time:** [`RealtimeHub.java`](src/main/java/com/uterspace/websocket/RealtimeHub.java) và [`realtime.js`](src/main/webapp/assets/js/realtime.js) (tự động chọn `ws://` khi chạy localhost/Tailscale và `wss://` khi chạy qua HTTPS Cloudflare Tunnel).

---

## 4. Quy trình Làm việc & Đồng bộ giữa Máy chạy Claude và Máy Chủ

1. **Đổi IP Database sang IP Tailscale của Máy Chủ (nếu chưa đồng bộ qua Git):**
   ```powershell
   .\set-tailscale-db-ip.ps1 -TailscaleIP <IP_TAILSCALE_MAY_CHU>
   ```
2. **Build & Test trên máy chạy Claude:**
   ```powershell
   mvn clean package -DskipTests
   ```
   Sau đó deploy `target/uterspace.war` lên Tomcat local (`http://localhost:8080/uterspace`).
3. **Đẩy code đã sửa xong lên Máy Chủ:**
   - `git add . && git commit -m "..." && git push`
   - Máy Chủ chỉ cần `git pull` và `mvn package -DskipTests` để cập nhật lên link báo cáo Cloudflare Tunnel (`.\start-cloudflare-tunnel.ps1`).
