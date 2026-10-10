USE [db_acf87d_uterspace];
GO


PRINT 'Wiping existing tables...';
GO
DECLARE @sql NVARCHAR(MAX) = ''; 
SELECT @sql += 'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(parent_object_id)) + ' DROP CONSTRAINT ' + QUOTENAME(name) + ';' FROM sys.foreign_keys; 
EXEC sp_executesql @sql;
GO
EXEC sp_MSforeachtable @command1 = 'DROP TABLE ?';
GO


PRINT '------------------------------------------------';
PRINT 'Executing 001_schema.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Database Schema (T-SQL for Microsoft SQL Server)
-- Tool: SQL Server Management Studio 22
-- Cách dùng: Chạy toàn bộ file này trong SSMS để tạo database và schema.
-- Thứ tự bảng quan trọng: tạo bảng cha trước, bảng con (FK) sau.
-- ============================================================

-- Tạo database (bỏ qua nếu đã tạo sẵn)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'uterspace')
BEGIN
    CREATE DATABASE uterspace;
END
GO
-- ============================================================
-- 1. users
-- ============================================================
IF OBJECT_ID('users', 'U') IS NOT NULL DROP TABLE users;
GO
CREATE TABLE users (
    user_id       INT           IDENTITY(1,1) PRIMARY KEY,
    first_name    NVARCHAR(100) NOT NULL,
    last_name     NVARCHAR(100) NOT NULL,
    email         NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255) NOT NULL,
    avatar        NVARCHAR(255) NULL,           -- tên file ảnh trong assets/images/
    role          NVARCHAR(20)  NOT NULL DEFAULT 'USER'
                  CHECK (role IN ('USER', 'ADMIN')),
    bio           NVARCHAR(MAX) NULL,
    location      NVARCHAR(200) NULL,
    website       NVARCHAR(255) NULL,
    cover_image   NVARCHAR(255) NULL,
    created_at    DATETIME2     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- 2. posts
-- ============================================================
IF OBJECT_ID('posts', 'U') IS NOT NULL DROP TABLE posts;
GO
CREATE TABLE posts (
    post_id           INT           IDENTITY(1,1) PRIMARY KEY,
    user_id           INT           NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    content           NVARCHAR(MAX) NOT NULL,
    image_path        NVARCHAR(255) NULL,
    visibility        NVARCHAR(20)  NOT NULL DEFAULT 'public'
                      CHECK (visibility IN ('public', 'friends')),
    media_type        NVARCHAR(10)  NULL
                      CHECK (media_type IN ('IMAGE', 'VIDEO')),
    video_path        NVARCHAR(255) NULL,
    video_duration_sec INT          NOT NULL DEFAULT 0,
    like_count        INT           NOT NULL DEFAULT 0,
    comment_count     INT           NOT NULL DEFAULT 0,
    share_count       INT           NOT NULL DEFAULT 0,
    -- Chia sẻ kèm bình luận: NULL = bài thường, != NULL = bài chia sẻ trỏ tới bài GỐC.
    -- Không đặt FK để bài chia sẻ vẫn còn (hiện "không khả dụng") khi bài gốc bị xoá.
    shared_post_id    INT           NULL,
    created_at        DATETIME2     NOT NULL DEFAULT GETDATE()
);
GO
CREATE INDEX ix_posts_shared_post_id ON posts(shared_post_id);
GO

-- ============================================================
-- 3. comments
-- ============================================================
IF OBJECT_ID('comments', 'U') IS NOT NULL DROP TABLE comments;
GO
CREATE TABLE comments (
    comment_id INT           IDENTITY(1,1) PRIMARY KEY,
    post_id    INT           NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id    INT           NOT NULL REFERENCES users(user_id),
    content    NVARCHAR(MAX) NOT NULL,
    created_at DATETIME2     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- 4. likes
-- ============================================================
IF OBJECT_ID('likes', 'U') IS NOT NULL DROP TABLE likes;
GO
CREATE TABLE likes (
    like_id    INT       IDENTITY(1,1) PRIMARY KEY,
    post_id    INT       NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    user_id    INT       NOT NULL REFERENCES users(user_id),
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT uq_likes UNIQUE (post_id, user_id)  -- mỗi user chỉ like 1 bài 1 lần
);
GO

-- ============================================================
-- 5. friendships
-- ============================================================
IF OBJECT_ID('friendships', 'U') IS NOT NULL DROP TABLE friendships;
GO
CREATE TABLE friendships (
    friendship_id INT          IDENTITY(1,1) PRIMARY KEY,
    requester_id  INT          NOT NULL REFERENCES users(user_id),
    receiver_id   INT          NOT NULL REFERENCES users(user_id),
    status        NVARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at    DATETIME2    NOT NULL DEFAULT GETDATE(),
    CONSTRAINT uq_friendship UNIQUE (requester_id, receiver_id)
);
GO

-- ============================================================
-- 6. notifications
-- ============================================================
IF OBJECT_ID('notifications', 'U') IS NOT NULL DROP TABLE notifications;
GO
CREATE TABLE notifications (
    notification_id INT           IDENTITY(1,1) PRIMARY KEY,
    user_id         INT           NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,  -- người nhận
    actor_id        INT           NOT NULL REFERENCES users(user_id),                   -- người gây ra hành động
    type            NVARCHAR(30)  NOT NULL
                    CONSTRAINT chk_notifications_type
                    CHECK (type IN ('LIKE', 'COMMENT', 'SHARE', 'FRIEND_REQUEST', 'FRIEND_ACCEPT', 'GROUP_INVITE', 'SYSTEM')),
    content         NVARCHAR(500) NOT NULL,   -- câu thông báo đầy đủ
    target_url      NVARCHAR(500) NULL,       -- URL dẫn tới khi click
    is_read         BIT           NOT NULL DEFAULT 0,
    created_at      DATETIME2     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- 7. saved_posts
-- ============================================================
IF OBJECT_ID('saved_posts', 'U') IS NOT NULL DROP TABLE saved_posts;
GO
CREATE TABLE saved_posts (
    saved_id   INT       IDENTITY(1,1) PRIMARY KEY,
    user_id    INT       NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    post_id    INT       NOT NULL REFERENCES posts(post_id) ON DELETE NO ACTION,
    saved_at   DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT uq_saved UNIQUE (user_id, post_id)  -- mỗi bài chỉ lưu 1 lần
);
GO

-- ============================================================
-- 8. groups_tbl
-- (Dùng tên groups_tbl vì GROUPS là reserved word trong T-SQL)
-- ============================================================
IF OBJECT_ID('groups_tbl', 'U') IS NOT NULL DROP TABLE groups_tbl;
GO
CREATE TABLE groups_tbl (
    group_id     INT           IDENTITY(1,1) PRIMARY KEY,
    name         NVARCHAR(200) NOT NULL,
    description  NVARCHAR(MAX) NULL,
    category     NVARCHAR(20)  NOT NULL DEFAULT 'STUDY'
                 CHECK (category IN ('STUDY', 'CLUB')),
    cover_icon   NVARCHAR(10)  NULL,          -- emoji đại diện nhóm
    member_count INT           NOT NULL DEFAULT 0,
    created_at   DATETIME2     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- 9. group_members
-- ============================================================
IF OBJECT_ID('group_members', 'U') IS NOT NULL DROP TABLE group_members;
GO
CREATE TABLE group_members (
    group_id  INT          NOT NULL REFERENCES groups_tbl(group_id) ON DELETE CASCADE,
    user_id   INT          NOT NULL REFERENCES users(user_id),
    role      NVARCHAR(10) NOT NULL DEFAULT 'MEMBER'
              CHECK (role IN ('MEMBER', 'ADMIN')),
    joined_at DATETIME2    NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (group_id, user_id)
);
GO

-- ============================================================
-- 10. conversations
-- Ràng buộc: user_a_id < user_b_id để tránh trùng lặp row
-- ============================================================
IF OBJECT_ID('conversations', 'U') IS NOT NULL DROP TABLE conversations;
GO
CREATE TABLE conversations (
    conversation_id   INT       IDENTITY(1,1) PRIMARY KEY,
    user_a_id         INT       NOT NULL REFERENCES users(user_id),
    user_b_id         INT       NOT NULL REFERENCES users(user_id),
    last_message_at   DATETIME2 NULL,
    CONSTRAINT uq_conversation UNIQUE (user_a_id, user_b_id),
    CONSTRAINT chk_user_order CHECK (user_a_id < user_b_id)  -- đảm bảo mỗi cặp chỉ 1 row
);
GO

-- ============================================================
-- 11. chat_messages
-- ============================================================
IF OBJECT_ID('chat_messages', 'U') IS NOT NULL DROP TABLE chat_messages;
GO
CREATE TABLE chat_messages (
    message_id      INT           IDENTITY(1,1) PRIMARY KEY,
    conversation_id INT           NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    sender_id       INT           NOT NULL REFERENCES users(user_id),
    content         NVARCHAR(MAX) NOT NULL,
    is_read         BIT           NOT NULL DEFAULT 0,
    sent_at         DATETIME2     NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Kiểm tra: sau khi chạy, mở Object Explorer trong SSMS
-- Databases > uterspace > Tables → phải thấy đủ 11 bảng:
--   dbo.users, dbo.posts, dbo.comments, dbo.likes,
--   dbo.friendships, dbo.notifications, dbo.saved_posts,
--   dbo.groups_tbl, dbo.group_members,
--   dbo.conversations, dbo.chat_messages
-- ============================================================


PRINT '------------------------------------------------';
PRINT 'Executing 002_seed_data.sql ...';
PRINT '------------------------------------------------';
GO

-- Xoa du lieu cu (DUNG THU TU FK)
DELETE FROM chat_messages;
DELETE FROM conversations;
DELETE FROM notifications;
DELETE FROM group_members;
DELETE FROM groups_tbl;
DELETE FROM saved_posts;
DELETE FROM comments;
DELETE FROM likes;
DELETE FROM posts;
DELETE FROM friendships;
DELETE FROM users;
GO

DBCC CHECKIDENT ('users',         RESEED, 0);
DBCC CHECKIDENT ('posts',         RESEED, 0);
DBCC CHECKIDENT ('comments',      RESEED, 0);
DBCC CHECKIDENT ('likes',         RESEED, 0);
DBCC CHECKIDENT ('friendships',   RESEED, 0);
DBCC CHECKIDENT ('notifications', RESEED, 0);
DBCC CHECKIDENT ('saved_posts',   RESEED, 0);
DBCC CHECKIDENT ('groups_tbl',    RESEED, 0);
DBCC CHECKIDENT ('conversations', RESEED, 0);
DBCC CHECKIDENT ('chat_messages', RESEED, 0);
GO

DECLARE @Pass NVARCHAR(255) = N'$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW';

-- =========================================================
-- 1. USERS (11 tai khoan)
-- =========================================================
SET IDENTITY_INSERT users ON;
INSERT INTO users (user_id, first_name, last_name, email, password_hash, avatar, role, bio, location, website) VALUES
(1,  N'Duc Huy',   N'Nguyen', 'duy@student.hcmute.edu.vn',     @Pass, 'avatar_duchuy.jpg',  'USER',  N'Yeu code, thich ca phe. Dang lam do an IoT.',          N'Thu Duc, HCM', NULL),
(2,  N'Lan Anh',   N'Tran',   'lananh@student.hcmute.edu.vn',  @Pass, 'avatar_lananh.jpg',  'USER',  N'Me du lich, doc sach va review do an.',                N'Quan 1, HCM', NULL),
(3,  N'Gia Bao',   N'Le',     'giabao@student.hcmute.edu.vn',  @Pass, 'avatar_giabao.jpg',  'USER',  N'Dam me Robot va xe co gioi. Leader CLB Robotics.',    N'Quan 9, HCM', NULL),
(4,  N'Minh Ha',   N'Pham',   'minhha@student.hcmute.edu.vn',  @Pass, 'avatar_minhha.jpg',  'USER',  N'Thich ve va thiet ke UI/UX. Mo lam tai Google.',      N'Go Vap, HCM', NULL),
(5,  N'Ngoc Han',  N'Bui',    'ngochan@student.hcmute.edu.vn', @Pass, 'avatar_ngochan.jpg', 'USER',  N'Biet 3 ngoai ngu. Dich thuat la dam me.',             N'Binh Thanh, HCM', NULL),
(6,  N'Tan Phat',  N'Vo',     'tanphat@student.hcmute.edu.vn', @Pass, 'avatar_tanphat.jpg', 'USER',  N'Maker chinh hieu. Nghien Arduino va Raspberry Pi.',   N'Thu Duc, HCM', NULL),
(7,  N'Thao My',   N'Dang',   'thaomy@student.hcmute.edu.vn',  @Pass, 'avatar_thaomy.jpg',  'USER',  N'Yeu mau hong, ghet su gia doi. Drama-free zone.',    N'Quan 3, HCM', NULL),
(8,  N'Hoang Nam', N'Trinh',  'hoangnam@student.hcmute.edu.vn',@Pass, NULL,                  'USER',  N'Tim hieu ve cybersecurity va pentesting. CTF player.',N'Binh Duong', NULL),
(9,  N'Thu Hang',  N'Vu',     'thuhang@student.hcmute.edu.vn', @Pass, NULL,                  'USER',  N'Phac thao moi luc moi noi. Yeu khong gian xanh.',    N'Quan 7, HCM', NULL),
(10, N'Quoc Bao',  N'Ly',     'quocbao@student.hcmute.edu.vn', @Pass, NULL,                  'USER',  N'Co dong vien bong da cuong nhiet. Man Utd fan.',      N'Long An', NULL),
(11, N'Admin',     N'UTEr',   'admin@uterspace.edu.vn',        @Pass, NULL,                  'ADMIN', N'Quan tri vien he thong UTErSpace.',                   N'HCMUTE Campus', NULL);
SET IDENTITY_INSERT users OFF;
GO

-- =========================================================
-- 2. FRIENDSHIPS
-- =========================================================
SET IDENTITY_INSERT friendships ON;
INSERT INTO friendships (friendship_id, requester_id, receiver_id, status, created_at) VALUES
(1,  1, 2,  'accepted', DATEADD(day,-30,GETDATE())),
(2,  1, 3,  'accepted', DATEADD(day,-28,GETDATE())),
(3,  1, 4,  'accepted', DATEADD(day,-25,GETDATE())),
(4,  1, 6,  'accepted', DATEADD(day,-20,GETDATE())),
(5,  2, 3,  'accepted', DATEADD(day,-18,GETDATE())),
(6,  2, 5,  'accepted', DATEADD(day,-15,GETDATE())),
(7,  2, 7,  'accepted', DATEADD(day,-12,GETDATE())),
(8,  3, 6,  'accepted', DATEADD(day,-10,GETDATE())),
(9,  4, 5,  'accepted', DATEADD(day,-8, GETDATE())),
(10, 4, 8,  'accepted', DATEADD(day,-7, GETDATE())),
(11, 5, 9,  'accepted', DATEADD(day,-6, GETDATE())),
(12, 6, 10, 'accepted', DATEADD(day,-5, GETDATE())),
(13, 1, 8,  'pending',  DATEADD(day,-1, GETDATE())),
(14, 1, 9,  'pending',  DATEADD(day,-2, GETDATE())),
(15, 7, 10, 'pending',  DATEADD(day,-1, GETDATE()));
SET IDENTITY_INSERT friendships OFF;
GO

-- =========================================================
-- 3. GROUPS
-- =========================================================
SET IDENTITY_INSERT groups_tbl ON;
INSERT INTO groups_tbl (group_id, name, description, cover_icon, category, member_count, created_at) VALUES
(1, N'CLB Robotics HCMUTE',           N'Noi giao luu hoc hoi ve Robot va thi dau. Chao don moi dam me ky thuat!',  N'robot',  'CLUB',  6, DATEADD(day,-60,GETDATE())),
(2, N'Hoi IT Sinh vien SPKT',         N'Chia se tai lieu do an va kinh nghiem IT. Day la nha cua dan code.',        N'laptop', 'STUDY', 7, DATEADD(day,-45,GETDATE())),
(3, N'Kien Truc Khong Gian Xanh',     N'Danh cho cac ban yeu thiet ke kien truc va khong gian song ben vung.',     N'house',  'STUDY', 3, DATEADD(day,-30,GETDATE())),
(4, N'CLB Tieng Anh HCMUTE',          N'Luyen noi luyen viet chia se tai nguyen hoc Tieng Anh va cac ngon ngu.',   N'globe',  'CLUB',  4, DATEADD(day,-20,GETDATE())),
(5, N'Cong Dong Cybersecurity SPKT',  N'Trao doi ve bao mat thong tin CTF challenges tools va tin tuc security.',  N'shield', 'STUDY', 3, DATEADD(day,-15,GETDATE()));
SET IDENTITY_INSERT groups_tbl OFF;
GO

INSERT INTO group_members (group_id, user_id, role, joined_at) VALUES
(1,3,'ADMIN',DATEADD(day,-60,GETDATE())),(1,6,'MEMBER',DATEADD(day,-55,GETDATE())),
(1,1,'MEMBER',DATEADD(day,-50,GETDATE())),(1,10,'MEMBER',DATEADD(day,-40,GETDATE())),
(1,8,'MEMBER',DATEADD(day,-30,GETDATE())),(1,4,'MEMBER',DATEADD(day,-20,GETDATE())),
(2,1,'ADMIN',DATEADD(day,-45,GETDATE())),(2,4,'MEMBER',DATEADD(day,-40,GETDATE())),
(2,8,'MEMBER',DATEADD(day,-35,GETDATE())),(2,6,'MEMBER',DATEADD(day,-20,GETDATE())),
(2,3,'MEMBER',DATEADD(day,-15,GETDATE())),(2,2,'MEMBER',DATEADD(day,-10,GETDATE())),
(2,5,'MEMBER',DATEADD(day,-5,GETDATE())),
(3,9,'ADMIN',DATEADD(day,-30,GETDATE())),(3,4,'MEMBER',DATEADD(day,-25,GETDATE())),
(3,2,'MEMBER',DATEADD(day,-10,GETDATE())),
(4,5,'ADMIN',DATEADD(day,-20,GETDATE())),(4,2,'MEMBER',DATEADD(day,-18,GETDATE())),
(4,9,'MEMBER',DATEADD(day,-10,GETDATE())),(4,7,'MEMBER',DATEADD(day,-5,GETDATE())),
(5,8,'ADMIN',DATEADD(day,-15,GETDATE())),(5,1,'MEMBER',DATEADD(day,-12,GETDATE())),
(5,4,'MEMBER',DATEADD(day,-8,GETDATE()));
GO

-- =========================================================
-- 4. POSTS (15 bai viet)
-- =========================================================
SET IDENTITY_INSERT posts ON;
INSERT INTO posts (post_id, user_id, content, image_path, media_type, like_count, comment_count, share_count, created_at) VALUES
(1,  1, N'Do an IoT cuoi ky da hoan thanh! Cam on anh em da chien dau cung nhau 2 thang. He thong theo doi nhiet do phong hoc real-time qua app. #IoT #HCMUTE', 'iot_project.jpg',    'IMAGE', 0, 0, 2, DATEADD(day,-7,GETDATE())),
(2,  2, N'Phat hien quan cafe moi mo goc duong Vo Van Ngan, view sieu chill cho mua deadline. Ai muon di cung khong? Ly ca phe trung ngon hon ca Ha Noi! #coffee', 'cafe_review.jpg',    'IMAGE', 0, 0, 1, DATEADD(day,-6,GETDATE())),
(3,  3, N'Test thu mo hinh robot do line cho cuoc thi cuoi tuan. Chay muot hon nho thay cam bien IR sang lidar mini! #Robotics #Maker #CLBRobotics', 'robot_demo.jpg',     'IMAGE', 0, 0, 3, DATEADD(day,-5,GETDATE())),
(4,  4, N'Goc hoc tap chuan bi cho tuan thi cuoi ky. Quyet tam hoc bong hoc ky nay! Moi nguoi chia se meo hoc bai hieu qua nha. #StudySpace #HCMUTE', 'study_setup.jpg',    'IMAGE', 0, 0, 0, DATEADD(day,-5,GETDATE())),
(5,  6, N'Ca team vua chot xong requirement cho do an Phan tich thiet ke he thong. Co len anh em, con 3 tuan nua la demo roi! #TeamWork #SoftwareEngineering', 'team_photo.jpg',     'IMAGE', 0, 0, 2, DATEADD(day,-4,GETDATE())),
(6,  7, N'Ngay cuoi thuc tap tai cty phan mem. 3 thang nhieu ky niem dep, hoc duoc rat nhieu. Cam on anh chi mentor da huong dan nhiet tinh! #Intern #Career', 'intern_last_day.jpg','IMAGE', 0, 0, 1, DATEADD(day,-4,GETDATE())),
(7,  1, N'Cho minh hoi thu vien trung tam HCMUTE chu nhat co mo cua khong? Can tim mot so sach tham khao cho bao cao do an. Cam on!', NULL, NULL, 0, 0, 0, DATEADD(day,-3,GETDATE())),
(8,  8, N'Vua solve xong challenge Web Exploitation tren HackTheBox sau 2 ngay ngoi. Flag cuoi cung hien len khong khac gi len dinh Everest! #CTF #Cybersecurity', NULL, NULL, 0, 0, 4, DATEADD(day,-3,GETDATE())),
(9,  5, N'Sharing tai nguyen hoc IELTS mien phi: Cambridge 1-18 PDF, E2IELTS YouTube, British Council app. Cu DM minh neu can them nha! #IELTS #English', NULL, NULL, 0, 0, 8, DATEADD(day,-2,GETDATE())),
(10, 9, N'Hoan thanh ban phac thao concept nha o xa hoi than thien moi truong. Moi nguoi thay sao? Minh muon tich hop vuon dung tren mat dung phia Nam. #Architecture', NULL, NULL, 0, 0, 0, DATEADD(day,-2,GETDATE())),
(11, 2, N'Tong hop 10 quan an sinh vien ngon re gan HCMUTE. Tu 20k den 40k, an no an ngon. Full list trong comment ben duoi! #FoodReview #HCMUTELife', NULL, NULL, 0, 0, 6, DATEADD(day,-1,GETDATE())),
(12, 4, N'UI Design challenge: Redesign app dat xe cho thi truong VN. Dung Figma de mockup trong 4 gio. Feedback chan thanh tu anh em nhe! #UIDesign #UX #Figma', NULL, NULL, 0, 0, 1, DATEADD(day,-1,GETDATE())),
(13, 6, N'Vua hoan thanh cai dat home server voi RPi 4B: NAS luu tru, VPN, Pi-hole chan quang cao va Home Assistant. Tat ca chay on dinh 24/7. AMA! #RaspberryPi', NULL, NULL, 0, 0, 3, GETDATE()),
(14, 3, N'CLB Robotics dang tuyen them thanh vien moi! Khong can kinh nghiem, chi can dam me. Workshop thu 7 tai C206. Tag ban be vao day nha! #Robotics', NULL, NULL, 0, 0, 5, GETDATE()),
(15, 1, N'Cam on moi nguoi da support kenh code cua minh. 100 followers dau tien! Sap toi lam series Spring Boot va microservices. Stay tuned! #SpringBoot #Java', NULL, NULL, 0, 0, 7, GETDATE());
SET IDENTITY_INSERT posts OFF;
GO

-- =========================================================
-- 5. LIKES
-- =========================================================
INSERT INTO likes (post_id, user_id) VALUES
(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),(1,8),
(2,1),(2,3),(2,4),(2,5),(2,6),(2,7),(2,8),(2,9),(2,10),
(3,1),(3,2),(3,4),(3,5),(3,6),(3,7),(3,8),(3,9),(3,10),(3,11),
(4,1),(4,2),(4,3),(4,5),(4,6),(4,7),(4,9),(4,10),
(5,1),(5,2),(5,3),(5,4),(5,5),(5,7),(5,8),(5,9),(5,10),(5,11),
(6,1),(6,2),(6,3),(6,4),(6,5),(6,6),(6,8),(6,9),(6,10),(6,11),
(7,2),(7,4),(7,5),
(8,1),(8,2),(8,4),(8,5),(8,6),(8,7),(8,9),(8,10),
(9,1),(9,2),(9,3),(9,4),(9,6),(9,7),(9,8),(9,10),
(10,1),(10,2),(10,4),(10,5),(10,7),(10,8),
(11,1),(11,3),(11,4),(11,5),(11,6),(11,7),(11,8),(11,9),(11,10),
(12,1),(12,2),(12,5),(12,6),(12,7),(12,8),(12,9),(12,10),
(13,1),(13,2),(13,3),(13,4),(13,5),(13,7),(13,8),(13,9),(13,10),
(14,1),(14,2),(14,4),(14,5),(14,6),(14,7),(14,8),(14,9),(14,10),
(15,2),(15,3),(15,4),(15,5),(15,6),(15,7),(15,8),(15,9),(15,10);
GO

-- =========================================================
-- 6. COMMENTS
-- =========================================================
SET IDENTITY_INSERT comments ON;
INSERT INTO comments (comment_id, post_id, user_id, content, created_at) VALUES
(1,  1,3,N'Xin source Github voi ban! Minh cung dang lam IoT nhung chua ra ket qua dep.',DATEADD(day,-6,GETDATE())),
(2,  1,6,N'Sensor nhiet do ban dung la DHT11 hay DHT22 vay?',DATEADD(day,-5,GETDATE())),
(3,  1,4,N'Bao gio ban demo cho ca lop xem vay? Hong lam!',DATEADD(day,-5,GETDATE())),
(4,  1,2,N'Ngưỡng mộ tinh thần chiến đấu của team quá! Chúc mừng nhé',DATEADD(day,-4,GETDATE())),
(5,  2,1,N'Dia chi cu the la dau ban oi? Minh tim mai khong ra quan do.',DATEADD(day,-5,GETDATE())),
(6,  2,7,N'Ca phe trung! Minh me mon nay tu lan dau thu o Ha Noi luon!',DATEADD(day,-4,GETDATE())),
(7,  2,3,N'Gia ca the nao ban? Sinh vien du suc khong?',DATEADD(day,-3,GETDATE())),
(8,  2,5,N'Review do uong hay that, lan sau vao day minh se thu ngay!',DATEADD(day,-2,GETDATE())),
(9,  2,9,N'Cam on ban da review nhe, minh se ru nhom di cuoi tuan nay!',DATEADD(day,-1,GETDATE())),
(10, 3,1,N'Robot nhin pro hon minh tuong. Thuat toan PID hay chi on/off vay?',DATEADD(day,-4,GETDATE())),
(11, 3,6,N'Lidar mini ban mua tu dau vay? Shopee hay Aliexpress?',DATEADD(day,-3,GETDATE())),
(12, 3,8,N'CLB cac ban impressive lam. Cho minh tham quan workshop duoc khong?',DATEADD(day,-2,GETDATE())),
(13, 4,1,N'Goc hoc tap nhin sach se yen tinh qua. Minh hoc o phong tro on ao chiu khong noi!',DATEADD(day,-4,GETDATE())),
(14, 4,5,N'Thi tot nha ban! Minh cung dang can motivation hoc bai lam.',DATEADD(day,-3,GETDATE())),
(15, 4,3,N'Meo cua minh: Pomodoro 25 phut hoc 5 phut nghi. Hieu qua lam!',DATEADD(day,-2,GETDATE())),
(16, 4,2,N'Thu 2 thi chua? Chuc may man ban oi!',DATEADD(day,-2,GETDATE())),
(17, 4,7,N'Nuoc uong du, anh sang du la dieu kien toi thieu de nao hoat dong tot nhe!',DATEADD(day,-1,GETDATE())),
(18, 4,4,N'Cam on moi nguoi, minh se co gang! Update ket qua sau nha.',GETDATE()),
(19, 5,1,N'Team minh cung dang trong giai doan nay. Vuot qua duoc requirement la on roi!',DATEADD(day,-3,GETDATE())),
(20, 5,4,N'Diagram ERD cac ban da xong chua? Phan do minh hay bi reject nhat.',DATEADD(day,-2,GETDATE())),
(21, 5,3,N'Cam giac chot xong requirement nhe nhom lam do. Phan code moi la thu thach!',DATEADD(day,-1,GETDATE())),
(22, 5,8,N'Chuc team may man! 3 tuan du neu moi ngay commit deu dan.',GETDATE()),
(23, 6,1,N'Thuc tap o do thu nhap tot khong ban? Minh dang tim cho thuc tap.',DATEADD(day,-3,GETDATE())),
(24, 6,2,N'Minh cung vua ket thuc dot thuc tap tuan truoc. Cam giac nho lam nhi!',DATEADD(day,-2,GETDATE())),
(25, 6,4,N'Ban chia se tips xin thuc tap duoc khong? Minh gui CV mai khong duoc call.',DATEADD(day,-1,GETDATE())),
(26, 6,5,N'3 thang thuc tap hoc duoc nhieu hon 1 nam hoc ly thuyet dung khong?',DATEADD(day,-1,GETDATE())),
(27, 6,7,N'Chuc ban som co viec full-time nhe! Kinh nghiem nhu vay de xin viec lam.',GETDATE()),
(28, 7,2,N'Chu nhat thu vien dong cua ban oi. Thu 2 den Thu 6 moi mo, tu 7h30 den 17h.',DATEADD(day,-2,GETDATE())),
(29, 7,4,N'Ngoai thu vien truong thi thu vien quan 9 cung co nhieu sach hoc tot lam!',DATEADD(day,-2,GETDATE())),
(30, 7,6,N'Ban can sach gi? Minh co the chia file PDF cho neu khong tim duoc ban in.',DATEADD(day,-1,GETDATE())),
(31, 7,9,N'Thu vien C2 tang 3 it nguoi hon, yen tinh hon de hoc nhe!',GETDATE()),
(32, 8,1,N'Respect! Minh cung muon thu HackTheBox nhung ngai kho qua. Loi khuyen cho nguoi moi?',DATEADD(day,-2,GETDATE())),
(33, 8,4,N'Web Exploitation la challenge minh thay kho nhat. Ban dung tool gi vay?',DATEADD(day,-1,GETDATE())),
(34, 8,6,N'Minh biet Python mot chut, vay co the bat dau CTF duoc khong?',DATEADD(day,-1,GETDATE())),
(35, 8,5,N'Minh khong hieu gi ve hacking nhung nghe hao hung lam!',GETDATE()),
(36, 8,2,N'Ban co tham gia team CTF chua? CLB Cybersecurity SPKT hay to chuc.',GETDATE()),
(37, 8,3,N'Flag la gi khong? Just kidding haha',GETDATE()),
(38, 8,9,N'Very impressive! Toi khong hieu ky thuat nhung day la achievement lon.',GETDATE()),
(39, 9,1,N'Cam on ban nhieu! Minh dang can tai lieu cho muc tieu 7.0 nay. DM ngay!',DATEADD(day,-1,GETDATE())),
(40, 9,2,N'Co app luyen speaking tot khong? Minh yeu nhat phan nay.',DATEADD(day,-1,GETDATE())),
(41, 9,3,N'Ban dang o band may roi? Share kinh nghiem dat diem cao di!',DATEADD(day,-1,GETDATE())),
(42, 9,4,N'IELTS Listening thi podcast nao hay nhat? BBC hay VOA?',GETDATE()),
(43, 9,6,N'Minh khong can IELTS nhung van follow de hoc tieng Anh chuyen nganh ky thuat.',GETDATE()),
(44, 9,7,N'Ban co khoa hoc nao recommend cho Writing task 2 khong?',GETDATE()),
(45, 9,8,N'DM ban ngay, can tai lieu cho ky thi thang sau!',GETDATE()),
(46, 9,10,N'Cam on ban da share! Rat huu ich cho cac ban khong du tien hoc trung tam.',GETDATE()),
(47, 9,9,N'Bo sung them: app Duolingo van tot de duy tri thoi quen hoc hang ngay nha!',GETDATE()),
(48,10,2,N'Sketch dep qua! Vuon dung y tuong hay, them panel nang luong mat troi nua thi hoan hao.',DATEADD(day,-1,GETDATE())),
(49,10,4,N'Thiet ke sustainable dang la trend lon. Ban co tinh toan ve nang luong chua?',DATEADD(day,-1,GETDATE())),
(50,10,5,N'Y tuong nha o xa hoi nhung van dep va xanh, rat can thiet cho do thi VN!',GETDATE()),
(51,11,1,N'Quan nao gan cong B nhat ban? Minh hay ra do an trua.',GETDATE()),
(52,11,3,N'Bun bo Hue tai cong A ngon khong ban oi? Hay chi la binh thuong?',GETDATE()),
(53,11,4,N'Com tam thi o cho nao ngon nhat? So sanh di!',GETDATE()),
(54,11,6,N'Toi vote cho quan chao ga goc duong To Vinh Dien, 20k mot to day du.',GETDATE()),
(55,11,7,N'An ngon khong lo beo hihi. Thanks ban da review!',GETDATE()),
(56,11,8,N'Co quan chay khong? Minh dang thuc hien an chay vao thu 2.',GETDATE()),
(57,11,9,N'Them quan tra sua 25k vao list nha! Uong ma khong lo ngheo.',GETDATE()),
(58,11,10,N'Lan nao cung an com tu nau. Phai thu doi vi thoi!',GETDATE()),
(59,12,1,N'Design trong clean va modern. Mau sac chon rat hop voi thi truong Viet.',GETDATE()),
(60,12,2,N'UX flow thanh toan hon nhieu step. User co the bo cuoc o buoc 3 do.',GETDATE()),
(61,12,6,N'Nut CTA mau noi hon chut nua se tot hon. Con lai thi tuyet!',GETDATE()),
(62,12,8,N'Font chon dep lam. San-serif trong professional hon serif nhieu.',GETDATE()),
(63,12,9,N'Ban co nghi den accessibility cho nguoi cao tuoi chua? Size font hoi nho.',GETDATE()),
(64,13,1,N'Home server nghe ngau qua! Ban ton bao nhieu dien moi thang?',GETDATE()),
(65,13,2,N'Pi-hole la gi vay? Chan quang cao nhu the nao?',GETDATE()),
(66,13,4,N'Home Assistant setup mat bao lau? Ban document lai ra tutorial duoc khong?',GETDATE()),
(67,13,8,N'NAS ban dung bao nhieu o cung? RAID 1 hay RAID 5?',GETDATE()),
(68,13,3,N'VPN tu host thi bao mat hon dich vu thuong mai chu? Toc do ra sao?',GETDATE()),
(69,13,10,N'Minh muon lam tuong tu nhung khong biet bat dau tu dau. Co video huong dan khong?',GETDATE()),
(70,14,1,N'Minh muon tham gia! Workshop thu 7 luc may gio?',GETDATE()),
(71,14,4,N'CLB co nhan thanh vien khong phai nganh Co khi/Dien tu khong?',GETDATE()),
(72,14,5,N'Minh hoc Ngoai ngu nhung rat thich Robot. Co duoc tham gia khong a?',GETDATE()),
(73,14,8,N'Co can dong phi thanh vien khong? Va can mang dung cu gi?',GETDATE()),
(74,14,2,N'Tag ban nay vao day, hay hoi ve Robotics lam!',GETDATE()),
(75,14,9,N'Kien truc nhu minh co the tham gia ve phan thiet ke vo robot khong nhi?',GETDATE()),
(76,14,10,N'Dang ky online khong hay phai den truc tiep?',GETDATE()),
(77,14,6,N'Moi nganh deu chao don! Cu den workshop thu 7 nhe, C206 luc 8h sang.',GETDATE()),
(78,15,2,N'100 followers chi la buoc khoi dau! Series Spring Boot dang rat duoc don nhan.',GETDATE()),
(79,15,4,N'Ban co lam video ve JPA/Hibernate khong? Minh dang hoc phan do kho qua.',GETDATE()),
(80,15,6,N'Subscribe roi! Cho series microservices cua ban day.',GETDATE()),
(81,15,3,N'Kenh nao vay? Share link di de minh follow luon!',GETDATE()),
(82,15,5,N'Chuc mung! Tiep tuc chia se kien thuc cho cong dong nhe.',GETDATE()),
(83,15,7,N'Cam on ban da chia se kien thuc mien phi cho moi nguoi!',GETDATE()),
(84,15,8,N'Hy vong ban cung cover Security trong Spring Boot nhe. Rat quan trong!',GETDATE()),
(85,15,9,N'Du khong phai IT nhung minh van follow vi noi dung hay qua.',GETDATE()),
(86,15,10,N'Sap co video moi chua? Dang cho series tiep theo!',GETDATE()),
(87,15,11,N'Khuyen khich tinh than chia se kien thuc nay! Keep it up.',GETDATE());
SET IDENTITY_INSERT comments OFF;
GO

-- =========================================================
-- 7. SAVED POSTS
-- =========================================================
INSERT INTO saved_posts (user_id, post_id, saved_at) VALUES
(1,2,DATEADD(day,-5,GETDATE())),(1,9,DATEADD(day,-1,GETDATE())),(1,8,DATEADD(day,-2,GETDATE())),
(2,9,DATEADD(day,-1,GETDATE())),(2,11,GETDATE()),
(3,14,GETDATE()),
(4,9,DATEADD(day,-1,GETDATE())),(4,12,GETDATE()),
(5,9,DATEADD(day,-1,GETDATE())),
(6,13,GETDATE()),
(7,11,GETDATE()),
(8,15,GETDATE());
GO

-- =========================================================
-- 8. NOTIFICATIONS
-- =========================================================
SET IDENTITY_INSERT notifications ON;
INSERT INTO notifications (notification_id, user_id, actor_id, type, content, target_url, is_read, created_at) VALUES
(1,  1,2,  'LIKE',           N'da thich bai viet cua ban.',              '/feed#post-1',  0, DATEADD(day,-6,GETDATE())),
(2,  1,3,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-1',  0, DATEADD(day,-6,GETDATE())),
(3,  1,4,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-7',  0, DATEADD(day,-2,GETDATE())),
(4,  1,9,  'FRIEND_REQUEST', N'da gui cho ban mot loi moi ket ban.',    '/friends',      0, DATEADD(day,-2,GETDATE())),
(5,  1,5,  'LIKE',           N'da thich bai viet cua ban.',              '/feed#post-15', 0, GETDATE()),
(6,  1,6,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-15', 0, GETDATE()),
(7,  2,1,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-2',  1, DATEADD(day,-5,GETDATE())),
(8,  2,7,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-2',  1, DATEADD(day,-4,GETDATE())),
(9,  2,3,  'LIKE',           N'da thich bai viet cua ban.',              '/feed#post-11', 0, GETDATE()),
(10, 3,1,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-3',  0, DATEADD(day,-4,GETDATE())),
(11, 3,8,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-3',  0, DATEADD(day,-2,GETDATE())),
(12, 3,5,  'LIKE',           N'da thich bai viet cua ban.',              '/feed#post-14', 0, GETDATE()),
(13, 4,1,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-4',  1, DATEADD(day,-4,GETDATE())),
(14, 4,3,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-4',  0, DATEADD(day,-2,GETDATE())),
(15, 4,2,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-12', 0, GETDATE()),
(16, 5,1,  'LIKE',           N'da thich bai viet cua ban.',              '/feed#post-9',  0, GETDATE()),
(17, 5,2,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-9',  0, GETDATE()),
(18, 6,1,  'LIKE',           N'da thich bai viet cua ban.',              '/feed#post-5',  1, DATEADD(day,-3,GETDATE())),
(19, 6,4,  'COMMENT',        N'da binh luan ve bai viet cua ban.',      '/feed#post-13', 0, GETDATE()),
(20, 1,2,  'FRIEND_ACCEPT',  N'da chap nhan loi moi ket ban cua ban.', '/profile?userId=2', 1, DATEADD(day,-29,GETDATE())),
(21, 2,3,  'FRIEND_ACCEPT',  N'da chap nhan loi moi ket ban cua ban.', '/profile?userId=3', 1, DATEADD(day,-17,GETDATE()));
SET IDENTITY_INSERT notifications OFF;
GO

-- =========================================================
-- 9. CONVERSATIONS & MESSAGES
-- =========================================================
SET IDENTITY_INSERT conversations ON;
INSERT INTO conversations (conversation_id, user_a_id, user_b_id, last_message_at) VALUES
(1, 1, 2, DATEADD(hour,-2, GETDATE())),
(2, 1, 3, DATEADD(day,-1, GETDATE())),
(3, 2, 5, DATEADD(day,-2, GETDATE())),
(4, 4, 8, DATEADD(day,-1, GETDATE())),
(5, 3, 6, DATEADD(hour,-5, GETDATE()));
SET IDENTITY_INSERT conversations OFF;
GO

SET IDENTITY_INSERT chat_messages ON;
INSERT INTO chat_messages (message_id, conversation_id, sender_id, content, is_read, sent_at) VALUES
(1, 1,1,N'Lan Anh oi, nhom minh can them nguoi lam phan bao cao, ban co the giup khong?',1,DATEADD(hour,-3,GETDATE())),
(2, 1,2,N'Ban can cu the phan nao? Minh co the lam phan kinh te va market research.',1,DATEADD(hour,-2,GETDATE())),
(3, 1,1,N'Tuyet! Minh can phan tich chi phi du an. Deadline cuoi tuan nay nha.',1,DATEADD(hour,-2,GETDATE())),
(4, 1,2,N'OK minh se lam! Gui template bao cao cho minh voi.',0,DATEADD(hour,-2,GETDATE())),
(5, 2,3,N'Huy oi, may co ranh thu 7 khong? CLB to chuc workshop Arduino co ban.',1,DATEADD(day,-1,GETDATE())),
(6, 2,1,N'Minh co ranh! May gio va o dau vay?',1,DATEADD(day,-1,GETDATE())),
(7, 2,3,N'8h sang tai phong C206. Mang laptop nha, cai san Arduino IDE gium.',1,DATEADD(day,-1,GETDATE())),
(8, 2,1,N'Okok minh se den! Can mang gi them khong?',0,DATEADD(day,-1,GETDATE())),
(9, 3,2,N'Han oi, chia se link tai lieu IELTS voi minh duoc khong? Minh dang can gap.',1,DATEADD(day,-2,GETDATE())),
(10,3,5,N'Day nha! Cambridge 1-18 link drive nay. Con muon gi them khong?',1,DATEADD(day,-2,GETDATE())),
(11,3,2,N'Du roi cam on ban nhieu lam! Dang can gap cho ky thi thang sau.',1,DATEADD(day,-2,GETDATE())),
(12,4,4,N'Nam oi, minh can tu van ve bao mat cho app web. Ban co thoi gian khong?',1,DATEADD(day,-1,GETDATE())),
(13,4,8,N'Duoc chu! App ban dung framework gi? Spring Boot hay Express.js?',1,DATEADD(day,-1,GETDATE())),
(14,4,4,N'Spring Boot. Minh chu yeu lo ve SQL Injection va XSS.',1,DATEADD(day,-1,GETDATE())),
(15,4,8,N'Spring Boot dung JPA thi da co parameterized query roi, kha an toan. XSS thi can escape output.',0,DATEADD(day,-1,GETDATE())),
(16,5,3,N'Phat, may tim duoc cai lidar mini do o dau vay? Link voi tao cai.',1,DATEADD(hour,-6,GETDATE())),
(17,5,6,N'Aliexpress day, search TF-Luna lidar. Khoang 200k, ship 2 tuan.',1,DATEADD(hour,-5,GETDATE())),
(18,5,3,N'OK cam on! May thay do chinh xac co du cho line following khong?',0,DATEADD(hour,-5,GETDATE()));
SET IDENTITY_INSERT chat_messages OFF;
GO

-- Dong bo so like va comment thuc te
UPDATE posts SET like_count    = (SELECT COUNT(*) FROM likes    WHERE likes.post_id    = posts.post_id);
UPDATE posts SET comment_count = (SELECT COUNT(*) FROM comments WHERE comments.post_id = posts.post_id);
GO

PRINT N'Seed data da them thanh cong!';
PRINT N'Users: 11 | Posts: 15 | Friendships: 15 | Comments: 87 | Groups: 5';
PRINT N'Conversations: 5 | Messages: 18 | Notifications: 21 | SavedPosts: 12';


PRINT '------------------------------------------------';
PRINT 'Executing 003_seed_more_data.sql ...';
PRINT '------------------------------------------------';
GO

/* ============================================================================
   UTErSpace — DỮ LIỆU MẪU BỔ SUNG
   ----------------------------------------------------------------------------
   Chạy SAU schema.sql + seed_data.sql, trên database đã có sẵn dữ liệu.
   Script được viết theo hướng "chạy lại nhiều lần không nhân bản":
   mọi INSERT đều có điều kiện NOT EXISTS hoặc khoá UNIQUE bảo vệ.

   Cách chạy bằng SSMS : mở file -> Execute (F5)
   Cách chạy bằng dòng lệnh (bắt buộc -f 65001 để giữ tiếng Việt có dấu):
     sqlcmd -S localhost,1433 -U uterspace_user -P 123456 -d uterspace -C
            -f 65001 -i seed_more_data.sql
   ============================================================================ */

SET NOCOUNT ON;
/* ============================================================================
   1. NGƯỜI DÙNG MỚI
   Mật khẩu dùng chung với tài khoản sẵn có (copy hash của user_id = 1),
   nhờ vậy không cần sinh hash BCrypt mới.
   ============================================================================ */
DECLARE @pwd NVARCHAR(255);
SELECT TOP 1 @pwd = password_hash FROM users WHERE user_id = 1;

/* Đưa vào bảng tạm trước, để phần INSERT thật bên dưới xử lý được cả hai
   trường hợp schema: có hoặc không có cột student_id (cột cũ, còn ràng buộc
   UNIQUE trên một số database được tạo từ bản schema trước). */
SELECT v.first_name, v.last_name, v.email, @pwd AS password_hash, v.bio, v.location, v.website,
       CAST(21110100 + ROW_NUMBER() OVER (ORDER BY v.email) AS NVARCHAR(20)) AS student_id
INTO #new_users
FROM (VALUES
  (N'Khánh Linh', N'Nguyễn', 'khanhlinh@student.hcmute.edu.vn',
     N'Sinh viên CNTT năm 3. Mê front-end và mấy cái animation mượt mượt.', N'Tân Bình, HCM', N'https://github.com/khanhlinh'),
  (N'Trọng Nghĩa', N'Phan', 'trongnghia@student.hcmute.edu.vn',
     N'Khoa Cơ khí. Ngày làm đồ án, tối chạy bộ quanh ký túc xá.', N'Dĩ An, Bình Dương', NULL),
  (N'Mai Phương', N'Đỗ', 'maiphuong@student.hcmute.edu.vn',
     N'Kinh tế K21. Thích đọc sách và săn học bổng trao đổi.', N'Quận 10, HCM', NULL),
  (N'Hữu Thắng', N'Đinh', 'huuthang@student.hcmute.edu.vn',
     N'Điện - Điện tử. Đang nghịch ESP32 và mấy con cảm biến.', N'Thủ Đức, HCM', NULL),
  (N'Bảo Ngọc', N'Lý', 'baongoc@student.hcmute.edu.vn',
     N'Công nghệ May & Thời trang. Mình vẽ phác thảo mỗi ngày.', N'Bình Tân, HCM', NULL),
  (N'Đức Anh', N'Hoàng', 'ducanh@student.hcmute.edu.vn',
     N'CNTT K20. Backend Java, đang học thêm Docker.', N'Biên Hòa, Đồng Nai', N'https://linkedin.com/in/ducanh'),
  (N'Tuyết Nhi', N'Cao', 'tuyetnhi@student.hcmute.edu.vn',
     N'Sư phạm Anh văn. Nhận kèm IELTS cho các bạn cùng trường nha.', N'Quận 4, HCM', NULL),
  (N'Minh Quân', N'Đặng', 'minhquan@student.hcmute.edu.vn',
     N'Công nghệ Ô tô. Cuối tuần hay ra gara phụ mấy anh khóa trên.', N'Thủ Đức, HCM', NULL),
  (N'Hải Yến', N'Trương', 'haiyen@student.hcmute.edu.vn',
     N'Xây dựng K22. Mê vẽ AutoCAD hơn mê ngủ nướng.', N'Gò Vấp, HCM', NULL),
  (N'Anh Tuấn', N'Lâm', 'anhtuan@student.hcmute.edu.vn',
     N'CNTT. Đang thực tập tại một công ty fintech ở Quận 1.', N'Quận 12, HCM', NULL),
  (N'Thanh Trúc', N'Nguyễn', 'thanhtruc@student.hcmute.edu.vn',
     N'Kế toán K21. Chủ nhiệm CLB Sách của trường.', N'Tân Phú, HCM', NULL),
  (N'Gia Huy', N'Phạm', 'giahuy@student.hcmute.edu.vn',
     N'Điện tử viễn thông. Thích làm mạch và quay vlog quá trình.', N'Thủ Đức, HCM', NULL),
  (N'Diễm Quỳnh', N'Võ', 'diemquynh@student.hcmute.edu.vn',
     N'Du lịch & Lữ hành. Đi được 18/63 tỉnh thành rồi!', N'Quận 5, HCM', NULL),
  (N'Nhật Minh', N'Trần', 'nhatminh@student.hcmute.edu.vn',
     N'CNTT K22. Mới bắt đầu học React, ai cùng team không?', N'Thuận An, Bình Dương', NULL)
) AS v(first_name, last_name, email, bio, location, website)
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);

IF COL_LENGTH('users', 'student_id') IS NULL
BEGIN
    /* Schema hiện tại (schema.sql) — không còn cột student_id */
    INSERT INTO users (first_name, last_name, email, password_hash, avatar, role, bio, location, website)
    SELECT first_name, last_name, email, password_hash, NULL, 'USER', bio, location, website
    FROM #new_users;
END
ELSE
BEGIN
    /* Database cũ vẫn còn cột student_id kèm ràng buộc UNIQUE: để NULL thì
       dòng thứ hai sẽ vi phạm ràng buộc, nên phải cấp mã số sinh viên.
       Dùng EXEC vì batch sẽ không biên dịch được nếu cột không tồn tại. */
    EXEC(N'INSERT INTO users (first_name, last_name, email, password_hash, avatar, role, bio, location, website, student_id)
           SELECT first_name, last_name, email, password_hash, NULL, ''USER'', bio, location, website, student_id
           FROM #new_users;');
END

DROP TABLE #new_users;
GO

DECLARE @n1 INT; SELECT @n1 = COUNT(*) FROM users;
PRINT N'--> Tổng số người dùng: ' + CAST(@n1 AS NVARCHAR(20));
GO

/* ============================================================================
   2. KẾT BẠN
   ============================================================================ */
DECLARE @me INT;
SELECT @me = user_id FROM users WHERE email = 'minhha@student.hcmute.edu.vn';

/* 2a. Minh Hà kết bạn (đã chấp nhận) với nhóm bạn mới */
INSERT INTO friendships (requester_id, receiver_id, status, created_at)
SELECT @me, u.user_id, 'accepted', DATEADD(DAY, -v.d, SYSDATETIME())
FROM (VALUES
  ('khanhlinh@student.hcmute.edu.vn', 40), ('ducanh@student.hcmute.edu.vn',    35),
  ('anhtuan@student.hcmute.edu.vn',   30), ('nhatminh@student.hcmute.edu.vn',  26),
  ('tuyetnhi@student.hcmute.edu.vn',  22), ('maiphuong@student.hcmute.edu.vn', 18),
  ('giahuy@student.hcmute.edu.vn',    15), ('haiyen@student.hcmute.edu.vn',    11)
) AS v(email, d)
JOIN users u ON u.email = v.email
WHERE NOT EXISTS (
  SELECT 1 FROM friendships f
  WHERE (f.requester_id = @me AND f.receiver_id = u.user_id)
     OR (f.requester_id = u.user_id AND f.receiver_id = @me));

/* 2b. Ba lời mời đang chờ Minh Hà xác nhận (hiện ở tab "Lời mời") */
INSERT INTO friendships (requester_id, receiver_id, status, created_at)
SELECT u.user_id, @me, 'pending', DATEADD(HOUR, -v.h, SYSDATETIME())
FROM (VALUES
  ('trongnghia@student.hcmute.edu.vn', 6),
  ('baongoc@student.hcmute.edu.vn',    20),
  ('thanhtruc@student.hcmute.edu.vn',  44)
) AS v(email, h)
JOIN users u ON u.email = v.email
WHERE NOT EXISTS (
  SELECT 1 FROM friendships f
  WHERE (f.requester_id = @me AND f.receiver_id = u.user_id)
     OR (f.requester_id = u.user_id AND f.receiver_id = @me));

/* 2c. Các bạn mới kết bạn chéo với nhau cho mạng lưới đỡ trống */
INSERT INTO friendships (requester_id, receiver_id, status, created_at)
SELECT a.user_id, b.user_id, 'accepted', DATEADD(DAY, -20, SYSDATETIME())
FROM (VALUES
  ('khanhlinh@student.hcmute.edu.vn', 'ducanh@student.hcmute.edu.vn'),
  ('khanhlinh@student.hcmute.edu.vn', 'nhatminh@student.hcmute.edu.vn'),
  ('ducanh@student.hcmute.edu.vn',    'anhtuan@student.hcmute.edu.vn'),
  ('giahuy@student.hcmute.edu.vn',    'huuthang@student.hcmute.edu.vn'),
  ('maiphuong@student.hcmute.edu.vn', 'tuyetnhi@student.hcmute.edu.vn'),
  ('haiyen@student.hcmute.edu.vn',    'minhquan@student.hcmute.edu.vn'),
  ('diemquynh@student.hcmute.edu.vn', 'thanhtruc@student.hcmute.edu.vn')
) AS v(ea, eb)
JOIN users a ON a.email = v.ea
JOIN users b ON b.email = v.eb
WHERE NOT EXISTS (
  SELECT 1 FROM friendships f
  WHERE (f.requester_id = a.user_id AND f.receiver_id = b.user_id)
     OR (f.requester_id = b.user_id AND f.receiver_id = a.user_id));
GO

DECLARE @n2 INT; SELECT @n2 = COUNT(*) FROM friendships;
PRINT N'--> Tổng số quan hệ bạn bè: ' + CAST(@n2 AS NVARCHAR(20));
GO

/* ============================================================================
   3. BÀI VIẾT
   hours_ago quyết định thứ tự trên Bảng tin (nhỏ = mới hơn).
   ============================================================================ */
INSERT INTO posts (user_id, content, image_path, visibility, media_type, video_duration_sec, created_at)
SELECT u.user_id, v.content, v.image_path, 'public', v.media_type, v.dur,
       DATEADD(HOUR, -v.hours_ago, SYSDATETIME())
FROM (VALUES
  -- ===== Bài viết thường =====
  ('khanhlinh@student.hcmute.edu.vn',
   N'Vừa hoàn thành giao diện trang chủ cho đồ án môn Lập trình Web. Lần đầu tự tay làm responsive mà không copy template, mừng muốn khóc! #WebProgramming #Frontend',
   'study_setup.jpg', NULL, 0, 2),

  ('ducanh@student.hcmute.edu.vn',
   N'Mẹo nhỏ cho các bạn học Java: đừng học thuộc cú pháp, hãy hiểu vì sao người ta thiết kế như vậy. Mình mất 2 năm mới ngộ ra điều này. #Java #HocTap',
   NULL, NULL, 0, 4),

  ('anhtuan@student.hcmute.edu.vn',
   N'Ngày đầu đi thực tập tại công ty fintech. Được anh mentor giao task nhỏ mà hồi hộp như thi cuối kỳ. Cố lên nào!',
   'intern_last_day.jpg', NULL, 0, 6),

  ('nhatminh@student.hcmute.edu.vn',
   N'Có bạn nào đang học React không cho mình join team với. Mình đang làm một app quản lý chi tiêu cho sinh viên, cần thêm người cùng làm cho vui. #React #TimTeam',
   NULL, NULL, 0, 9),

  ('tuyetnhi@student.hcmute.edu.vn',
   N'Lịch học nhóm IELTS Speaking tuần này: thứ 3 và thứ 6, 18h tại thư viện tầng 3. Bạn nào muốn tham gia thì nhắn mình nhé, hoàn toàn miễn phí!',
   NULL, NULL, 0, 12),

  ('maiphuong@student.hcmute.edu.vn',
   N'Săn được học bổng trao đổi ngắn hạn 2 tuần tại Singapore. Kinh nghiệm: nộp sớm, viết luận thật, đừng cố make up câu chuyện. #HocBong #KinhTe',
   'team_photo.jpg', NULL, 0, 16),

  ('giahuy@student.hcmute.edu.vn',
   N'Mạch cảm biến nhiệt độ của nhóm mình chạy ổn định sau 3 lần cháy linh kiện. Ai làm phần cứng chắc hiểu cảm giác này. #IoT #DienTu',
   'iot_project.jpg', NULL, 0, 20),

  ('haiyen@student.hcmute.edu.vn',
   N'Bản vẽ mặt bằng cuối cùng cũng xong sau 3 đêm thức trắng. AutoCAD ơi là AutoCAD. #XayDung #DoAn',
   NULL, NULL, 0, 24),

  ('khanhlinh@student.hcmute.edu.vn',
   N'Quán cà phê mới mở gần cổng sau: yên tĩnh, ổ cắm nhiều, nước uống 25k. Rất hợp để ngồi làm đồ án cả buổi chiều. #CaPhe #HCMUTE',
   'cafe_review.jpg', NULL, 0, 30),

  ('huuthang@student.hcmute.edu.vn',
   N'Chia sẻ bộ tài liệu ôn thi Vi xử lý mình tổng hợp suốt học kỳ. Link Drive để dưới bình luận, các bạn cứ lấy dùng thoải mái nha. #TaiLieu #ViXuLy',
   'tailieu_cover.jpg', NULL, 0, 34),

  ('trongnghia@student.hcmute.edu.vn',
   N'Xưởng cơ khí hôm nay đông kinh khủng, chờ máy tiện gần 2 tiếng. Nhưng mà thành phẩm ra đẹp nên cũng đáng. #CoKhi',
   NULL, NULL, 0, 40),

  ('minhquan@student.hcmute.edu.vn',
   N'Cuối tuần theo mấy anh khóa trên ra gara học tháo lắp động cơ. Học ở xưởng một buổi bằng đọc sách cả tuần thật sự. #OTo',
   'robot_demo.jpg', NULL, 0, 46),

  ('baongoc@student.hcmute.edu.vn',
   N'Bộ sưu tập đồ án tốt nghiệp của mình lấy cảm hứng từ áo dài truyền thống. Đang phác thảo mẫu thứ 12 rồi mà vẫn chưa ưng. #ThoiTrang #DoAnCuoiKy',
   NULL, NULL, 0, 52),

  ('thanhtruc@student.hcmute.edu.vn',
   N'CLB Sách tuần này đọc chung cuốn "Nhà giả kim". Buổi thảo luận 19h thứ 5 tại phòng A3-204, mọi người tới đông nha!',
   NULL, NULL, 0, 58),

  ('diemquynh@student.hcmute.edu.vn',
   N'Vừa đi tour thực tế ở Vũng Tàu về. Ngành Du lịch cái hay là bài tập nhiều khi là... đi chơi rồi viết báo cáo. #DuLich',
   'cover_hcmute.jpg', NULL, 0, 66),

  ('anhtuan@student.hcmute.edu.vn',
   N'Hôm nay được review code lần đầu. 27 comment. Mà anh mentor nói vậy là ít so với người mới. Về đọc lại Clean Code đây. #ThucTap',
   NULL, NULL, 0, 72),

  ('ducanh@student.hcmute.edu.vn',
   N'Docker Compose thật sự cứu mạng khi làm đồ án nhóm. Không còn cảnh "máy tao chạy được mà máy mày lỗi" nữa. #Docker #DevOps',
   NULL, NULL, 0, 80),

  ('nhatminh@student.hcmute.edu.vn',
   N'Góc học tập mới setup xong. Bàn 1m2, đèn vàng, một chậu sen đá. Ngồi học tự dưng thấy siêng hơn hẳn. #StudySetup',
   'study_setup.jpg', NULL, 0, 90),

  ('maiphuong@student.hcmute.edu.vn',
   N'Kinh nghiệm thuyết trình mà mình rút ra sau 4 học kỳ: chuẩn bị kỹ phần mở đầu, 30 giây đầu quyết định cả bài. #KyNangMem',
   NULL, NULL, 0, 100),

  ('tuyetnhi@student.hcmute.edu.vn',
   N'Chúc mừng các bạn khóa 2022 vừa hoàn thành kỳ thi giữa kỳ. Nghỉ ngơi một chút rồi chiến tiếp nhé!',
   NULL, NULL, 0, 112),

  ('giahuy@student.hcmute.edu.vn',
   N'Team mình vừa nộp báo cáo đồ án IoT lúc 23h58, sát nút deadline 2 phút. Cảm giác vừa mệt vừa sung sướng.',
   'team_photo.jpg', NULL, 0, 126),

  ('haiyen@student.hcmute.edu.vn',
   N'Ai có tài liệu môn Sức bền vật liệu cho mình xin với. Đổi lại mình có full slide môn Cơ học kết cấu nha. #TaiLieu',
   NULL, NULL, 0, 140),

  -- ===== Video (hiện ở trang Video) =====
  ('giahuy@student.hcmute.edu.vn',
   N'Vlog: một ngày làm đồ án ở phòng Lab Điện tử — từ 7h sáng tới 10h tối',
   'iot_project.jpg', 'VIDEO', 754, 5),

  ('khanhlinh@student.hcmute.edu.vn',
   N'Hướng dẫn dựng giao diện trang đăng nhập bằng HTML + CSS thuần trong 15 phút',
   'study_setup.jpg', 'VIDEO', 918, 14),

  ('minhquan@student.hcmute.edu.vn',
   N'Demo tháo lắp động cơ 4 kỳ — bài thực hành môn Công nghệ Ô tô',
   'robot_demo.jpg', 'VIDEO', 1265, 28),

  ('ducanh@student.hcmute.edu.vn',
   N'Chia sẻ: cách mình chuẩn bị cho vòng phỏng vấn thực tập Java Backend',
   'intern_last_day.jpg', 'VIDEO', 1520, 44),

  ('diemquynh@student.hcmute.edu.vn',
   N'Tour thực tế Vũng Tàu cùng lớp Du lịch K21 — bản đầy đủ',
   'cover_hcmute.jpg', 'VIDEO', 2043, 70),

  ('thanhtruc@student.hcmute.edu.vn',
   N'Talkshow CLB Sách: đọc sách thế nào để không quên sau một tuần',
   'cafe_review.jpg', 'VIDEO', 1687, 96)
) AS v(email, content, image_path, media_type, dur, hours_ago)
JOIN users u ON u.email = v.email
WHERE NOT EXISTS (SELECT 1 FROM posts p WHERE p.content = v.content);
GO

DECLARE @n3 INT; SELECT @n3 = COUNT(*) FROM posts;
PRINT N'--> Tổng số bài viết: ' + CAST(@n3 AS NVARCHAR(20));
GO

/* ============================================================================
   4. LƯỢT THÍCH
   Phân bố theo công thức số học cho đều và luôn cho ra cùng kết quả.
   ============================================================================ */
INSERT INTO likes (post_id, user_id, created_at)
SELECT p.post_id, u.user_id, DATEADD(MINUTE, -((p.post_id * 13 + u.user_id * 7) % 4000), SYSDATETIME())
FROM posts p
CROSS JOIN users u
WHERE u.user_id <> p.user_id
  AND ((p.post_id * 7 + u.user_id * 3) % 5) < 2          -- ~40% số cặp
  AND NOT EXISTS (SELECT 1 FROM likes l WHERE l.post_id = p.post_id AND l.user_id = u.user_id);
GO

/* ============================================================================
   5. BÌNH LUẬN
   Lấy từ một kho câu bình luận, gán vào bài theo công thức số học.
   ============================================================================ */
INSERT INTO comments (post_id, user_id, content, created_at)
SELECT p.post_id, u.user_id, t.txt,
       DATEADD(MINUTE, -((p.post_id * 11 + u.user_id * 5) % 2800), SYSDATETIME())
FROM posts p
CROSS JOIN users u
CROSS APPLY (
  SELECT txt FROM (VALUES
    (0, N'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!'),
    (1, N'Cho mình xin link tài liệu với được không?'),
    (2, N'Công nhận, mình cũng đang gặp đúng vấn đề này.'),
    (3, N'Chúc mừng bạn nhé, xứng đáng mà!'),
    (4, N'Nhìn chất lượng thật sự, học hỏi nhiều.'),
    (5, N'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.'),
    (6, N'Bạn làm bằng công cụ gì vậy? Chỉ mình với.'),
    (7, N'Quá đỉnh luôn, cố lên nha bạn!'),
    (8, N'Cuối kỳ này chắc cả trường đều bận như này.'),
    (9, N'Mình cũng muốn tham gia, inbox cho mình nhé!')
  ) AS pool(k, txt)
  WHERE pool.k = (p.post_id * 3 + u.user_id * 7) % 10
) AS t
WHERE u.user_id <> p.user_id
  AND ((p.post_id * 5 + u.user_id * 11) % 7) < 2          -- ~28% số cặp
  AND NOT EXISTS (
    SELECT 1 FROM comments c WHERE c.post_id = p.post_id AND c.user_id = u.user_id);
GO

/* ---- Đồng bộ lại bộ đếm trên bảng posts cho khớp dữ liệu thật ---- */
UPDATE p
SET like_count    = (SELECT COUNT(*) FROM likes    l WHERE l.post_id = p.post_id),
    comment_count = (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.post_id),
    share_count   = (SELECT COUNT(*) FROM posts s   WHERE s.shared_post_id = p.post_id)
FROM posts p;
GO

DECLARE @n4 INT, @n5 INT;
SELECT @n4 = COUNT(*) FROM likes;
SELECT @n5 = COUNT(*) FROM comments;
PRINT N'--> Lượt thích: ' + CAST(@n4 AS NVARCHAR(20)) + N' | Bình luận: ' + CAST(@n5 AS NVARCHAR(20));
GO

/* ============================================================================
   6. NHÓM
   ============================================================================ */
INSERT INTO groups_tbl (name, description, category, cover_icon, member_count)
SELECT v.name, v.descr, v.cat, v.icon, v.cnt
FROM (VALUES
  (N'Lập trình Web HCMUTE',      N'Nơi trao đổi HTML, CSS, JavaScript và các đồ án môn Lập trình Web.', 'STUDY', N'💻', 412),
  (N'CLB Sách & Cà phê',          N'Mỗi tuần một cuốn sách, mỗi tháng một buổi offline.',               'CLUB',  N'📚', 187),
  (N'Góc Đồ án Cuối kỳ',          N'Hỏi đáp, tìm đồng đội và chia sẻ tài liệu cho đồ án tốt nghiệp.',   'STUDY', N'🎓', 934),
  (N'CLB Nhiếp ảnh UTE',          N'Chia sẻ ảnh đẹp quanh trường và các buổi chụp chung cuối tuần.',     'CLUB',  N'📷', 256),
  (N'Việc làm & Thực tập IT',     N'Tin tuyển dụng thực tập, fresher dành riêng cho sinh viên HCMUTE.',  'STUDY', N'💼', 1508),
  (N'CLB Bóng rổ HCMUTE',         N'Tập luyện thứ 3 - 5 - 7 tại sân thể thao khu A.',                    'CLUB',  N'🏀', 143)
) AS v(name, descr, cat, icon, cnt)
WHERE NOT EXISTS (SELECT 1 FROM groups_tbl g WHERE g.name = v.name);
GO

/* Minh Hà tham gia một vài nhóm */
DECLARE @me2 INT;
SELECT @me2 = user_id FROM users WHERE email = 'minhha@student.hcmute.edu.vn';

INSERT INTO group_members (group_id, user_id, role, joined_at)
SELECT g.group_id, @me2, 'MEMBER', DATEADD(DAY, -15, SYSDATETIME())
FROM groups_tbl g
WHERE g.name IN (N'Lập trình Web HCMUTE', N'Góc Đồ án Cuối kỳ', N'Việc làm & Thực tập IT')
  AND NOT EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = g.group_id AND m.user_id = @me2);

/* Các bạn khác cũng tham gia để nhóm không trống */
INSERT INTO group_members (group_id, user_id, role, joined_at)
SELECT g.group_id, u.user_id, 'MEMBER', DATEADD(DAY, -10, SYSDATETIME())
FROM groups_tbl g
CROSS JOIN users u
WHERE ((g.group_id * 5 + u.user_id * 3) % 4) = 0
  AND NOT EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = g.group_id AND m.user_id = u.user_id);
GO

/* ============================================================================
   7. BÀI VIẾT ĐÃ LƯU (của Minh Hà)
   ============================================================================ */
DECLARE @me3 INT;
SELECT @me3 = user_id FROM users WHERE email = 'minhha@student.hcmute.edu.vn';

DECLARE @daluu INT;
SELECT @daluu = COUNT(*) FROM saved_posts WHERE user_id = @me3;

/* Chỉ bổ sung cho đủ 8 bài, để chạy lại script không cộng dồn thêm */
IF @daluu < 8
BEGIN
    INSERT INTO saved_posts (user_id, post_id, saved_at)
    SELECT TOP (8 - @daluu) @me3, p.post_id, DATEADD(HOUR, -(p.post_id % 60), SYSDATETIME())
    FROM posts p
    WHERE p.user_id <> @me3
      AND NOT EXISTS (SELECT 1 FROM saved_posts s WHERE s.user_id = @me3 AND s.post_id = p.post_id)
    ORDER BY p.created_at DESC;
END
GO

/* ============================================================================
   8. HỘI THOẠI & TIN NHẮN
   Ràng buộc chk_user_order yêu cầu user_a_id < user_b_id.
   ============================================================================ */
DECLARE @me4 INT;
SELECT @me4 = user_id FROM users WHERE email = 'minhha@student.hcmute.edu.vn';

INSERT INTO conversations (user_a_id, user_b_id, last_message_at)
SELECT CASE WHEN @me4 < u.user_id THEN @me4 ELSE u.user_id END,
       CASE WHEN @me4 < u.user_id THEN u.user_id ELSE @me4 END,
       DATEADD(MINUTE, -v.mins, SYSDATETIME())
FROM (VALUES
  ('khanhlinh@student.hcmute.edu.vn', 12),
  ('ducanh@student.hcmute.edu.vn',    95),
  ('anhtuan@student.hcmute.edu.vn',   240),
  ('tuyetnhi@student.hcmute.edu.vn',  760)
) AS v(email, mins)
JOIN users u ON u.email = v.email
WHERE NOT EXISTS (
  SELECT 1 FROM conversations c
  WHERE c.user_a_id = CASE WHEN @me4 < u.user_id THEN @me4 ELSE u.user_id END
    AND c.user_b_id = CASE WHEN @me4 < u.user_id THEN u.user_id ELSE @me4 END);
GO

DECLARE @me5 INT;
SELECT @me5 = user_id FROM users WHERE email = 'minhha@student.hcmute.edu.vn';

INSERT INTO chat_messages (conversation_id, sender_id, content, is_read, sent_at)
SELECT c.conversation_id,
       CASE WHEN v.from_me = 1 THEN @me5 ELSE u.user_id END,
       v.content,
       CASE WHEN v.from_me = 1 THEN 1 ELSE v.is_read END,
       DATEADD(MINUTE, -v.mins, SYSDATETIME())
FROM (VALUES
  ('khanhlinh@student.hcmute.edu.vn', 0, N'Hà ơi, phần giao diện trang chủ bạn làm xong chưa?', 1, 60),
  ('khanhlinh@student.hcmute.edu.vn', 1, N'Rồi nha, mình vừa push lên nhánh feature/home tối qua.', 1, 52),
  ('khanhlinh@student.hcmute.edu.vn', 0, N'Tuyệt vời! Để mình pull về xem rồi góp ý thêm nhé.', 1, 48),
  ('khanhlinh@student.hcmute.edu.vn', 1, N'Ok bạn, phần responsive mình chưa kỹ lắm, xem giúp mình với.', 1, 40),
  ('khanhlinh@student.hcmute.edu.vn', 0, N'Mình vừa xem rồi, ổn áp lắm. Chỉ cần chỉnh lại cái sidebar ở mobile thôi.', 0, 12),

  ('ducanh@student.hcmute.edu.vn', 1, N'Anh ơi, cho em hỏi Docker Compose với MySQL nên cấu hình sao ạ?', 1, 180),
  ('ducanh@student.hcmute.edu.vn', 0, N'Em nhớ mount volume cho thư mục data, không là restart mất sạch database đó.', 1, 150),
  ('ducanh@student.hcmute.edu.vn', 1, N'Dạ em hiểu rồi, cảm ơn anh nhiều!', 1, 140),
  ('ducanh@student.hcmute.edu.vn', 0, N'Có gì cứ hỏi nhé, anh cũng từng mất 2 ngày vì cái lỗi đó.', 0, 95),

  ('anhtuan@student.hcmute.edu.vn', 0, N'Bên công ty mình đang tuyển thực tập sinh, Hà có muốn thử không?', 1, 400),
  ('anhtuan@student.hcmute.edu.vn', 1, N'Có chứ! Bạn gửi mình JD với nha.', 1, 380),
  ('anhtuan@student.hcmute.edu.vn', 0, N'Ok để mình xin anh HR rồi gửi qua cho bạn trong hôm nay.', 0, 240),

  ('tuyetnhi@student.hcmute.edu.vn', 0, N'Buổi Speaking thứ 6 này Hà tham gia được không?', 1, 900),
  ('tuyetnhi@student.hcmute.edu.vn', 1, N'Được nha, mình rảnh từ 18h. Hẹn ở thư viện tầng 3 nhé.', 1, 800),
  ('tuyetnhi@student.hcmute.edu.vn', 0, N'Chốt vậy nha, hẹn gặp bạn!', 1, 760)
) AS v(email, from_me, content, is_read, mins)
JOIN users u ON u.email = v.email
JOIN conversations c
  ON c.user_a_id = CASE WHEN @me5 < u.user_id THEN @me5 ELSE u.user_id END
 AND c.user_b_id = CASE WHEN @me5 < u.user_id THEN u.user_id ELSE @me5 END
WHERE NOT EXISTS (
  SELECT 1 FROM chat_messages m
  WHERE m.conversation_id = c.conversation_id AND m.content = v.content);
GO

/* Cập nhật mốc tin nhắn cuối cho danh sách hội thoại sắp xếp đúng */
UPDATE c
SET last_message_at = (SELECT MAX(sent_at) FROM chat_messages m WHERE m.conversation_id = c.conversation_id)
FROM conversations c;
GO

/* ============================================================================
   9. THÔNG BÁO
   ============================================================================ */
DECLARE @me6 INT;
SELECT @me6 = user_id FROM users WHERE email = 'minhha@student.hcmute.edu.vn';

INSERT INTO notifications (user_id, actor_id, type, content, target_url, is_read, created_at)
SELECT @me6, u.user_id, v.type, v.content, v.url, v.is_read, DATEADD(MINUTE, -v.mins, SYSDATETIME())
FROM (VALUES
  ('trongnghia@student.hcmute.edu.vn', 'FRIEND_REQUEST', N'đã gửi cho bạn một lời mời kết bạn.', '/friends', 0, 360),
  ('baongoc@student.hcmute.edu.vn',    'FRIEND_REQUEST', N'đã gửi cho bạn một lời mời kết bạn.', '/friends', 0, 1200),
  ('khanhlinh@student.hcmute.edu.vn',  'LIKE',           N'đã thích bài viết của bạn.',          '/feed',    0, 45),
  ('ducanh@student.hcmute.edu.vn',     'COMMENT',        N'đã bình luận vào bài viết của bạn.',  '/feed',    1, 300),
  ('anhtuan@student.hcmute.edu.vn',    'LIKE',           N'đã thích bài viết của bạn.',          '/feed',    1, 720)
) AS v(email, type, content, url, is_read, mins)
JOIN users u ON u.email = v.email
WHERE NOT EXISTS (
  SELECT 1 FROM notifications n
  WHERE n.user_id = @me6 AND n.actor_id = u.user_id AND n.type = v.type AND n.content = v.content);
GO

/* ============================================================================
   TỔNG KẾT
   ============================================================================ */
SELECT N'Người dùng'   AS bang, COUNT(*) AS so_dong FROM users
UNION ALL SELECT N'Bài viết',      COUNT(*) FROM posts
UNION ALL SELECT N'Video',         COUNT(*) FROM posts WHERE media_type = 'VIDEO'
UNION ALL SELECT N'Bình luận',     COUNT(*) FROM comments
UNION ALL SELECT N'Lượt thích',    COUNT(*) FROM likes
UNION ALL SELECT N'Bạn bè',        COUNT(*) FROM friendships
UNION ALL SELECT N'Nhóm',          COUNT(*) FROM groups_tbl
UNION ALL SELECT N'Thành viên nhóm', COUNT(*) FROM group_members
UNION ALL SELECT N'Bài đã lưu',    COUNT(*) FROM saved_posts
UNION ALL SELECT N'Hội thoại',     COUNT(*) FROM conversations
UNION ALL SELECT N'Tin nhắn',      COUNT(*) FROM chat_messages
UNION ALL SELECT N'Thông báo',     COUNT(*) FROM notifications;
GO


PRINT '------------------------------------------------';
PRINT 'Executing 005_seed_test_accounts.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — 4 tài khoản test cố định (plan mục 1.3)
-- Cả nhóm test trên cùng bộ tài khoản để dễ tái hiện lỗi cho nhau.
-- Mật khẩu xem trong db/README.md. Hash BCrypt dùng chung với 002_seed_data.sql.
-- Chạy lại nhiều lần vẫn an toàn (chỉ INSERT khi email chưa có).
-- ============================================================
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#test_users') IS NOT NULL DROP TABLE #test_users;
SELECT v.first_name, v.last_name, v.email, v.role, v.bio, v.student_id
INTO #test_users
FROM (VALUES
    (N'Test', N'A',     'a@test.com',     'USER',  N'Tài khoản test A',                N'TEST-A'),
    (N'Test', N'B',     'b@test.com',     'USER',  N'Tài khoản test B',                N'TEST-B'),
    (N'Test', N'C',     'c@test.com',     'USER',  N'Tài khoản test C',                N'TEST-C'),
    (N'Test', N'Admin', 'admin@test.com', 'ADMIN', N'Tài khoản quản trị dùng để test', N'TEST-ADMIN')
) AS v(first_name, last_name, email, role, bio, student_id)
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);

DECLARE @Pass NVARCHAR(255) = N'$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW';

IF COL_LENGTH('users', 'student_id') IS NULL
    INSERT INTO users (first_name, last_name, email, password_hash, role, bio, location)
    SELECT first_name, last_name, email, @Pass, role, bio, N'HCMUTE' FROM #test_users;
ELSE
    -- Database tạo từ schema cũ còn cột student_id (UNIQUE) → phải điền giá trị riêng
    EXEC sp_executesql N'
        INSERT INTO users (first_name, last_name, email, password_hash, role, bio, location, student_id)
        SELECT first_name, last_name, email, @p, role, bio, N''HCMUTE'', student_id FROM #test_users;',
        N'@p NVARCHAR(255)', @p = @Pass;
GO

SELECT user_id, email, role FROM users WHERE email LIKE '%@test.com' ORDER BY user_id;
GO


PRINT '------------------------------------------------';
PRINT 'Executing 010_migration_share_hashtag.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration: Chia sẻ kèm bình luận (Quote Share) + Hashtag
-- Chạy file này trong SSMS trên database ĐÃ CÓ DỮ LIỆU (không xoá dữ liệu cũ).
-- Chạy lại nhiều lần vẫn an toàn (idempotent).
--
-- Hashtag KHÔNG cần bảng riêng: thẻ #tag được tách bằng regex từ posts.content
-- và lọc bằng LIKE '%#tag%' (xem PostDAOImpl.getPostsByHashtag).
-- ============================================================
-- ------------------------------------------------------------
-- 1. posts.shared_post_id — bài chia sẻ trỏ tới bài GỐC
--    NULL  = bài viết thường
--    != NULL = bài chia sẻ; content là bình luận kèm theo (có thể rỗng)
--
--    Cố ý KHÔNG đặt FOREIGN KEY: khi bài gốc bị xoá, bài chia sẻ vẫn giữ
--    shared_post_id để giao diện hiện "Nội dung không còn khả dụng"
--    (giống Facebook). SQL Server cũng không cho ON DELETE SET NULL trên
--    khoá ngoại tự tham chiếu.
-- ------------------------------------------------------------
IF COL_LENGTH('posts', 'shared_post_id') IS NULL
BEGIN
    ALTER TABLE posts ADD shared_post_id INT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'ix_posts_shared_post_id' AND object_id = OBJECT_ID('posts'))
BEGIN
    CREATE INDEX ix_posts_shared_post_id ON posts(shared_post_id);
END
GO

-- ------------------------------------------------------------
-- 2. Đồng bộ share_count = số bài chia sẻ THẬT trỏ tới bài đó
--    (dữ liệu mẫu cũ đặt share_count giả theo công thức post_id * 3 % 9)
-- ------------------------------------------------------------
UPDATE p
SET share_count = (SELECT COUNT(*) FROM posts s WHERE s.shared_post_id = p.post_id)
FROM posts p;
GO

-- ------------------------------------------------------------
-- 3. Cho phép loại thông báo 'SHARE'
--    Ràng buộc CHECK cũ không đặt tên → tìm tên hệ thống sinh ra rồi thay mới.
-- ------------------------------------------------------------
DECLARE @ck SYSNAME;
SELECT @ck = cc.name
FROM sys.check_constraints cc
JOIN sys.columns c ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
WHERE cc.parent_object_id = OBJECT_ID('notifications') AND c.name = 'type';

IF @ck IS NOT NULL AND @ck <> 'chk_notifications_type'
BEGIN
    EXEC('ALTER TABLE notifications DROP CONSTRAINT ' + @ck);
END

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_notifications_type')
BEGIN
    ALTER TABLE notifications ADD CONSTRAINT chk_notifications_type
        CHECK (type IN ('LIKE', 'COMMENT', 'SHARE', 'FRIEND_REQUEST', 'FRIEND_ACCEPT', 'GROUP_INVITE', 'SYSTEM'));
END
GO

-- Kiểm tra nhanh
SELECT COL_LENGTH('posts', 'shared_post_id')                         AS shared_post_id_bytes,
       (SELECT COUNT(*) FROM posts WHERE shared_post_id IS NOT NULL) AS so_bai_chia_se;
GO


PRINT '------------------------------------------------';
PRINT 'Executing 020_migration_post_moderation.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 020: kiểm duyệt bài viết + trạng thái tài khoản
-- (plan mục 2.2, 6.2 — Phụ lục A.1). Chạy lại nhiều lần vẫn an toàn.
--
-- posts.group_id            : bài thuộc nhóm nào (NULL = bài cá nhân). FK thêm ở 030.
-- posts.moderation_status   : ACTIVE | HIDDEN | DELETED — CHỈ admin đổi
-- posts.is_hidden_by_owner  : 0/1 — CHỈ chủ bài đổi
--   Hai cờ tách rời để hành động của admin và của chủ bài không đè lên nhau.
-- users.status              : ACTIVE | LOCKED (+ locked_reason)
-- ============================================================
IF COL_LENGTH('posts', 'group_id') IS NULL
    ALTER TABLE posts ADD group_id INT NULL;
IF COL_LENGTH('posts', 'moderation_status') IS NULL
    ALTER TABLE posts ADD moderation_status NVARCHAR(10) NOT NULL
        CONSTRAINT DF_posts_moderation DEFAULT 'ACTIVE';
IF COL_LENGTH('posts', 'is_hidden_by_owner') IS NULL
    ALTER TABLE posts ADD is_hidden_by_owner BIT NOT NULL
        CONSTRAINT DF_posts_hidden DEFAULT 0;
GO

IF COL_LENGTH('users', 'status') IS NULL
    ALTER TABLE users ADD status NVARCHAR(10) NOT NULL
        CONSTRAINT DF_users_status DEFAULT 'ACTIVE';
IF COL_LENGTH('users', 'locked_reason') IS NULL
    ALTER TABLE users ADD locked_reason NVARCHAR(255) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_posts_moderation')
    ALTER TABLE posts ADD CONSTRAINT CK_posts_moderation
        CHECK (moderation_status IN ('ACTIVE', 'HIDDEN', 'DELETED'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_users_status')
    ALTER TABLE users ADD CONSTRAINT CK_users_status
        CHECK (status IN ('ACTIVE', 'LOCKED'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_posts_group_id' AND object_id = OBJECT_ID('posts'))
    CREATE INDEX IX_posts_group_id ON posts(group_id);
GO

-- Kiểm tra nhanh
SELECT COL_LENGTH('posts', 'group_id')           AS posts_group_id,
       COL_LENGTH('posts', 'moderation_status')  AS posts_moderation_status,
       COL_LENGTH('posts', 'is_hidden_by_owner') AS posts_is_hidden_by_owner,
       COL_LENGTH('users', 'status')             AS users_status,
       COL_LENGTH('users', 'locked_reason')      AS users_locked_reason;
GO


PRINT '------------------------------------------------';
PRINT 'Executing 030_migration_groups.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 030: Nhóm có chủ nhóm (plan mục 4.2 — Phụ lục A.2)
-- Chạy lại nhiều lần vẫn an toàn.
--
-- groups_tbl.privacy      : PUBLIC | PRIVATE (nhóm kín phải được chủ nhóm duyệt)
-- groups_tbl.cover_image  : ảnh bìa nhóm (uploads/groups/...)
-- group_members.status    : ACTIVE | PENDING (chờ duyệt) | BANNED (bị xóa khỏi nhóm, không vào lại được)
-- group_members.role      : OWNER | ADMIN | MEMBER — chủ nhóm xác định DUY NHẤT bằng role = 'OWNER'
--                           (không thêm cột owner_id để khỏi có hai nơi lệch nhau)
-- posts.group_id          : khóa ngoại tới groups_tbl
-- ============================================================
-- Filtered index yêu cầu 2 SET này (SSMS bật sẵn, sqlcmd thì không)
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
-- ------------------------------------------------------------
-- 1. Cột mới
-- ------------------------------------------------------------
IF COL_LENGTH('groups_tbl', 'privacy') IS NULL
    ALTER TABLE groups_tbl ADD privacy NVARCHAR(10) NOT NULL
        CONSTRAINT DF_groups_privacy DEFAULT 'PUBLIC';
IF COL_LENGTH('groups_tbl', 'description') IS NULL
    ALTER TABLE groups_tbl ADD description NVARCHAR(500) NULL;
IF COL_LENGTH('groups_tbl', 'cover_image') IS NULL
    ALTER TABLE groups_tbl ADD cover_image NVARCHAR(255) NULL;
IF COL_LENGTH('group_members', 'status') IS NULL
    ALTER TABLE group_members ADD status NVARCHAR(10) NOT NULL
        CONSTRAINT DF_gm_status DEFAULT 'ACTIVE';
IF COL_LENGTH('group_members', 'joined_at') IS NULL
    ALTER TABLE group_members ADD joined_at DATETIME2 NOT NULL
        CONSTRAINT DF_gm_joined DEFAULT SYSDATETIME();
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_groups_privacy')
    ALTER TABLE groups_tbl ADD CONSTRAINT CK_groups_privacy CHECK (privacy IN ('PUBLIC', 'PRIVATE'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_gm_status')
    ALTER TABLE group_members ADD CONSTRAINT CK_gm_status CHECK (status IN ('ACTIVE', 'PENDING', 'BANNED'));
GO

-- ------------------------------------------------------------
-- 2. Cho phép role = 'OWNER' (CHECK cũ chỉ có MEMBER/ADMIN, không đặt tên → tìm tên rồi thay)
-- ------------------------------------------------------------
DECLARE @ck SYSNAME;
SELECT @ck = cc.name
FROM sys.check_constraints cc
JOIN sys.columns c ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
WHERE cc.parent_object_id = OBJECT_ID('group_members') AND c.name = 'role';
IF @ck IS NOT NULL AND @ck <> 'CK_gm_role'
    EXEC('ALTER TABLE group_members DROP CONSTRAINT ' + @ck);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_gm_role')
    ALTER TABLE group_members ADD CONSTRAINT CK_gm_role CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER'));
GO

-- ------------------------------------------------------------
-- 3. Backfill: mỗi nhóm cũ phải có đúng một OWNER
--    a) ADMIN có user_id nhỏ nhất của nhóm → OWNER
--    b) Nhóm không có ADMIN → thành viên vào sớm nhất → OWNER
-- ------------------------------------------------------------
UPDATE gm SET role = 'OWNER'
FROM group_members gm
WHERE gm.role = 'ADMIN'
  AND gm.user_id = (SELECT MIN(x.user_id) FROM group_members x
                    WHERE x.group_id = gm.group_id AND x.role = 'ADMIN')
  AND NOT EXISTS (SELECT 1 FROM group_members o WHERE o.group_id = gm.group_id AND o.role = 'OWNER');

UPDATE gm SET role = 'OWNER'
FROM group_members gm
WHERE gm.user_id = (SELECT TOP 1 x.user_id FROM group_members x
                    WHERE x.group_id = gm.group_id AND x.status = 'ACTIVE'
                    ORDER BY x.joined_at, x.user_id)
  AND NOT EXISTS (SELECT 1 FROM group_members o WHERE o.group_id = gm.group_id AND o.role = 'OWNER');
GO

-- member_count cũ là số giả của dữ liệu mẫu → đồng bộ theo số thành viên ACTIVE thật
UPDATE g SET member_count = (SELECT COUNT(*) FROM group_members m
                             WHERE m.group_id = g.group_id AND m.status = 'ACTIVE')
FROM groups_tbl g;
GO

-- ------------------------------------------------------------
-- 4. Mỗi nhóm đúng một chủ + khóa ngoại bài viết → nhóm
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_group_one_owner')
    CREATE UNIQUE INDEX UX_group_one_owner ON group_members(group_id) WHERE role = 'OWNER';
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_posts_group')
    ALTER TABLE posts ADD CONSTRAINT FK_posts_group
        FOREIGN KEY (group_id) REFERENCES groups_tbl(group_id);
GO

-- ------------------------------------------------------------
-- 5. Loại thông báo mới cho nhóm
-- ------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_notifications_type')
    ALTER TABLE notifications DROP CONSTRAINT chk_notifications_type;
ALTER TABLE notifications ADD CONSTRAINT chk_notifications_type
    CHECK (type IN ('LIKE', 'COMMENT', 'SHARE', 'FRIEND_REQUEST', 'FRIEND_ACCEPT', 'GROUP_INVITE',
                    'GROUP_JOIN_REQUEST', 'GROUP_APPROVED', 'GROUP_POST', 'SYSTEM'));
GO

-- ------------------------------------------------------------
-- KIỂM TRA: phải trả về 0 dòng (nhóm nào còn thiếu chủ nhóm)
-- ------------------------------------------------------------
SELECT g.group_id AS nhom_thieu_chu FROM groups_tbl g
WHERE NOT EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = g.group_id AND m.role = 'OWNER');
GO


PRINT '------------------------------------------------';
PRINT 'Executing 040_migration_reports_admin.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 040: Báo cáo vi phạm + nhật ký quản trị (plan mục 6.2 — Phụ lục A.3)
-- Chạy lại nhiều lần vẫn an toàn.
--
-- reports    : người dùng báo cáo bài viết / bình luận / tài khoản. Mỗi người chỉ báo cáo
--              một đối tượng một lần (UNIQUE). Admin xử lý theo nhóm đối tượng ("5 người báo cáo").
-- admin_logs : ai làm gì lúc nào trong khu quản trị.
-- ============================================================
IF OBJECT_ID('reports', 'U') IS NULL
CREATE TABLE reports (
    report_id    INT IDENTITY(1,1) PRIMARY KEY,
    reporter_id  INT NOT NULL,
    target_type  NVARCHAR(10) NOT NULL,          -- POST | COMMENT | USER
    target_id    INT NOT NULL,
    reason       NVARCHAR(30) NOT NULL,
    detail       NVARCHAR(500) NULL,
    status       NVARCHAR(10) NOT NULL CONSTRAINT DF_reports_status DEFAULT 'PENDING',  -- PENDING | RESOLVED | DISMISSED
    handled_by   INT NULL,
    handled_at   DATETIME2 NULL,
    created_at   DATETIME2 NOT NULL CONSTRAINT DF_reports_created DEFAULT SYSDATETIME(),
    CONSTRAINT FK_reports_reporter FOREIGN KEY (reporter_id) REFERENCES users(user_id),
    CONSTRAINT FK_reports_handler  FOREIGN KEY (handled_by)  REFERENCES users(user_id),
    CONSTRAINT UQ_reports_once UNIQUE (reporter_id, target_type, target_id),
    CONSTRAINT CK_reports_target CHECK (target_type IN ('POST', 'COMMENT', 'USER')),
    CONSTRAINT CK_reports_status CHECK (status IN ('PENDING', 'RESOLVED', 'DISMISSED'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_reports_queue' AND object_id = OBJECT_ID('reports'))
    CREATE INDEX IX_reports_queue ON reports(status, target_type, target_id);
GO

IF OBJECT_ID('admin_logs', 'U') IS NULL
CREATE TABLE admin_logs (
    log_id       INT IDENTITY(1,1) PRIMARY KEY,
    admin_id     INT NOT NULL,
    action       NVARCHAR(40) NOT NULL,
    target_type  NVARCHAR(10) NULL,
    target_id    INT NULL,
    detail       NVARCHAR(500) NULL,
    created_at   DATETIME2 NOT NULL CONSTRAINT DF_adminlogs_created DEFAULT SYSDATETIME(),
    CONSTRAINT FK_adminlogs_admin FOREIGN KEY (admin_id) REFERENCES users(user_id)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_adminlogs_created' AND object_id = OBJECT_ID('admin_logs'))
    CREATE INDEX IX_adminlogs_created ON admin_logs(created_at DESC);
GO

-- Tạo admin đầu tiên (dữ liệu mẫu đã có admin@uterspace.edu.vn và admin@test.com):
-- UPDATE users SET role = 'ADMIN' WHERE email = '<email_của_bạn>';

SELECT OBJECT_ID('reports') AS reports_table, OBJECT_ID('admin_logs') AS admin_logs_table,
       (SELECT COUNT(*) FROM users WHERE role = 'ADMIN') AS so_admin;
GO


PRINT '------------------------------------------------';
PRINT 'Executing 050_migration_stories.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 050: Tin (Stories) — đăng ảnh hoặc video, tự hết hạn sau 24 giờ.
-- Chạy lại nhiều lần vẫn an toàn.
--
-- stories      : mỗi dòng là một tin (ảnh HOẶC video) của một người dùng.
--                expires_at = created_at + 24 giờ. Tin hết hạn không còn hiển thị;
--                AppContextListener dọn bản ghi + file định kỳ (StoryDAO.purgeExpired).
-- story_views  : ai đã xem tin nào, lúc nào → vòng tròn "đã xem" (xám) và danh sách người xem cho chủ tin.
--                Xóa tin thì xóa luôn lượt xem (ON DELETE CASCADE).
-- Ai được xem: chính chủ + bạn bè (friendships.status = 'accepted') — kiểm tra ở StoryDAO.
-- ============================================================
IF OBJECT_ID('stories', 'U') IS NULL
CREATE TABLE stories (
    story_id      INT IDENTITY(1,1) PRIMARY KEY,
    user_id       INT NOT NULL,
    media_path    NVARCHAR(500) NOT NULL,        -- uploads/stories/<uuid>.<ext>
    media_type    NVARCHAR(10)  NOT NULL,        -- IMAGE | VIDEO
    caption       NVARCHAR(200) NULL,
    duration_sec  INT NULL,                      -- thời lượng video (đọc ở trình duyệt), NULL với ảnh
    created_at    DATETIME2 NOT NULL CONSTRAINT DF_stories_created DEFAULT SYSDATETIME(),
    expires_at    DATETIME2 NOT NULL,
    CONSTRAINT FK_stories_user  FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT CK_stories_media CHECK (media_type IN ('IMAGE', 'VIDEO'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_stories_user_expires' AND object_id = OBJECT_ID('stories'))
    CREATE INDEX IX_stories_user_expires ON stories(user_id, expires_at);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_stories_expires' AND object_id = OBJECT_ID('stories'))
    CREATE INDEX IX_stories_expires ON stories(expires_at);
GO

IF OBJECT_ID('story_views', 'U') IS NULL
CREATE TABLE story_views (
    story_id   INT NOT NULL,
    viewer_id  INT NOT NULL,
    viewed_at  DATETIME2 NOT NULL CONSTRAINT DF_story_views_at DEFAULT SYSDATETIME(),
    CONSTRAINT PK_story_views PRIMARY KEY (story_id, viewer_id),
    CONSTRAINT FK_story_views_story  FOREIGN KEY (story_id)  REFERENCES stories(story_id) ON DELETE CASCADE,
    CONSTRAINT FK_story_views_viewer FOREIGN KEY (viewer_id) REFERENCES users(user_id)
);
GO

PRINT N'050: stories + story_views OK';
GO


PRINT '------------------------------------------------';
PRINT 'Executing 060_migration_social.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 060: Bạn bè · Tin nhắn · Thông báo (bản nâng cấp)
-- Chạy lại nhiều lần vẫn an toàn. BẮT BUỘC chạy với QUOTED_IDENTIFIER ON
-- (SSMS bật sẵn; sqlcmd thêm -I) vì có index trên cột tính toán và filtered index.
--
--  1. friendships        : MỖI CẶP NGƯỜI CHỈ MỘT DÒNG (A→B và B→A không thể cùng tồn tại) bằng
--                          2 cột tính toán user_lo/user_hi + UNIQUE INDEX; thêm accepted_at ("bạn bè từ").
--                          Từ chối / hủy lời mời / hủy kết bạn = XÓA dòng (bỏ trạng thái 'rejected').
--  2. user_blocks        : chặn người dùng.
--  3. users.last_active_at: lần hoạt động gần nhất (trạng thái online / "hoạt động x phút trước").
--  4. user_settings      : quyền riêng tư + tùy chọn thông báo theo nhóm chức năng (1 dòng / người, tạo khi lưu lần đầu).
--  5. notifications      : thêm loại MESSAGE, ACCOUNT; cột ref_key để gộp / gỡ thông báo theo đối tượng.
--  6. conversations      : hỗ trợ NHÓM CHAT (is_group, title); cặp 1-1 vẫn duy nhất (filtered unique index).
--  7. conversation_members: thành viên hội thoại + mốc đã nhận / đã xem / đã xóa lịch sử của từng người.
--  8. chat_messages      : client_id (chống gửi trùng khi gửi lại), reply, sửa, thu hồi, ghim, file đính kèm, tin hệ thống.
--  9. message_reactions  : thả cảm xúc (mỗi người 1 cảm xúc / tin).
-- 10. message_hidden     : "Xóa ở phía tôi".
-- ============================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
-- ------------------------------------------------------------
-- 1. FRIENDSHIPS
-- ------------------------------------------------------------
DELETE FROM friendships WHERE status = 'rejected';
GO
-- Dọn cặp trùng chiều ngược (nếu có): giữ dòng 'accepted', sau đó dòng cũ nhất
;WITH d AS (
    SELECT friendship_id,
           ROW_NUMBER() OVER (
               PARTITION BY CASE WHEN requester_id < receiver_id THEN requester_id ELSE receiver_id END,
                            CASE WHEN requester_id < receiver_id THEN receiver_id ELSE requester_id END
               ORDER BY CASE status WHEN 'accepted' THEN 0 ELSE 1 END, created_at, friendship_id) AS rn
    FROM friendships)
DELETE FROM d WHERE rn > 1;
GO
IF COL_LENGTH('friendships', 'user_lo') IS NULL
    ALTER TABLE friendships ADD
        user_lo AS (CASE WHEN requester_id < receiver_id THEN requester_id ELSE receiver_id END) PERSISTED,
        user_hi AS (CASE WHEN requester_id < receiver_id THEN receiver_id ELSE requester_id END) PERSISTED;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_friendships_pair' AND object_id = OBJECT_ID('friendships'))
    CREATE UNIQUE INDEX UX_friendships_pair ON friendships(user_lo, user_hi);
GO
IF COL_LENGTH('friendships', 'accepted_at') IS NULL
    ALTER TABLE friendships ADD accepted_at DATETIME2 NULL;
GO
UPDATE friendships SET accepted_at = created_at WHERE status = 'accepted' AND accepted_at IS NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_friendships_not_self')
    ALTER TABLE friendships ADD CONSTRAINT CK_friendships_not_self CHECK (requester_id <> receiver_id);
GO

-- ------------------------------------------------------------
-- 2. USER_BLOCKS
-- ------------------------------------------------------------
IF OBJECT_ID('user_blocks', 'U') IS NULL
CREATE TABLE user_blocks (
    blocker_id  INT NOT NULL,
    blocked_id  INT NOT NULL,
    created_at  DATETIME2 NOT NULL CONSTRAINT DF_user_blocks_created DEFAULT SYSDATETIME(),
    CONSTRAINT PK_user_blocks PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT FK_user_blocks_blocker FOREIGN KEY (blocker_id) REFERENCES users(user_id),
    CONSTRAINT FK_user_blocks_blocked FOREIGN KEY (blocked_id) REFERENCES users(user_id),
    CONSTRAINT CK_user_blocks_self CHECK (blocker_id <> blocked_id)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_user_blocks_blocked' AND object_id = OBJECT_ID('user_blocks'))
    CREATE INDEX IX_user_blocks_blocked ON user_blocks(blocked_id);
GO

-- ------------------------------------------------------------
-- 3. USERS.LAST_ACTIVE_AT
-- ------------------------------------------------------------
IF COL_LENGTH('users', 'last_active_at') IS NULL
    ALTER TABLE users ADD last_active_at DATETIME2 NULL;
GO

-- ------------------------------------------------------------
-- 4. USER_SETTINGS
-- ------------------------------------------------------------
IF OBJECT_ID('user_settings', 'U') IS NULL
CREATE TABLE user_settings (
    user_id                INT NOT NULL CONSTRAINT PK_user_settings PRIMARY KEY,
    friend_request_policy  NVARCHAR(20) NOT NULL CONSTRAINT DF_us_frp DEFAULT 'EVERYONE',  -- EVERYONE | FRIENDS_OF_FRIENDS | NOBODY
    message_policy         NVARCHAR(20) NOT NULL CONSTRAINT DF_us_msg DEFAULT 'EVERYONE',  -- EVERYONE | FRIENDS
    show_online            BIT NOT NULL CONSTRAINT DF_us_online DEFAULT 1,
    -- Thông báo trong ứng dụng (tạo bản ghi ở trang Thông báo). Nhóm "Tài khoản" luôn bật vì lý do bảo mật.
    notif_friend           BIT NOT NULL CONSTRAINT DF_us_nf  DEFAULT 1,
    notif_interaction      BIT NOT NULL CONSTRAINT DF_us_ni  DEFAULT 1,
    notif_group            BIT NOT NULL CONSTRAINT DF_us_ng  DEFAULT 1,
    notif_message          BIT NOT NULL CONSTRAINT DF_us_nm  DEFAULT 1,
    -- Thông báo đẩy trên màn hình (Notification API của trình duyệt)
    push_friend            BIT NOT NULL CONSTRAINT DF_us_pf  DEFAULT 1,
    push_interaction       BIT NOT NULL CONSTRAINT DF_us_pi  DEFAULT 0,
    push_group             BIT NOT NULL CONSTRAINT DF_us_pg  DEFAULT 0,
    push_message           BIT NOT NULL CONSTRAINT DF_us_pm  DEFAULT 1,
    push_account           BIT NOT NULL CONSTRAINT DF_us_pa  DEFAULT 1,
    updated_at             DATETIME2 NULL,
    CONSTRAINT FK_user_settings_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT CK_us_frp CHECK (friend_request_policy IN ('EVERYONE', 'FRIENDS_OF_FRIENDS', 'NOBODY')),
    CONSTRAINT CK_us_msg CHECK (message_policy IN ('EVERYONE', 'FRIENDS'))
);
GO

-- ------------------------------------------------------------
-- 5. NOTIFICATIONS
-- ------------------------------------------------------------
IF COL_LENGTH('notifications', 'ref_key') IS NULL
    ALTER TABLE notifications ADD ref_key NVARCHAR(100) NULL;
GO
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_notifications_type')
    ALTER TABLE notifications DROP CONSTRAINT chk_notifications_type;
GO
ALTER TABLE notifications ADD CONSTRAINT chk_notifications_type CHECK (type IN (
    'LIKE', 'COMMENT', 'SHARE', 'FRIEND_REQUEST', 'FRIEND_ACCEPT', 'GROUP_INVITE', 'SYSTEM',
    'GROUP_JOIN_REQUEST', 'GROUP_APPROVED', 'GROUP_POST', 'MESSAGE', 'ACCOUNT'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifications_user' AND object_id = OBJECT_ID('notifications'))
    CREATE INDEX IX_notifications_user ON notifications(user_id, is_read, created_at);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_notifications_ref' AND object_id = OBJECT_ID('notifications'))
    CREATE INDEX IX_notifications_ref ON notifications(user_id, ref_key) WHERE ref_key IS NOT NULL;
GO

-- ------------------------------------------------------------
-- 6. CONVERSATIONS — thêm nhóm chat
-- ------------------------------------------------------------
IF COL_LENGTH('conversations', 'is_group') IS NULL
    ALTER TABLE conversations ADD
        is_group   BIT NOT NULL CONSTRAINT DF_conversations_is_group DEFAULT 0,
        title      NVARCHAR(100) NULL,
        created_by INT NULL,
        created_at DATETIME2 NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_conversations_creator')
    ALTER TABLE conversations ADD CONSTRAINT FK_conversations_creator FOREIGN KEY (created_by) REFERENCES users(user_id);
GO
-- user_a_id / user_b_id phải cho phép NULL (nhóm chat không có "cặp"). Muốn ALTER COLUMN phải gỡ tạm
-- các ràng buộc đang dùng 2 cột này (UNIQUE, CHECK, FOREIGN KEY tên tự sinh) rồi tạo lại có tên rõ ràng.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('conversations') AND name = 'user_a_id' AND is_nullable = 0)
BEGIN
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'uq_conversation')
        ALTER TABLE conversations DROP CONSTRAINT uq_conversation;
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_user_order')
        ALTER TABLE conversations DROP CONSTRAINT chk_user_order;
    DECLARE @sql NVARCHAR(MAX) = N'';
    SELECT @sql += N'ALTER TABLE conversations DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
    FROM sys.foreign_keys fk
    JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
    JOIN sys.columns c ON c.object_id = fkc.parent_object_id AND c.column_id = fkc.parent_column_id
    WHERE fk.parent_object_id = OBJECT_ID('conversations') AND c.name IN ('user_a_id', 'user_b_id');
    EXEC sp_executesql @sql;
    ALTER TABLE conversations ALTER COLUMN user_a_id INT NULL;
    ALTER TABLE conversations ALTER COLUMN user_b_id INT NULL;
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_conversations_user_a')
    ALTER TABLE conversations ADD CONSTRAINT FK_conversations_user_a FOREIGN KEY (user_a_id) REFERENCES users(user_id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_conversations_user_b')
    ALTER TABLE conversations ADD CONSTRAINT FK_conversations_user_b FOREIGN KEY (user_b_id) REFERENCES users(user_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_conversations_pair' AND object_id = OBJECT_ID('conversations'))
    CREATE UNIQUE INDEX UX_conversations_pair ON conversations(user_a_id, user_b_id)
        WHERE user_a_id IS NOT NULL AND user_b_id IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_conversations_kind')
    ALTER TABLE conversations ADD CONSTRAINT CK_conversations_kind CHECK (
        (is_group = 1 AND user_a_id IS NULL AND user_b_id IS NULL)
     OR (is_group = 0 AND user_a_id IS NOT NULL AND user_b_id IS NOT NULL AND user_a_id < user_b_id));
GO

-- ------------------------------------------------------------
-- 7. CONVERSATION_MEMBERS
-- ------------------------------------------------------------
IF OBJECT_ID('conversation_members', 'U') IS NULL
CREATE TABLE conversation_members (
    conversation_id            INT NOT NULL,
    user_id                    INT NOT NULL,
    role                       NVARCHAR(10) NOT NULL CONSTRAINT DF_cm_role DEFAULT 'MEMBER',   -- OWNER | MEMBER
    joined_at                  DATETIME2 NOT NULL CONSTRAINT DF_cm_joined DEFAULT SYSDATETIME(),
    last_read_message_id       INT NOT NULL CONSTRAINT DF_cm_read DEFAULT 0,       -- đã XEM tới tin này
    last_delivered_message_id  INT NOT NULL CONSTRAINT DF_cm_delivered DEFAULT 0,  -- đã NHẬN (thiết bị đã tải về) tới tin này
    cleared_message_id         INT NOT NULL CONSTRAINT DF_cm_cleared DEFAULT 0,    -- "Xóa cuộc trò chuyện": ẩn mọi tin <= mốc này với riêng người này
    CONSTRAINT PK_conversation_members PRIMARY KEY (conversation_id, user_id),
    CONSTRAINT FK_cm_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    CONSTRAINT FK_cm_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT CK_cm_role CHECK (role IN ('OWNER', 'MEMBER'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_conversation_members_user' AND object_id = OBJECT_ID('conversation_members'))
    CREATE INDEX IX_conversation_members_user ON conversation_members(user_id);
GO
-- Backfill: mỗi hội thoại 1-1 cũ có 2 thành viên. Đã xem tới = tin trước tin chưa đọc đầu tiên (nếu có),
-- ngược lại = tin mới nhất của hội thoại.
INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, last_read_message_id, last_delivered_message_id)
SELECT c.conversation_id, u.uid, 'MEMBER', COALESCE(c.last_message_at, SYSDATETIME()),
       COALESCE((SELECT MIN(m.message_id) - 1 FROM chat_messages m
                 WHERE m.conversation_id = c.conversation_id AND m.sender_id <> u.uid AND m.is_read = 0),
                (SELECT MAX(m.message_id) FROM chat_messages m WHERE m.conversation_id = c.conversation_id), 0),
       COALESCE((SELECT MAX(m.message_id) FROM chat_messages m WHERE m.conversation_id = c.conversation_id), 0)
FROM conversations c
CROSS APPLY (VALUES (c.user_a_id), (c.user_b_id)) AS u(uid)
WHERE c.is_group = 0
  AND NOT EXISTS (SELECT 1 FROM conversation_members cm WHERE cm.conversation_id = c.conversation_id AND cm.user_id = u.uid);
GO

-- ------------------------------------------------------------
-- 8. CHAT_MESSAGES
-- ------------------------------------------------------------
IF COL_LENGTH('chat_messages', 'client_id') IS NULL
    ALTER TABLE chat_messages ADD
        client_id        NVARCHAR(40)  NULL,     -- mã do trình duyệt sinh: gửi lại tin lỗi không tạo bản trùng
        message_type     NVARCHAR(10)  NOT NULL CONSTRAINT DF_cmsg_type DEFAULT 'TEXT',   -- TEXT | SYSTEM
        reply_to_id      INT           NULL,     -- trả lời tin nào (không đặt FK: tin gốc bị thu hồi vẫn giữ được liên kết)
        edited_at        DATETIME2     NULL,
        recalled_at      DATETIME2     NULL,     -- thu hồi với mọi người
        pinned_at        DATETIME2     NULL,
        pinned_by        INT           NULL,
        attachment_path  NVARCHAR(500) NULL,     -- lưu NGOÀI thư mục /uploads công khai, tải qua /chat/file (kiểm quyền)
        attachment_type  NVARCHAR(10)  NULL,     -- IMAGE | FILE
        attachment_name  NVARCHAR(255) NULL,
        attachment_size  BIGINT        NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_cmsg_type')
    ALTER TABLE chat_messages ADD CONSTRAINT CK_cmsg_type CHECK (message_type IN ('TEXT', 'SYSTEM'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_cmsg_attachment')
    ALTER TABLE chat_messages ADD CONSTRAINT CK_cmsg_attachment CHECK (attachment_type IS NULL OR attachment_type IN ('IMAGE', 'FILE'));
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_cmsg_pinned_by')
    ALTER TABLE chat_messages ADD CONSTRAINT FK_cmsg_pinned_by FOREIGN KEY (pinned_by) REFERENCES users(user_id);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_chat_messages_client' AND object_id = OBJECT_ID('chat_messages'))
    CREATE UNIQUE INDEX UX_chat_messages_client ON chat_messages(sender_id, client_id) WHERE client_id IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_chat_messages_conv' AND object_id = OBJECT_ID('chat_messages'))
    CREATE INDEX IX_chat_messages_conv ON chat_messages(conversation_id, message_id);
GO

-- ------------------------------------------------------------
-- 9. MESSAGE_REACTIONS
-- ------------------------------------------------------------
IF OBJECT_ID('message_reactions', 'U') IS NULL
CREATE TABLE message_reactions (
    message_id  INT NOT NULL,
    user_id     INT NOT NULL,
    emoji       NVARCHAR(16) NOT NULL,
    created_at  DATETIME2 NOT NULL CONSTRAINT DF_mr_created DEFAULT SYSDATETIME(),
    CONSTRAINT PK_message_reactions PRIMARY KEY (message_id, user_id),
    CONSTRAINT FK_mr_message FOREIGN KEY (message_id) REFERENCES chat_messages(message_id) ON DELETE CASCADE,
    CONSTRAINT FK_mr_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);
GO

-- ------------------------------------------------------------
-- 10. MESSAGE_HIDDEN — "Xóa ở phía tôi"
-- ------------------------------------------------------------
IF OBJECT_ID('message_hidden', 'U') IS NULL
CREATE TABLE message_hidden (
    message_id  INT NOT NULL,
    user_id     INT NOT NULL,
    CONSTRAINT PK_message_hidden PRIMARY KEY (message_id, user_id),
    CONSTRAINT FK_mh_message FOREIGN KEY (message_id) REFERENCES chat_messages(message_id) ON DELETE CASCADE,
    CONSTRAINT FK_mh_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);
GO

PRINT N'060: friendships (1 cặp 1 dòng), user_blocks, user_settings, notifications, nhóm chat, chat_messages mở rộng OK';
GO


PRINT '------------------------------------------------';
PRINT 'Executing 070_migration_admin_logs_ip.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 070: Trang quản trị (admin_ui_plan)
-- Chạy lại nhiều lần vẫn an toàn. Cần chạy SAU 040_migration_reports_admin.sql.
--
-- admin_logs.ip_address : địa chỉ IP của admin lúc thao tác (trang "Nhật ký quản trị").
--                         IPv6 dài tối đa 45 ký tự. Log cũ để NULL (hiện "—").
-- ============================================================
SET QUOTED_IDENTIFIER ON;
GO
IF COL_LENGTH('admin_logs', 'ip_address') IS NULL
    ALTER TABLE admin_logs ADD ip_address NVARCHAR(45) NULL;
GO

-- Lọc nhật ký theo loại thao tác
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_adminlogs_action' AND object_id = OBJECT_ID('admin_logs'))
    CREATE INDEX IX_adminlogs_action ON admin_logs(action, created_at DESC);
GO

SELECT COL_LENGTH('admin_logs', 'ip_address') AS ip_address_len,
       (SELECT COUNT(*) FROM admin_logs) AS so_log;
GO


PRINT '------------------------------------------------';
PRINT 'Executing 080_fix_student_id_unique.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 080: sửa lỗi ĐĂNG KÝ TÀI KHOẢN MỚI trên database cũ
-- Chạy lại nhiều lần vẫn an toàn. Database không có cột student_id → script không làm gì.
--
-- Database tạo từ schema cũ còn cột users.student_id với ràng buộc UNIQUE thường.
-- SQL Server coi NULL là một giá trị → cả bảng chỉ được 1 tài khoản không có mã sinh viên.
-- Code hiện tại không dùng student_id (đăng ký để NULL) → từ tài khoản mới thứ hai trở đi lỗi
-- "Violation of UNIQUE KEY constraint 'UQ__users__...'".
-- Sửa: bỏ ràng buộc cũ, thay bằng chỉ mục UNIQUE CÓ LỌC — mã sinh viên (nếu có) vẫn không trùng,
-- còn NULL thì bao nhiêu cũng được.
-- ============================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF COL_LENGTH('users', 'student_id') IS NOT NULL
BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'';
    -- Mọi ràng buộc UNIQUE đặt trên đúng một cột student_id (tên tự sinh dạng UQ__users__xxxx)
    SELECT @sql += N'ALTER TABLE users DROP CONSTRAINT ' + QUOTENAME(kc.name) + N';'
    FROM sys.key_constraints kc
    JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE kc.parent_object_id = OBJECT_ID('users') AND kc.type = 'UQ' AND c.name = 'student_id'
      AND (SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id = kc.parent_object_id AND x.index_id = kc.unique_index_id) = 1;
    IF @sql <> N'' EXEC sp_executesql @sql;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_users_student_id' AND object_id = OBJECT_ID('users'))
        EXEC(N'CREATE UNIQUE INDEX UX_users_student_id ON users(student_id) WHERE student_id IS NOT NULL');
END
GO

SELECT COL_LENGTH('users', 'student_id') AS student_id_len,
       (SELECT COUNT(*) FROM sys.key_constraints kc
          JOIN sys.index_columns ic ON ic.object_id = kc.parent_object_id AND ic.index_id = kc.unique_index_id
          JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
         WHERE kc.parent_object_id = OBJECT_ID('users') AND c.name = 'student_id') AS old_unique_left,
       (SELECT COUNT(*) FROM sys.indexes WHERE name = 'UX_users_student_id') AS filtered_index;
GO


PRINT '------------------------------------------------';
PRINT 'Executing 090_migration_ai_social.sql ...';
PRINT '------------------------------------------------';
GO

-- ============================================================
-- UTErSpace — Migration 090: Story nâng cao · AI · Cá nhân hóa · Bảo mật nâng cao
-- Chạy lại nhiều lần vẫn an toàn. Chạy sau 080. sqlcmd nhớ thêm -I -f 65001.
--
--  1. user_settings        : lưu trữ tin, chế độ bảng tin, ẩn bài tiêu cực, bộ lọc từ khóa cá nhân.
--  2. story_reactions      : thả tim tin (mỗi người 1 lần / tin) — chủ tin thấy ❤️ cạnh người đã xem.
--  3. stories.archived_at  : (thông tin) mốc tin chuyển vào kho lưu trữ; tin hết hạn KHÔNG còn bị xóa
--                            nếu chủ tin bật lưu trữ (mặc định bật).
--  4. posts                : nhãn cảm xúc (sentiment), chế độ media nâng cao (ảnh 360° / ảnh 3D chiều sâu / mô hình 3D-AR),
--                            đường dẫn mô hình .glb, phụ đề WebVTT của video.
--  5. notifications.type   : thêm STORY_REACT.
--  6. search_history       : từ khóa người dùng đã tìm → gợi ý nhóm / hashtag / video theo thói quen tìm kiếm.
--  7. webauthn_credentials : passkey (vân tay / khuôn mặt của thiết bị) — chỉ lưu khóa công khai.
--  8. user_dids            : danh tính số did:key (Ed25519) gắn với tài khoản — chỉ lưu khóa công khai.
-- ============================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
-- ------------------------------------------------------------
-- 1. USER_SETTINGS
-- ------------------------------------------------------------
IF COL_LENGTH('user_settings', 'archive_stories') IS NULL
    ALTER TABLE user_settings ADD archive_stories BIT NOT NULL CONSTRAINT DF_us_archive DEFAULT 1;
GO
IF COL_LENGTH('user_settings', 'feed_mode') IS NULL
    ALTER TABLE user_settings ADD feed_mode NVARCHAR(10) NOT NULL CONSTRAINT DF_us_feed_mode DEFAULT 'SMART';
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_us_feed_mode')
    ALTER TABLE user_settings ADD CONSTRAINT CK_us_feed_mode CHECK (feed_mode IN ('SMART', 'LATEST'));
GO
IF COL_LENGTH('user_settings', 'hide_negative') IS NULL
    ALTER TABLE user_settings ADD hide_negative BIT NOT NULL CONSTRAINT DF_us_hide_negative DEFAULT 0;
GO
-- Mỗi dòng một từ khóa / cụm từ / emoji (tối đa 100 mục, kiểm tra ở SettingsController)
IF COL_LENGTH('user_settings', 'content_filter') IS NULL
    ALTER TABLE user_settings ADD content_filter NVARCHAR(2000) NULL;
GO

-- ------------------------------------------------------------
-- 2. STORY_REACTIONS
-- ------------------------------------------------------------
IF OBJECT_ID('story_reactions', 'U') IS NULL
CREATE TABLE story_reactions (
    story_id    INT NOT NULL,
    user_id     INT NOT NULL,
    emoji       NVARCHAR(8) NOT NULL CONSTRAINT DF_story_reactions_emoji DEFAULT N'❤️',
    created_at  DATETIME2 NOT NULL CONSTRAINT DF_story_reactions_at DEFAULT SYSDATETIME(),
    CONSTRAINT PK_story_reactions PRIMARY KEY (story_id, user_id),
    CONSTRAINT FK_story_reactions_story FOREIGN KEY (story_id) REFERENCES stories(story_id) ON DELETE CASCADE,
    CONSTRAINT FK_story_reactions_user  FOREIGN KEY (user_id)  REFERENCES users(user_id)
);
GO

-- ------------------------------------------------------------
-- 3. STORIES — chỉ mục cho kho lưu trữ (tin hết hạn của một người, mới nhất trước)
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_stories_user_created' AND object_id = OBJECT_ID('stories'))
    CREATE INDEX IX_stories_user_created ON stories(user_id, created_at DESC);
GO

-- ------------------------------------------------------------
-- 4. POSTS
-- ------------------------------------------------------------
IF COL_LENGTH('posts', 'sentiment') IS NULL
    ALTER TABLE posts ADD sentiment NVARCHAR(10) NULL;           -- POSITIVE | NEUTRAL | NEGATIVE, NULL = chưa phân tích
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_posts_sentiment')
    ALTER TABLE posts ADD CONSTRAINT CK_posts_sentiment CHECK (sentiment IS NULL OR sentiment IN ('POSITIVE', 'NEUTRAL', 'NEGATIVE'));
GO
IF COL_LENGTH('posts', 'sentiment_score') IS NULL
    ALTER TABLE posts ADD sentiment_score FLOAT NULL;            -- -1 (rất tiêu cực) .. +1 (rất tích cực)
GO
IF COL_LENGTH('posts', 'sentiment_source') IS NULL
    ALTER TABLE posts ADD sentiment_source NVARCHAR(10) NULL;    -- AI (Claude) | LEXICON (bộ từ điển nội bộ)
GO
IF COL_LENGTH('posts', 'media_mode') IS NULL
    ALTER TABLE posts ADD media_mode NVARCHAR(12) NULL;          -- NULL | PANORAMA | DEPTH | MODEL3D
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_posts_media_mode')
    ALTER TABLE posts ADD CONSTRAINT CK_posts_media_mode CHECK (media_mode IS NULL OR media_mode IN ('PANORAMA', 'DEPTH', 'MODEL3D'));
GO
IF COL_LENGTH('posts', 'model_path') IS NULL
    ALTER TABLE posts ADD model_path NVARCHAR(500) NULL;         -- uploads/models/<uuid>.glb (media_mode = MODEL3D)
GO
IF COL_LENGTH('posts', 'captions_vtt') IS NULL
    ALTER TABLE posts ADD captions_vtt NVARCHAR(MAX) NULL;       -- phụ đề WebVTT của video (tự nhận dạng / tự gõ)
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_posts_sentiment' AND object_id = OBJECT_ID('posts'))
    CREATE INDEX IX_posts_sentiment ON posts(sentiment) INCLUDE (created_at);
GO

-- ------------------------------------------------------------
-- 5. NOTIFICATIONS.TYPE
-- ------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_notifications_type')
    ALTER TABLE notifications DROP CONSTRAINT chk_notifications_type;
GO
ALTER TABLE notifications ADD CONSTRAINT chk_notifications_type CHECK (type IN (
    'LIKE', 'COMMENT', 'SHARE', 'FRIEND_REQUEST', 'FRIEND_ACCEPT', 'GROUP_INVITE', 'SYSTEM',
    'GROUP_JOIN_REQUEST', 'GROUP_APPROVED', 'GROUP_POST', 'MESSAGE', 'ACCOUNT', 'STORY_REACT'));
GO

-- ------------------------------------------------------------
-- 6. SEARCH_HISTORY
-- ------------------------------------------------------------
IF OBJECT_ID('search_history', 'U') IS NULL
CREATE TABLE search_history (
    search_id   INT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT NOT NULL,
    query       NVARCHAR(200) NOT NULL,
    created_at  DATETIME2 NOT NULL CONSTRAINT DF_search_history_at DEFAULT SYSDATETIME(),
    CONSTRAINT FK_search_history_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_search_history_user' AND object_id = OBJECT_ID('search_history'))
    CREATE INDEX IX_search_history_user ON search_history(user_id, created_at DESC);
GO

-- ------------------------------------------------------------
-- 7. WEBAUTHN_CREDENTIALS (passkey / sinh trắc học của thiết bị)
-- ------------------------------------------------------------
IF OBJECT_ID('webauthn_credentials', 'U') IS NULL
CREATE TABLE webauthn_credentials (
    id             INT IDENTITY(1,1) PRIMARY KEY,
    user_id        INT NOT NULL,
    credential_id  NVARCHAR(700) NOT NULL,   -- base64url của rawId
    public_key     VARBINARY(1024) NOT NULL, -- SubjectPublicKeyInfo (DER) do trình duyệt trả về
    alg            INT NOT NULL,             -- COSE: -7 = ES256, -257 = RS256
    sign_count     BIGINT NOT NULL CONSTRAINT DF_webauthn_count DEFAULT 0,
    label          NVARCHAR(100) NULL,
    created_at     DATETIME2 NOT NULL CONSTRAINT DF_webauthn_created DEFAULT SYSDATETIME(),
    last_used_at   DATETIME2 NULL,
    CONSTRAINT FK_webauthn_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_webauthn_credential' AND object_id = OBJECT_ID('webauthn_credentials'))
    CREATE UNIQUE INDEX UX_webauthn_credential ON webauthn_credentials(credential_id);
GO

-- ------------------------------------------------------------
-- 8. USER_DIDS (danh tính số did:key)
-- ------------------------------------------------------------
IF OBJECT_ID('user_dids', 'U') IS NULL
CREATE TABLE user_dids (
    user_id     INT NOT NULL PRIMARY KEY,
    did         NVARCHAR(200) NOT NULL,
    public_key  VARBINARY(64) NOT NULL,      -- khóa công khai Ed25519 thô (32 byte)
    created_at  DATETIME2 NOT NULL CONSTRAINT DF_user_dids_created DEFAULT SYSDATETIME(),
    CONSTRAINT FK_user_dids_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_user_dids_did' AND object_id = OBJECT_ID('user_dids'))
    CREATE UNIQUE INDEX UX_user_dids_did ON user_dids(did);
GO

PRINT N'090: story reactions, AI sentiment, cá nhân hóa, passkey, DID OK';
GO

PRINT '------------------------------------------------';
PRINT 'Executing 100_cloudinary_seed_media.sql ...';
PRINT '------------------------------------------------';
GO
-- ============================================================
-- 100: Gắn ảnh / video mẫu trên Cloudinary cho dữ liệu seed
--   - File nằm ở gốc uterspace_uploads/ (avatar_N, group_cover_N, post_img_N, post_video_N) là ảnh / video
--     minh họa. UploadUtil.delete KHÔNG bao giờ xóa các file này (chỉ xóa file người dùng upload, nằm trong
--     uterspace_uploads/<thư mục>/), nên chạy lại script dựng DB vẫn còn đủ ảnh.
--   - Ảnh chỉ gắn vào cột ảnh (avatar, cover_image, image_path), video chỉ gắn vào cột video (video_path).
--   - Chạy lại nhiều lần không sao: chỉ thay giá trị seed (tên file trong assets/images hoặc NULL),
--     không đụng tới ảnh / video người dùng tự upload (URL http... hoặc uploads/...).
-- ============================================================
SET QUOTED_IDENTIFIER ON;
GO

-- Ảnh đại diện user 1..15
UPDATE u SET avatar = m.url
FROM users u JOIN (VALUES
    (1, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617040/uterspace_uploads/avatar_1.jpg'),
    (2, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617046/uterspace_uploads/avatar_2.jpg'),
    (3, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617047/uterspace_uploads/avatar_3.jpg'),
    (4, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617048/uterspace_uploads/avatar_4.jpg'),
    (5, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617048/uterspace_uploads/avatar_5.jpg'),
    (6, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617049/uterspace_uploads/avatar_6.jpg'),
    (7, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617050/uterspace_uploads/avatar_7.jpg'),
    (8, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617051/uterspace_uploads/avatar_8.jpg'),
    (9, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617051/uterspace_uploads/avatar_9.jpg'),
    (10, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617042/uterspace_uploads/avatar_10.jpg'),
    (11, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617043/uterspace_uploads/avatar_11.jpg'),
    (12, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617044/uterspace_uploads/avatar_12.jpg'),
    (13, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617044/uterspace_uploads/avatar_13.jpg'),
    (14, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617045/uterspace_uploads/avatar_14.jpg'),
    (15, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617046/uterspace_uploads/avatar_15.jpg')
) m(id, url) ON u.user_id = m.id
WHERE u.avatar IS NULL OR (u.avatar NOT LIKE 'http%' AND u.avatar NOT LIKE 'uploads/%');
GO

-- Ảnh bìa nhóm 1..11 (trước đó dùng nền gradient + biểu tượng)
UPDATE g SET cover_image = m.url
FROM groups_tbl g JOIN (VALUES
    (1, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617052/uterspace_uploads/group_cover_1.jpg'),
    (2, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617055/uterspace_uploads/group_cover_2.jpg'),
    (3, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617056/uterspace_uploads/group_cover_3.jpg'),
    (4, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617056/uterspace_uploads/group_cover_4.jpg'),
    (5, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617057/uterspace_uploads/group_cover_5.jpg'),
    (6, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617059/uterspace_uploads/group_cover_6.jpg'),
    (7, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617059/uterspace_uploads/group_cover_7.jpg'),
    (8, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617061/uterspace_uploads/group_cover_8.jpg'),
    (9, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617061/uterspace_uploads/group_cover_9.jpg'),
    (10, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617053/uterspace_uploads/group_cover_10.jpg'),
    (11, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617053/uterspace_uploads/group_cover_11.jpg')
) m(id, url) ON g.group_id = m.id
WHERE g.cover_image IS NULL OR (g.cover_image NOT LIKE 'http%' AND g.cover_image NOT LIKE 'uploads/%');
GO

-- Ảnh của 16 bài viết có ảnh (không đụng ảnh bìa của bài video)
UPDATE p SET image_path = m.url
FROM posts p JOIN (VALUES
    (1, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617063/uterspace_uploads/post_img_1.jpg'),
    (2, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617068/uterspace_uploads/post_img_2.jpg'),
    (3, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617069/uterspace_uploads/post_img_3.jpg'),
    (4, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617069/uterspace_uploads/post_img_4.jpg'),
    (5, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617071/uterspace_uploads/post_img_5.jpg'),
    (6, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617072/uterspace_uploads/post_img_6.jpg'),
    (16, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617073/uterspace_uploads/post_img_7.jpg'),
    (18, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617073/uterspace_uploads/post_img_8.jpg'),
    (21, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617075/uterspace_uploads/post_img_9.jpg'),
    (22, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617063/uterspace_uploads/post_img_10.jpg'),
    (24, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617065/uterspace_uploads/post_img_11.jpg'),
    (25, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617066/uterspace_uploads/post_img_12.jpg'),
    (27, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617066/uterspace_uploads/post_img_13.jpg'),
    (30, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617067/uterspace_uploads/post_img_14.jpg'),
    (33, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617067/uterspace_uploads/post_img_15.jpg'),
    (36, N'https://res.cloudinary.com/yjjoybu5/image/upload/v1791617054/uterspace_uploads/group_cover_12.jpg')
) m(id, url) ON p.post_id = m.id
WHERE p.image_path IS NOT NULL AND p.image_path NOT LIKE 'http%' AND p.image_path NOT LIKE 'uploads/%'
  AND (p.media_type IS NULL OR p.media_type <> 'VIDEO');
GO

-- File video cho 6 bài video mẫu (trước đó "Video mẫu — chưa có file video"); clip mẫu dài 10 giây
UPDATE p SET video_path = m.url, video_duration_sec = 10
FROM posts p JOIN (VALUES
    (38, N'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617076/uterspace_uploads/post_video_1.mp4'),
    (39, N'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617080/uterspace_uploads/post_video_2.mp4'),
    (40, N'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617081/uterspace_uploads/post_video_3.mp4'),
    (41, N'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617082/uterspace_uploads/post_video_4.mp4'),
    (42, N'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617083/uterspace_uploads/post_video_5.mp4'),
    (43, N'https://res.cloudinary.com/yjjoybu5/video/upload/v1791617084/uterspace_uploads/post_video_6.mp4')
) m(id, url) ON p.post_id = m.id
WHERE p.media_type = 'VIDEO' AND p.video_path IS NULL;
GO

PRINT N'100: ảnh / video mẫu trên Cloudinary OK';
GO
