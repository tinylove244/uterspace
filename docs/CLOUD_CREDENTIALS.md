# Thông tin Hệ thống Cloud (UTErSpace)

> **LƯU Ý BẢO MẬT:** File này chứa thông tin kết nối tới hệ thống Cloud của toàn bộ nhóm. File đã nằm trong `.gitignore` — KHÔNG commit, chỉ gửi riêng cho thành viên (Zalo / Drive). Code không còn chứa mật khẩu: mỗi máy khai báo trong file cấu hình của Tomcat (mục 3).

### 1. CLOUD DATABASE (MySQL 8 trên Aiven)
*Dùng để lưu trữ dữ liệu có cấu trúc (User, Post, Comment,...). Thay thế cho DB SQL Server cũ trên SmarterASP.*

- **Host:** `uterspace-uterspace.b.aivencloud.com`
- **Port:** `23135`
- **Database:** `defaultdb`
- **Username:** `avnadmin`
- **Password:** `AVNS_roUZKch5x11VqG_LnD6`
- **SSL Mode:** `REQUIRED` (bắt buộc bật SSL)
- **Service URI:** `mysql://avnadmin:AVNS_roUZKch5x11VqG_LnD6@uterspace-uterspace.b.aivencloud.com:23135/defaultdb?ssl-mode=REQUIRED`

*Hướng dẫn kết nối bằng MySQL Workbench / DBeaver:*
- Nhập Host, Port, Username, Password như trên; Default Schema: `defaultdb`.
- Tab SSL: chọn `Require` (Workbench) hoặc bật `Use SSL` + `Require SSL` (DBeaver).
- Aiven bật `sql_mode` ANSI: chuỗi trong câu SQL phải dùng nháy đơn `'...'` (nháy kép là tên cột).

*DB cũ (SmarterASP, SQL Server) — app không còn dùng, giữ để đối chiếu:* `sql5113.site4now.net` / `db_acf87d_uterspace` /
`db_acf87d_uterspace_admin` / `UterSpace@2026`.

---

### 2. CLOUD MEDIA (Cloudinary)
*Dùng để lưu trữ tài nguyên phi cấu trúc (Hình ảnh avatar, Hình ảnh/Video bài đăng). Thay thế cho thư mục ổ C cục bộ.*

- **Cloud name:** `yjjoybu5`
- **API Key:** `121991863298958`
- **API Secret:** `0dfgTCjQyl7hsip2Bv_7NMkpiVU`

*Trang chủ quản trị:* [Cloudinary Console](https://console.cloudinary.com/)

---

### 3. KHAI BÁO CHO WEB CHẠY (mỗi máy làm 1 lần)
Tạo file `<thư mục Tomcat>/conf/uterspace-cloud.properties` (vd: `C:\ApacheTomcat\conf\uterspace-cloud.properties`),
mẫu ở `db/uterspace-cloud.properties.example`, điền theo mục 1 và 2 rồi khởi động lại Tomcat:

```properties
db.user=<Username ở mục 1>
db.password=<Password ở mục 1>
cloudinary.cloudName=<Cloud name ở mục 2>
cloudinary.apiKey=<API Key ở mục 2>
cloudinary.apiSecret=<API Secret ở mục 2>
```

Đổi mật khẩu DB / API secret (trên trang Aiven Console / Cloudinary Console) thì chỉ cần sửa file này và mục 1, 2 — không phải sửa code.
