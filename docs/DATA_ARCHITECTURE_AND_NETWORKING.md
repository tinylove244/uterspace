# UTErSpace — Kiến Trúc Dữ Liệu, Dịch Vụ Cloud & Cơ Chế Mạng (Networking)

Tài liệu này mô tả toàn diện về **kiến trúc dữ liệu**, **các dịch vụ đám mây (Cloud Services)**, **cách triển khai trong mã nguồn**, và **cơ chế kết nối mạng đa thiết bị (Multi-client Networking)** dành cho thành viên phát triển và các mô hình AI tiếp theo tiếp quản dự án.

---

## 1. Tổng Quan Kiến Trúc (Architecture Overview)

Dự án UTErSpace được thiết kế theo mô hình **Cloud-Native Hybrid**: ứng dụng Java Web chạy trên máy chủ Apache Tomcat nội bộ, nhưng toàn bộ trạng thái dữ liệu (Database và Media Tệp) đều được phi tập trung hóa lên các nền tảng Cloud chuyên dụng.

```mermaid
graph TD
    ClientA["💻 Máy Bạn A (10.47.178.53:8080)"] -->|HTTP / WebSocket| HostTomcat["🚀 Apache Tomcat 9 (Máy chủ - 10.47.178.53)"]
    ClientB["💻 Máy Bạn B (Trình duyệt)"] -->|Mạng Nội Bộ Wi-Fi (Private LAN)| HostTomcat
    ClientC["📱 Điện thoại di động"] -->|Mạng Nội Bộ Wi-Fi (Private LAN)| HostTomcat

    subgraph "Tầng Ứng Dụng (Application Layer)"
        HostTomcat --> AppContext["AppContextListener"]
        AppContext --> JPA["JPAUtil + HikariCP Pool"]
        AppContext --> WSHub["RealtimeHub (WebSocket JSR 356)"]
        AppContext --> Upload["UploadUtil (Cloudinary SDK)"]
        HostTomcat --> Conf["conf/uterspace-cloud.properties<br/>(Bảo mật ngoài repo)"]
    end

    subgraph "Tầng Dữ Liệu Đám Mây (Cloud Data Layer)"
        JPA -->|JDBC over SSL (Port 23135)| Aiven["☁️ MySQL 8 Managed on Aiven<br/>(uterspace-uterspace.b.aivencloud.com)"]
        Upload -->|REST API over HTTPS| Cloudinary["☁️ Cloudinary Media Storage<br/>(Bucket: yjjoybu5 / uterspace_uploads)"]
    end

    subgraph "Lưu Trữ Tạm Cục Bộ (Local Fallback)"
        Upload -.->|Khi Cloudinary chưa bật| LocalDisk["📁 ${catalina.base}/uterspace-uploads"]
    end
```

---

## 2. Chi Tiết Các Dịch Vụ Đám Mây (Cloud Services)

### 2.1. Cơ Sở Dữ Liệu: MySQL 8 trên Aiven Cloud
- **Nhà cung cấp**: [Aiven.io](https://aiven.io/) (Dịch vụ MySQL Managed Database trên hạ tầng Cloud).
- **Mục đích**: Lưu trữ dữ liệu cấu trúc của toàn bộ ứng dụng (Tài khoản người dùng, Bài viết, Bình luận, Lượt thích, Quan hệ bạn bè, Nhóm, Thông báo, Tin nhắn...).
- **Thông số kết nối**:
  - **Host**: `uterspace-uterspace.b.aivencloud.com`
  - **Port**: `23135`
  - **Database / Schema**: `defaultdb`
  - **Giao thức**: MySQL 8.x Protocol, bắt buộc mã hóa **SSL Mode = REQUIRED**.
  - **Múi giờ**: `Asia/Ho_Chi_Minh` (được cấu hình trực tiếp trên JDBC connection string để đồng bộ với múi giờ thực tế tại Việt Nam, máy chủ gốc của Aiven đặt tại UTC).
- **Lưu ý vận hành (Cực kỳ quan trọng)**:
  - Gói miễn phí / dùng thử của Aiven có cơ chế **Auto Power-off** khi không có kết nối trong một khoảng thời gian.
  - Khi service bị *Powered off*, Aiven sẽ **gỡ bản ghi DNS** của host khỏi internet $\rightarrow$ Client sẽ gặp lỗi `UnknownHostException: No such host is known`.
  - **Khắc phục**: Đăng nhập [Aiven Console](https://console.aiven.io/), vào service `uterspace` và bấm nút **Power on** (hoặc dấu `...` $\rightarrow$ Power on).

### 2.2. Kho Lưu Trữ Đa Phương Tiện: Cloudinary
- **Nhà cung cấp**: [Cloudinary](https://cloudinary.com/).
- **Mục đích**: Lưu trữ phi cấu trúc các tài nguyên hình ảnh đại diện (avatar), ảnh bìa (cover), ảnh bài đăng, video (MP4/WebM), tệp tin 24h (stories).
- **Cấu trúc thư mục Cloud**: Thư mục gốc `uterspace_uploads/`, chia nhỏ thành:
  - `uterspace_uploads/avatars`
  - `uterspace_uploads/covers`
  - `uterspace_uploads/posts`
  - `uterspace_uploads/stories`
  - `uterspace_uploads/videos`
- **Tối ưu hóa**: Hệ thống có luồng ngầm `cloudinary-cleaner` tự động gửi API xóa file cũ trên Cloudinary khi người dùng đổi avatar hoặc xóa bài viết, tránh lãng phí dung lượng.

### 2.3. Fallback Lưu Trữ Cục Bộ (Local Disk)
- Nếu chưa có Cloudinary hoặc chạy chế độ phát triển ngoại tuyến: Tệp được lưu tại thư mục:
  `${catalina.base}/uterspace-uploads` (ánh xạ qua `context.xml` thành đường dẫn `/uploads/...`).

---

## 3. Cách Thức Mã Nguồn (Codebase) Khởi Tạo và Quản Lý Dữ Liệu

### 3.1. Cơ chế nạp cấu hình bảo mật (`CloudConfig.java`)
Mật khẩu DB và API Key **tuyệt đối không ghi trong mã nguồn** (giúp dự án an toàn khi đẩy lên GitHub). Thứ tự ưu tiên nạp:
1. **Biến môi trường**: `UTERSPACE_DB_URL`, `UTERSPACE_DB_USER`, `UTERSPACE_DB_PASSWORD`, `CLOUDINARY_URL`.
2. **File tệp ngoài**: `${catalina.base}/conf/uterspace-cloud.properties` (nằm trong thư mục `conf` của Tomcat, độc lập với thư mục mã nguồn).
   ```properties
   db.user=avnadmin
   db.password=<YOUR_DB_PASSWORD>
   cloudinary.cloudName=yjjoybu5
   cloudinary.apiKey=121991863298958
   cloudinary.apiSecret=<YOUR_CLOUDINARY_SECRET>
   ```

### 3.2. Quản lý kết nối JPA & HikariCP (`JPAUtil.java`, `persistence.xml`)
- Đọc tham số từ `CloudConfig.java` và ghi đè vào Persistence Unit `uterspacePU`.
- Sử dụng **HikariCP** làm connection pool thay cho pool mặc định của Hibernate:
  - Duy trì tối thiểu 5 kết nối mở sẵn (`minimumIdle = 5`, `maximumPoolSize = 10`).
  - Gửi ping nền kiểm tra (`keepaliveTime = 30000ms`), giúp giảm độ trễ mạng từ Việt Nam sang máy chủ Cloud Aiven (~100-200ms/round-trip).
  - Tự động bỏ qua kiểm tra rảnh trong vòng 10 giây đầu để tối ưu tốc độ người dùng duyệt web.

### 3.3. Khởi tạo vòng đời ứng dụng (`AppContextListener.java`)
- Khi Tomcat deploy webapp, listener này được kích hoạt đầu tiên:
  1. Gọi `JPAUtil.init()` để khởi tạo trước `EntityManagerFactory` (tránh nghẽn ở request đầu tiên).
  2. Tạo chuỗi cache-busting `assetVersion` cho tài nguyên CSS/JS.
  3. Khởi tạo dịch vụ nền `storyCleaner` dọn dẹp các Tin hết hạn (sau 24h).
  4. Khởi động AI phân tích cảm xúc ngầm (`AiService.backfillAsync()`).

---

## 4. Cơ Chế Real-time & Mạng Đa Thiết Bị (Networking & WebSocket)

### 4.1. Kiến trúc Real-time (`RealtimeHub.java`)
- Sử dụng chuẩn **WebSocket JSR 356** (`javax.websocket`).
- Tất cả các phiên kết nối WebSocket mở được quản lý tập trung trong bộ nhớ RAM của Tomcat:
  ```java
  Map<Integer, Set<Session>> BY_USER = new ConcurrentHashMap<>();
  ```
- **Hệ thống 4 làn xử lý (4-lane Thread Executor)**: Đảm bảo thứ tự gửi tin nhắn chính xác theo trình tự thời gian cho cùng 1 user mà không bị chặn bởi các user khác.
- **Tại sao cần kết nối chung 1 máy chủ Tomcat để test real-time?**:
  Vì WebSocket session được lưu trên bộ nhớ của tiến trình Tomcat máy chủ. Khi máy A gửi tin nhắn, tiến trình Tomcat sẽ tìm thấy phiên WebSocket của máy B và đẩy (push) gói tin JSON xuống trình duyệt máy B tức thì.

### 4.2. Cơ Chế Kết Nối Mạng Nội Bộ (LAN / Wi-Fi)
Khi triển khai cho nhóm kiểm thử mà không dùng Tailscale hay Cloudflare Tunnel:
1. **IP Binding**: Tomcat lắng nghe trên tất cả các interface mạng (`0.0.0.0` / `::`), cho phép các máy cùng dải mạng truy cập qua địa chỉ IP cục bộ của máy chủ (ví dụ: `http://10.47.178.53:8080/uterspace`).
2. **Cơ chế Windows Firewall (Bài học quan trọng)**:
   - Trên hệ điều hành Windows, khi kết nối vào Wi-Fi mới, Windows thường đặt mặc định là **Public Network**.
   - Mặc định, Windows Defender Firewall có sẵn quy tắc: **`Block inbound connection cho java.exe trên Public Profile`**.
   - **Quy tắc giải quyết**:
     - Chuyển chế độ mạng Wi-Fi sang **Private Network** (trong Windows Settings).
     - Mở cổng 8080 TCP Inbound:
       ```powershell
       New-NetFirewallRule -DisplayName "Tomcat 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
       ```
3. **Lưu ý về AP Isolation ở mạng công cộng**:
   - Ở các mạng Wi-Fi quán cafe hoặc trường học có bật tính năng **AP Isolation** (Client Isolation), router sẽ chặn các máy nói chuyện trực tiếp với nhau qua IP LAN.
   - Khi đó, giải pháp tốt nhất là: **Một máy bật Mobile Hotspot (Điểm phát sóng di động)** cho các máy khác bắt vào, hoặc dùng SSH reverse tunnel (`ssh -p 443 -R0:localhost:8080 a.pinggy.io`).

---

## 5. Checklist Dành Cho AI Model & Lập Trình Viên Khi Xử Lý Lỗi

| Lỗi Gặp Phải | Nguyên Nhân Gốc | Giải Pháp Nhanh |
|:---|:---|:---|
| **HTTP 404** khi vừa deploy | Thiếu file `conf/uterspace-cloud.properties` khiến `AppContextListener` ném lỗi $\rightarrow$ Tomcat hủy khởi động context `/uterspace`. | Tạo file `uterspace-cloud.properties` trong `<Tomcat>/conf/` theo tài liệu `CLOUD_CREDENTIALS.md`. |
| **UnknownHostException** `uterspace-uterspace.b.aivencloud.com` | Service MySQL trên Aiven Cloud đang ở trạng thái **Powered off** (Aiven gỡ bản ghi DNS). | Đăng nhập [Aiven Console](https://console.aiven.io/), bấm **Power on** và chờ 1-2 phút cho DNS phục hồi. |
| **ERR_CONNECTION_TIMED_OUT** khi máy khác vào IP | 1. Mạng đang ở chế độ **Public** và Firewall chặn Java.<br>2. Wi-Fi quán cafe bật **AP Isolation**. | 1. Chuyển Wi-Fi sang **Private Network**.<br>2. Phát Wi-Fi từ điện thoại hoặc dùng Pinggy Tunnel. |
| **Không đăng được ảnh / video** | Chưa cấu hình hoặc sai thông số Cloudinary. | Kiểm tra lại 3 tham số `cloudinary.cloudName`, `apiKey`, `apiSecret` trong file properties. |
