# THIẾT KẾ CƠ SỞ DỮ LIỆU & SƠ ĐỒ THỰC THỂ (ERD) - DỰ ÁN UTErSPACE

Tài liệu này cung cấp toàn bộ **sơ đồ quan hệ thực thể (Entity-Relationship Diagram)** và **đặc tả chi tiết 24 bảng dữ liệu** của mạng xã hội UTErSpace (chạy trên MySQL 8.4 Local, database `defaultdb`).

---

## 1. Sơ Đồ Quan Hệ Thực Thể (ERD - Mermaid Diagram)

```mermaid
erDiagram
    USERS ||--|| USER_SETTINGS : "cai_dat"
    USER_SETTINGS ||--o{ WEBAUTHN_CREDENTIALS : "passkey"
    WEBAUTHN_CREDENTIALS ||--o{ USER_DIDS : "danh_tinh"
    USER_DIDS ||--o{ USER_BLOCKS : "chan"
    USER_BLOCKS ||--o{ SEARCH_HISTORY : "tim_kiem"
    USERS ||--o{ POSTS : "dang_bai"
    POSTS ||--o{ COMMENTS : "binh_luan"
    COMMENTS ||--o{ LIKES : "luot_thich"
    LIKES ||--o{ SAVED_POSTS : "luu_bai"
    USERS ||--o{ FRIENDSHIPS : "ket_ban"
    FRIENDSHIPS ||--o{ GROUPS_TBL : "nhom"
    GROUPS_TBL ||--o{ GROUP_MEMBERS : "thanh_vien"
    USERS ||--o{ NOTIFICATIONS : "thong_bao"
    NOTIFICATIONS ||--o{ CONVERSATIONS : "cuoc_chat"
    CONVERSATIONS ||--o{ CONVERSATION_MEMBERS : "thanh_vien"
    CONVERSATIONS ||--o{ CHAT_MESSAGES : "tin_nhan"
    CHAT_MESSAGES ||--o{ MESSAGE_REACTIONS : "emoji"
    MESSAGE_REACTIONS ||--o{ MESSAGE_HIDDEN : "an_tin"
    USERS ||--o{ STORIES : "tin_24h"
    STORIES ||--o{ STORY_VIEWS : "luot_xem"
    STORY_VIEWS ||--o{ STORY_REACTIONS : "tha_tim"
    USERS ||--o{ REPORTS : "bao_cao"
    REPORTS ||--o{ ADMIN_LOGS : "nhat_ky"

    ADMIN_LOGS {
        int log_id PK
        int admin_id FK
        varchar action
        varchar target_type
        int target_id
        varchar detail
        varchar ip_address
        datetime created_at
    }
    CHAT_MESSAGES {
        int message_id PK
        int conversation_id FK
        int sender_id FK
        longtext content
        tinyint is_read
        datetime sent_at
        varchar client_id
        varchar message_type
        int reply_to_id
        datetime edited_at
        datetime recalled_at
        datetime pinned_at
        int pinned_by FK
        varchar attachment_path
        varchar attachment_type
        varchar attachment_name
        bigint attachment_size
    }
    COMMENTS {
        int comment_id PK
        int post_id FK
        int user_id FK
        text content
        datetime created_at
    }
    CONVERSATION_MEMBERS {
        int conversation_id PK,FK
        int user_id PK,FK
        varchar role
        datetime joined_at
        int last_read_message_id
        int last_delivered_message_id
        int cleared_message_id
    }
    CONVERSATIONS {
        int conversation_id PK
        int user_a_id FK
        int user_b_id FK
        datetime last_message_at
        tinyint is_group
        varchar title
        int created_by FK
        datetime created_at
    }
    FRIENDSHIPS {
        int friendship_id PK
        int requester_id FK
        int receiver_id FK
        varchar status
        datetime created_at
        datetime accepted_at
        int user_lo
        int user_hi
    }
    GROUP_MEMBERS {
        int group_id PK,FK
        int user_id PK,FK
        varchar role
        datetime joined_at
        varchar status
    }
    GROUPS_TBL {
        int group_id PK
        varchar name
        text description
        varchar category
        varchar cover_icon
        int member_count
        datetime created_at
        varchar privacy
        varchar cover_image
    }
    LIKES {
        int like_id PK
        int post_id FK
        int user_id FK
        datetime created_at
    }
    MESSAGE_HIDDEN {
        int message_id PK,FK
        int user_id PK,FK
    }
    MESSAGE_REACTIONS {
        int message_id PK,FK
        int user_id PK,FK
        varchar emoji
        datetime created_at
    }
    NOTIFICATIONS {
        int notification_id PK
        int user_id FK
        int actor_id FK
        varchar type
        varchar content
        varchar target_url
        tinyint is_read
        datetime created_at
        varchar ref_key
    }
    POSTS {
        int post_id PK
        int user_id FK
        longtext content
        varchar image_path
        varchar visibility
        varchar media_type
        varchar video_path
        int video_duration_sec
        int like_count
        int comment_count
        int share_count
        datetime created_at
        int shared_post_id
        int group_id FK
        varchar moderation_status
        tinyint is_hidden_by_owner
        varchar sentiment
        double sentiment_score
        varchar sentiment_source
        varchar media_mode
        varchar model_path
        longtext captions_vtt
    }
    REPORTS {
        int report_id PK
        int reporter_id FK
        varchar target_type
        int target_id
        varchar reason
        varchar detail
        varchar status
        int handled_by FK
        datetime handled_at
        datetime created_at
    }
    SAVED_POSTS {
        int saved_id PK
        int user_id FK
        int post_id FK
        datetime saved_at
    }
    SEARCH_HISTORY {
        int search_id PK
        int user_id FK
        varchar query
        datetime created_at
    }
    STORIES {
        int story_id PK
        int user_id FK
        varchar media_path
        varchar media_type
        varchar caption
        int duration_sec
        datetime created_at
        datetime expires_at
    }
    STORY_REACTIONS {
        int story_id PK,FK
        int user_id PK,FK
        varchar emoji
        datetime created_at
    }
    STORY_VIEWS {
        int story_id PK,FK
        int viewer_id PK,FK
        datetime viewed_at
    }
    USER_BLOCKS {
        int blocker_id PK,FK
        int blocked_id PK,FK
        datetime created_at
    }
    USER_DIDS {
        int user_id PK,FK
        varchar did
        varbinary public_key
        datetime created_at
    }
    USER_SETTINGS {
        int user_id PK,FK
        varchar friend_request_policy
        varchar message_policy
        tinyint show_online
        tinyint notif_friend
        tinyint notif_interaction
        tinyint notif_group
        tinyint notif_message
        tinyint push_friend
        tinyint push_interaction
        tinyint push_group
        tinyint push_message
        tinyint push_account
        datetime updated_at
        tinyint archive_stories
        varchar feed_mode
        tinyint hide_negative
        varchar content_filter
    }
    USERS {
        int user_id PK
        varchar first_name
        varchar last_name
        varchar email
        varchar password_hash
        varchar avatar
        varchar role
        text bio
        varchar location
        varchar website
        varchar cover_image
        datetime created_at
        varchar status
        varchar locked_reason
        datetime last_active_at
    }
    WEBAUTHN_CREDENTIALS {
        int id PK
        int user_id FK
        varchar credential_id
        varbinary public_key
        int alg
        bigint sign_count
        varchar label
        datetime created_at
        datetime last_used_at
    }
```

---

## 2. Đặc Tả Chi Tiết 24 Bảng Dữ Liệu Theo Module

### Module 1: Quản Lý Người Dùng & Xác Thực Bảo Mật
1. **`users`**: Lưu trữ thông tin tài khoản (Sinh viên HCMUTE, Giảng viên, Quản trị viên).
   * `user_id` (INT, PK, Auto Increment): Mã định danh duy nhất.
   * `first_name`, `last_name` (VARCHAR): Họ và tên tiếng Việt có dấu.
   * `email` (VARCHAR, Unique): Email sinh viên (`@student.hcmute.edu.vn`) hoặc email quản trị.
   * `password_hash` (VARCHAR): Mật khẩu băm an toàn theo giải thuật BCrypt (cost = 12).
   * `avatar`, `cover_image` (VARCHAR): Đường dẫn ảnh đại diện và ảnh bìa trên Cloudinary / Local.
   * `role` (VARCHAR): Phân quyền (`USER`, `ADMIN`).
   * `status` (VARCHAR): Trạng thái tài khoản (`ACTIVE`, `LOCKED`).
   * `last_active_at` (DATETIME): Thời gian hoạt động gần nhất để hiển thị trạng thái online.

2. **`user_settings`**: Cài đặt cá nhân hóa của từng người dùng.
   * `user_id` (INT, PK, FK -> `users.user_id`).
   * `friend_request_policy`, `message_policy`: Quyền riêng tư nhận tin nhắn / kết bạn.
   * `show_online`: Ẩn/hiện trạng thái đang hoạt động.
   * `feed_mode`: Chế độ hiển thị bảng tin (`SMART` - thuật toán gợi ý, hoặc `LATEST` - mới nhất).
   * `hide_negative`: Tự động ẩn bài viết có cảm xúc tiêu cực được gắn nhãn bởi AI.

3. **`user_dids`**: Danh tính số phi tập trung (Decentralized Identity - `did:key` dùng Ed25519).
   * `user_id` (INT, PK, FK -> `users.user_id`).
   * `did` (VARCHAR, Unique): Định danh DID theo chuẩn W3C.
   * `public_key` (VARBINARY): Khóa công khai của người dùng.

4. **`webauthn_credentials`**: Khóa xác thực sinh trắc học (Passkey / FIDO2 - Vân tay & FaceID).
   * `id` (INT, PK), `user_id` (INT, FK -> `users.user_id`).
   * `credential_id` (VARCHAR, Unique), `public_key` (VARBINARY), `sign_count` (BIGINT).

5. **`user_blocks`**: Quản lý chặn người dùng.
   * `blocker_id`, `blocked_id` (PK, FK -> `users.user_id`).

6. **`search_history`**: Lịch sử tìm kiếm để phục vụ thuật toán Recommendation System.
   * `search_id` (INT, PK), `user_id` (INT, FK), `query` (VARCHAR).

---

### Module 2: Bảng Tin, Bài Đăng & Tương Tác
7. **`posts`**: Lưu trữ bài viết mạng xã hội (Ảnh, Video, Mô hình 3D AR, Bài viết nhóm).
   * `post_id` (INT, PK, Auto Increment).
   * `user_id` (INT, FK -> `users.user_id`): Tác giả bài viết.
   * `group_id` (INT, FK -> `groups_tbl.group_id`, Nullable): Bài đăng trong nhóm (nếu có).
   * `content` (LONGTEXT): Nội dung văn bản, hỗ trợ hashtag (#).
   * `media_type` (VARCHAR): Loại đa phương tiện (`IMAGE`, `VIDEO`, `MODEL3D`).
   * `image_path`, `video_path`, `model_path`: Liên kết tệp trên Cloudinary.
   * `sentiment`, `sentiment_score`: Nhãn cảm xúc phân tích tự động bằng AI (`POSITIVE`, `NEUTRAL`, `NEGATIVE`).
   * `visibility`: Phạm vi chia sẻ (`PUBLIC`, `FRIENDS`, `PRIVATE`, `GROUP`).
   * `like_count`, `comment_count`, `share_count` (INT): Bộ đếm tối ưu hiệu năng trang feed.

8. **`comments`**: Bình luận bài viết.
   * `comment_id` (INT, PK), `post_id` (INT, FK), `user_id` (INT, FK), `content` (TEXT).

9. **`likes`**: Lượt thích bài viết.
   * `like_id` (INT, PK), `post_id` (INT, FK), `user_id` (INT, FK).

10. **`saved_posts`**: Bài viết được người dùng lưu lại.
    * `saved_id` (INT, PK), `user_id` (INT, FK), `post_id` (INT, FK).

---

### Module 3: Quan Hệ Bạn Bè & Cộng Đồng Nhóm
11. **`friendships`**: Quan hệ kết bạn hai chiều.
    * `friendship_id` (INT, PK), `requester_id` (INT, FK), `receiver_id` (INT, FK).
    * `status` (VARCHAR): `PENDING` (chờ chấp nhận), `ACCEPTED` (đã là bạn bè).
    * `user_lo`, `user_hi` (VIRTUAL GENERATED): Cột ảo tự động sắp xếp `LEAST`/`GREATEST` đảm bảo chống trùng lặp quan hệ.

12. **`groups_tbl`**: Nhóm cộng đồng (Học tập, CLB Robotics, Nhiếp ảnh, Đồ án...).
    * `group_id` (INT, PK), `name` (VARCHAR), `description` (TEXT), `privacy` (VARCHAR), `cover_image` (VARCHAR), `member_count` (INT).

13. **`group_members`**: Thành viên trong nhóm.
    * `group_id` (INT, PK, FK), `user_id` (INT, PK, FK), `role` (`ADMIN`, `MODERATOR`, `MEMBER`), `status` (`ACTIVE`, `PENDING`).

---

### Module 4: Nhắn Tin Trực Tuyến & Thông Báo Thời Gian Thực
14. **`conversations`**: Cuộc trò chuyện (1-1 hoặc Nhóm chat).
    * `conversation_id` (INT, PK), `is_group` (TINYINT), `user_a_id`, `user_b_id` (FK, Nullable nếu là nhóm), `title` (VARCHAR).

15. **`conversation_members`**: Thành viên nhóm chat.
    * `conversation_id` (INT, PK, FK), `user_id` (INT, PK, FK), `last_read_message_id` (INT).

16. **`chat_messages`**: Tin nhắn trò chuyện (văn bản, ảnh, tệp đính kèm, trả lời, ghim, thu hồi).
    * `message_id` (INT, PK), `conversation_id` (INT, FK), `sender_id` (INT, FK).
    * `content` (LONGTEXT), `message_type` (`TEXT`, `IMAGE`, `FILE`), `attachment_path` (VARCHAR).
    * `pinned_at`, `pinned_by`, `recalled_at`, `edited_at` (DATETIME).

17. **`message_reactions`**: Thả biểu tượng cảm xúc (Emoji reaction) trên tin nhắn.
    * `message_id` (INT, PK, FK), `user_id` (INT, PK, FK), `emoji` (VARCHAR).

18. **`message_hidden`**: Ẩn tin nhắn ở phía người dùng.
    * `message_id` (INT, PK, FK), `user_id` (INT, PK, FK).

19. **`notifications`**: Thông báo hệ thống thời gian thực (WebSocket Push).
    * `notification_id` (INT, PK), `user_id` (INT, FK - người nhận), `actor_id` (INT, FK - người thực hiện).
    * `type` (`LIKE`, `COMMENT`, `FRIEND_REQUEST`, `MESSAGE`, `GROUP`), `content` (VARCHAR), `target_url` (VARCHAR), `is_read` (TINYINT).

---

### Module 5: Tin 24 Giờ (Story) & Quản Trị Hệ Thống
20. **`stories`**: Tin biến mất sau 24 giờ.
    * `story_id` (INT, PK), `user_id` (INT, FK), `media_path` (VARCHAR), `expires_at` (DATETIME).

21. **`story_views`**: Lượt xem tin.
    * `story_id` (INT, PK, FK), `viewer_id` (INT, PK, FK), `viewed_at` (DATETIME).

22. **`story_reactions`**: Thả tim tin 24h.
    * `story_id` (INT, PK, FK), `user_id` (INT, PK, FK), `emoji` (VARCHAR).

23. **`reports`**: Báo cáo vi phạm nội dung từ người dùng.
    * `report_id` (INT, PK), `reporter_id` (INT, FK), `target_type` (`POST`, `COMMENT`, `USER`), `target_id` (INT), `status` (`PENDING`, `RESOLVED`, `DISMISSED`), `handled_by` (INT, FK).

24. **`admin_logs`**: Nhật ký kiểm toán hành động của Quản trị viên (Audit Log).
    * `log_id` (INT, PK), `admin_id` (INT, FK), `action` (VARCHAR), `target_type` (VARCHAR), `detail` (VARCHAR), `ip_address` (VARCHAR).
