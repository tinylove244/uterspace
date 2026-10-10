# Thông tin Hệ thống Cloud (UTErSpace)

> **LƯU Ý BẢO MẬT:** File này chứa thông tin kết nối tới hệ thống Cloud của toàn bộ nhóm. File đã nằm trong `.gitignore` — KHÔNG commit, chỉ gửi riêng cho thành viên (Zalo / Drive). Code không còn chứa mật khẩu: mỗi máy khai báo trong file cấu hình của Tomcat (mục 3).

### 1. CLOUD DATABASE (SmarterASP.NET)
*Dùng để lưu trữ dữ liệu có cấu trúc (User, Post, Comment,...). Thay thế cho SQL Server Local.*

- **Server IP / Host:** `sql5113.site4now.net`
- **Database Name:** `db_acf87d_uterspace`
- **Username:** `db_acf87d_uterspace_admin`
- **Password:** `UterSpace@2026`

*Hướng dẫn kết nối qua SQL Server Management Studio (SSMS):*
- Chọn Authentication: `SQL Server Authentication`
- Nhập Server name, Username và Password như trên.

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

Đổi mật khẩu DB / API secret (trên trang SmarterASP / Cloudinary Console) thì chỉ cần sửa file này và mục 1, 2 — không phải sửa code.
