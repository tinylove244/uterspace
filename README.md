# UTErSpace — Mạng Xã Hội Sinh Viên HCMUTE
> **Đồ án môn học:** Lập trình Web (Web Programming)  
> **Khoa:** Công nghệ Thông tin — Trường ĐH Sư phạm Kỹ thuật TP.HCM (HCMUTE)

---

## 🛠️ Công Nghệ Sử Dụng (Tech Stack)
- **Backend:** Java Servlet / JSP (Mô hình MVC chuẩn Jakarta EE / `javax.*`)
- **ORM / Database Access:** JPA 2.2 / Hibernate 5.6 & HikariCP Connection Pool
- **Cơ sở dữ liệu:** MySQL 8.x (24 bảng quan hệ chuẩn hóa, UTF-8 MB4)
- **Quản lý dự án & Thư viện:** Apache Maven
- **Web Server:** Apache Tomcat 9.x
- **Bảo mật:** Mã hóa mật khẩu chuẩn BCrypt (Cost 12), Bộ lọc CSRF Token, XSS Sanitizer, Session Fixation Protection

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Dự Án

### 1. Yêu cầu môi trường
- **Java Development Kit (JDK):** **JDK 17 trở lên** *(Bắt buộc, `pom.xml` biên dịch ở mức Java 17)*.
- **Web Server:** Apache Tomcat 9.0.x
- **Database:** MySQL 8.x (hoặc MySQL trong XAMPP / Laragon đang bật cổng `3306`).
- **IDE khuyên dùng:** Eclipse IDE for Enterprise Java / IntelliJ IDEA Ultimate.

---

### 2. Các bước chuẩn bị & chạy Web

#### ⚠️ Bước 1 (Bắt buộc - Chỉ làm 1 lần): Tạo thư mục upload cho Tomcat
Do dự án được cấu hình lưu trữ file đa phương tiện (ảnh, video) ở thư mục ngoài webapp để tránh bị xóa mất khi redeploy file WAR, Tomcat yêu cầu thư mục này phải tồn tại trước khi khởi động:
- **Tên thư mục cần tạo:** **`uterspace-uploads`**
- **Vị trí tạo:** Nằm ngay tại thư mục gốc cài đặt của Tomcat (ngang hàng với `bin`, `conf`, `webapps`).  
  *(Ví dụ nếu Tomcat của bạn nằm tại `C:\ApacheTomcat` hoặc `D:\Tomcat9\apache-tomcat-9.0.x`, hãy tạo thư mục: `C:\ApacheTomcat\uterspace-uploads`)*.
- **Minh họa cấu trúc thư mục Tomcat sau khi tạo:**
  ```text
  apache-tomcat-9.0.x/
   ├── bin/
   ├── conf/
   ├── lib/
   ├── webapps/
   └── uterspace-uploads/   <--- [Tạo thư mục rỗng này ở đây]
  ```

#### Bước 2: Đảm bảo dịch vụ MySQL đang chạy
- Khởi động MySQL cục bộ (cổng mặc định `3306`).
- *(Bạn không cần mở MySQL Workbench tạo database hay gõ câu lệnh SQL nào, hệ thống sẽ tự làm).*

#### Bước 3: Mở dự án trong IDE & Khởi chạy
1. Trong Eclipse (hoặc IntelliJ): Chọn `File` ➔ `Open Projects from File System...` (hoặc `Open...`) ➔ Chọn thư mục chứa file `pom.xml`.
2. Click chuột phải vào dự án ➔ Chọn **`Run As`** ➔ **`Run on Server`** (Chọn Apache Tomcat 9).
3. **Cơ chế Auto-Seed tự động:** Khi Tomcat khởi động, `DatabaseAutoSeeder` sẽ tự động kết nối MySQL, tạo database `defaultdb` và nạp toàn bộ **24 bảng, 70 bài viết thật, 33 tài khoản người dùng** trong vòng 2 - 3 giây.
4. Trình duyệt sẽ tự động mở trang web tại: **`http://localhost:8080/uterspace/`**

> **Ghi chú (Nếu muốn import Database thủ công):**  
> Trong thư mục `db/` có sẵn file master: **`db/uterspace_database.sql`**. Bạn có thể mở file này bằng MySQL Workbench / DBeaver và bấm Execute để nạp thủ công nếu muốn.

---

## 👥 Danh Sách Tài Khoản Mẫu Để Chấm Điểm & Test

*(Tất cả tài khoản mẫu trong hệ thống đều dùng chung một mật khẩu duy nhất)*:

| Vai trò | Họ và tên | Email đăng nhập | Mật khẩu |
| :--- | :--- | :--- | :--- |
| **Quản trị viên (ADMIN)** | Quản trị UTEr | **`admin@uterspace.edu.vn`** | **`12345678`** |
| **Admin Test** | Test Admin | **`admin@test.com`** | **`12345678`** |
| **Sinh viên (USER - Nhiều bài viết)** | Nguyễn Đức Huy | **`duy@student.hcmute.edu.vn`** | **`12345678`** |
| **Sinh viên (USER)** | Trần Lan Anh | **`lananh@student.hcmute.edu.vn`** | **`12345678`** |
| **Sinh viên (USER)** | Võ Diễm Quỳnh | **`diemquynh@student.hcmute.edu.vn`** | **`12345678`** |

---

## ✨ Các Tính Năng Nổi Bật Sẵn Sàng Trải Nghiệm
1. **Bảng tin (Newsfeed):** Bài viết đa phương tiện (Ảnh sắc nét, Video MP4 có trình phát tua mượt mà), Thích (Like), Bình luận (Comment), Chia sẻ bài viết (Quote Share), Lưu bài viết.
2. **Kênh Video UTErTube:** Trang dành riêng để xem video ngắn và vlog đời sống sinh viên.
3. **Trang cá nhân (Profile):** Cắt ảnh đại diện Cropper, Đổi ảnh bìa, Quản lý danh sách bài viết cá nhân, Bộ lọc ảnh/video.
4. **Nhắn tin Thời gian thực (Chat):** Trò chuyện cá nhân 1-1, gửi sticker/ảnh qua WebSocket.
5. **Bảo mật & Cài đặt:** Đổi mật khẩu, Khóa/mở tài khoản, Đăng nhập bảo mật.
