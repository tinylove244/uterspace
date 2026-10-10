# UTErSpace

Mạng xã hội dành cho sinh viên HCMUTE – Đồ án môn học Web Programming.

## Tech Stack
- **Backend:** Java Servlet / JSP (Jakarta EE-style MVC)
- **Build tool:** Maven
- **Server:** Apache Tomcat 9.x
- **Database:** Microsoft SQL Server (Đã được Cloud hóa trên SmarterASP)
- **Media Storage:** Cloudinary (Tự động upload và đồng bộ)

---

## 🚀 Hướng Dẫn Chạy Dự Án (Dành Cho Nhóm)

Dự án này đã được cấu hình **100% Cloud**. Bạn **KHÔNG CẦN** phải cài đặt SQL Server tại máy hay cấu hình thư mục lưu trữ ảnh. Tất cả đã được đồng bộ để chạy ngay lập tức.

### Bước 1: Chuẩn Bị
1. Clone dự án về máy.
2. Mở thư mục dự án bằng **VS Code**.
3. Cài đặt các Extension cần thiết:
   - **Extension Pack for Java** (Của Microsoft).
   - **Community Server Connector** (Của Red Hat - Để chạy Tomcat).

### Bước 2: Build Dự Án (Bắt buộc)
> **Lưu ý cực kỳ quan trọng:** Extension Tomcat của VS Code đôi khi không nhận diện đúng các thư viện Maven (như jdbc, cloudinary). Để tránh lỗi HTTP 404 hoặc ClassNotFound, bạn **bắt buộc** phải build file .war thủ công.

1. Mở Terminal trong VS Code (Ctrl + ~).
2. Chạy lệnh sau để Maven tải thư viện và đóng gói dự án:
   `ash
   mvn clean package
   `
3. Đợi đến khi báo BUILD SUCCESS. Lúc này, trong thư mục 	arget/ sẽ xuất hiện file **uterspace.war** (khoảng 45MB).

### Bước 3: Chạy Web (Debug)
1. Mở thanh Explorer bên trái của VS Code.
2. Mở thư mục **	arget/**.
3. **Click chuột phải** vào file **uterspace.war**.
4. Chọn **Run on Server** (hoặc Debug on Server).
5. Chọn Tomcat của bạn.

Tomcat sẽ tự động khởi động, giải nén toàn bộ code và thư viện, sau đó mở trang web tại http://localhost:8080/uterspace.

---

## 📂 Cơ Sở Dữ Liệu & Ảnh
- **Database:** Mọi dữ liệu (tài khoản, bài đăng, comment...) đều được đọc/ghi trực tiếp vào Server sql5113.site4now.net. (Xem file docs/CLOUD_CREDENTIALS.md để biết tài khoản quản trị nếu cần mở bằng SSMS).
- **Ảnh & Video:** Khi bạn đăng ảnh mới trên trang web, ảnh sẽ tự động được đẩy lên **Cloudinary** và mọi người trong nhóm đều có thể thấy.

Chúc các bạn code vui vẻ và đạt điểm cao! 🎉
