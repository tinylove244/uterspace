# CHANGELOG — Cloud: sửa hiển thị media Cloudinary, xóa file theo bài, bỏ mật khẩu khỏi code
> Session ngày 10/10/2026 — migration mới **100_cloudinary_seed_media** (cuối `db/all_migrations_cloud.sql`, đã chạy trên DB cloud).
> **Mỗi máy phải tạo `<Tomcat>/conf/uterspace-cloud.properties`** (mẫu `db/uterspace-cloud.properties.example`) — thiếu thì web không khởi động.

| Thay đổi | File chính |
|:--|:--|
| **Sửa:** ảnh / video upload lên Cloudinary không hiển thị (JSP nối `${ctx}` + URL tuyệt đối → `/uterspacehttps://...`). URL Cloudinary đổi thành `/cdn/...`, servlet chuyển hướng 301 sang `res.cloudinary.com` (chỉ host này, trình duyệt cache) | `MediaUrl`, `CloudMediaController` (mới) |
| **Sửa:** Cloudinary từ chối file (quá giới hạn gói Free, file hỏng, mất mạng) → trước trả trang lỗi 500, nay trả thông báo tiếng Việt, không tạo bài rác | `UploadUtil.uploadToCloudinary` |
| **Sửa:** WEBM quay từ trình duyệt / ghi màn hình hiện "Infinity:NaN" và mất thời lượng — tua tới cuối để trình duyệt tự tính | `post-modal.jsp` |
| **Mới:** xóa bài / đổi ảnh đại diện / ảnh bìa / xóa tin / giải tán nhóm → xóa luôn file trên Cloudinary (luồng nền `cloudinary-cleaner`). Chỉ xóa file người dùng upload (`uterspace_uploads/<thư mục>/...`), không bao giờ xóa ảnh / video mẫu ở gốc `uterspace_uploads/` | `UploadUtil.delete`, `AppContextListener` |
| **Bảo mật:** mật khẩu DB và API secret Cloudinary không còn trong code; đọc từ `conf/uterspace-cloud.properties` hoặc biến môi trường `UTERSPACE_DB_*`, `CLOUDINARY_URL`. `docs/CLOUD_CREDENTIALS.md` vào `.gitignore` | `CloudConfig` (mới), `JPAUtil`, `persistence.xml`, `UploadUtil` |
| **Dữ liệu mẫu:** 54 ảnh / video minh họa đã có sẵn trên Cloudinary được gắn vào DB — ảnh chỉ vào cột ảnh, video chỉ vào cột video: avatar user 1–15, bìa nhóm 1–11, ảnh 16 bài viết, file video cho 6 bài video mẫu (10 giây). Chạy lại nhiều lần không sao, không đè ảnh người dùng tự upload | `db/all_migrations_cloud.sql` (mục 100) |
| Dừng ứng dụng: mỗi bước dọn dẹp bọc riêng — trước đây `AiService.shutdown()` lỗi khi redeploy nóng làm bỏ qua bước đóng pool kết nối DB cloud | `AppContextListener` |

**Kiểm thử:** đăng video MP4 0,8 MB / WEBM 35 MB / WEBM không có thời lượng, ảnh PNG → hiển thị và tua được ở Video, Bảng tin, Trang cá nhân; file hỏng → báo lỗi 400; đổi avatar 2 lần → avatar cũ bị xóa trên Cloudinary; xóa bài video + bài ảnh → file bị xóa, file mẫu còn nguyên; thiếu file cấu hình → log ghi rõ cần tạo file nào. Dữ liệu test đã xóa.

---

# CHANGELOG — Hoàn thiện Danh tính số (DID) & giao diện Quản trị mới
> Session ngày 10/10/2026 — không cần migration mới (dùng bảng `user_dids` của 090).

## 1. Danh tính số (DID)
| Thay đổi | File chính |
|:--|:--|
| **Bảo mật:** liên kết / thay / hủy liên kết DID bắt buộc **xác thực lại** (vân tay hoặc mật khẩu) — chặn kẻ chiếm phiên gắn DID của mình vào tài khoản nạn nhân. Có thông báo khi thay hoặc hủy DID | `SecurityController`, `security.js` (`UTDid.link/unlink` dùng `guarded`) |
| VC ký đúng chuẩn **W3C `eddsa-jcs-2022`** (SHA-256 proofConfig ‖ SHA-256 tài liệu); tệp xuất bằng bản cũ vẫn kiểm tra được | `security.js` (`signDocument`, `verifyCredential`) |
| Nhập hồ sơ từ VC **chỉ khi VC do chính DID của tài khoản ký** (trước đây VC của người khác cũng ghi đè được hồ sơ) | `settings.jsp` |
| Trang Cài đặt → Danh tính số làm lại: trạng thái (khớp / chưa liên kết / lệch khóa / chưa sao lưu), sao chép DID, xem DID Document, xóa khóa khỏi trình duyệt, thay khóa | `settings.jsp`, `settings.css` |
| `GET /did/resolve?did=…` / `?userId=` — DID Resolution Result (DID Document + tài khoản đã liên kết), công khai | `DidLoginController` |
| Trang công khai **`/did/verify`**: kéo thả tệp VC để kiểm tra chữ ký, tra cứu DID | `auth/did-verify.jsp`, `did-verify.css` |
| Huy hiệu "Danh tính số đã xác minh" cạnh tên ở trang cá nhân; tùy chọn ghi nhớ khóa khi đăng nhập bằng tệp sao lưu | `profile.jsp`, `ProfileController`, `login.jsp` |

## 2. Giao diện Quản trị
- Nền sáng cùng hệ màu với phía người dùng (Poppins, navy + đỏ), **logo UTErSpace giống thanh bên của người dùng** kèm nhãn "Admin"; có chế độ tối (nút trên topbar).
- Thanh bên mới nhóm theo chức năng, icon SVG (Heroicons) thay toàn bộ emoji; menu trượt trên điện thoại.
- Bảng điều khiển: lời chào + việc cần làm, thẻ chỉ số, biểu đồ cột 7 ngày có trục, tooltip và bảng số liệu, "Tình trạng cộng đồng" (gồm số tài khoản dùng DID), dòng thời gian hoạt động.
- Bảng, bộ lọc, hộp xác nhận, toast, trạng thái trống làm lại; bảng người dùng hiện huy hiệu DID.
- File: `admin/*.jsp`, `admin.css`, `admin.js`, `AdminController`, `AdminLog`, `common/icons.jsp` (thêm icon).

---

# CHANGELOG — Tính năng mới (Migration 090)
> Session ngày 08/10/2026

Chạy `db/090_migration_ai_social.sql` (sqlcmd thêm `-I -f 65001`) trước khi deploy. Thư viện mới: `com.anthropic:anthropic-java:2.34.0`.

## 1. Sửa lỗi & bổ sung nhỏ
| Tính năng | File chính |
|:--|:--|
| Ô "Tìm cuộc trò chuyện" ở Tin nhắn tìm cả **bạn bè chưa từng nhắn tin** (mục "Bạn bè" → bấm mở chat 1-1) | `assets/js/chat.js` |
| Chia sẻ bài có thêm **🔒 Chỉ mình tôi** | `common/share-modal.jsp`, `FeedController.handleSharePost`, `PostDAO.sharePost` |
| Trang **Điều khoản sử dụng** `/terms` và **Chính sách bảo mật** `/privacy` (công khai); đăng ký bắt buộc đồng ý (kiểm cả ở server) | `LegalController`, `views/legal/*`, `AuthController` |

## 2. Story
- **Thả tim** (nút ❤️ / phím L), chủ tin nhận thông báo `STORY_REACT`; **trả lời tin** → gửi thành tin nhắn 1-1 tới chủ tin.
- Chủ tin thấy số người xem + số tim; danh sách người xem đưa người thả tim lên đầu kèm ❤️.
- **Kho lưu trữ tin** (Cài đặt → Kho lưu trữ tin): tin hết hạn được giữ lại (mặc định bật); xem lại, tải về, xóa vĩnh viễn. Tắt lưu trữ → bộ dọn tin xóa như cũ.
- File: `StoryController` (`/stories/react`, `/stories/reply`, `/stories/archive`), `StoryDAOImpl`, `feed/story-viewer.jsp`.

## 3. AI — Google Gemini / Claude + dự phòng offline (`com.uterspace.ai`)
- `AiConfig` đọc key từ `<Tomcat>/conf/uterspace-ai.properties` (tự nạp lại khi sửa), tự nhận nhà cung cấp theo dạng key.
- `GeminiClient` (REST generateContent, chuỗi model dự phòng khi 503/429/404); `ClaudeClient` (SDK chính thức, `claude-opus-5-5`). Kiểm tra kết nối: `/ai/status?ping=1`.
- **Phân tích cảm xúc** bài viết: `SentimentAnalyzer` (từ điển tiếng Việt có/không dấu, phủ định theo mệnh đề, từ nhấn mạnh, emoji) + Claude cho bài mới (chạy nền). Nhãn 😊/😟 trên thẻ bài, bộ lọc "Tiêu cực (AI)" ở trang quản trị, nhắc nhẹ trước khi đăng bài rất tiêu cực.
- **Trợ lý soạn bài**: viết chú thích theo giọng văn (Claude nhìn cả ảnh), tóm tắt, dịch, **tạo ảnh nghệ thuật** từ văn bản (vẽ canvas trên máy).
- **Người đọc**: 🌐 Dịch (Claude hoặc Translator API của Chrome), 📝 Tóm tắt, 🔊 Nghe (Text-to-Speech, chọn giọng + ngữ điệu).
- Endpoint `/ai/status|caption|summarize|translate|sentiment` (`AiController`, giới hạn 40 lần / 10 phút).

## 4. Gợi ý & cá nhân hóa (`RecommendationService`)
- **Smart Feed** "Dành cho bạn" / "Mới nhất": điểm = độ mới + thân thiết (thích, bình luận, nhắn tin) + chủ đề quan tâm + tìm kiếm + xu hướng; đa dạng tác giả; mỗi bài có lý do "✨ Vì bạn hay tương tác với…".
- **Gợi ý kết bạn**: bạn chung, nhóm chung, cùng sở thích hashtag, cùng khu vực (kèm lý do); **tìm bạn từ danh bạ** `POST /friends/contacts` (không lưu email).
- **Gợi ý nhóm / hashtag / video** trên Bảng tin; lịch sử tìm kiếm lưu ở `search_history`.

## 5. Bảng tin & media nâng cao
- Ảnh **360°** (Pannellum), ảnh **3D chiều sâu** (nghiêng điện thoại / rê chuột), **vật thể 3D .glb + AR** (`<model-viewer>`). `post-media.jsp`, `post-media.js`, `UploadUtil.saveModel`.
- **Phụ đề tự động** cho video: Whisper chạy trong trình duyệt (transformers.js) → WebVTT lưu `posts.captions_vtt`, phát qua `/media/captions`; nút **🗣️ Thuyết minh** đọc phụ đề bằng TTS.

## 6. Bảo mật & quyền riêng tư
- **Bộ lọc nội dung cá nhân** (từ khóa / cụm từ / emoji, không phân biệt dấu) + ẩn bài tiêu cực: thu gọn bài & bình luận (`ContentFilter`).
- **Sinh trắc học (WebAuthn / passkey)**: đăng ký vân tay / khuôn mặt, bắt buộc xác thực khi đổi mật khẩu, mở **Album ẩn**, gỡ passkey (`com.uterspace.security`, `SecurityController`, `assets/js/security.js`). Tự viết bộ kiểm tra chữ ký ES256/RS256, rpIdHash, cờ UP/UV, bộ đếm.
- **Danh tính số DID** (`did:key`, Ed25519 trên WebCrypto): liên kết tài khoản, **đăng nhập không mật khẩu** (`/did/challenge`, `/did/login`), sao lưu / khôi phục khóa, xuất hồ sơ thành **Verifiable Credential** có chữ ký (`eddsa-jcs-2022`) và kiểm tra / nhập VC.

---

# CHANGELOG — UTErSpace Cải tiến (Priority 1)
> Session ngày 27/09/2026

---

## Tổng quan

Phiên làm việc này tập trung vào việc khắc phục **3 lỗi nghiêm trọng** (Priority 1) được xác định sau khi đánh giá toàn bộ project, cộng thêm **1 hotfix phát sinh** khi kiểm tra thực tế.

---

## 1. Fix: Xóa bài viết thật từ Database

**Vấn đề trước đây:**
Nút `Xóa` trong menu `...` của bài viết chỉ xóa thẻ HTML ra khỏi DOM trên trình duyệt. Khi reload trang, bài viết vẫn còn nguyên vì không có request nào gửi lên server.

**Nguyên nhân gốc:**
Hàm `deletePost()` trong `newsfeed.jsp` chỉ gọi `card.remove()` và `showToast(...)` mà không có bất kỳ `fetch()` nào.

**Các file đã thay đổi:**

| File | Nội dung thay đổi |
|:-----|:-----------------|
| `src/main/java/.../dao/PostDAO.java` | Thêm method `void deletePost(int postId)` vào interface |
| `src/main/java/.../dao/PostDAOImpl.java` | Implement `deletePost`: xóa tuần tự Comments -> Likes -> SavedPosts -> Post trong 1 transaction để tránh vi phạm Foreign Key |
| `src/main/java/.../controller/FeedController.java` | Thêm URL pattern `/feed/delete` vào `@WebServlet`; thêm method `handleDeletePost()`: kiểm tra quyền sở hữu (HTTP 403 nếu không phải tác giả), gọi DAO, trả `{"success":true}` |
| `src/main/webapp/.../feed/newsfeed.jsp` | Hàm `deletePost(postId)` JS: gửi `fetch POST /feed/delete` trước; chỉ chạy animation xóa DOM khi nhận được `success:true`; hiển thị `showToast` lỗi nếu thất bại |

**Luồng hoạt động mới:**
```
User click "Xóa" -> confirm() -> fetch POST /feed/delete?postId=X
  -> FeedController.handleDeletePost()
    -> postDAO.getPostById(X) -> kiểm tra author == currentUser
    -> postDAO.deletePost(X)
      -> DELETE Comments WHERE postId=X
      -> DELETE Likes WHERE post.postId=X
      -> DELETE SavedPosts WHERE post.postId=X
      -> DELETE Post WHERE postId=X
    -> Response: {"success": true}
  -> JS: animate card ra khỏi DOM
  -> showToast("Đã xóa bài viết.")
```

---

## 2. Tính năng mới: Chỉnh sửa bài viết (Edit Post)

**Vấn đề trước đây:**
Nút "Chỉnh sửa" trong menu `...` chỉ hiển thị toast "Tính năng sắp ra mắt" — không làm gì cả.

**Các file đã thay đổi:**

| File | Nội dung thay đổi |
|:-----|:-----------------|
| `src/main/java/.../dao/PostDAO.java` | Thêm method `Post updatePost(int postId, String content, String visibility)` |
| `src/main/java/.../dao/PostDAOImpl.java` | Implement: `em.find(Post, postId)` -> set content/visibility -> `em.merge()` -> commit |
| `src/main/java/.../controller/FeedController.java` | Thêm URL pattern `/feed/edit`; `handleEditPost()`: kiểm tra quyền, gọi DAO, trả JSON kèm nội dung mới |
| `src/main/webapp/.../feed/newsfeed.jsp` | Hàm JS `openEditModal()`, `handleEditPost()`, thêm HTML modal `#edit-post-modal` |

**Luồng hoạt động mới:**
```
User click "Chỉnh sửa"
  -> openEditModal(postId): đọc nội dung hiện tại -> openModal('edit-post-modal')
  -> User chỉnh sửa textarea -> click "Lưu thay đổi"
  -> handleEditPost(): fetch POST /feed/edit {postId, content, visibility}
    -> FeedController.handleEditPost()
      -> kiểm tra author == currentUser (403 nếu không phải)
      -> postDAO.updatePost(X, newContent, visibility)
      -> Response: {"success":true, "content":"...", "visibilityLabel":"..."}
  -> JS: cập nhật .post-caption-text tại chỗ (không reload)
  -> closeModal + showToast("Đã cập nhật bài viết!")
```

---

## 3. Fix: Ảnh bài viết không hiển thị trên trang Profile

**Vấn đề trước đây:**
Sau khi đăng bài có ảnh, đường dẫn được lưu vào DB dạng `/assets/images/posts/{uuid}_{filename}`.
Nhưng JSP profile dùng template cứng `/assets/images/`
-> tạo ra path lặp: `/uterspace/assets/images//assets/images/posts/...` -> ảnh vỡ.

Ảnh cũ (seeded data) lưu dạng `study_setup.jpg` (không có `/` đầu) -> vẫn hiển thị đúng.

**File đã thay đổi:**

| File | Vị trí | Nội dung thay đổi |
|:-----|:-------|:-----------------|
| `views/profile/profile.jsp` | Cột bài viết (post cards) | Thêm `c:set postImg` với `fn:startsWith` |
| `views/profile/profile.jsp` | Tab Ảnh (photo grid) | Thêm `c:set gridImg` với logic tương tự |

**Logic phân biệt:**
```
imagePath bắt đầu bằng '/'  -> ảnh mới upload -> dùng ctx + imagePath
imagePath không có '/' đầu  -> ảnh cũ/seed   -> dùng ctx + '/assets/images/' + imagePath
```

---

## 4. Hotfix: Widget thumbnail "Ảnh" mini trong sidebar Profile

**Vấn đề:**
Phát hiện khi test thực tế: widget thumbnail 6 ảnh ở sidebar trái trang Profile bị bỏ sót khỏi fix mục 3
-> ảnh mới upload vẫn hiện broken image icon trong phần đó.

**File đã thay đổi:**

| File | Vị trí | Nội dung thay đổi |
|:-----|:-------|:-----------------|
| `views/profile/profile.jsp` | Widget `pf-photo-mini` (sidebar) | Thêm `c:set miniImg` với `fn:startsWith`; thêm `onerror` fallback ẩn ảnh vỡ |

**Thêm onerror fallback:**
```html
<img src="" alt="" loading="lazy"
     onerror="this.onerror=null;this.style.display='none';">
```

---

## Tóm tắt file thay đổi

| File | Loại thay đổi |
|:-----|:-------------|
| `dao/PostDAO.java` | +2 method mới (deletePost, updatePost) |
| `dao/PostDAOImpl.java` | +2 method (~55 dòng) |
| `controller/FeedController.java` | +2 URL pattern, +2 private method (~55 dòng) |
| `views/feed/newsfeed.jsp` | Sửa deletePost JS, thêm openEditModal, handleEditPost, modal HTML |
| `views/profile/profile.jsp` | Fix imagePath tại 4 vị trí: post cards, photo grid, mini widget, hotfix sidebar |

**Kết quả build:**
```
[INFO] Compiling 49 source files -> BUILD SUCCESS
[INFO] Building war: uterspace.war -> BUILD SUCCESS
```

---

## Ghi chú kỹ thuật

- `deletePost()` xóa theo thứ tự `Comments -> Likes -> SavedPosts -> Post` để tránh FK constraint của SQL Server.
- `Like` entity dùng `@ManyToOne Post post` -> JPQL phải dùng `l.post.postId`, không phải `l.postId`.
- Edit Post chưa hỗ trợ thay ảnh (chỉ chỉnh sửa text và chế độ hiển thị).
- File JSP không cần Maven recompile, Tomcat hot-reload tự động.

---

## 5. Cải thiện UX trang Profile và Upload Ảnh

**Vấn đề:**
1. Bài đăng trên Profile không có menu "..." để xoá, sửa như trên Newsfeed.
2. Ảnh bìa (cover) bị lấn vào ảnh đại diện (avatar) gây lỗi giao diện.
3. Chức năng cập nhật ảnh bìa và ảnh đại diện chưa hoạt động (chỉ hiện toast).
4. Avatar trong phần bình luận (của bài viết) bị lỗi đường dẫn khi là ảnh mới upload.

**Chi tiết các thay đổi:**

| File | Nội dung thay đổi |
|:-----|:-----------------|
| `views/profile/profile.jsp` | - Thêm menu tuỳ chọn (sửa/xoá/copy) vào bài viết.<br>- Thay thế button đổi ảnh bìa bằng form ẩn chứa `input type="file"` tự động submit.<br>- Thêm form ẩn tương tự cho avatar.<br>- Bổ sung JS function xử lý menu, xoá, sửa (giống bảng tin). |
| `assets/css/pages/profile.css`| - Thêm `position: relative; z-index: 2;` vào class `.pf-identity` để avatar luôn đè lên trên ảnh bìa. |
| `controller/ProfileController.java`| - Thêm annotation `@MultipartConfig` để xử lý upload file.<br>- Thêm URL mappings `/profile/avatar` và `/profile/cover`.<br>- Triển khai logic lưu file vào `/assets/images/users/` bằng thư viện `Part`. |
| `dao/UserDAO.java` & `UserDAOImpl.java`| - Bổ sung các method `updateAvatar()` và `updateCover()`. |
| `views/feed/newsfeed.jsp` | - Sửa logic hàm JS `buildComment()`: kiểm tra đường dẫn `data.avatar` có `startsWith('/')` hay không để nối string chính xác, giúp ảnh hiển thị đúng. |

**Luồng hoạt động Upload Ảnh (Avatar/Cover):**
1. User nhấn nút Đổi ảnh, trình duyệt mở hộp thoại chọn file nhờ thuộc tính `.click()` gọi sang một `<input type="file">` ẩn.
2. Thuộc tính `onchange` tự động submit form.
3. Controller nhận request tại `/profile/avatar` (hoặc cover), lưu file ảnh vào thư mục `assets/images/users/` và tạo chuỗi path.
4. Gọi method `updateAvatar()`/`updateCover()` cập nhật DB và session. Redirect trở về `/profile`.

---

## Cập nhật Profile: Cropper & Đồng bộ UI (Bản vá)
**Mục tiêu:** Cải tiến tính năng thay đổi hình ảnh (Cover/Avatar) thông qua giao diện kéo thả, cắt tỷ lệ chuyên nghiệp. Đồng bộ toàn bộ fallback avatar của hệ thống sang dạng "initials".

**Chi tiết các thay đổi:**
| File | Nội dung thay đổi |
|:-----|:-----------------|
| `views/profile/profile.jsp` | - Tích hợp thư viện **Cropper.js** qua CDN.<br>- Thêm Modal "Cắt ảnh" với cơ chế `dragMode: 'move'` và khóa khung hình.<br>- Thêm tính năng click vào để View Fullsize ảnh.<br>- Khắc phục triệt để lỗi chặn click đổi ảnh bằng cách dùng thuộc tính Native `<label for="...">` thay cho `button` Javascript.<br>- Update code xử lý Fetch API upload ảnh sau khi cắt. |
| `assets/css/pages/profile.css` | - Tăng chiều cao khối `.pf-cover` từ `190px` lên `230px`.<br>- Tăng `z-index: 3` cho nút bấm Đổi ảnh bìa, ngăn việc bị màng chắn vô hình của `.pf-identity` che khuất click. |
| `views/feed/newsfeed.jsp` &<br>`views/common/app-sidebar.jsp`| - Thay thế toàn bộ ảnh mặc định xám xịt (`avatar.jpg`) bằng dạng khối chữ cái đầu "initials" (ví dụ: chữ "DN" trên nền gradient) giúp đồng bộ 100% diện mạo với Topbar và khung Bình luận. |
| `controller/ProfileController.java`| - Tối ưu lại chuỗi `imagePath` lưu vào DB thành dạng tương đối (`users/xyz.jpg`), tương thích tự nhiên với tất cả các JSP mà không cần dùng đến chuỗi tuyệt đối `/assets...`. |

---

## 6. Tính năng mới: Chia sẻ kèm bình luận (Quote Share)

**Mô tả:** Bấm nút chia sẻ (máy bay giấy) trên bài viết → hộp thoại cho viết bình luận (không bắt buộc) + chọn chế độ hiển thị → tạo **một bài viết mới** của người chia sẻ, bên trong lồng bài gốc. Số lượt chia sẻ của bài gốc = số bài chia sẻ thật trỏ tới nó.

**Quy tắc chính:**
- Bài chia sẻ luôn trỏ tới **bài gốc**: chia sẻ lại một bài chia sẻ = chia sẻ bài gốc của nó → bài lồng chỉ sâu đúng **1 cấp**, JSP không phải render đệ quy.
- Bài `friends` (chỉ bạn bè) chỉ tác giả được chia sẻ (server trả 403, nút chia sẻ báo lỗi ngay).
- Xóa bài chia sẻ → giảm `share_count` bài gốc. Xóa bài gốc → bài chia sẻ vẫn còn, hiện "Nội dung này hiện không khả dụng" (vì vậy cột `shared_post_id` cố ý **không** có FK).
- Bài chia sẻ được phép để trống bình luận (cả khi tạo và khi chỉnh sửa).
- Tác giả bài gốc nhận thông báo loại mới `SHARE` (🔁), link tới bài chia sẻ trên trang cá nhân người chia sẻ.

| File | Nội dung thay đổi |
|:-----|:-----------------|
| `migration_share_hashtag.sql` (mới) | Thêm cột `posts.shared_post_id` + index, đồng bộ `share_count` về số thật, thêm `'SHARE'` vào CHECK của `notifications.type`. Chạy lại nhiều lần vẫn an toàn |
| `schema.sql`, `seed_more_data.sql` | Cập nhật tương ứng cho người tạo DB từ đầu; seed không còn đặt `share_count` giả |
| `model/Post.java` | Field `Integer sharedPostId`, `@Transient Post sharedPost`, helper `isShare()` |
| `dao/PostDAO(Impl).java` | `sharePost()` (tạo bài + tăng `share_count` trong 1 transaction), `attachSharedPosts()` (nạp bài gốc cho cả danh sách bằng 1 query, lọc theo quyền xem); `deletePost()` giảm `share_count` khi xóa bài chia sẻ |
| `controller/FeedController.java` | Route `POST /feed/share`; `/feed/edit` cho phép bình luận rỗng với bài chia sẻ |
| `controller/ProfileController.java`, `SavedController.java` | Gọi `attachSharedPosts()` để trang cá nhân / đã lưu hiện được bài lồng |
| `views/common/shared-post-embed.jsp` (mới) | Khung bài gốc lồng bên trong (include tĩnh trong vòng lặp bài viết) |
| `views/common/share-modal.jsp` (mới) | Hộp thoại chia sẻ + xem trước bài gốc (dựng bằng clone DOM, không chèn chuỗi HTML) |
| `views/feed/newsfeed.jsp`, `profile/profile.jsp`, `saved/saved.jsp` | Render bài chia sẻ (bình luận ở trên, bài gốc bên dưới), hiện "· N chia sẻ" |
| `model/Notification.java` | Icon cho loại `SHARE` |

**Luồng hoạt động:**
```
Click nút chia sẻ -> openShareModal(): data-share-id = id bài GỐC
  -> submitShare(): fetch POST /feed/share {postId, content, visibility}
    -> FeedController.handleSharePost()
      -> bài là bài chia sẻ? -> đổi sang bài gốc (410 nếu bài gốc đã xóa)
      -> bài gốc 'friends' và không phải tác giả? -> 403
      -> postDAO.sharePost(): INSERT posts(shared_post_id=gốc) + share_count+1
      -> Notification SHARE cho tác giả bài gốc
    -> {"success":true, "postId":..., "originalId":..., "shareCount":...}
  -> cập nhật "N chia sẻ" tại chỗ, reload để bài chia sẻ mới hiện lên
```

---

## 7. Tính năng mới: Hashtag & trang tìm theo hashtag

**Mô tả:** Mọi `#tag` trong bài viết (kể cả trong bài gốc được lồng) là link → `/hashtag?tag=DoAnCuoiKy`: trang tổng hợp mọi bài có thẻ đó mà người dùng được phép xem (bài công khai + bài của bạn bè + bài của mình). Không có bảng hashtag riêng.

**Cách lọc:** `LIKE '%#tag%'` trong SQL, sau đó lọc lại bằng regex để khớp **đúng nguyên thẻ** (`#IoT` không khớp `#IoTProject`), không phân biệt hoa thường, hỗ trợ tiếng Việt có dấu.

| File | Nội dung thay đổi |
|:-----|:-----------------|
| `util/HashtagUtil.java` (mới) | Regex tách thẻ, chuẩn hóa `?tag=`, so khớp chính xác, đếm hashtag thịnh hành |
| `dao/PostDAO(Impl).java` | `getPostsByHashtag()`, `getRecentContentsVisibleTo()` |
| `controller/FeedController.java` | Route `GET /hashtag` (dùng lại `newsfeed.jsp`); chip "Thịnh hành" giờ là hashtag **thật** (đếm trên 300 bài gần nhất) thay cho dữ liệu cứng |
| `filter/AuthFilter.java` | Bảo vệ `/hashtag` |
| `views/feed/newsfeed.jsp` | Chế độ trang hashtag: tiêu đề `#tag` + số bài, nút "Đăng bài với #tag", chip đang xem được tô đậm, trạng thái rỗng riêng |
| `views/common/footer.jsp` | Hàm toàn cục `linkifyHashtags()` (regex giống `HashtagUtil`) thay cho đoạn tô màu hashtag lặp ở từng trang; `searchHashtag()` |
| `views/common/app-topbar.jsp` | Gõ `#tag` vào ô tìm kiếm → mở trang hashtag |
| `assets/css/app-shell.css`, `pages/feed.css` | Style bài lồng, hộp thoại chia sẻ, link hashtag, trang hashtag |

**Sửa kèm:** caption bài viết trên trang Profile thiếu `id="caption-{postId}"` nên "Chỉnh sửa" mở ra ô trống và không cập nhật lại nội dung sau khi lưu — đã thêm id.

**Kiểm thử:** build `mvn clean package` thành công; chạy thử trên Tomcat 9 + SQL Server local: chia sẻ có/không bình luận, chia sẻ lại bài chia sẻ, chặn bài `friends`, xóa bài gốc/bài chia sẻ, thông báo, trang hashtag (hoa thường, tiếng Việt, tag không hợp lệ, tag không có bài).

## 8. Cải tiến: Thanh tìm kiếm · Đăng bài ẩn ("Chỉ mình tôi") · Tin (Stories) ảnh/video

### 8.1 Thanh tìm kiếm toàn trang
**Mô tả:** Ô tìm kiếm trên thanh công cụ giờ tìm được **mọi người, bài viết, nhóm, hashtag**, không phân biệt dấu
(gõ `duc` ra "Đức", `minh ha` ra "Minh Hà"). Gõ tới đâu hiện gợi ý tới đó; Enter mở trang kết quả đầy đủ.
Gõ `#tag` vẫn mở thẳng trang hashtag như trước.

| File | Nội dung |
|:--|:--|
| `dao/SearchDAO.java` (mới) | Tìm người (họ tên 2 chiều + email, bỏ tài khoản bị khóa), bài viết, nhóm, hashtag; quan hệ bạn bè từng kết quả. Lọc chữ bằng SQL gốc `COLLATE Latin1_General_100_CI_AI` (coi `đ` = `d`), **quyền xem bài vẫn lọc bằng `PostDAOImpl.VISIBLE`** → bài ẩn / bài nhóm kín / bài bị kiểm duyệt không lộ qua tìm kiếm. Thoát ký tự `%` `_` `[` trong LIKE |
| `controller/SearchController.java` (mới) | `GET /search?q=&tab=all\|people\|posts\|groups\|tags` và `GET /api/search/suggest?q=` (JSON) |
| `views/search/search.jsp`, `assets/css/pages/search.css` (mới) | Trang kết quả: tab có đếm số, thẻ người dùng (Kết bạn / Bạn bè / Đã gửi lời mời / Phản hồi), chip hashtag, danh sách nhóm (Chủ nhóm / Đã tham gia / Chờ duyệt), bài viết dùng lại `post-card.jsp` (thích, bình luận, lưu… như bảng tin); **tô vàng từ khóa** không phân biệt dấu (JS, chỉ thao tác text node) |
| `views/common/app-topbar.jsp`, `footer.jsp`, `app-shell.css` | Hộp gợi ý khi gõ (chờ 200 ms, hủy request cũ bằng `AbortController`), phím ↑ ↓ Enter Esc, mục "Tìm kiếm gần đây" (localStorage, nút Xóa), chuẩn ARIA combobox/listbox |

### 8.2 Đăng bài ở chế độ ẩn + ẩn/hiện bài ở trang cá nhân và hộp chỉnh sửa
**Mô tả:** Dùng cờ `posts.is_hidden_by_owner` (migration 020, plan 6.2). Bài ẩn: người khác không thấy ở bất kỳ đâu
(bảng tin, trang cá nhân, hashtag, video, tìm kiếm); chủ bài vẫn thấy ở trang cá nhân kèm nhãn và nút "Hiện lại".

| File | Nội dung |
|:--|:--|
| `views/common/post-modal.jsp` | Ô chế độ hiển thị thêm **🔒 Chỉ mình tôi** + dòng giải thích; đăng xong báo "đã đăng ở chế độ Chỉ mình tôi" |
| Hộp **Chỉnh sửa bài viết** (`post-support.jsp`, `profile.jsp`) | Thêm lựa chọn **🔒 Chỉ mình tôi (ẩn bài)**; mở hộp thì **chọn sẵn đúng chế độ hiện tại** của bài (trước đây luôn về "Công khai" — lỗi cũ) |
| `views/common/post-privacy.jsp` (mới) | JS dùng chung: `togglePostHidden`, chọn sẵn / đọc lựa chọn trong hộp sửa |
| Menu (...) | Bài của mình: **Ẩn bài viết** (bảng tin, trang nhóm) / **Hiện lại bài viết** (trang cá nhân) |
| `views/profile/profile.jsp` | Bài đang ẩn: viền nét đứt, mờ nhẹ, nhãn "Bạn đã ẩn bài này — chỉ mình bạn nhìn thấy" + nút **Hiện lại**, dòng phạm vi đổi thành "🔒 Chỉ mình tôi". Bài bị admin ẩn: nhãn đỏ "Bài bị ẩn do vi phạm", không sửa/xóa được |
| `controller/FeedController.java` | `POST /feed/hide`; `/feed/create` và `/feed/edit` nhận `hidden=true\|false` (bài trong nhóm không có chế độ ẩn); chặn sửa/xóa bài đang bị admin ẩn |
| `dao/PostDAO(Impl).java` | `setHiddenByOwner()` — `UPDATE ... WHERE author = người gửi` nên không ẩn được bài người khác |

### 8.3 Tin (Stories) — đăng ảnh hoặc video, tự biến mất sau 24 giờ
| File | Nội dung |
|:--|:--|
| `db/050_migration_stories.sql` (mới) | Bảng `stories` (ảnh/video, chú thích, thời lượng, `expires_at`) và `story_views` (ai đã xem, `ON DELETE CASCADE`) |
| `model/Story.java`, `model/StoryRing.java` (mới) | Entity tin; DTO một "vòng tin" trên thanh Tin |
| `dao/StoryDAO(Impl).java` (mới) | Chỉ chủ tin + bạn bè xem được; vòng tin xếp: của mình → bạn có tin chưa xem → đã xem; ghi lượt xem chống trùng; đếm người xem; xóa; dọn tin hết hạn |
| `controller/StoryController.java` (mới) | `POST /stories/create` (ảnh ≤ 10 MB; video MP4/WEBM ≤ 50 MB, ≤ 60 giây; chú thích ≤ 200 ký tự; tối đa 15 tin/24 giờ; nhận diện file bằng magic bytes), `GET /stories/user`, `POST /stories/view`, `GET /stories/viewers` (chỉ chủ tin), `POST /stories/delete` (xóa luôn file) |
| `views/feed/newsfeed.jsp` | Thanh Tin dùng dữ liệu thật: "Tạo tin" / "Tin của bạn" (số tin + nút ➕), vòng **màu** = còn tin chưa xem, vòng **xám** = đã xem hết; chưa ai đăng thì hiện lời mời đăng tin |
| `views/feed/story-create-modal.jsp` (mới) | Chọn hoặc **kéo thả** file, xem trước khung **9:16** có chú thích đè lên, kiểm tra dung lượng/thời lượng/phát được ngay trên trình duyệt, thanh **% tải lên** |
| `views/feed/story-viewer.jsp` (mới) | Xem toàn màn hình: thanh tiến trình chia đoạn, ảnh 5 giây / video hết thời lượng rồi tự sang tin kế và **người kế**; bấm nửa trái/phải hoặc ← →; **giữ để tạm dừng**, Space, Esc; bật/tắt tiếng; chủ tin: "👁 n người đã xem" (danh sách + thời gian) và nút xóa |
| `util/AppContextListener.java` | Luồng nền `story-cleaner` mỗi 30 phút xóa tin hết hạn quá 1 giờ (bản ghi + file) |
| `util/UploadUtil.java` | Thư mục `uploads/stories`, `saveVideo(..., subdir)`, `looksLikeVideo()` |

### 8.4 Kèm theo (phần đầu giai đoạn Admin đã làm)
- `POST /report/create` + hộp thoại **Báo cáo vi phạm** (bài viết, bình luận, tài khoản) dùng chung `report-modal.jsp`; nút "Báo cáo" nhỏ dưới bình luận của người khác, nút 🚩 ở trang cá nhân người khác.
- Bảo mật: `AuthFilter` đọc lại tài khoản từ DB mỗi request (bị khóa → đá ra ngay), `AdminFilter`, `CsrfFilter` (POST `/admin/*`, `/report/*` phải có `X-CSRF-Token`), cookie phiên `SameSite=Lax`, tạo phiên mới khi đăng nhập, chặn ký tự HTML trong họ tên khi đăng ký. Thứ tự filter khai báo trong `web.xml`.
- **Chưa xong:** các trang quản trị `/admin/*` (dashboard, người dùng, bài viết, báo cáo, nhật ký).

**Kiểm thử (Tomcat 9 + SQL Server local):** tìm không dấu / có dấu / email / ký tự đặc biệt / `<script>` (không chạy); bài ẩn không lộ qua feed, profile người khác, tìm kiếm; người khác gửi `/feed/hide` → 403; đăng / sửa / hiện lại qua giao diện; tin: bạn bè xem được, người lạ → 403, lượt xem không trùng, chủ tin không tự tính lượt xem, vòng chuyển xám khi xem hết, file giả → 400, video > 60 giây → 400, xóa tin xóa file, tin hết hạn ẩn ngay và được luồng dọn xóa cả file; báo cáo thiếu/sai CSRF → 403, báo cáo trùng → thông báo thân thiện. Mọi trang trả 200 với cả tài khoản mới tinh.


## 9. Nâng cấp lớn: Bạn bè · Tin nhắn thời gian thực · Thông báo · Cài đặt

**Chạy trước:** `db/060_migration_social.sql` (SSMS, hoặc `sqlcmd ... -I -f 65001 -i db/060_migration_social.sql`).
Thư viện mới: `javax.websocket-api 1.1` (scope provided — Tomcat 9 có sẵn).

### 9.1 Nền tảng thời gian thực (WebSocket)
| File | Nội dung |
|:--|:--|
| `realtime/RealtimeEndpoint.java` | Endpoint `ws://.../ws` (JSR 356). Xác thực bằng phiên đăng nhập lúc bắt tay; chưa đăng nhập / bị khóa → đóng mã 1008. Trình duyệt chỉ gửi lên `ping` và `typing` |
| `realtime/RealtimeHub.java` | Sổ kết nối theo userId (nhiều tab / thiết bị), gửi ở luồng nền theo "làn" giữ đúng thứ tự từng tab, đóng kết nối khi đăng xuất / hết phiên |
| `realtime/Live.java`, `ChatLive.java` | Dựng sự kiện: `badge`, `notification`, `friend`, `presence`, `chat.message / update / remove / receipt / typing / conv` |
| `realtime/Presence.java` | Online = đang có WebSocket (hoặc pulse trong 90 giây); `users.last_active_at` ghi tối đa 1 lần/phút; báo bạn bè khi online/offline |
| `realtime/RealtimeSessionListener.java` | Phiên HTTP kết thúc → đóng WebSocket của phiên đó |
| `assets/js/realtime.js` (mới, mọi trang) | Kết nối + tự nối lại (1s→30s), dự phòng `/api/pulse` 12s khi mất WebSocket, huy hiệu, toast thông báo, **thông báo trên màn hình** (Notification API), chấm online, hộp xác nhận `UTConfirm` |
| `header.jsp` | Tự gắn `X-CSRF-Token` vào mọi fetch/XHR POST cùng nguồn; CsrfFilter nay bảo vệ `/friends/*`, `/chat/*`, `/notifications/*`, `/settings/*`, `/stories/*` |

### 9.2 Bạn bè
| File | Nội dung |
|:--|:--|
| `060`: `friendships.user_lo/user_hi` + UNIQUE | **Mỗi cặp chỉ một dòng** → không thể có lời mời trùng / hai chiều; `accepted_at` ("Bạn bè từ") |
| `dao/FriendshipDAO(Impl)` (viết lại) | Gửi / chấp nhận / từ chối / **thu hồi** / **hủy kết bạn**; gửi khi người kia đã mời mình → **tự thành bạn bè**; an toàn khi bấm nhiều lần / hai người bấm cùng lúc (đã thử 20 request đồng thời → đúng 1 dòng); **gợi ý** theo số bạn chung → cùng khu vực |
| `dao/BlockDAO`, `model/UserBlock` (mới) | **Chặn** hai chiều: xóa quan hệ, ẩn bài (thêm vào quy tắc `VISIBLE`), ẩn khỏi tìm kiếm / gợi ý, chặn nhắn tin 1-1, trang cá nhân "không khả dụng" |
| `service/RelationService` (mới) | Trạng thái `NONE / SENT / RECEIVED / FRIEND / BLOCKED / BLOCKED_BY`, kiểm **quyền riêng tư** (ai được gửi lời mời), thông báo + đẩy realtime cho **cả hai người** |
| `controller/FriendsController` (viết lại) | `/friends/request · accept · decline · cancel · unfriend · block · unblock · status` |
| `views/friends/friends.jsp`, `person-card.jsp` | 4 tab: **Lời mời · Đã gửi · Gợi ý · Bạn bè**; tìm kiếm không dấu, lọc Đang hoạt động / Mới kết bạn, sắp xếp; tự làm mới khi có thay đổi |
| `assets/js/relation.js` (mới) | **Nút quan hệ dùng chung** ở trang cá nhân, tìm kiếm, gợi ý bảng tin, trang Bạn bè, thông báo — tự cập nhật khi người kia thao tác |
| `profile.jsp` | Nút quan hệ mới, "Đang hoạt động / Hoạt động x phút trước", số bạn chung, trang khi bị chặn |
| Sửa lỗi cũ | Từ chối xong không gửi lại được (UNIQUE cũ → lỗi 500); trang cá nhân hiện sai "Đã gửi lời mời" |

### 9.3 Tin nhắn
| File | Nội dung |
|:--|:--|
| `060`: `conversation_members`, cột mới `chat_messages`, `message_reactions`, `message_hidden` | Nhóm chat; mốc **đã nhận / đã xem** từng người; trả lời, sửa, thu hồi, ghim, file, chống trùng `client_id` |
| `dao/ConversationDAO(Impl)`, `MessageDAO(Impl)` (viết lại) | Danh sách hội thoại (1-1 + nhóm) với số chưa đọc, tin cuối; lịch sử phân trang; **tìm kiếm không dấu**; cảm xúc; ghim; xóa ở phía mình; xóa cuộc trò chuyện; đánh dấu chưa đọc; tự vá hội thoại tạo bởi bản cũ |
| `service/ChatService` (mới) | Quyền gửi (chặn, "chỉ bạn bè được nhắn tin"), gửi + thông báo gộp, sửa trong 15 phút, thu hồi, nhóm: tạo / thêm / xóa thành viên (trưởng nhóm) / rời / đổi tên, tin hệ thống |
| `controller/ChatController` (viết lại) | `/chat/*` — xem chú thích đầu file; **file đính kèm lưu ngoài thư mục công khai**, tải qua `/chat/file` có kiểm thành viên |
| `views/chat/chat.jsp`, `assets/js/chat.js`, `pages/chat.css` | Gửi / nhận **tức thì**, ✓ Đã gửi · ✓✓ Đã nhận · ✓✓ Đã xem (nhóm: "Đã xem bởi…"), **đang soạn tin…**, online, trả lời (trích dẫn), 6 cảm xúc, sửa (phím ↑), thu hồi, xóa ở phía mình, ghim + thanh tin ghim, tìm kiếm + nhảy tới tin, ảnh (xem lớn) / tài liệu (≤ 20 MB, chặn file .exe), kéo-thả & dán ảnh, emoji, **nhóm chat** + bảng thông tin. **Chịu lỗi:** tin chờ mạng khi offline rồi tự gửi, gửi lỗi có "Thử lại", không gửi trùng, tải bù sau khi nối lại |

### 9.4 Thông báo
| File | Nội dung |
|:--|:--|
| `service/NotificationService` (mới) | NƠI DUY NHẤT tạo thông báo: bỏ qua tự gửi mình / đang chặn nhau / nhóm người nhận đã tắt; **đẩy realtime**; **gộp tin nhắn** ("đã gửi 3 tin nhắn mới"); gỡ thông báo lời mời đã thu hồi / đã trả lời; đọc hội thoại → thông báo tin nhắn tự đã đọc |
| `dao/NotificationDAO(Impl)` | Phân trang, đếm theo loại, đọc / chưa đọc từng cái, xóa, xóa đã đọc, `ref_key` |
| `controller/NotificationController` (viết lại) | Tab theo **nhóm chức năng** (Bạn bè · Tương tác · Nhóm · Tin nhắn · Tài khoản) + số chưa đọc; `/notifications/open` đánh dấu đã đọc rồi **đi thẳng tới nội dung** (chặn open redirect); KHÔNG còn tự đánh dấu tất cả khi mở trang |
| `notifications.jsp` | Gom Hôm nay / Hôm qua / 7 ngày qua / Trước đó, menu từng thông báo, Chấp nhận / Từ chối lời mời ngay trong thông báo, "Đánh dấu tất cả đã đọc" (lỗi cũ: chỉ đổi giao diện), "Xóa thông báo đã đọc" |
| Thông báo tài khoản | **Đăng nhập từ thiết bị mới** (không lặp lại trong 30 ngày), **đổi mật khẩu** |

### 9.5 Cài đặt (trước đây "sắp ra mắt")
`controller/SettingsController`, `views/settings/settings.jsp`, `model/UserSettings`, `dao/UserSettingsDAO`:
**Tài khoản** (đổi mật khẩu) · **Quyền riêng tư** (ai được gửi lời mời: mọi người / bạn của bạn bè / không ai; ai được nhắn tin: mọi người / chỉ bạn bè; ẩn trạng thái hoạt động) · **Thông báo** (bật/tắt từng nhóm trong ứng dụng và trên màn hình, xin quyền + gửi thử) · **Đã chặn** (bỏ chặn).

### 9.6 Bảo mật kèm theo
- JSON escape `< > &` (`JsonUtil`) — dữ liệu nhúng trong `<script type="application/json">` không thể bị `</script>` phá ra ngoài (đã thử payload XSS).
- Mọi endpoint nhận id đều kiểm quyền: hội thoại / tin / file (chỉ thành viên), thông báo (chỉ của mình), quan hệ (đúng chiều người gửi / người nhận).

**Kiểm thử:** kịch bản Node.js `rt_test` 18/18 đạt (WebSocket từ chối người chưa đăng nhập, lời mời / chấp nhận / tin nhắn / đã nhận / đã xem / đang gõ / cảm xúc / thu hồi / online-offline tới ngay); kiểm thử tay trên trình duyệt (gửi, trả lời, nhóm, ảnh, sửa, ghim, tìm, mất mạng rồi có mạng, thu hồi); 20 lời mời đồng thời → 1 dòng; chặn, quyền riêng tư, file riêng tư (người ngoài 404), XSS; mọi trang trả 200 kể cả tài khoản mới tinh.


## 10. Khu quản trị (Admin UI) — theo `admin_ui_plan.md`

**Chạy trước:** `db/070_migration_admin_logs_ip.sql`. Vào trang: đăng nhập tài khoản ADMIN → link **🛡️ Quản trị** ở cột trái (chỉ admin thấy) hoặc `/admin`.

Giao diện tách riêng hoàn toàn với phía người dùng (theme tối, topbar đỏ "CHẾ ĐỘ QUẢN TRỊ", font Fraunces + Inter — chuyển từ `admin-demo.html`). Phân quyền vẫn do `AdminFilter` (đọc role từ DB mỗi request), CSRF do `CsrfFilter`.

| File | Nội dung |
|:--|:--|
| `controller/AdminController.java` (mới) | 6 trang GET + 8 thao tác POST trả JSON, mọi thao tác ghi `admin_logs` kèm IP |
| `views/admin/layout.jsp`, `layout-end.jsp`, `pager.jsp` (mới) | Khung chung: topbar đỏ, rail trái (badge số đối tượng bị báo cáo), phân trang |
| `views/admin/dashboard.jsp` | 4 thẻ số liệu (người dùng / bài viết / báo cáo chờ / nhóm, kèm "+x trong 7 ngày"), biểu đồ cột 7 ngày, **Hoạt động gần đây** gộp nhật ký admin + báo cáo mới + tài khoản mới |
| `views/admin/users.jsp` | Tìm theo tên/email, lọc Tất cả / Đang hoạt động / Đã khóa / Quản trị viên (kèm số), bảng người dùng, **Khóa** (bắt buộc lý do, có lý do nhanh) / **Mở khóa** — cập nhật dòng tại chỗ |
| `views/admin/reports.jsp` | Mỗi thẻ = một đối tượng bị báo cáo (gom nhiều báo cáo): người báo cáo, nhãn lý do, xem trước nội dung (bài + ảnh/video, bình luận, hồ sơ), chi tiết từng báo cáo; **Ẩn bài viết / Xóa bình luận / Khóa tài khoản** hoặc **Bỏ qua**; hết báo cáo → "Không có vi phạm nào chờ xử lý ✅" |
| `views/admin/posts.jsp` (mở rộng) | Bài viết **Bị ẩn / Đang bị báo cáo / Đã xóa / Tất cả**: Ẩn, Xóa (mềm), **Khôi phục** |
| `views/admin/groups.jsp` (mở rộng) | Danh sách nhóm (chủ nhóm, thành viên, loại), **Giải tán** nhóm vi phạm (bắt buộc lý do, thành viên được báo) |
| `views/admin/logs.jsp` (mở rộng) | Nhật ký: thời gian, admin, thao tác, đối tượng, chi tiết, **IP**; lọc theo thao tác |
| `assets/css/pages/admin.css`, `assets/js/admin.js` (mới) | Design system admin; `Admin.post` (gắn CSRF), hộp xác nhận có ô lý do (Esc / Ctrl+Enter, giữ focus), toast |
| `model/AdminLog` (+ `ipAddress`, nhãn/biểu tượng), `model/AdminActivity` (mới), `dao/AdminLogDAO` (lọc theo thao tác), `ReportDAO.pendingReasons`, `GroupDAO.adminList`, `Group.owner`, `Comment.getFormattedCreatedAt` | Hỗ trợ các trang trên |
| `app-sidebar.jsp`, `rail.jsp`, `header.jsp` | Link **Quản trị** — chỉ hiện khi tài khoản (đọc từ DB) là ADMIN |

**Quy tắc nghiệp vụ** (kiểm ở server, không chỉ ẩn nút):
- Không tự khóa mình, không khóa admin khác. Khóa → đóng ngay WebSocket của người đó; request kế tiếp bị đăng xuất, trang đăng nhập hiện lý do khóa.
- Xử lý báo cáo bài viết = **ẩn** (khôi phục được), bình luận = xóa, tài khoản = khóa; mọi báo cáo đang chờ về đối tượng đó được đóng một lần (RESOLVED / DISMISSED, lưu admin xử lý + thời điểm).
- Người bị xử lý nhận thông báo (loại SYSTEM) kèm lý do — không lộ tên admin.

**Kiểm thử:** mọi trang 200 với admin; người thường → về `/feed` (trang) / 403 (POST); POST thiếu CSRF → 403; tự khóa / khóa admin khác / thiếu lý do / id sai / khóa lặp → lỗi đúng mã; khóa xong người bị khóa bị đăng xuất ngay, mở khóa đăng nhập lại được; ẩn bài qua báo cáo → người khác không thấy, tác giả vẫn thấy; xóa bình luận; khóa qua báo cáo; bỏ qua; ẩn → xóa → khôi phục; giải tán nhóm (2 thành viên nhận thông báo); nội dung `<script>` trong bài bị báo cáo được escape; giao diện thử bằng chuột, bàn phím và màn hình 375px. Dữ liệu test đã xóa.


## 11. Tính năng mới: Quên mật khẩu (xác thực OTP qua email)

Ghép từ `forgot_password_changelog.md` của nhóm, có chỉnh sửa về bảo mật (xem bảng "Khác với bản gốc").
**Không cần migration DB.** Cấu hình email: `db/uterspace-mail.properties.example` → `<Tomcat>/conf/uterspace-mail.properties` (xem `huong_dan_chay_project.md` bước 4). Chưa cấu hình → chế độ phát triển, mã OTP in ra log Tomcat.

| File | Nội dung |
|:--|:--|
| `pom.xml` | `com.sun.mail:javax.mail 1.6.2` + `com.sun.activation:javax.activation 1.2.0` (bản cài đặt đầy đủ — chỉ có `javax.activation-api` thì gửi mail lỗi `ClassNotFoundException`, đã gặp và sửa khi test) |
| `util/MailUtil.java` (mới) | Gửi email OTP qua SMTP (STARTTLS, timeout 10 giây), thư 2 phần chữ thuần + HTML; đọc tài khoản từ file cấu hình / biến môi trường, **không ghi mật khẩu trong code** |
| `controller/ForgotPasswordController.java` (mới) | `/forgot-password` 3 bước: Email → Mã OTP → Mật khẩu mới; lưu trạng thái trong session, mọi POST redirect về GET (tải lại trang không gửi lại email) |
| `views/auth/forgot-password.jsp` (mới) + `auth.css` | Thanh 3 bước, ô nhập mã lớn (chỉ nhận số, đủ 6 số tự xác nhận, hỗ trợ tự điền mã), đếm ngược hiệu lực, "Gửi lại mã sau 59 giây", "Dùng email khác", danh sách luật mật khẩu tích ✓ khi gõ, thanh độ mạnh, nút hiện/ẩn mật khẩu, nút "Đang gửi mã…" chống bấm nhiều lần |
| `login.jsp`, `AuthController` | Link "Quên mật khẩu?" (trước là `href="#"`), hộp thông báo xanh "Đặt lại mật khẩu thành công" + điền sẵn email |
| `util/PasswordUtil.policyError` | **Luật mật khẩu chung** (8–64 ký tự, 1 chữ hoa, 1 ký tự đặc biệt — hỗ trợ chữ có dấu) cho Đăng ký, Đổi mật khẩu (Cài đặt), Quên mật khẩu; `register.jsp` / `settings.jsp` kiểm tra giống hệt phía trình duyệt |
| `filter/AuthFilter`, `realtime/RealtimeEndpoint`, `SettingsController` | Mật khẩu đổi / đặt lại → **mọi phiên đăng nhập cũ bị đăng xuất** ở request kế tiếp và không nối lại realtime được; phiên vừa đổi trong Cài đặt vẫn giữ đăng nhập |
| `settings.jsp` | Gợi ý "Quên mật khẩu hiện tại? Đăng xuất rồi chọn Quên mật khẩu" |

**Khác với bản gốc (lý do bảo mật):**

| Bản gốc | Bản trong project |
|:--|:--|
| Email + App Password Gmail ghi thẳng trong `MailUtil.java` | Đọc từ file cấu hình ngoài project / biến môi trường |
| `java.util.Random`, `nextInt(999999)` (không bao giờ ra 999999) | `SecureRandom`, đủ 000000–999999 |
| Lưu mã OTP nguyên văn trong session | Chỉ lưu bản băm SHA-256, so sánh thời gian hằng, dùng một lần |
| Nhập sai không giới hạn | Sai 5 lần → mã bị hủy, phải xin mã mới |
| Gửi mã không giới hạn (spam hộp thư) | 60 giây / lần / email; tối đa 5 mã / email / giờ, 10 mã / IP / giờ |
| Báo "Email không tồn tại" | Giữ như plan (báo rõ email chưa đăng ký), nhưng giới hạn 10 lần / IP / giờ để hạn chế dò tài khoản hàng loạt |
| Đếm ngược theo giờ máy người dùng | Theo số giây còn lại máy chủ gửi xuống |
| Đã xác thực OTP thì đặt mật khẩu lúc nào cũng được | Phải đặt trong 10 phút sau khi xác thực |
| Đổi xong các phiên cũ vẫn đăng nhập | Đăng xuất mọi phiên cũ + thông báo bảo mật trong Thông báo → Tài khoản |
| Thêm `UserDAO.updatePassword` | Dùng lại `updatePasswordHash` đã có (tránh 2 hàm trùng) |

**Kiểm thử:** email sai định dạng / chưa đăng ký (báo lỗi ngay ở bước 1), mã sai (còn 4 lần…), mã có dấu cách, sai 5 lần → hủy, gửi lại trong 60 giây → chặn (kể cả quay lại bước 1), đặt mật khẩu khi chưa xác thực → không cho, mật khẩu yếu / không khớp, đặt thành công → mật khẩu cũ không đăng nhập được, mật khẩu mới được, phiên cũ bị đăng xuất + WebSocket phiên cũ bị từ chối (1008); gửi thật qua máy chủ SMTP giả: đúng người nhận, tiêu đề, 2 phần chữ/HTML, mã khớp; SMTP lỗi → báo thân thiện, thử lại được ngay; luật mật khẩu ở Đăng ký và Cài đặt; toàn bộ 3 bước trên giao diện bằng bàn phím. Mật khẩu tài khoản test đã khôi phục, dữ liệu test đã xóa.


## 12. Dùng chung database cho cả nhóm qua Tailscale

Hướng dẫn từng bước: **`docs/HUONG_DAN_TAILSCALE.md`**. Không cần migration DB.

| File | Nội dung |
|:--|:--|
| `util/JPAUtil.java` | Đọc `${catalina.base}/conf/uterspace-db.properties` hoặc biến môi trường `UTERSPACE_DB_*` để chọn DB (host, port, tên DB, tài khoản, số kết nối); không có → dùng `persistence.xml` (localhost) như cũ. Log khi khởi động: `[JPAUtil] Database: ...` (không in mật khẩu) |
| `db/uterspace-db.properties.example` (mới) | Mẫu cấu hình DB |
| `tools/tailscale/_common.ps1` | Hàm dùng chung: tìm Tailscale / sqlcmd / instance SQL Server, chạy T-SQL, tạo mật khẩu ngẫu nhiên, T-SQL tạo tài khoản thành viên, ghi file cấu hình |
| `tools/tailscale/00-install-tailscale` | Mọi máy: cài Tailscale (winget), đăng nhập mạng nhóm, in IP |
| `tools/tailscale/10-server-setup` | Máy chủ (Administrator): bật TCP 1433 cố định + Mixed mode, tắt AUTO_CLOSE, tài khoản `ut_<tên>` **chỉ đọc/ghi** cho từng thành viên, đổi mật khẩu `uterspace_user`, tường lửa chỉ cho `100.64.0.0/10`, chống ngủ khi cắm sạc, lịch backup 23:00, tự kiểm tra đăng nhập qua IP Tailscale; `-DryRun`, `-ResetPasswords` |
| `tools/tailscale/20-backup` | `BACKUP DATABASE ... WITH CHECKSUM` + `RESTORE VERIFYONLY`, nén ảnh/video/file chat, chép lên Google Drive, giữ 7 bản trên máy / 30 bản trên Drive, ghi `backup-log.txt` |
| `tools/tailscale/30-member-setup` | Thành viên: kiểm tra Tailscale + cổng 1433 + đăng nhập DB rồi ghi file cấu hình; `-UseLocal` / `-UseShared` để chuyển DB local ↔ DB chung |
| `tools/tailscale/40-restore-local` | Restore DB (+ ảnh/video) từ file backup, tự đặt lại đường dẫn file DB và nối lại tài khoản `uterspace_user` (orphaned user) |
| `tools/tailscale/50-funnel` | Bật / tắt web công khai HTTPS (Tailscale Funnel, cổng 443 → Tomcat 8080) cho buổi demo |
| `huong_dan_chay_project.md`, `db/README.md` | Trỏ tới hướng dẫn mới |

Mỗi script có file `.cmd` đi kèm (bấm đúp chạy được, bỏ qua chặn ExecutionPolicy); file `.ps1` lưu UTF-8 có BOM để Windows PowerShell 5.1 hiện đúng tiếng Việt.

**Kiểm thử trên máy này** (máy không có Tailscale nên các bước mạng chưa chạy thật): cú pháp mọi script qua trình phân tích của PowerShell 5.1; backup bằng quyền thường (file 8,4 MB, checksum đạt, zip ảnh, chép sang thư mục Drive giả lập, xóa được file do dịch vụ SQL tạo); restore sang DB thử `uterspace_restoretest` (đủ 30 tài khoản, giải nén ảnh); tài khoản thành viên: đọc + ghi được (trong transaction đã rollback), **không** `ALTER TABLE` được, **không** vào được DB khác, chạy lại giữ nguyên mật khẩu; `JPAUtil` đọc file cấu hình (log đúng DB, pool 3), sai mật khẩu → log `Login failed` rõ ràng. Đã sửa 2 lỗi phát hiện khi test (mảng 1 phần tử bị PowerShell "mở" thành chuỗi; `"$ServerHost:1433"` bị hiểu sai tên biến). Dữ liệu test đã xóa.
