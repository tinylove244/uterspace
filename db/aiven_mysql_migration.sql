-- ============================================================
-- UTErSpace — chuyển DB cloud từ SQL Server (SmarterASP) sang MySQL 8 (Aiven)
--
-- Chạy SAU KHI đã tạo bảng + dữ liệu trên Aiven (bản MySQL của migration 001 → 080).
-- File này bù phần còn thiếu so với DB SmarterASP:
--   1. friendships.user_lo / user_hi thành cột TÍNH TỰ ĐỘNG (bản dựng trên Aiven là cột thường → app
--      thêm lời mời kết bạn sẽ để NULL, UNIQUE(user_lo, user_hi) không còn chặn cặp trùng).
--   2. Các chỉ mục UNIQUE app dựa vào khi 2 request ghi cùng lúc: hội thoại 1-1 theo cặp, tin nhắn theo client_id.
--   3. Migration 090 (Story nâng cao · AI · Cá nhân hóa · Passkey · DID) viết lại cho MySQL.
--   4. Migration 100: link ảnh / video trên Cloudinary lấy từ DB SmarterASP. ID trên Aiven KHÁC SmarterASP
--      (vd: anhtuan là user 12 ở SmarterASP, 15 ở Aiven) nên khớp theo khóa tự nhiên: email, tên nhóm,
--      email tác giả + đầu nội dung bài.
--
-- Chạy lại nhiều lần vẫn an toàn. Cách chạy: MySQL Workbench / DBeaver / mysql CLI, kết nối Aiven
-- (docs/CLOUD_CREDENTIALS.md, bật SSL), chọn database defaultdb rồi chạy cả file (bảng mã UTF-8).
-- Aiven bật sql_mode ANSI: chuỗi phải dùng nháy đơn '...', nháy kép là tên cột.
-- ============================================================

-- ------------------------------------------------------------
-- 1. FRIENDSHIPS — user_lo / user_hi tự tính từ requester_id, receiver_id
--    Dùng cột VIRTUAL: MySQL không cho cột STORED dựa trên cột có FOREIGN KEY ... ON DELETE CASCADE.
-- ------------------------------------------------------------
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.columns
               WHERE table_schema = DATABASE() AND table_name = 'friendships' AND column_name = 'user_lo'
                 AND extra NOT LIKE '%GENERATED%') > 0,
              'ALTER TABLE friendships DROP INDEX ux_friendships_pair, DROP COLUMN user_lo, DROP COLUMN user_hi', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

SET @ddl = IF((SELECT COUNT(*) FROM information_schema.columns
               WHERE table_schema = DATABASE() AND table_name = 'friendships' AND column_name = 'user_lo') = 0,
              'ALTER TABLE friendships
                 ADD COLUMN user_lo INT AS (LEAST(requester_id, receiver_id)) VIRTUAL,
                 ADD COLUMN user_hi INT AS (GREATEST(requester_id, receiver_id)) VIRTUAL,
                 ADD UNIQUE INDEX ux_friendships_pair (user_lo, user_hi)', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

-- ------------------------------------------------------------
-- 2. CHỈ MỤC UNIQUE / tra cứu (bản SQL Server là filtered index; UNIQUE của MySQL vốn cho nhiều dòng NULL)
-- ------------------------------------------------------------
-- Hội thoại 1-1: mỗi cặp một dòng (ConversationDAOImpl.getOrCreateConversation dựa vào lỗi trùng khi 2 người mở cùng lúc)
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.statistics
               WHERE table_schema = DATABASE() AND table_name = 'conversations' AND index_name = 'ux_conversations_pair') = 0,
              'CREATE UNIQUE INDEX ux_conversations_pair ON conversations (user_a_id, user_b_id)', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

-- Tin nhắn: gửi lại sau lỗi mạng không tạo bản trùng (MessageDAOImpl.send)
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.statistics
               WHERE table_schema = DATABASE() AND table_name = 'chat_messages' AND index_name = 'ux_chat_messages_client') = 0,
              'CREATE UNIQUE INDEX ux_chat_messages_client ON chat_messages (sender_id, client_id)', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

-- Gộp / gỡ thông báo theo đối tượng (ref_key)
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.statistics
               WHERE table_schema = DATABASE() AND table_name = 'notifications' AND index_name = 'ix_notifications_ref') = 0,
              'CREATE INDEX ix_notifications_ref ON notifications (user_id, ref_key)', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

-- ------------------------------------------------------------
-- 3. MIGRATION 090 — Story nâng cao · AI · Cá nhân hóa · Bảo mật nâng cao
-- ------------------------------------------------------------
-- 3.1 USER_SETTINGS: lưu trữ tin, chế độ bảng tin, ẩn bài tiêu cực, bộ lọc từ khóa cá nhân
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.columns
               WHERE table_schema = DATABASE() AND table_name = 'user_settings' AND column_name = 'archive_stories') = 0,
              'ALTER TABLE user_settings
                 ADD COLUMN archive_stories TINYINT(1) NOT NULL DEFAULT 1,
                 ADD COLUMN feed_mode VARCHAR(10) NOT NULL DEFAULT ''SMART'',
                 ADD COLUMN hide_negative TINYINT(1) NOT NULL DEFAULT 0,
                 ADD COLUMN content_filter VARCHAR(2000) NULL,
                 ADD CONSTRAINT ck_us_feed_mode CHECK (feed_mode IN (''SMART'', ''LATEST''))', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

-- 3.2 STORY_REACTIONS: thả tim tin (mỗi người 1 lần / tin)
CREATE TABLE IF NOT EXISTS story_reactions (
    story_id    INT NOT NULL,
    user_id     INT NOT NULL,
    emoji       VARCHAR(8) NOT NULL DEFAULT '❤️',
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (story_id, user_id),
    KEY ix_story_reactions_user (user_id),
    CONSTRAINT fk_story_reactions_story FOREIGN KEY (story_id) REFERENCES stories (story_id) ON DELETE CASCADE,
    CONSTRAINT fk_story_reactions_user  FOREIGN KEY (user_id)  REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- 3.3 STORIES: kho lưu trữ (tin hết hạn của một người, mới nhất trước)
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.statistics
               WHERE table_schema = DATABASE() AND table_name = 'stories' AND index_name = 'ix_stories_user_created') = 0,
              'CREATE INDEX ix_stories_user_created ON stories (user_id, created_at DESC)', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

-- 3.4 POSTS: nhãn cảm xúc, chế độ media nâng cao (ảnh 360° / ảnh 3D chiều sâu / mô hình 3D-AR), mô hình .glb, phụ đề WebVTT
SET @ddl = IF((SELECT COUNT(*) FROM information_schema.columns
               WHERE table_schema = DATABASE() AND table_name = 'posts' AND column_name = 'sentiment') = 0,
              'ALTER TABLE posts
                 ADD COLUMN sentiment VARCHAR(10) NULL,
                 ADD COLUMN sentiment_score DOUBLE NULL,
                 ADD COLUMN sentiment_source VARCHAR(10) NULL,
                 ADD COLUMN media_mode VARCHAR(12) NULL,
                 ADD COLUMN model_path VARCHAR(500) NULL,
                 ADD COLUMN captions_vtt LONGTEXT NULL,
                 ADD CONSTRAINT ck_posts_sentiment CHECK (sentiment IS NULL OR sentiment IN (''POSITIVE'', ''NEUTRAL'', ''NEGATIVE'')),
                 ADD CONSTRAINT ck_posts_media_mode CHECK (media_mode IS NULL OR media_mode IN (''PANORAMA'', ''DEPTH'', ''MODEL3D'')),
                 ADD INDEX ix_posts_sentiment (sentiment, created_at)', 'DO 0');
PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;

-- 3.5 SEARCH_HISTORY: từ khóa đã tìm → gợi ý nhóm / hashtag / video
CREATE TABLE IF NOT EXISTS search_history (
    search_id   INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    query       VARCHAR(200) NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY ix_search_history_user (user_id, created_at DESC),
    CONSTRAINT fk_search_history_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- 3.6 WEBAUTHN_CREDENTIALS: passkey (vân tay / khuôn mặt) — chỉ lưu khóa công khai.
--     credential_id là base64url → so khớp PHÂN BIỆT hoa thường (ascii_bin)
CREATE TABLE IF NOT EXISTS webauthn_credentials (
    id             INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    credential_id  VARCHAR(700) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    public_key     VARBINARY(1024) NOT NULL,      -- SubjectPublicKeyInfo (DER) do trình duyệt trả về
    alg            INT NOT NULL,                  -- COSE: -7 = ES256, -257 = RS256
    sign_count     BIGINT NOT NULL DEFAULT 0,
    label          VARCHAR(100) NULL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at   DATETIME NULL,
    UNIQUE KEY ux_webauthn_credential (credential_id),
    KEY ix_webauthn_user (user_id),
    CONSTRAINT fk_webauthn_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- 3.7 USER_DIDS: danh tính số did:key (Ed25519) — chỉ lưu khóa công khai. DID dạng base58 → phân biệt hoa thường
CREATE TABLE IF NOT EXISTS user_dids (
    user_id     INT NOT NULL PRIMARY KEY,
    did         VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    public_key  VARBINARY(64) NOT NULL,           -- khóa công khai Ed25519 thô (32 byte)
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY ux_user_dids_did (did),
    CONSTRAINT fk_user_dids_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. MIGRATION 100 — ảnh / video mẫu trên Cloudinary (link lấy từ DB SmarterASP)
--   - File ở gốc uterspace_uploads/ là ảnh / video minh họa; UploadUtil.delete KHÔNG bao giờ xóa các file này.
--   - Chỉ thay giá trị chưa nằm trên cloud (tên file trong assets/images, đường dẫn uploads/... chỉ có trên
--     một máy, NULL); không đụng link http... đã có (ảnh / video người dùng upload lên Cloudinary).
-- ------------------------------------------------------------
-- Ảnh đại diện (khớp theo email)
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617040/uterspace_uploads/avatar_1.jpg'
WHERE email = 'duy@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617046/uterspace_uploads/avatar_2.jpg'
WHERE email = 'lananh@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617047/uterspace_uploads/avatar_3.jpg'
WHERE email = 'giabao@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617048/uterspace_uploads/avatar_4.jpg'
WHERE email = 'minhha@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617048/uterspace_uploads/avatar_5.jpg'
WHERE email = 'ngochan@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617049/uterspace_uploads/avatar_6.jpg'
WHERE email = 'tanphat@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617050/uterspace_uploads/avatar_7.jpg'
WHERE email = 'thaomy@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617051/uterspace_uploads/avatar_8.jpg'
WHERE email = 'hoangnam@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617051/uterspace_uploads/avatar_9.jpg'
WHERE email = 'thuhang@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617042/uterspace_uploads/avatar_10.jpg'
WHERE email = 'quocbao@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617043/uterspace_uploads/avatar_11.jpg'
WHERE email = 'admin@uterspace.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617044/uterspace_uploads/avatar_12.jpg'
WHERE email = 'anhtuan@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617044/uterspace_uploads/avatar_13.jpg'
WHERE email = 'baongoc@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617045/uterspace_uploads/avatar_14.jpg'
WHERE email = 'diemquynh@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');
UPDATE users SET avatar = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617046/uterspace_uploads/avatar_15.jpg'
WHERE email = 'ducanh@student.hcmute.edu.vn' AND (avatar IS NULL OR avatar NOT LIKE 'http%');

-- Ảnh bìa nhóm (khớp theo tên nhóm)
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617052/uterspace_uploads/group_cover_1.jpg'
WHERE name = 'CLB Robotics HCMUTE' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617055/uterspace_uploads/group_cover_2.jpg'
WHERE name = 'Hoi IT Sinh vien SPKT' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617056/uterspace_uploads/group_cover_3.jpg'
WHERE name = 'Kien Truc Khong Gian Xanh' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617056/uterspace_uploads/group_cover_4.jpg'
WHERE name = 'CLB Tieng Anh HCMUTE' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617057/uterspace_uploads/group_cover_5.jpg'
WHERE name = 'Cong Dong Cybersecurity SPKT' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617059/uterspace_uploads/group_cover_6.jpg'
WHERE name = 'Lập trình Web HCMUTE' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617059/uterspace_uploads/group_cover_7.jpg'
WHERE name = 'CLB Sách & Cà phê' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617061/uterspace_uploads/group_cover_8.jpg'
WHERE name = 'Góc Đồ án Cuối kỳ' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617061/uterspace_uploads/group_cover_9.jpg'
WHERE name = 'CLB Nhiếp ảnh UTE' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617053/uterspace_uploads/group_cover_10.jpg'
WHERE name = 'Việc làm & Thực tập IT' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');
UPDATE groups_tbl SET cover_image = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617053/uterspace_uploads/group_cover_11.jpg'
WHERE name = 'CLB Bóng rổ HCMUTE' AND (cover_image IS NULL OR cover_image NOT LIKE 'http%');

-- Ảnh bài viết (khớp theo email tác giả + đầu nội dung); không đụng ảnh bìa của bài video
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617063/uterspace_uploads/post_img_1.jpg'
WHERE u.email = 'duy@student.hcmute.edu.vn' AND p.content LIKE 'Do an IoT cuoi ky da hoan than%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617068/uterspace_uploads/post_img_2.jpg'
WHERE u.email = 'lananh@student.hcmute.edu.vn' AND p.content LIKE 'Phat hien quan cafe moi mo goc%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617069/uterspace_uploads/post_img_3.jpg'
WHERE u.email = 'giabao@student.hcmute.edu.vn' AND p.content LIKE 'Test thu mo hinh robot do line%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617069/uterspace_uploads/post_img_4.jpg'
WHERE u.email = 'minhha@student.hcmute.edu.vn' AND p.content LIKE 'Goc hoc tap chuan bi cho tuan %'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617071/uterspace_uploads/post_img_5.jpg'
WHERE u.email = 'tanphat@student.hcmute.edu.vn' AND p.content LIKE 'Ca team vua chot xong requirem%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617072/uterspace_uploads/post_img_6.jpg'
WHERE u.email = 'thaomy@student.hcmute.edu.vn' AND p.content LIKE 'Ngay cuoi thuc tap tai cty pha%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617073/uterspace_uploads/post_img_7.jpg'
WHERE u.email = 'khanhlinh@student.hcmute.edu.vn' AND p.content LIKE 'Vừa hoàn thành giao diện trang%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617073/uterspace_uploads/post_img_8.jpg'
WHERE u.email = 'anhtuan@student.hcmute.edu.vn' AND p.content LIKE 'Ngày đầu đi thực tập tại công %'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617075/uterspace_uploads/post_img_9.jpg'
WHERE u.email = 'maiphuong@student.hcmute.edu.vn' AND p.content LIKE 'Săn được học bổng trao đổi ngắ%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617063/uterspace_uploads/post_img_10.jpg'
WHERE u.email = 'giahuy@student.hcmute.edu.vn' AND p.content LIKE 'Mạch cảm biến nhiệt độ của nhó%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617065/uterspace_uploads/post_img_11.jpg'
WHERE u.email = 'khanhlinh@student.hcmute.edu.vn' AND p.content LIKE 'Quán cà phê mới mở gần cổng sa%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617066/uterspace_uploads/post_img_12.jpg'
WHERE u.email = 'huuthang@student.hcmute.edu.vn' AND p.content LIKE 'Chia sẻ bộ tài liệu ôn thi Vi %'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617066/uterspace_uploads/post_img_13.jpg'
WHERE u.email = 'minhquan@student.hcmute.edu.vn' AND p.content LIKE 'Cuối tuần theo mấy anh khóa tr%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617067/uterspace_uploads/post_img_14.jpg'
WHERE u.email = 'diemquynh@student.hcmute.edu.vn' AND p.content LIKE 'Vừa đi tour thực tế ở Vũng Tàu%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617067/uterspace_uploads/post_img_15.jpg'
WHERE u.email = 'nhatminh@student.hcmute.edu.vn' AND p.content LIKE 'Góc học tập mới setup xong. Bà%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.image_path = 'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617054/uterspace_uploads/group_cover_12.jpg'
WHERE u.email = 'giahuy@student.hcmute.edu.vn' AND p.content LIKE 'Team mình vừa nộp báo cáo đồ á%'
  AND (p.image_path IS NULL OR p.image_path NOT LIKE 'http%') AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');

-- File video của 6 bài video mẫu (clip mẫu dài 10 giây)
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.video_path = 'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617076/uterspace_uploads/post_video_1.mp4', p.video_duration_sec = 10
WHERE u.email = 'giahuy@student.hcmute.edu.vn' AND p.content LIKE 'Vlog: một ngày làm đồ án ở phò%'
  AND p.media_type = 'VIDEO' AND (p.video_path IS NULL OR p.video_path NOT LIKE 'http%');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.video_path = 'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617080/uterspace_uploads/post_video_2.mp4', p.video_duration_sec = 10
WHERE u.email = 'khanhlinh@student.hcmute.edu.vn' AND p.content LIKE 'Hướng dẫn dựng giao diện trang%'
  AND p.media_type = 'VIDEO' AND (p.video_path IS NULL OR p.video_path NOT LIKE 'http%');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.video_path = 'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617081/uterspace_uploads/post_video_3.mp4', p.video_duration_sec = 10
WHERE u.email = 'minhquan@student.hcmute.edu.vn' AND p.content LIKE 'Demo tháo lắp động cơ 4 kỳ — b%'
  AND p.media_type = 'VIDEO' AND (p.video_path IS NULL OR p.video_path NOT LIKE 'http%');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.video_path = 'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617082/uterspace_uploads/post_video_4.mp4', p.video_duration_sec = 10
WHERE u.email = 'ducanh@student.hcmute.edu.vn' AND p.content LIKE 'Chia sẻ: cách mình chuẩn bị ch%'
  AND p.media_type = 'VIDEO' AND (p.video_path IS NULL OR p.video_path NOT LIKE 'http%');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.video_path = 'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617083/uterspace_uploads/post_video_5.mp4', p.video_duration_sec = 10
WHERE u.email = 'diemquynh@student.hcmute.edu.vn' AND p.content LIKE 'Tour thực tế Vũng Tàu cùng lớp%'
  AND p.media_type = 'VIDEO' AND (p.video_path IS NULL OR p.video_path NOT LIKE 'http%');
UPDATE posts p JOIN users u ON u.user_id = p.user_id SET p.video_path = 'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617084/uterspace_uploads/post_video_6.mp4', p.video_duration_sec = 10
WHERE u.email = 'thanhtruc@student.hcmute.edu.vn' AND p.content LIKE 'Talkshow CLB Sách: đọc sách th%'
  AND p.media_type = 'VIDEO' AND (p.video_path IS NULL OR p.video_path NOT LIKE 'http%');
