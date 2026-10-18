# 🚀 KẾ HOẠCH & HƯỚNG DẪN SETUP CHO MÁY DÙNG CLAUDE (TỐI NAY & BÁO CÁO SÁNG MAI)

Tài liệu này hướng dẫn chi tiết từng bước để máy của bạn kết nối trực tiếp vào **Database MySQL 8.4 trên Máy Chủ (máy của Khuê — IP Tailscale: `100.119.255.40`)** và sử dụng **Claude** để đọc code, truy vấn SQL từ xa, sửa tính năng và test tốc độ cao.

---

## 📌 TÓM TẮT KIẾN TRÚC HIỆN TẠI (ĐÃ SETUP XONG TRÊN MÁY CHỦ)

1. **Database Dùng Chung (MySQL 8.4 trên Máy Chủ qua Tailscale):**
   - Toàn bộ 24 bảng dữ liệu thật từ Aiven Cloud đã được kéo về chạy trên **MySQL 8.4 của Máy Chủ (`100.119.255.40:3306`, database `defaultdb`)**.
   - Tốc độ truy vấn đã giảm từ ~150ms (Aiven Ấn Độ) xuống **~2–5ms** qua Tailscale, và mở giới hạn kết nối lên **200 connections**.
   - File [`src/main/resources/META-INF/persistence.xml`](src/main/resources/META-INF/persistence.xml) đã được cấu hình trỏ sẵn về `100.119.255.40:3306` và dùng chung tài khoản `avnadmin` / `db.password` có sẵn trong `<Tomcat>/conf/uterspace-cloud.properties` của bạn.
2. **Ảnh & Video (Giữ nguyên 100% trên Cloudinary):**
   - Mọi ảnh/video bạn upload khi test ở máy bạn (`localhost:8080/uterspace`) vẫn đẩy thẳng lên **Cloudinary** (`yjjoybu5`) và lưu link vào Database của Máy Chủ → Máy Chủ thấy ảnh ngay lập tức.

---

## 🛠️ 3 BƯỚC SETUP TRÊN MÁY CỦA BẠN (CHỈ MẤT 3 PHÚT)

### Bước 1: Cài đặt & Kết nối cùng mạng Tailscale với Máy Chủ
1. Tải và cài đặt **Tailscale** tại: [https://tailscale.com/download/windows](https://tailscale.com/download/windows) (hoặc chạy lệnh `winget install Tailscale.Tailscale` trong PowerShell).
2. Đăng nhập vào **cùng mạng Tailscale (Tailnet)** với máy của Khuê (qua link Invite hoặc tài khoản chung).
3. Kiểm tra kết nối tới Máy Chủ bằng cách mở Terminal (PowerShell) gõ:
   ```powershell
   ping 100.119.255.40
   ```
   *(Nếu thấy phản hồi `Reply from 100.119.255.40...` là hai máy đã thông nhau hoàn toàn!).*

---

### Bước 2: Kéo Code mới nhất về máy & Kiểm tra kết nối Database
1. Trong thư mục dự án trên máy bạn, kéo code mới nhất về:
   ```powershell
   git pull
   ```
2. Kiểm tra file `<Thư-mục-Tomcat-của-bạn>/conf/uterspace-cloud.properties`:
   - **Không cần sửa gì cả** nếu file đó của bạn đã có sẵn `db.user=avnadmin`, `db.password=...` và 3 dòng `cloudinary.*` như trước đây!
   - *(Nếu trước đó bạn từng thêm dòng `db.url=...` riêng vào file đó, hãy xóa hoặc thêm dấu `#` trước dòng `db.url` để dự án tự đọc địa chỉ `100.119.255.40:3306` từ `persistence.xml`, hoặc chạy lệnh `.\set-tailscale-db-ip.ps1 -TailscaleIP 100.119.255.40`).*
3. **Test kết nối Database từ xa ngay tại Terminal (không cần cài MySQL):**
   ```powershell
   .\run-sql.ps1 -Query "SELECT 'Ket noi thanh cong!' AS Status, COUNT(*) AS TotalUsers FROM users;"
   ```
   Nếu hiện bảng kết quả `TotalUsers = 32` nghĩa là máy bạn đã đọc/ghi trực tiếp vào Database của Máy Chủ thành công!

---

### Bước 3: Làm việc với Claude & Quy trình Sửa Code / Test

#### A. Cách sử dụng Claude hiệu quả nhất trên dự án này
- Ở thư mục gốc của dự án đã có sẵn file **[`CLAUDE.md`](CLAUDE.md)**. Khi bạn mở **Claude Code** (hoặc gửi file `CLAUDE.md` vào đầu cuộc trò chuyện với Claude), Claude sẽ nắm toàn bộ cấu trúc 24 bảng, các ràng buộc Tomcat 9 (`javax.servlet.*`, `javax.websocket.*`) và cấu hình Cloudinary.
- **Đặc biệt:** Khi Claude cần kiểm tra cấu trúc bảng, xem dữ liệu mẫu hoặc chạy lệnh SQL sửa lỗi/thêm cột, Claude có thể tự chạy trực tiếp lệnh này trong Terminal trên máy bạn mà không cần cài MySQL Workbench:
  ```powershell
  .\run-sql.ps1 -Query "DESCRIBE posts;"
  .\run-sql.ps1 -Query "SELECT * FROM posts ORDER BY created_at DESC LIMIT 5;"
  ```

#### B. Cách Build & Test giao diện / tính năng trên máy của bạn
1. Mỗi khi Claude sửa xong code (JSP, CSS, JS, Controller, DAO), bạn build lại file `.war`:
   ```powershell
   mvn clean package -DskipTests
   ```
2. Chuột phải vào `target/uterspace.war` -> **Run on Server** (chạy trên Tomcat của máy bạn tại `http://localhost:8080/uterspace`).
   - Mọi thao tác đăng bài, bình luận, thả tim, nhắn tin, upload ảnh trên máy bạn sẽ cập nhật **trực tiếp vào Database trên Máy Chủ** và tốc độ phản hồi cực nhanh!

#### C. Đẩy code hoàn thiện lên cho Máy Chủ phát sóng báo cáo
Khi một tính năng đã test ngon lành trên máy bạn:
1. Bạn commit & push lên GitHub:
   ```powershell
   git add .
   git commit -m "feat: mo ta tinh nang vua sua"
   git push
   ```
2. Báo cho Khuê (Máy Chủ) chạy `git pull` và `mvn package -DskipTests` để cập nhật lên Server chính phát qua **Cloudflare Tunnel** (`.\start-cloudflare-tunnel.ps1`) cho buổi báo cáo sáng mai!
