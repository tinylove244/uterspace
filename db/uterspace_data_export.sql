-- MySQL dump 10.13  Distrib 8.4.9, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: defaultdb
-- ------------------------------------------------------
-- Server version	8.4.9

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `admin_logs`
--

DROP TABLE IF EXISTS `admin_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_logs` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `admin_id` int NOT NULL,
  `action` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` int DEFAULT NULL,
  `detail` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ip_address` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`log_id`),
  KEY `ix_adminlogs_created` (`created_at`),
  KEY `ix_adminlogs_action` (`action`,`created_at`),
  KEY `ix_adminlogs_admin` (`admin_id`),
  CONSTRAINT `fk_adminlogs_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_logs`
--

LOCK TABLES `admin_logs` WRITE;
/*!40000 ALTER TABLE `admin_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `chat_messages`
--

DROP TABLE IF EXISTS `chat_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_messages` (
  `message_id` int NOT NULL AUTO_INCREMENT,
  `conversation_id` int NOT NULL,
  `sender_id` int NOT NULL,
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `sent_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `client_id` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'TEXT',
  `reply_to_id` int DEFAULT NULL,
  `edited_at` datetime DEFAULT NULL,
  `recalled_at` datetime DEFAULT NULL,
  `pinned_at` datetime DEFAULT NULL,
  `pinned_by` int DEFAULT NULL,
  `attachment_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_size` bigint DEFAULT NULL,
  PRIMARY KEY (`message_id`),
  UNIQUE KEY `ux_chat_messages_client` (`sender_id`,`client_id`),
  KEY `ix_chat_messages_conv` (`conversation_id`,`message_id`),
  KEY `ix_chat_messages_sender` (`sender_id`),
  KEY `ix_chat_messages_pinned_by` (`pinned_by`),
  CONSTRAINT `fk_chat_messages_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`conversation_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_chat_messages_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cmsg_pinned_by` FOREIGN KEY (`pinned_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `chat_messages`
--

LOCK TABLES `chat_messages` WRITE;
/*!40000 ALTER TABLE `chat_messages` DISABLE KEYS */;
INSERT INTO `chat_messages` VALUES (1,1,1,'Lan Anh oi, nhom minh can them nguoi lam phan bao cao, ban co the giup khong?',1,'2026-09-14 20:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(2,1,2,'Ban can cu the phan nao? Minh co the lam phan kinh te va market research.',1,'2026-09-14 21:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(3,1,1,'Tuyet! Minh can phan tich chi phi du an. Deadline cuoi tuan nay nha.',1,'2026-09-14 21:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(4,1,2,'OK minh se lam! Gui template bao cao cho minh voi.',1,'2026-09-14 21:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(5,2,3,'Huy oi, may co ranh thu 7 khong? CLB to chuc workshop Arduino co ban.',1,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(6,2,1,'Minh co ranh! May gio va o dau vay?',1,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(7,2,3,'8h sang tai phong C206. Mang laptop nha, cai san Arduino IDE gium.',1,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(8,2,1,'Okok minh se den! Can mang gi them khong?',0,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(9,3,2,'Han oi, chia se link tai lieu IELTS voi minh duoc khong? Minh dang can gap.',1,'2026-09-12 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(10,3,5,'Day nha! Cambridge 1-18 link drive nay. Con muon gi them khong?',1,'2026-09-12 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(11,3,2,'Du roi cam on ban nhieu lam! Dang can gap cho ky thi thang sau.',1,'2026-09-12 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(12,4,4,'Nam oi, minh can tu van ve bao mat cho app web. Ban co thoi gian khong?',1,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(13,4,8,'Duoc chu! App ban dung framework gi? Spring Boot hay Express.js?',1,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(14,4,4,'Spring Boot. Minh chu yeu lo ve SQL Injection va XSS.',1,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(15,4,8,'Spring Boot dung JPA thi da co parameterized query roi, kha an toan. XSS thi can escape output.',0,'2026-09-13 23:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(16,5,3,'Phat, may tim duoc cai lidar mini do o dau vay? Link voi tao cai.',1,'2026-09-14 17:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(17,5,6,'Aliexpress day, search TF-Luna lidar. Khoang 200k, ship 2 tuan.',1,'2026-09-14 18:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(18,5,3,'OK cam on! May thay do chinh xac co du cho line following khong?',1,'2026-09-14 18:33:00',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(19,6,22,'Hà ơi, phần giao diện trang chủ bạn làm xong chưa?',1,'2026-09-18 13:33:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(20,6,4,'Rồi nha, mình vừa push lên nhánh feature/home tối qua.',1,'2026-09-18 13:41:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(21,6,22,'Tuyệt vời! Để mình pull về xem rồi góp ý thêm nhé.',1,'2026-09-18 13:45:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(22,6,4,'Ok bạn, phần responsive mình chưa kỹ lắm, xem giúp mình với.',1,'2026-09-18 13:53:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(23,6,22,'Mình vừa xem rồi, ổn áp lắm. Chỉ cần chỉnh lại cái sidebar ở mobile thôi.',0,'2026-09-18 14:21:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(24,7,4,'Anh ơi, cho em hỏi Docker Compose với MySQL nên cấu hình sao ạ?',1,'2026-09-18 11:33:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(25,7,18,'Em nhớ mount volume cho thư mục data, không là restart mất sạch database đó.',1,'2026-09-18 12:03:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(26,7,4,'Dạ em hiểu rồi, cảm ơn anh nhiều!',1,'2026-09-18 12:13:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(27,7,18,'Có gì cứ hỏi nhé, anh cũng từng mất 2 ngày vì cái lỗi đó.',0,'2026-09-18 12:58:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(28,8,15,'Bên công ty mình đang tuyển thực tập sinh, Hà có muốn thử không?',1,'2026-09-18 07:53:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(29,8,4,'Có chứ! Bạn gửi mình JD với nha.',1,'2026-09-18 08:13:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(30,8,15,'Ok để mình xin anh HR rồi gửi qua cho bạn trong hôm nay.',0,'2026-09-18 10:33:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(31,9,28,'Buổi Speaking thứ 6 này Hà tham gia được không?',1,'2026-09-17 23:33:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(32,9,4,'Được nha, mình rảnh từ 18h. Hẹn ở thư viện tầng 3 nhé.',1,'2026-09-18 01:13:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(33,9,28,'Chốt vậy nha, hẹn gặp bạn!',1,'2026-09-18 01:53:59',NULL,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(34,12,33,'',0,'2026-10-08 08:23:27','cmuyurmfz08srxb52','TEXT',NULL,NULL,'2026-10-08 08:34:04',NULL,NULL,NULL,NULL,NULL,NULL),(35,13,1,'Duc Huy Nguyen đã tạo nhóm \"web\".',0,'2026-10-08 08:37:48',NULL,'SYSTEM',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(36,13,1,'Duc Huy Nguyen đã thêm Nguyễn Hữu Phú vào nhóm.',0,'2026-10-08 08:38:22',NULL,'SYSTEM',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(37,13,1,'hello',0,'2026-10-08 08:38:31','cmuyvazle3yihu2mm','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(38,13,1,'💯',0,'2026-10-08 08:38:38','cmuyvb53b7padcddh','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(39,14,1,'Duc Huy Nguyen đã tạo nhóm \"Test web\".',0,'2026-10-08 09:07:48',NULL,'SYSTEM',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(40,14,1,'Hi cả nhóm',0,'2026-10-08 09:08:03','cmuywcz41vnnvrld6','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(43,13,4,'hi',0,'2026-10-12 13:33:38','cmv4vlw79gg537tgs','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(44,17,1,'Chào bạn',0,'2026-10-18 16:28:13','cmvdmhizp9ko3qu3v','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(45,17,14,'Chào bạn nhá',0,'2026-10-18 16:28:24','cmvdmhr3upadw1my7','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(46,18,1,'Khang beo',0,'2026-10-18 16:47:57','cmvdn6vzyh5lv9srt','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(47,18,34,'hi',0,'2026-10-18 16:48:07','cmvdn73td5nbcsec7','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(48,18,34,'đồ hôi chân',0,'2026-10-18 16:48:14','cmvdn78tvlymlszy8','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(49,13,1,'Duc Huy Nguyen đã thêm Nguyễn Khang vào nhóm.',0,'2026-10-18 16:48:18',NULL,'SYSTEM',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(50,13,1,'Chào bạn mới đi ae',0,'2026-10-18 16:48:34','cmvdn7oufb970pxrc','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),(51,13,34,'chào các bạn nha',0,'2026-10-18 16:48:51','cmvdn82bvfr9tclr3','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `chat_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `comments`
--

DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `comment_id` int NOT NULL AUTO_INCREMENT,
  `post_id` int NOT NULL,
  `user_id` int NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`comment_id`),
  KEY `ix_comments_post_id` (`post_id`),
  KEY `ix_comments_user_id` (`user_id`),
  CONSTRAINT `fk_comments_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_comments_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=389 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `comments`
--

LOCK TABLES `comments` WRITE;
/*!40000 ALTER TABLE `comments` DISABLE KEYS */;
INSERT INTO `comments` VALUES (1,1,3,'Xin source Github voi ban! Minh cung dang lam IoT nhung chua ra ket qua dep.','2026-09-08 23:33:00'),(2,1,6,'Sensor nhiet do ban dung la DHT11 hay DHT22 vay?','2026-09-09 23:33:00'),(3,1,4,'Bao gio ban demo cho ca lop xem vay? Hong lam!','2026-09-09 23:33:00'),(4,1,2,'Ngưỡng mộ tinh thần chiến đấu của team quá! Chúc mừng nhé','2026-09-10 23:33:00'),(5,2,1,'Dia chi cu the la dau ban oi? Minh tim mai khong ra quan do.','2026-09-09 23:33:00'),(6,2,7,'Ca phe trung! Minh me mon nay tu lan dau thu o Ha Noi luon!','2026-09-10 23:33:00'),(7,2,3,'Gia ca the nao ban? Sinh vien du suc khong?','2026-09-11 23:33:00'),(8,2,5,'Review do uong hay that, lan sau vao day minh se thu ngay!','2026-09-12 23:33:00'),(9,2,9,'Cam on ban da review nhe, minh se ru nhom di cuoi tuan nay!','2026-09-13 23:33:00'),(10,3,1,'Robot nhin pro hon minh tuong. Thuat toan PID hay chi on/off vay?','2026-09-10 23:33:00'),(11,3,6,'Lidar mini ban mua tu dau vay? Shopee hay Aliexpress?','2026-09-11 23:33:00'),(12,3,8,'CLB cac ban impressive lam. Cho minh tham quan workshop duoc khong?','2026-09-12 23:33:00'),(13,4,1,'Goc hoc tap nhin sach se yen tinh qua. Minh hoc o phong tro on ao chiu khong noi!','2026-09-10 23:33:00'),(14,4,5,'Thi tot nha ban! Minh cung dang can motivation hoc bai lam.','2026-09-11 23:33:00'),(15,4,3,'Meo cua minh: Pomodoro 25 phut hoc 5 phut nghi. Hieu qua lam!','2026-09-12 23:33:00'),(16,4,2,'Thu 2 thi chua? Chuc may man ban oi!','2026-09-12 23:33:00'),(17,4,7,'Nuoc uong du, anh sang du la dieu kien toi thieu de nao hoat dong tot nhe!','2026-09-13 23:33:00'),(18,4,4,'Cam on moi nguoi, minh se co gang! Update ket qua sau nha.','2026-09-14 23:33:00'),(19,5,1,'Team minh cung dang trong giai doan nay. Vuot qua duoc requirement la on roi!','2026-09-11 23:33:00'),(20,5,4,'Diagram ERD cac ban da xong chua? Phan do minh hay bi reject nhat.','2026-09-12 23:33:00'),(21,5,3,'Cam giac chot xong requirement nhe nhom lam do. Phan code moi la thu thach!','2026-09-13 23:33:00'),(22,5,8,'Chuc team may man! 3 tuan du neu moi ngay commit deu dan.','2026-09-14 23:33:00'),(23,6,1,'Thuc tap o do thu nhap tot khong ban? Minh dang tim cho thuc tap.','2026-09-11 23:33:00'),(24,6,2,'Minh cung vua ket thuc dot thuc tap tuan truoc. Cam giac nho lam nhi!','2026-09-12 23:33:00'),(25,6,4,'Ban chia se tips xin thuc tap duoc khong? Minh gui CV mai khong duoc call.','2026-09-13 23:33:00'),(26,6,5,'3 thang thuc tap hoc duoc nhieu hon 1 nam hoc ly thuyet dung khong?','2026-09-13 23:33:00'),(27,6,7,'Chuc ban som co viec full-time nhe! Kinh nghiem nhu vay de xin viec lam.','2026-09-14 23:33:00'),(28,7,2,'Chu nhat thu vien dong cua ban oi. Thu 2 den Thu 6 moi mo, tu 7h30 den 17h.','2026-09-12 23:33:00'),(29,7,4,'Ngoai thu vien truong thi thu vien quan 9 cung co nhieu sach hoc tot lam!','2026-09-12 23:33:00'),(30,7,6,'Ban can sach gi? Minh co the chia file PDF cho neu khong tim duoc ban in.','2026-09-13 23:33:00'),(31,7,9,'Thu vien C2 tang 3 it nguoi hon, yen tinh hon de hoc nhe!','2026-09-14 23:33:00'),(32,8,1,'Respect! Minh cung muon thu HackTheBox nhung ngai kho qua. Loi khuyen cho nguoi moi?','2026-09-12 23:33:00'),(33,8,4,'Web Exploitation la challenge minh thay kho nhat. Ban dung tool gi vay?','2026-09-13 23:33:00'),(34,8,6,'Minh biet Python mot chut, vay co the bat dau CTF duoc khong?','2026-09-13 23:33:00'),(35,8,5,'Minh khong hieu gi ve hacking nhung nghe hao hung lam!','2026-09-14 23:33:00'),(36,8,2,'Ban co tham gia team CTF chua? CLB Cybersecurity SPKT hay to chuc.','2026-09-14 23:33:00'),(37,8,3,'Flag la gi khong? Just kidding haha','2026-09-14 23:33:00'),(38,8,9,'Very impressive! Toi khong hieu ky thuat nhung day la achievement lon.','2026-09-14 23:33:00'),(39,9,1,'Cam on ban nhieu! Minh dang can tai lieu cho muc tieu 7.0 nay. DM ngay!','2026-09-13 23:33:00'),(40,9,2,'Co app luyen speaking tot khong? Minh yeu nhat phan nay.','2026-09-13 23:33:00'),(41,9,3,'Ban dang o band may roi? Share kinh nghiem dat diem cao di!','2026-09-13 23:33:00'),(42,9,4,'IELTS Listening thi podcast nao hay nhat? BBC hay VOA?','2026-09-14 23:33:00'),(43,9,6,'Minh khong can IELTS nhung van follow de hoc tieng Anh chuyen nganh ky thuat.','2026-09-14 23:33:00'),(44,9,7,'Ban co khoa hoc nao recommend cho Writing task 2 khong?','2026-09-14 23:33:00'),(45,9,8,'DM ban ngay, can tai lieu cho ky thi thang sau!','2026-09-14 23:33:00'),(46,9,10,'Cam on ban da share! Rat huu ich cho cac ban khong du tien hoc trung tam.','2026-09-14 23:33:00'),(47,9,9,'Bo sung them: app Duolingo van tot de duy tri thoi quen hoc hang ngay nha!','2026-09-14 23:33:00'),(48,10,2,'Sketch dep qua! Vuon dung y tuong hay, them panel nang luong mat troi nua thi hoan hao.','2026-09-13 23:33:00'),(49,10,4,'Thiet ke sustainable dang la trend lon. Ban co tinh toan ve nang luong chua?','2026-09-13 23:33:00'),(50,10,5,'Y tuong nha o xa hoi nhung van dep va xanh, rat can thiet cho do thi VN!','2026-09-14 23:33:00'),(51,11,1,'Quan nao gan cong B nhat ban? Minh hay ra do an trua.','2026-09-14 23:33:00'),(52,11,3,'Bun bo Hue tai cong A ngon khong ban oi? Hay chi la binh thuong?','2026-09-14 23:33:00'),(53,11,4,'Com tam thi o cho nao ngon nhat? So sanh di!','2026-09-14 23:33:00'),(54,11,6,'Toi vote cho quan chao ga goc duong To Vinh Dien, 20k mot to day du.','2026-09-14 23:33:00'),(55,11,7,'An ngon khong lo beo hihi. Thanks ban da review!','2026-09-14 23:33:00'),(56,11,8,'Co quan chay khong? Minh dang thuc hien an chay vao thu 2.','2026-09-14 23:33:00'),(57,11,9,'Them quan tra sua 25k vao list nha! Uong ma khong lo ngheo.','2026-09-14 23:33:00'),(58,11,10,'Lan nao cung an com tu nau. Phai thu doi vi thoi!','2026-09-14 23:33:00'),(59,12,1,'Design trong clean va modern. Mau sac chon rat hop voi thi truong Viet.','2026-09-14 23:33:00'),(60,12,2,'UX flow thanh toan hon nhieu step. User co the bo cuoc o buoc 3 do.','2026-09-14 23:33:00'),(61,12,6,'Nut CTA mau noi hon chut nua se tot hon. Con lai thi tuyet!','2026-09-14 23:33:00'),(62,12,8,'Font chon dep lam. San-serif trong professional hon serif nhieu.','2026-09-14 23:33:00'),(63,12,9,'Ban co nghi den accessibility cho nguoi cao tuoi chua? Size font hoi nho.','2026-09-14 23:33:00'),(64,13,1,'Home server nghe ngau qua! Ban ton bao nhieu dien moi thang?','2026-09-14 23:33:00'),(65,13,2,'Pi-hole la gi vay? Chan quang cao nhu the nao?','2026-09-14 23:33:00'),(66,13,4,'Home Assistant setup mat bao lau? Ban document lai ra tutorial duoc khong?','2026-09-14 23:33:00'),(67,13,8,'NAS ban dung bao nhieu o cung? RAID 1 hay RAID 5?','2026-09-14 23:33:00'),(68,13,3,'VPN tu host thi bao mat hon dich vu thuong mai chu? Toc do ra sao?','2026-09-14 23:33:00'),(69,13,10,'Minh muon lam tuong tu nhung khong biet bat dau tu dau. Co video huong dan khong?','2026-09-14 23:33:00'),(70,14,1,'Minh muon tham gia! Workshop thu 7 luc may gio?','2026-09-14 23:33:00'),(71,14,4,'CLB co nhan thanh vien khong phai nganh Co khi/Dien tu khong?','2026-09-14 23:33:00'),(72,14,5,'Minh hoc Ngoai ngu nhung rat thich Robot. Co duoc tham gia khong a?','2026-09-14 23:33:00'),(73,14,8,'Co can dong phi thanh vien khong? Va can mang dung cu gi?','2026-09-14 23:33:00'),(74,14,2,'Tag ban nay vao day, hay hoi ve Robotics lam!','2026-09-14 23:33:00'),(75,14,9,'Kien truc nhu minh co the tham gia ve phan thiet ke vo robot khong nhi?','2026-09-14 23:33:00'),(76,14,10,'Dang ky online khong hay phai den truc tiep?','2026-09-14 23:33:00'),(77,14,6,'Moi nganh deu chao don! Cu den workshop thu 7 nhe, C206 luc 8h sang.','2026-09-14 23:33:00'),(78,15,2,'100 followers chi la buoc khoi dau! Series Spring Boot dang rat duoc don nhan.','2026-09-14 23:33:00'),(79,15,4,'Ban co lam video ve JPA/Hibernate khong? Minh dang hoc phan do kho qua.','2026-09-14 23:33:00'),(80,15,6,'Subscribe roi! Cho series microservices cua ban day.','2026-09-14 23:33:00'),(81,15,3,'Kenh nao vay? Share link di de minh follow luon!','2026-09-14 23:33:00'),(82,15,5,'Chuc mung! Tiep tuc chia se kien thuc cho cong dong nhe.','2026-09-14 23:33:00'),(83,15,7,'Cam on ban da chia se kien thuc mien phi cho moi nguoi!','2026-09-14 23:33:00'),(84,15,8,'Hy vong ban cung cover Security trong Spring Boot nhe. Rat quan trong!','2026-09-14 23:33:00'),(85,15,9,'Du khong phai IT nhung minh van follow vi noi dung hay qua.','2026-09-14 23:33:00'),(86,15,10,'Sap co video moi chua? Dang cho series tiep theo!','2026-09-14 23:33:00'),(87,15,11,'Khuyen khich tinh than chia se kien thuc nay! Keep it up.','2026-09-14 23:33:00'),(88,15,1,'test 1','2026-09-14 23:42:05'),(89,15,1,'test 2','2026-09-15 00:53:10'),(90,16,1,'test 2','2026-09-15 00:55:10'),(91,15,1,'tuyệt vời quá','2026-09-15 01:32:51'),(92,13,1,'test lần nữa','2026-09-15 01:36:59'),(93,13,1,'Test lần nữa nữa','2026-09-15 01:37:16'),(94,14,1,'okay','2026-09-17 08:06:25'),(95,1,11,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 13:27:58'),(96,4,11,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 12:54:58'),(97,8,11,'Cho mình xin link tài liệu với được không?','2026-09-18 12:10:58'),(98,11,11,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 11:37:58'),(99,18,11,'Cho mình xin link tài liệu với được không?','2026-09-18 10:20:58'),(100,22,11,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 09:36:58'),(101,25,11,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 09:03:58'),(102,29,11,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 08:19:58'),(103,32,11,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 07:46:58'),(104,36,11,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 07:02:58'),(105,39,11,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 06:29:58'),(106,43,11,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 05:45:58'),(107,2,15,'Cho mình xin link tài liệu với được không?','2026-09-18 12:56:58'),(108,5,15,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 12:23:58'),(109,9,15,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 11:39:58'),(110,12,15,'Cho mình xin link tài liệu với được không?','2026-09-18 11:06:58'),(111,16,15,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 10:22:58'),(112,19,15,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 09:49:58'),(113,23,15,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 09:05:58'),(114,26,15,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 08:32:58'),(115,30,15,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 07:48:58'),(116,37,15,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 06:31:58'),(117,40,15,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 05:58:58'),(118,44,15,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 05:14:58'),(119,4,16,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 12:29:58'),(120,7,16,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 11:56:58'),(121,11,16,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 11:12:58'),(122,14,16,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 10:39:58'),(123,18,16,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 09:55:58'),(124,21,16,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 09:22:58'),(125,25,16,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 08:38:58'),(126,28,16,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 08:05:58'),(127,32,16,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 07:21:58'),(128,35,16,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 06:48:58'),(129,39,16,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 06:04:58'),(130,42,16,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 05:31:58'),(131,2,17,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 12:46:58'),(132,6,17,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 12:02:58'),(133,9,17,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 11:29:58'),(134,13,17,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 10:45:58'),(135,16,17,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 10:12:58'),(136,20,17,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 09:28:58'),(137,23,17,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 08:55:58'),(138,27,17,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 08:11:58'),(139,30,17,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 07:38:58'),(140,34,17,'Cho mình xin link tài liệu với được không?','2026-09-18 06:54:58'),(141,37,17,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 06:21:58'),(142,41,17,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 05:37:58'),(143,1,18,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 12:52:58'),(144,4,18,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 12:19:58'),(145,8,18,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 11:35:58'),(146,11,18,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 11:02:58'),(147,15,18,'Cho mình xin link tài liệu với được không?','2026-09-18 10:18:58'),(148,18,18,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 09:45:58'),(149,22,18,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 09:01:58'),(150,25,18,'Cho mình xin link tài liệu với được không?','2026-09-18 08:28:58'),(151,29,18,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 07:44:58'),(152,32,18,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 07:11:58'),(153,36,18,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 06:27:58'),(154,39,18,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 05:54:58'),(155,19,1,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 10:59:58'),(156,23,1,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 10:15:58'),(157,26,1,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 09:42:58'),(158,30,1,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 08:58:58'),(159,33,1,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 08:25:58'),(160,37,1,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 07:41:58'),(161,40,1,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 07:08:58'),(162,44,1,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 06:24:58'),(163,6,3,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 13:12:58'),(164,16,3,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 11:22:58'),(165,20,3,'Cho mình xin link tài liệu với được không?','2026-09-18 10:38:58'),(166,23,3,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 10:05:58'),(167,27,3,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 09:21:58'),(168,30,3,'Cho mình xin link tài liệu với được không?','2026-09-18 08:48:58'),(169,34,3,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 08:04:58'),(170,37,3,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 07:31:58'),(171,41,3,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 06:47:58'),(172,44,3,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 06:14:58'),(173,3,19,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 12:25:58'),(174,6,19,'Cho mình xin link tài liệu với được không?','2026-09-18 11:52:58'),(175,10,19,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 11:08:58'),(176,13,19,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 10:35:58'),(178,20,19,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 09:18:58'),(179,27,19,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 08:01:58'),(180,31,19,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 07:17:58'),(181,34,19,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 06:44:58'),(182,41,19,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 05:27:58'),(183,45,19,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 04:43:58'),(184,1,20,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 12:42:58'),(185,5,20,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 11:58:58'),(186,8,20,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 11:25:58'),(187,12,20,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 10:41:58'),(188,15,20,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 10:08:58'),(189,19,20,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 09:24:58'),(190,22,20,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 08:51:58'),(191,26,20,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 08:07:58'),(192,29,20,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 07:34:58'),(193,33,20,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 06:50:58'),(194,36,20,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 06:17:58'),(195,40,20,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 05:33:58'),(196,43,20,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 05:00:58'),(197,2,8,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 13:31:58'),(198,16,8,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 10:57:58'),(199,19,8,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 10:24:58'),(200,23,8,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 09:40:58'),(201,26,8,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 09:07:58'),(202,30,8,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 08:23:58'),(203,33,8,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 07:50:58'),(204,37,8,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 07:06:58'),(205,40,8,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 06:33:58'),(206,44,8,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 05:49:58'),(207,3,21,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 12:15:58'),(208,7,21,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 11:31:58'),(209,10,21,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 10:58:58'),(210,14,21,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 10:14:58'),(212,21,21,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 08:57:58'),(213,24,21,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 08:24:58'),(214,28,21,'Cho mình xin link tài liệu với được không?','2026-09-18 07:40:58'),(215,31,21,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 07:07:58'),(216,35,21,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 06:23:58'),(217,38,21,'Cho mình xin link tài liệu với được không?','2026-09-18 05:50:58'),(218,42,21,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 05:06:58'),(219,45,21,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 04:33:58'),(220,2,22,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 12:21:58'),(221,5,22,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 11:48:58'),(222,9,22,'Cho mình xin link tài liệu với được không?','2026-09-18 11:04:58'),(223,12,22,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 10:31:58'),(224,16,22,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 09:47:58'),(225,19,22,'Cho mình xin link tài liệu với được không?','2026-09-18 09:14:58'),(226,23,22,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 08:30:58'),(227,30,22,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 07:13:58'),(228,33,22,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 06:40:58'),(229,37,22,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 05:56:58'),(230,40,22,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 05:23:58'),(231,44,22,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 04:39:58'),(232,18,2,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 11:05:58'),(233,21,2,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 10:32:58'),(234,25,2,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 09:48:58'),(235,28,2,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 09:15:58'),(236,32,2,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 08:31:58'),(237,35,2,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 07:58:58'),(238,39,2,'Cho mình xin link tài liệu với được không?','2026-09-18 07:14:58'),(239,42,2,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 06:41:58'),(240,4,23,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 11:54:58'),(241,7,23,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 11:21:58'),(242,11,23,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 10:37:58'),(243,14,23,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 10:04:58'),(244,18,23,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 09:20:58'),(245,21,23,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 08:47:58'),(246,25,23,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 08:03:58'),(247,28,23,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 07:30:58'),(248,32,23,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 06:46:58'),(249,35,23,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 06:13:58'),(250,39,23,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 05:29:58'),(251,42,23,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 04:56:58'),(252,18,4,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 10:55:58'),(253,22,4,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 10:11:58'),(254,25,4,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 09:38:58'),(255,29,4,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 08:54:58'),(256,32,4,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 08:21:58'),(257,36,4,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 07:37:58'),(258,39,4,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 07:04:58'),(259,43,4,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 06:20:58'),(260,2,24,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 12:11:58'),(261,6,24,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 11:27:58'),(262,9,24,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 10:54:58'),(263,13,24,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 10:10:58'),(264,16,24,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 09:37:58'),(265,20,24,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 08:53:58'),(266,23,24,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 08:20:58'),(267,27,24,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 07:36:58'),(268,30,24,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 07:03:58'),(269,34,24,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 06:19:58'),(270,37,24,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 05:46:58'),(271,41,24,'Cho mình xin link tài liệu với được không?','2026-09-18 05:02:58'),(272,44,24,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 04:29:58'),(273,3,5,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 13:35:58'),(274,13,5,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 11:45:58'),(276,20,5,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 10:28:58'),(277,24,5,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 09:44:58'),(278,27,5,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 09:11:58'),(279,31,5,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 08:27:58'),(280,34,5,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 07:54:58'),(281,38,5,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 07:10:58'),(282,41,5,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 06:37:58'),(283,45,5,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 05:53:58'),(284,3,14,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 12:50:58'),(285,7,14,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 12:06:58'),(286,10,14,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 11:33:58'),(287,14,14,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 10:49:58'),(289,21,14,'Cho mình xin link tài liệu với được không?','2026-09-18 09:32:58'),(290,24,14,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 08:59:58'),(291,28,14,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 08:15:58'),(292,31,14,'Cho mình xin link tài liệu với được không?','2026-09-18 07:42:58'),(293,35,14,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 06:58:58'),(294,38,14,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 06:25:58'),(295,42,14,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 05:41:58'),(296,45,14,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 05:08:58'),(297,1,25,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 12:17:58'),(298,4,25,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 11:44:58'),(299,8,25,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 11:00:58'),(300,11,25,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 10:27:58'),(301,15,25,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 09:43:58'),(302,18,25,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 09:10:58'),(303,22,25,'Cho mình xin link tài liệu với được không?','2026-09-18 08:26:58'),(304,25,25,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 07:53:58'),(305,29,25,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 07:09:58'),(306,32,25,'Cho mình xin link tài liệu với được không?','2026-09-18 06:36:58'),(307,36,25,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 05:52:58'),(308,39,25,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 05:19:58'),(309,43,25,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 04:35:58'),(310,2,10,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 13:21:58'),(311,6,10,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 12:37:58'),(312,16,10,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 10:47:58'),(313,20,10,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 10:03:58'),(314,23,10,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 09:30:58'),(315,27,10,'Cho mình xin link tài liệu với được không?','2026-09-18 08:46:58'),(316,30,10,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 08:13:58'),(317,34,10,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 07:29:58'),(318,37,10,'Cho mình xin link tài liệu với được không?','2026-09-18 06:56:58'),(319,41,10,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 06:12:58'),(320,44,10,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 05:39:58'),(321,19,6,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 10:34:58'),(322,22,6,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 10:01:58'),(323,26,6,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 09:17:58'),(324,29,6,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 08:44:58'),(325,33,6,'Cho mình xin link tài liệu với được không?','2026-09-18 08:00:58'),(326,36,6,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 07:27:58'),(327,40,6,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 06:43:58'),(328,43,6,'Cho mình xin link tài liệu với được không?','2026-09-18 06:10:58'),(329,3,26,'Cho mình xin link tài liệu với được không?','2026-09-18 11:50:58'),(330,6,26,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 11:17:58'),(331,10,26,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 10:33:58'),(332,13,26,'Cho mình xin link tài liệu với được không?','2026-09-18 10:00:58'),(334,20,26,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 08:43:58'),(335,24,26,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 07:59:58'),(336,27,26,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 07:26:58'),(337,34,26,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 06:09:58'),(338,38,26,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 05:25:58'),(339,41,26,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 04:52:58'),(340,3,7,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 13:25:58'),(341,7,7,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 12:41:58'),(342,10,7,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 12:08:58'),(343,14,7,'Cho mình xin link tài liệu với được không?','2026-09-18 11:24:58'),(345,21,7,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 10:07:58'),(346,24,7,'Cho mình xin link tài liệu với được không?','2026-09-18 09:34:58'),(347,28,7,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 08:50:58'),(348,31,7,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 08:17:58'),(349,35,7,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 07:33:58'),(350,38,7,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 07:00:58'),(351,42,7,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 06:16:58'),(352,45,7,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 05:43:58'),(353,4,9,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 13:04:58'),(354,18,9,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 10:30:58'),(355,21,9,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 09:57:58'),(356,25,9,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 09:13:58'),(357,28,9,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 08:40:58'),(358,32,9,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 07:56:58'),(359,35,9,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 07:23:58'),(360,39,9,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 06:39:58'),(361,42,9,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 06:06:58'),(362,1,27,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 12:07:58'),(363,5,27,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 11:23:58'),(364,8,27,'Chúc mừng bạn nhé, xứng đáng mà!','2026-09-18 10:50:58'),(365,12,27,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 10:06:58'),(366,15,27,'Nhìn chất lượng thật sự, học hỏi nhiều.','2026-09-18 09:33:58'),(367,19,27,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 08:49:58'),(368,22,27,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 08:16:58'),(369,26,27,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 07:32:58'),(370,29,27,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 06:59:58'),(371,33,27,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 06:15:58'),(372,36,27,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 05:42:58'),(373,40,27,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 04:58:58'),(374,43,27,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 04:25:58'),(375,3,28,'Mình lưu lại để tối về đọc kỹ, cảm ơn bạn.','2026-09-18 11:40:58'),(376,7,28,'Quá đỉnh luôn, cố lên nha bạn!','2026-09-18 10:56:58'),(377,10,28,'Bạn làm bằng công cụ gì vậy? Chỉ mình với.','2026-09-18 10:23:58'),(378,14,28,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 09:39:58'),(380,21,28,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 08:22:58'),(381,24,28,'Cuối kỳ này chắc cả trường đều bận như này.','2026-09-18 07:49:58'),(382,28,28,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 07:05:58'),(383,31,28,'Mình cũng muốn tham gia, inbox cho mình nhé!','2026-09-18 06:32:58'),(384,35,28,'Cho mình xin link tài liệu với được không?','2026-09-18 05:48:58'),(385,38,28,'Hay quá bạn ơi, cảm ơn đã chia sẻ nha!','2026-09-18 05:15:58'),(386,42,28,'Công nhận, mình cũng đang gặp đúng vấn đề này.','2026-09-18 04:31:58'),(387,45,28,'Cho mình xin link tài liệu với được không?','2026-09-18 03:58:58'),(388,11,1,'like','2026-10-08 09:03:01');
/*!40000 ALTER TABLE `comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `conversation_members`
--

DROP TABLE IF EXISTS `conversation_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversation_members` (
  `conversation_id` int NOT NULL,
  `user_id` int NOT NULL,
  `role` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'MEMBER',
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_read_message_id` int NOT NULL DEFAULT '0',
  `last_delivered_message_id` int NOT NULL DEFAULT '0',
  `cleared_message_id` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`conversation_id`,`user_id`),
  KEY `ix_cm_user` (`user_id`),
  CONSTRAINT `fk_cm_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`conversation_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cm_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversation_members`
--

LOCK TABLES `conversation_members` WRITE;
/*!40000 ALTER TABLE `conversation_members` DISABLE KEYS */;
INSERT INTO `conversation_members` VALUES (1,1,'MEMBER','2026-09-14 21:33:00',4,4,0),(1,2,'MEMBER','2026-09-14 21:33:00',4,4,0),(2,1,'MEMBER','2026-09-13 23:33:00',8,8,0),(2,3,'MEMBER','2026-09-13 23:33:00',7,8,0),(3,2,'MEMBER','2026-09-12 23:33:00',11,11,0),(3,5,'MEMBER','2026-09-12 23:33:00',11,11,0),(4,4,'MEMBER','2026-09-13 23:33:00',14,15,0),(4,8,'MEMBER','2026-09-13 23:33:00',15,15,0),(5,3,'MEMBER','2026-09-14 18:33:00',18,18,0),(5,6,'MEMBER','2026-09-14 18:33:00',18,18,0),(6,4,'MEMBER','2026-09-18 14:21:59',22,23,0),(6,22,'MEMBER','2026-09-18 14:21:59',23,23,0),(7,4,'MEMBER','2026-09-18 12:58:59',26,27,0),(7,18,'MEMBER','2026-09-18 12:58:59',27,27,0),(8,4,'MEMBER','2026-09-18 10:33:59',29,30,0),(8,15,'MEMBER','2026-09-18 10:33:59',30,30,0),(9,4,'MEMBER','2026-09-18 01:53:59',33,33,0),(9,28,'MEMBER','2026-09-18 01:53:59',33,33,0),(10,1,'MEMBER','2026-10-02 08:59:20',0,0,0),(10,6,'MEMBER','2026-10-02 08:59:20',0,0,0),(11,1,'MEMBER','2026-10-08 08:12:57',0,0,0),(11,7,'MEMBER','2026-10-08 08:12:57',0,0,0),(12,14,'MEMBER','2026-10-08 08:22:40',34,34,0),(12,33,'MEMBER','2026-10-08 08:22:40',34,34,0),(13,1,'OWNER','2026-10-08 08:37:48',51,51,0),(13,2,'MEMBER','2026-10-08 08:37:48',0,0,0),(13,3,'MEMBER','2026-10-08 08:37:48',0,0,0),(13,4,'MEMBER','2026-10-08 08:37:48',43,43,0),(13,5,'MEMBER','2026-10-08 08:37:48',0,0,0),(13,33,'MEMBER','2026-10-08 08:38:22',38,38,0),(13,34,'MEMBER','2026-10-18 16:48:17',51,51,0),(14,1,'OWNER','2026-10-08 09:07:48',40,40,0),(14,6,'MEMBER','2026-10-08 09:07:48',0,0,0),(14,7,'MEMBER','2026-10-08 09:07:48',0,0,0),(14,33,'MEMBER','2026-10-08 09:07:48',0,0,0),(17,1,'MEMBER','2026-10-18 16:28:06',45,45,0),(17,14,'MEMBER','2026-10-18 16:28:06',45,45,0),(18,1,'MEMBER','2026-10-18 16:47:43',48,48,0),(18,34,'MEMBER','2026-10-18 16:47:43',48,48,0);
/*!40000 ALTER TABLE `conversation_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `conversations`
--

DROP TABLE IF EXISTS `conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversations` (
  `conversation_id` int NOT NULL AUTO_INCREMENT,
  `user_a_id` int DEFAULT NULL,
  `user_b_id` int DEFAULT NULL,
  `last_message_at` datetime DEFAULT NULL,
  `is_group` tinyint(1) NOT NULL DEFAULT '0',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by` int DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`conversation_id`),
  UNIQUE KEY `ux_conversations_pair` (`user_a_id`,`user_b_id`),
  KEY `fk_conversations_user_a` (`user_a_id`),
  KEY `fk_conversations_user_b` (`user_b_id`),
  KEY `fk_conversations_creator` (`created_by`),
  CONSTRAINT `fk_conversations_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_conversations_user_a` FOREIGN KEY (`user_a_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_conversations_user_b` FOREIGN KEY (`user_b_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversations`
--

LOCK TABLES `conversations` WRITE;
/*!40000 ALTER TABLE `conversations` DISABLE KEYS */;
INSERT INTO `conversations` VALUES (1,1,2,'2026-09-14 21:33:00',0,NULL,NULL,NULL),(2,1,3,'2026-09-13 23:33:00',0,NULL,NULL,NULL),(3,2,5,'2026-09-12 23:33:00',0,NULL,NULL,NULL),(4,4,8,'2026-09-13 23:33:00',0,NULL,NULL,NULL),(5,3,6,'2026-09-14 18:33:00',0,NULL,NULL,NULL),(6,4,22,'2026-09-18 14:21:59',0,NULL,NULL,NULL),(7,4,18,'2026-09-18 12:58:59',0,NULL,NULL,NULL),(8,4,15,'2026-09-18 10:33:59',0,NULL,NULL,NULL),(9,4,28,'2026-09-18 01:53:59',0,NULL,NULL,NULL),(10,1,6,NULL,0,NULL,NULL,NULL),(11,1,7,NULL,0,NULL,1,'2026-10-08 08:12:57'),(12,14,33,'2026-10-08 08:23:27',0,NULL,33,'2026-10-08 08:22:40'),(13,NULL,NULL,'2026-10-18 16:48:51',1,'web',1,'2026-10-08 08:37:48'),(14,NULL,NULL,'2026-10-08 09:08:03',1,'Test web',1,'2026-10-08 09:07:48'),(17,1,14,'2026-10-18 16:28:24',0,NULL,1,'2026-10-18 16:28:06'),(18,1,34,'2026-10-18 16:48:14',0,NULL,1,'2026-10-18 16:47:43');
/*!40000 ALTER TABLE `conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `friendships`
--

DROP TABLE IF EXISTS `friendships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `friendships` (
  `friendship_id` int NOT NULL AUTO_INCREMENT,
  `requester_id` int NOT NULL,
  `receiver_id` int NOT NULL,
  `status` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `accepted_at` datetime DEFAULT NULL,
  `user_lo` int GENERATED ALWAYS AS (least(`requester_id`,`receiver_id`)) VIRTUAL,
  `user_hi` int GENERATED ALWAYS AS (greatest(`requester_id`,`receiver_id`)) VIRTUAL,
  PRIMARY KEY (`friendship_id`),
  UNIQUE KEY `ux_friendships_pair` (`user_lo`,`user_hi`),
  KEY `ix_friendships_receiver` (`receiver_id`),
  KEY `fk_friendships_requester` (`requester_id`),
  CONSTRAINT `fk_friendships_receiver` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_friendships_requester` FOREIGN KEY (`requester_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=45 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `friendships`
--

LOCK TABLES `friendships` WRITE;
/*!40000 ALTER TABLE `friendships` DISABLE KEYS */;
INSERT INTO `friendships` (`friendship_id`, `requester_id`, `receiver_id`, `status`, `created_at`, `accepted_at`) VALUES (1,1,2,'accepted','2026-08-15 23:33:00','2026-08-15 23:33:00'),(2,1,3,'accepted','2026-08-17 23:33:00','2026-08-17 23:33:00'),(3,1,4,'accepted','2026-08-20 23:33:00','2026-08-20 23:33:00'),(4,1,6,'accepted','2026-08-25 23:33:00','2026-08-25 23:33:00'),(5,2,3,'accepted','2026-08-27 23:33:00','2026-08-27 23:33:00'),(6,2,5,'accepted','2026-08-30 23:33:00','2026-08-30 23:33:00'),(7,2,7,'accepted','2026-09-02 23:33:00','2026-09-02 23:33:00'),(8,3,6,'accepted','2026-09-04 23:33:00','2026-09-04 23:33:00'),(9,4,5,'accepted','2026-09-06 23:33:00','2026-09-06 23:33:00'),(10,4,8,'accepted','2026-09-07 23:33:00','2026-09-07 23:33:00'),(11,5,9,'accepted','2026-09-08 23:33:00','2026-09-08 23:33:00'),(12,6,10,'accepted','2026-09-09 23:33:00','2026-09-09 23:33:00'),(13,1,8,'pending','2026-09-13 23:33:00',NULL),(14,1,9,'pending','2026-09-12 23:33:00',NULL),(15,7,10,'pending','2026-09-13 23:33:00',NULL),(16,1,5,'accepted','2026-09-14 23:38:07','2026-09-14 23:38:07'),(17,1,7,'accepted','2026-09-15 01:38:34','2026-09-15 01:38:34'),(18,4,22,'accepted','2026-08-09 14:33:58','2026-08-09 14:33:58'),(19,4,18,'accepted','2026-08-14 14:33:58','2026-08-14 14:33:58'),(20,4,15,'accepted','2026-08-19 14:33:58','2026-08-19 14:33:58'),(21,4,25,'accepted','2026-08-23 14:33:58','2026-08-23 14:33:58'),(22,4,28,'accepted','2026-08-27 14:33:58','2026-08-27 14:33:58'),(23,4,23,'accepted','2026-08-31 14:33:58','2026-08-31 14:33:58'),(24,4,19,'accepted','2026-09-03 14:33:58','2026-09-03 14:33:58'),(25,4,20,'accepted','2026-09-07 14:33:58','2026-09-07 14:33:58'),(26,27,4,'pending','2026-09-18 08:33:58',NULL),(27,16,4,'pending','2026-09-17 18:33:58',NULL),(28,26,4,'pending','2026-09-16 18:33:58',NULL),(29,22,18,'accepted','2026-08-29 14:33:58','2026-08-29 14:33:58'),(30,22,25,'accepted','2026-08-29 14:33:58','2026-08-29 14:33:58'),(31,18,15,'accepted','2026-08-29 14:33:58','2026-08-29 14:33:58'),(32,19,21,'accepted','2026-08-29 14:33:58','2026-08-29 14:33:58'),(33,23,28,'accepted','2026-08-29 14:33:58','2026-08-29 14:33:58'),(34,20,24,'accepted','2026-08-29 14:33:58','2026-08-29 14:33:58'),(35,17,26,'accepted','2026-08-29 14:33:58','2026-08-29 14:33:58'),(36,33,1,'accepted','2026-10-08 08:16:54','2026-10-08 08:18:22'),(37,33,14,'accepted','2026-10-08 08:17:36','2026-10-08 08:17:59'),(43,1,14,'accepted','2026-10-18 16:27:20','2026-10-18 16:27:33'),(44,34,1,'accepted','2026-10-18 16:47:12','2026-10-18 16:47:23');
/*!40000 ALTER TABLE `friendships` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_VALUE_ON_ZERO' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`avnadmin`@`%`*/ /*!50003 TRIGGER `trg_friendships_bi` BEFORE INSERT ON `friendships` FOR EACH ROW SET NEW.user_lo = IF(NEW.user_lo IS NOT NULL, NEW.user_lo, IF(NEW.requester_id < NEW.receiver_id, NEW.requester_id, NEW.receiver_id)), NEW.user_hi = IF(NEW.user_hi IS NOT NULL, NEW.user_hi, IF(NEW.requester_id < NEW.receiver_id, NEW.receiver_id, NEW.requester_id)) */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `group_members`
--

DROP TABLE IF EXISTS `group_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `group_members` (
  `group_id` int NOT NULL,
  `user_id` int NOT NULL,
  `role` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'MEMBER',
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE',
  PRIMARY KEY (`group_id`,`user_id`),
  KEY `fk_gm_user` (`user_id`),
  CONSTRAINT `fk_gm_group` FOREIGN KEY (`group_id`) REFERENCES `groups_tbl` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_gm_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_members`
--

LOCK TABLES `group_members` WRITE;
/*!40000 ALTER TABLE `group_members` DISABLE KEYS */;
INSERT INTO `group_members` VALUES (1,1,'MEMBER','2026-07-26 23:33:00','ACTIVE'),(1,3,'OWNER','2026-07-16 23:33:00','ACTIVE'),(1,4,'MEMBER','2026-08-25 23:33:00','ACTIVE'),(1,5,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(1,6,'MEMBER','2026-07-21 23:33:00','ACTIVE'),(1,8,'MEMBER','2026-08-15 23:33:00','ACTIVE'),(1,9,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(1,10,'MEMBER','2026-08-05 23:33:00','ACTIVE'),(1,17,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(1,21,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(1,25,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(2,1,'OWNER','2026-07-31 23:33:00','ACTIVE'),(2,2,'MEMBER','2026-09-04 23:33:00','ACTIVE'),(2,3,'MEMBER','2026-08-30 23:33:00','ACTIVE'),(2,4,'MEMBER','2026-08-05 23:33:00','ACTIVE'),(2,5,'MEMBER','2026-09-09 23:33:00','ACTIVE'),(2,6,'MEMBER','2026-08-25 23:33:00','ACTIVE'),(2,8,'MEMBER','2026-08-10 23:33:00','ACTIVE'),(2,10,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(2,14,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(2,18,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(2,22,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(2,26,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(3,2,'MEMBER','2026-09-04 23:33:00','ACTIVE'),(3,3,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(3,4,'MEMBER','2026-08-20 23:33:00','ACTIVE'),(3,7,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(3,9,'OWNER','2026-08-15 23:33:00','ACTIVE'),(3,11,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(3,15,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(3,19,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(3,23,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(3,27,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(4,2,'MEMBER','2026-08-27 23:33:00','ACTIVE'),(4,4,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(4,5,'OWNER','2026-08-25 23:33:00','ACTIVE'),(4,7,'MEMBER','2026-09-09 23:33:00','ACTIVE'),(4,8,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(4,9,'MEMBER','2026-09-04 23:33:00','ACTIVE'),(4,16,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(4,20,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(4,24,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(4,28,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(5,1,'MEMBER','2026-09-02 23:33:00','ACTIVE'),(5,4,'MEMBER','2026-09-06 23:33:00','ACTIVE'),(5,5,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(5,8,'OWNER','2026-08-30 23:33:00','ACTIVE'),(5,9,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(5,17,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(5,21,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(5,25,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(6,2,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(6,4,'OWNER','2026-09-03 14:33:58','ACTIVE'),(6,6,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(6,10,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(6,14,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(6,18,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(6,22,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(6,26,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(7,3,'OWNER','2026-09-08 14:33:58','ACTIVE'),(7,7,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(7,11,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(7,15,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(7,19,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(7,23,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(7,27,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(8,4,'OWNER','2026-09-03 14:33:58','ACTIVE'),(8,8,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(8,16,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(8,20,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(8,24,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(8,28,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(9,1,'OWNER','2026-09-08 14:33:58','ACTIVE'),(9,5,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(9,9,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(9,17,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(9,21,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(9,25,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,2,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,4,'OWNER','2026-09-03 14:33:58','ACTIVE'),(10,6,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,10,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,14,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,18,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,22,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,26,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(10,33,'MEMBER','2026-10-08 08:21:57','ACTIVE'),(11,3,'OWNER','2026-09-08 14:33:58','ACTIVE'),(11,7,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(11,11,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(11,15,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(11,19,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(11,23,'MEMBER','2026-09-08 14:33:58','ACTIVE'),(11,27,'MEMBER','2026-09-08 14:33:58','ACTIVE');
/*!40000 ALTER TABLE `group_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `groups_tbl`
--

DROP TABLE IF EXISTS `groups_tbl`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `groups_tbl` (
  `group_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `category` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'STUDY',
  `cover_icon` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `member_count` int NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `privacy` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PUBLIC',
  `cover_image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`group_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `groups_tbl`
--

LOCK TABLES `groups_tbl` WRITE;
/*!40000 ALTER TABLE `groups_tbl` DISABLE KEYS */;
INSERT INTO `groups_tbl` VALUES (1,'CLB Robotics HCMUTE','Noi giao luu hoc hoi ve Robot va thi dau. Chao don moi dam me ky thuat!','CLUB','robot',11,'2026-07-16 23:33:00','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617052/uterspace_uploads/group_cover_1.jpg'),(2,'Hoi IT Sinh vien SPKT','Chia se tai lieu do an va kinh nghiem IT. Day la nha cua dan code.','STUDY','laptop',12,'2026-07-31 23:33:00','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617055/uterspace_uploads/group_cover_2.jpg'),(3,'Kien Truc Khong Gian Xanh','Danh cho cac ban yeu thiet ke kien truc va khong gian song ben vung.','STUDY','house',10,'2026-08-15 23:33:00','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617056/uterspace_uploads/group_cover_3.jpg'),(4,'CLB Tieng Anh HCMUTE','Luyen noi luyen viet chia se tai nguyen hoc Tieng Anh va cac ngon ngu.','CLUB','globe',10,'2026-08-25 23:33:00','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617056/uterspace_uploads/group_cover_4.jpg'),(5,'Cong Dong Cybersecurity SPKT','Trao doi ve bao mat thong tin CTF challenges tools va tin tuc security.','STUDY','shield',8,'2026-08-30 23:33:00','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617057/uterspace_uploads/group_cover_5.jpg'),(6,'Lập trình Web HCMUTE','Nơi trao đổi HTML, CSS, JavaScript và các đồ án môn Lập trình Web.','STUDY','💻',8,'2026-09-18 14:33:58','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617059/uterspace_uploads/group_cover_6.jpg'),(7,'CLB Sách & Cà phê','Mỗi tuần một cuốn sách, mỗi tháng một buổi offline.','CLUB','📚',7,'2026-09-18 14:33:58','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617059/uterspace_uploads/group_cover_7.jpg'),(8,'Góc Đồ án Cuối kỳ','Hỏi đáp, tìm đồng đội và chia sẻ tài liệu cho đồ án tốt nghiệp.','STUDY','🎓',6,'2026-09-18 14:33:58','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617061/uterspace_uploads/group_cover_8.jpg'),(9,'CLB Nhiếp ảnh UTE','Chia sẻ ảnh đẹp quanh trường và các buổi chụp chung cuối tuần.','CLUB','📷',6,'2026-09-18 14:33:58','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617061/uterspace_uploads/group_cover_9.jpg'),(10,'Việc làm & Thực tập IT','Tin tuyển dụng thực tập, fresher dành riêng cho sinh viên HCMUTE.','STUDY','💼',9,'2026-09-18 14:33:58','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617053/uterspace_uploads/group_cover_10.jpg'),(11,'CLB Bóng rổ HCMUTE','Tập luyện thứ 3 - 5 - 7 tại sân thể thao khu A.','CLUB','🏀',7,'2026-09-18 14:33:58','PUBLIC','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617053/uterspace_uploads/group_cover_11.jpg');
/*!40000 ALTER TABLE `groups_tbl` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `likes`
--

DROP TABLE IF EXISTS `likes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `likes` (
  `like_id` int NOT NULL AUTO_INCREMENT,
  `post_id` int NOT NULL,
  `user_id` int NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`like_id`),
  UNIQUE KEY `uq_likes` (`post_id`,`user_id`),
  KEY `ix_likes_user_id` (`user_id`),
  CONSTRAINT `fk_likes_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_likes_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=548 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `likes`
--

LOCK TABLES `likes` WRITE;
/*!40000 ALTER TABLE `likes` DISABLE KEYS */;
INSERT INTO `likes` VALUES (1,1,2,'2026-09-14 23:33:00'),(2,1,3,'2026-09-14 23:33:00'),(3,1,4,'2026-09-14 23:33:00'),(4,1,5,'2026-09-14 23:33:00'),(5,1,6,'2026-09-14 23:33:00'),(6,1,7,'2026-09-14 23:33:00'),(7,1,8,'2026-09-14 23:33:00'),(8,2,1,'2026-09-14 23:33:00'),(9,2,3,'2026-09-14 23:33:00'),(10,2,4,'2026-09-14 23:33:00'),(11,2,5,'2026-09-14 23:33:00'),(12,2,6,'2026-09-14 23:33:00'),(13,2,7,'2026-09-14 23:33:00'),(14,2,8,'2026-09-14 23:33:00'),(15,2,9,'2026-09-14 23:33:00'),(16,2,10,'2026-09-14 23:33:00'),(17,3,1,'2026-09-14 23:33:00'),(18,3,2,'2026-09-14 23:33:00'),(19,3,4,'2026-09-14 23:33:00'),(20,3,5,'2026-09-14 23:33:00'),(21,3,6,'2026-09-14 23:33:00'),(22,3,7,'2026-09-14 23:33:00'),(23,3,8,'2026-09-14 23:33:00'),(24,3,9,'2026-09-14 23:33:00'),(25,3,10,'2026-09-14 23:33:00'),(26,3,11,'2026-09-14 23:33:00'),(27,4,1,'2026-09-14 23:33:00'),(28,4,2,'2026-09-14 23:33:00'),(29,4,3,'2026-09-14 23:33:00'),(30,4,5,'2026-09-14 23:33:00'),(31,4,6,'2026-09-14 23:33:00'),(32,4,7,'2026-09-14 23:33:00'),(33,4,9,'2026-09-14 23:33:00'),(34,4,10,'2026-09-14 23:33:00'),(35,5,1,'2026-09-14 23:33:00'),(36,5,2,'2026-09-14 23:33:00'),(37,5,3,'2026-09-14 23:33:00'),(38,5,4,'2026-09-14 23:33:00'),(39,5,5,'2026-09-14 23:33:00'),(40,5,7,'2026-09-14 23:33:00'),(41,5,8,'2026-09-14 23:33:00'),(42,5,9,'2026-09-14 23:33:00'),(43,5,10,'2026-09-14 23:33:00'),(44,5,11,'2026-09-14 23:33:00'),(45,6,1,'2026-09-14 23:33:00'),(46,6,2,'2026-09-14 23:33:00'),(47,6,3,'2026-09-14 23:33:00'),(48,6,4,'2026-09-14 23:33:00'),(49,6,5,'2026-09-14 23:33:00'),(50,6,6,'2026-09-14 23:33:00'),(51,6,8,'2026-09-14 23:33:00'),(52,6,9,'2026-09-14 23:33:00'),(53,6,10,'2026-09-14 23:33:00'),(54,6,11,'2026-09-14 23:33:00'),(55,7,2,'2026-09-14 23:33:00'),(56,7,4,'2026-09-14 23:33:00'),(57,7,5,'2026-09-14 23:33:00'),(58,8,1,'2026-09-14 23:33:00'),(59,8,2,'2026-09-14 23:33:00'),(60,8,4,'2026-09-14 23:33:00'),(61,8,5,'2026-09-14 23:33:00'),(62,8,6,'2026-09-14 23:33:00'),(63,8,7,'2026-09-14 23:33:00'),(64,8,9,'2026-09-14 23:33:00'),(65,8,10,'2026-09-14 23:33:00'),(66,9,1,'2026-09-14 23:33:00'),(67,9,2,'2026-09-14 23:33:00'),(68,9,3,'2026-09-14 23:33:00'),(69,9,4,'2026-09-14 23:33:00'),(70,9,6,'2026-09-14 23:33:00'),(71,9,7,'2026-09-14 23:33:00'),(72,9,8,'2026-09-14 23:33:00'),(73,9,10,'2026-09-14 23:33:00'),(74,10,1,'2026-09-14 23:33:00'),(75,10,2,'2026-09-14 23:33:00'),(76,10,4,'2026-09-14 23:33:00'),(77,10,5,'2026-09-14 23:33:00'),(78,10,7,'2026-09-14 23:33:00'),(79,10,8,'2026-09-14 23:33:00'),(81,11,3,'2026-09-14 23:33:00'),(82,11,4,'2026-09-14 23:33:00'),(83,11,5,'2026-09-14 23:33:00'),(84,11,6,'2026-09-14 23:33:00'),(85,11,7,'2026-09-14 23:33:00'),(86,11,8,'2026-09-14 23:33:00'),(87,11,9,'2026-09-14 23:33:00'),(88,11,10,'2026-09-14 23:33:00'),(89,12,1,'2026-09-14 23:33:00'),(90,12,2,'2026-09-14 23:33:00'),(91,12,5,'2026-09-14 23:33:00'),(92,12,6,'2026-09-14 23:33:00'),(93,12,7,'2026-09-14 23:33:00'),(94,12,8,'2026-09-14 23:33:00'),(95,12,9,'2026-09-14 23:33:00'),(96,12,10,'2026-09-14 23:33:00'),(98,13,2,'2026-09-14 23:33:00'),(99,13,3,'2026-09-14 23:33:00'),(100,13,4,'2026-09-14 23:33:00'),(101,13,5,'2026-09-14 23:33:00'),(102,13,7,'2026-09-14 23:33:00'),(103,13,8,'2026-09-14 23:33:00'),(104,13,9,'2026-09-14 23:33:00'),(105,13,10,'2026-09-14 23:33:00'),(106,14,1,'2026-09-14 23:33:00'),(107,14,2,'2026-09-14 23:33:00'),(108,14,4,'2026-09-14 23:33:00'),(109,14,5,'2026-09-14 23:33:00'),(110,14,6,'2026-09-14 23:33:00'),(111,14,7,'2026-09-14 23:33:00'),(112,14,8,'2026-09-14 23:33:00'),(113,14,9,'2026-09-14 23:33:00'),(114,14,10,'2026-09-14 23:33:00'),(115,15,2,'2026-09-14 23:33:00'),(116,15,3,'2026-09-14 23:33:00'),(117,15,4,'2026-09-14 23:33:00'),(118,15,5,'2026-09-14 23:33:00'),(119,15,6,'2026-09-14 23:33:00'),(120,15,7,'2026-09-14 23:33:00'),(121,15,8,'2026-09-14 23:33:00'),(122,15,9,'2026-09-14 23:33:00'),(123,15,10,'2026-09-14 23:33:00'),(126,1,1,'2026-09-14 23:41:24'),(130,13,1,'2026-09-15 00:49:07'),(131,15,1,'2026-09-15 00:49:55'),(134,1,11,'2026-09-18 13:03:58'),(135,4,11,'2026-09-18 12:24:58'),(136,9,11,'2026-09-18 11:19:58'),(137,11,11,'2026-09-18 10:53:58'),(138,14,11,'2026-09-18 10:14:58'),(139,16,11,'2026-09-18 09:48:58'),(140,19,11,'2026-09-18 09:09:58'),(141,21,11,'2026-09-18 08:43:58'),(142,24,11,'2026-09-18 08:04:58'),(143,26,11,'2026-09-18 07:38:58'),(144,29,11,'2026-09-18 06:59:58'),(145,31,11,'2026-09-18 06:33:58'),(146,34,11,'2026-09-18 05:54:58'),(147,36,11,'2026-09-18 05:28:58'),(148,39,11,'2026-09-18 04:49:58'),(149,41,11,'2026-09-18 04:23:58'),(150,44,11,'2026-09-18 03:44:58'),(151,3,15,'2026-09-18 12:09:58'),(152,5,15,'2026-09-18 11:43:58'),(153,8,15,'2026-09-18 11:04:58'),(154,10,15,'2026-09-18 10:38:58'),(155,13,15,'2026-09-18 09:59:58'),(156,15,15,'2026-09-18 09:33:58'),(157,18,15,'2026-09-18 08:54:58'),(158,23,15,'2026-09-18 07:49:58'),(159,25,15,'2026-09-18 07:23:58'),(160,28,15,'2026-09-18 06:44:58'),(161,30,15,'2026-09-18 06:18:58'),(162,35,15,'2026-09-18 05:13:58'),(163,38,15,'2026-09-18 04:34:58'),(164,40,15,'2026-09-18 04:08:58'),(165,43,15,'2026-09-18 03:29:58'),(166,45,15,'2026-09-18 03:03:58'),(167,1,16,'2026-09-18 12:28:58'),(168,4,16,'2026-09-18 11:49:58'),(169,6,16,'2026-09-18 11:23:58'),(170,9,16,'2026-09-18 10:44:58'),(171,11,16,'2026-09-18 10:18:58'),(172,14,16,'2026-09-18 09:39:58'),(173,16,16,'2026-09-18 09:13:58'),(174,19,16,'2026-09-18 08:34:58'),(175,21,16,'2026-09-18 08:08:58'),(176,24,16,'2026-09-18 07:29:58'),(177,26,16,'2026-09-18 07:03:58'),(178,29,16,'2026-09-18 06:24:58'),(179,31,16,'2026-09-18 05:58:58'),(180,34,16,'2026-09-18 05:19:58'),(181,36,16,'2026-09-18 04:53:58'),(182,39,16,'2026-09-18 04:14:58'),(183,41,16,'2026-09-18 03:48:58'),(184,44,16,'2026-09-18 03:09:58'),(185,2,17,'2026-09-18 12:08:58'),(186,5,17,'2026-09-18 11:29:58'),(187,7,17,'2026-09-18 11:03:58'),(188,10,17,'2026-09-18 10:24:58'),(189,12,17,'2026-09-18 09:58:58'),(190,15,17,'2026-09-18 09:19:58'),(192,20,17,'2026-09-18 08:14:58'),(193,22,17,'2026-09-18 07:48:58'),(194,25,17,'2026-09-18 07:09:58'),(195,27,17,'2026-09-18 06:43:58'),(196,30,17,'2026-09-18 06:04:58'),(197,35,17,'2026-09-18 04:59:58'),(198,37,17,'2026-09-18 04:33:58'),(199,40,17,'2026-09-18 03:54:58'),(200,42,17,'2026-09-18 03:28:58'),(201,45,17,'2026-09-18 02:49:58'),(202,1,18,'2026-09-18 12:14:58'),(203,3,18,'2026-09-18 11:48:58'),(204,6,18,'2026-09-18 11:09:58'),(205,8,18,'2026-09-18 10:43:58'),(206,11,18,'2026-09-18 10:04:58'),(207,13,18,'2026-09-18 09:38:58'),(208,16,18,'2026-09-18 08:59:58'),(209,18,18,'2026-09-18 08:33:58'),(210,21,18,'2026-09-18 07:54:58'),(211,23,18,'2026-09-18 07:28:58'),(212,26,18,'2026-09-18 06:49:58'),(213,28,18,'2026-09-18 06:23:58'),(214,31,18,'2026-09-18 05:44:58'),(215,33,18,'2026-09-18 05:18:58'),(216,36,18,'2026-09-18 04:39:58'),(217,38,18,'2026-09-18 04:13:58'),(218,41,18,'2026-09-18 03:34:58'),(219,19,1,'2026-09-18 10:19:58'),(220,21,1,'2026-09-18 09:53:58'),(221,24,1,'2026-09-18 09:14:58'),(222,26,1,'2026-09-18 08:48:58'),(223,29,1,'2026-09-18 08:09:58'),(224,31,1,'2026-09-18 07:43:58'),(225,34,1,'2026-09-18 07:04:58'),(226,36,1,'2026-09-18 06:38:58'),(227,39,1,'2026-09-18 05:59:58'),(228,41,1,'2026-09-18 05:33:58'),(229,44,1,'2026-09-18 04:54:58'),(230,8,3,'2026-09-18 12:28:58'),(231,16,3,'2026-09-18 10:44:58'),(232,18,3,'2026-09-18 10:18:58'),(233,21,3,'2026-09-18 09:39:58'),(234,23,3,'2026-09-18 09:13:58'),(235,26,3,'2026-09-18 08:34:58'),(236,28,3,'2026-09-18 08:08:58'),(237,31,3,'2026-09-18 07:29:58'),(238,33,3,'2026-09-18 07:03:58'),(239,36,3,'2026-09-18 06:24:58'),(240,38,3,'2026-09-18 05:58:58'),(241,41,3,'2026-09-18 05:19:58'),(242,43,3,'2026-09-18 04:53:58'),(243,2,19,'2026-09-18 11:54:58'),(244,4,19,'2026-09-18 11:28:58'),(245,7,19,'2026-09-18 10:49:58'),(246,9,19,'2026-09-18 10:23:58'),(247,12,19,'2026-09-18 09:44:58'),(248,14,19,'2026-09-18 09:18:58'),(250,19,19,'2026-09-18 08:13:58'),(251,22,19,'2026-09-18 07:34:58'),(252,27,19,'2026-09-18 06:29:58'),(253,29,19,'2026-09-18 06:03:58'),(254,32,19,'2026-09-18 05:24:58'),(255,34,19,'2026-09-18 04:58:58'),(256,37,19,'2026-09-18 04:19:58'),(257,39,19,'2026-09-18 03:53:58'),(258,42,19,'2026-09-18 03:14:58'),(259,44,19,'2026-09-18 02:48:58'),(260,3,20,'2026-09-18 11:34:58'),(261,5,20,'2026-09-18 11:08:58'),(262,8,20,'2026-09-18 10:29:58'),(263,10,20,'2026-09-18 10:03:58'),(264,13,20,'2026-09-18 09:24:58'),(265,15,20,'2026-09-18 08:58:58'),(266,18,20,'2026-09-18 08:19:58'),(267,20,20,'2026-09-18 07:53:58'),(268,23,20,'2026-09-18 07:14:58'),(269,28,20,'2026-09-18 06:09:58'),(270,30,20,'2026-09-18 05:43:58'),(271,33,20,'2026-09-18 05:04:58'),(272,35,20,'2026-09-18 04:38:58'),(273,38,20,'2026-09-18 03:59:58'),(274,40,20,'2026-09-18 03:33:58'),(275,43,20,'2026-09-18 02:54:58'),(276,45,20,'2026-09-18 02:28:58'),(277,16,8,'2026-09-18 10:09:58'),(278,18,8,'2026-09-18 09:43:58'),(279,21,8,'2026-09-18 09:04:58'),(280,23,8,'2026-09-18 08:38:58'),(281,26,8,'2026-09-18 07:59:58'),(282,28,8,'2026-09-18 07:33:58'),(283,31,8,'2026-09-18 06:54:58'),(284,33,8,'2026-09-18 06:28:58'),(285,36,8,'2026-09-18 05:49:58'),(286,38,8,'2026-09-18 05:23:58'),(287,41,8,'2026-09-18 04:44:58'),(288,43,8,'2026-09-18 04:18:58'),(289,1,21,'2026-09-18 11:53:58'),(290,4,21,'2026-09-18 11:14:58'),(291,6,21,'2026-09-18 10:48:58'),(292,9,21,'2026-09-18 10:09:58'),(293,11,21,'2026-09-18 09:43:58'),(294,14,21,'2026-09-18 09:04:58'),(295,16,21,'2026-09-18 08:38:58'),(296,19,21,'2026-09-18 07:59:58'),(297,21,21,'2026-09-18 07:33:58'),(298,24,21,'2026-09-18 06:54:58'),(299,26,21,'2026-09-18 06:28:58'),(300,29,21,'2026-09-18 05:49:58'),(301,31,21,'2026-09-18 05:23:58'),(302,34,21,'2026-09-18 04:44:58'),(303,36,21,'2026-09-18 04:18:58'),(304,39,21,'2026-09-18 03:39:58'),(305,41,21,'2026-09-18 03:13:58'),(306,44,21,'2026-09-18 02:34:58'),(307,2,22,'2026-09-18 11:33:58'),(308,5,22,'2026-09-18 10:54:58'),(309,7,22,'2026-09-18 10:28:58'),(310,10,22,'2026-09-18 09:49:58'),(311,12,22,'2026-09-18 09:23:58'),(312,15,22,'2026-09-18 08:44:58'),(314,20,22,'2026-09-18 07:39:58'),(315,22,22,'2026-09-18 07:13:58'),(316,25,22,'2026-09-18 06:34:58'),(317,27,22,'2026-09-18 06:08:58'),(318,30,22,'2026-09-18 05:29:58'),(319,32,22,'2026-09-18 05:03:58'),(320,35,22,'2026-09-18 04:24:58'),(321,37,22,'2026-09-18 03:58:58'),(322,40,22,'2026-09-18 03:19:58'),(323,42,22,'2026-09-18 02:53:58'),(324,45,22,'2026-09-18 02:14:58'),(326,20,2,'2026-09-18 09:59:58'),(327,22,2,'2026-09-18 09:33:58'),(328,25,2,'2026-09-18 08:54:58'),(329,27,2,'2026-09-18 08:28:58'),(330,30,2,'2026-09-18 07:49:58'),(331,32,2,'2026-09-18 07:23:58'),(332,35,2,'2026-09-18 06:44:58'),(333,37,2,'2026-09-18 06:18:58'),(334,40,2,'2026-09-18 05:39:58'),(335,42,2,'2026-09-18 05:13:58'),(336,45,2,'2026-09-18 04:34:58'),(337,1,23,'2026-09-18 11:39:58'),(338,3,23,'2026-09-18 11:13:58'),(339,6,23,'2026-09-18 10:34:58'),(340,8,23,'2026-09-18 10:08:58'),(341,11,23,'2026-09-18 09:29:58'),(342,13,23,'2026-09-18 09:03:58'),(343,16,23,'2026-09-18 08:24:58'),(344,18,23,'2026-09-18 07:58:58'),(345,21,23,'2026-09-18 07:19:58'),(346,26,23,'2026-09-18 06:14:58'),(347,28,23,'2026-09-18 05:48:58'),(348,31,23,'2026-09-18 05:09:58'),(349,33,23,'2026-09-18 04:43:58'),(350,38,23,'2026-09-18 03:38:58'),(351,41,23,'2026-09-18 02:59:58'),(352,43,23,'2026-09-18 02:33:58'),(354,19,4,'2026-09-18 09:58:58'),(355,22,4,'2026-09-18 09:19:58'),(356,24,4,'2026-09-18 08:53:58'),(357,27,4,'2026-09-18 08:14:58'),(358,29,4,'2026-09-18 07:48:58'),(359,32,4,'2026-09-18 07:09:58'),(360,34,4,'2026-09-18 06:43:58'),(361,37,4,'2026-09-18 06:04:58'),(362,39,4,'2026-09-18 05:38:58'),(363,42,4,'2026-09-18 04:59:58'),(364,44,4,'2026-09-18 04:33:58'),(365,2,24,'2026-09-18 11:19:58'),(366,4,24,'2026-09-18 10:53:58'),(367,7,24,'2026-09-18 10:14:58'),(368,9,24,'2026-09-18 09:48:58'),(369,12,24,'2026-09-18 09:09:58'),(370,14,24,'2026-09-18 08:43:58'),(372,19,24,'2026-09-18 07:38:58'),(373,22,24,'2026-09-18 06:59:58'),(374,24,24,'2026-09-18 06:33:58'),(375,27,24,'2026-09-18 05:54:58'),(376,32,24,'2026-09-18 04:49:58'),(377,34,24,'2026-09-18 04:23:58'),(378,37,24,'2026-09-18 03:44:58'),(379,39,24,'2026-09-18 03:18:58'),(380,44,24,'2026-09-18 02:13:58'),(381,18,5,'2026-09-18 10:04:58'),(382,20,5,'2026-09-18 09:38:58'),(383,23,5,'2026-09-18 08:59:58'),(384,25,5,'2026-09-18 08:33:58'),(385,28,5,'2026-09-18 07:54:58'),(386,30,5,'2026-09-18 07:28:58'),(387,33,5,'2026-09-18 06:49:58'),(388,35,5,'2026-09-18 06:23:58'),(389,38,5,'2026-09-18 05:44:58'),(390,40,5,'2026-09-18 05:18:58'),(391,43,5,'2026-09-18 04:39:58'),(392,45,5,'2026-09-18 04:13:58'),(393,2,14,'2026-09-18 12:29:58'),(394,4,14,'2026-09-18 12:03:58'),(395,7,14,'2026-09-18 11:24:58'),(396,9,14,'2026-09-18 10:58:58'),(397,12,14,'2026-09-18 10:19:58'),(398,14,14,'2026-09-18 09:53:58'),(400,19,14,'2026-09-18 08:48:58'),(401,22,14,'2026-09-18 08:09:58'),(402,24,14,'2026-09-18 07:43:58'),(403,27,14,'2026-09-18 07:04:58'),(404,29,14,'2026-09-18 06:38:58'),(405,32,14,'2026-09-18 05:59:58'),(406,34,14,'2026-09-18 05:33:58'),(407,37,14,'2026-09-18 04:54:58'),(408,39,14,'2026-09-18 04:28:58'),(409,42,14,'2026-09-18 03:49:58'),(410,44,14,'2026-09-18 03:23:58'),(411,3,25,'2026-09-18 10:59:58'),(412,5,25,'2026-09-18 10:33:58'),(413,8,25,'2026-09-18 09:54:58'),(414,10,25,'2026-09-18 09:28:58'),(415,13,25,'2026-09-18 08:49:58'),(416,15,25,'2026-09-18 08:23:58'),(417,18,25,'2026-09-18 07:44:58'),(418,20,25,'2026-09-18 07:18:58'),(419,23,25,'2026-09-18 06:39:58'),(420,25,25,'2026-09-18 06:13:58'),(421,28,25,'2026-09-18 05:34:58'),(422,30,25,'2026-09-18 05:08:58'),(423,33,25,'2026-09-18 04:29:58'),(424,38,25,'2026-09-18 03:24:58'),(425,40,25,'2026-09-18 02:58:58'),(426,43,25,'2026-09-18 02:19:58'),(427,45,25,'2026-09-18 01:53:58'),(428,10,10,'2026-09-18 11:13:58'),(429,18,10,'2026-09-18 09:29:58'),(430,20,10,'2026-09-18 09:03:58'),(431,23,10,'2026-09-18 08:24:58'),(432,25,10,'2026-09-18 07:58:58'),(433,28,10,'2026-09-18 07:19:58'),(434,30,10,'2026-09-18 06:53:58'),(435,33,10,'2026-09-18 06:14:58'),(436,35,10,'2026-09-18 05:48:58'),(437,38,10,'2026-09-18 05:09:58'),(438,40,10,'2026-09-18 04:43:58'),(439,43,10,'2026-09-18 04:04:58'),(440,45,10,'2026-09-18 03:38:58'),(441,16,6,'2026-09-18 10:23:58'),(442,19,6,'2026-09-18 09:44:58'),(443,21,6,'2026-09-18 09:18:58'),(444,24,6,'2026-09-18 08:39:58'),(445,26,6,'2026-09-18 08:13:58'),(446,29,6,'2026-09-18 07:34:58'),(447,31,6,'2026-09-18 07:08:58'),(448,34,6,'2026-09-18 06:29:58'),(449,36,6,'2026-09-18 06:03:58'),(450,39,6,'2026-09-18 05:24:58'),(451,41,6,'2026-09-18 04:58:58'),(452,44,6,'2026-09-18 04:19:58'),(453,1,26,'2026-09-18 11:18:58'),(454,4,26,'2026-09-18 10:39:58'),(455,6,26,'2026-09-18 10:13:58'),(456,9,26,'2026-09-18 09:34:58'),(457,11,26,'2026-09-18 09:08:58'),(458,14,26,'2026-09-18 08:29:58'),(459,16,26,'2026-09-18 08:03:58'),(460,19,26,'2026-09-18 07:24:58'),(461,21,26,'2026-09-18 06:58:58'),(462,24,26,'2026-09-18 06:19:58'),(463,26,26,'2026-09-18 05:53:58'),(464,29,26,'2026-09-18 05:14:58'),(465,34,26,'2026-09-18 04:09:58'),(466,36,26,'2026-09-18 03:43:58'),(467,39,26,'2026-09-18 03:04:58'),(468,41,26,'2026-09-18 02:38:58'),(469,44,26,'2026-09-18 01:59:58'),(470,7,7,'2026-09-18 12:13:58'),(472,20,7,'2026-09-18 09:24:58'),(473,22,7,'2026-09-18 08:58:58'),(474,25,7,'2026-09-18 08:19:58'),(475,27,7,'2026-09-18 07:53:58'),(476,30,7,'2026-09-18 07:14:58'),(477,32,7,'2026-09-18 06:48:58'),(478,35,7,'2026-09-18 06:09:58'),(479,37,7,'2026-09-18 05:43:58'),(480,40,7,'2026-09-18 05:04:58'),(481,42,7,'2026-09-18 04:38:58'),(482,45,7,'2026-09-18 03:59:58'),(483,7,9,'2026-09-18 11:59:58'),(484,9,9,'2026-09-18 11:33:58'),(486,19,9,'2026-09-18 09:23:58'),(487,22,9,'2026-09-18 08:44:58'),(488,24,9,'2026-09-18 08:18:58'),(489,27,9,'2026-09-18 07:39:58'),(490,29,9,'2026-09-18 07:13:58'),(491,32,9,'2026-09-18 06:34:58'),(492,34,9,'2026-09-18 06:08:58'),(493,37,9,'2026-09-18 05:29:58'),(494,39,9,'2026-09-18 05:03:58'),(495,42,9,'2026-09-18 04:24:58'),(496,44,9,'2026-09-18 03:58:58'),(497,2,27,'2026-09-18 10:58:58'),(498,5,27,'2026-09-18 10:19:58'),(499,7,27,'2026-09-18 09:53:58'),(500,10,27,'2026-09-18 09:14:58'),(501,12,27,'2026-09-18 08:48:58'),(502,15,27,'2026-09-18 08:09:58'),(504,20,27,'2026-09-18 07:04:58'),(505,22,27,'2026-09-18 06:38:58'),(506,25,27,'2026-09-18 05:59:58'),(507,27,27,'2026-09-18 05:33:58'),(508,30,27,'2026-09-18 04:54:58'),(509,32,27,'2026-09-18 04:28:58'),(510,35,27,'2026-09-18 03:49:58'),(511,37,27,'2026-09-18 03:23:58'),(512,40,27,'2026-09-18 02:44:58'),(513,42,27,'2026-09-18 02:18:58'),(514,45,27,'2026-09-18 01:39:58'),(515,1,28,'2026-09-18 11:04:58'),(516,3,28,'2026-09-18 10:38:58'),(517,6,28,'2026-09-18 09:59:58'),(518,8,28,'2026-09-18 09:33:58'),(519,11,28,'2026-09-18 08:54:58'),(520,13,28,'2026-09-18 08:28:58'),(521,16,28,'2026-09-18 07:49:58'),(522,18,28,'2026-09-18 07:23:58'),(523,21,28,'2026-09-18 06:44:58'),(524,23,28,'2026-09-18 06:18:58'),(525,26,28,'2026-09-18 05:39:58'),(526,28,28,'2026-09-18 05:13:58'),(527,31,28,'2026-09-18 04:34:58'),(528,33,28,'2026-09-18 04:08:58'),(529,36,28,'2026-09-18 03:29:58'),(530,38,28,'2026-09-18 03:03:58'),(531,41,28,'2026-09-18 02:24:58'),(532,43,28,'2026-09-18 01:58:58'),(535,40,1,'2026-10-01 08:51:36'),(546,11,1,'2026-10-08 08:27:08'),(547,48,1,'2026-10-08 08:27:40');
/*!40000 ALTER TABLE `likes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `message_hidden`
--

DROP TABLE IF EXISTS `message_hidden`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_hidden` (
  `message_id` int NOT NULL,
  `user_id` int NOT NULL,
  PRIMARY KEY (`message_id`,`user_id`),
  KEY `ix_mh_user` (`user_id`),
  CONSTRAINT `fk_mh_message` FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`message_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mh_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `message_hidden`
--

LOCK TABLES `message_hidden` WRITE;
/*!40000 ALTER TABLE `message_hidden` DISABLE KEYS */;
/*!40000 ALTER TABLE `message_hidden` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `message_reactions`
--

DROP TABLE IF EXISTS `message_reactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_reactions` (
  `message_id` int NOT NULL,
  `user_id` int NOT NULL,
  `emoji` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`message_id`,`user_id`),
  KEY `ix_mr_user` (`user_id`),
  CONSTRAINT `fk_mr_message` FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`message_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_mr_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `message_reactions`
--

LOCK TABLES `message_reactions` WRITE;
/*!40000 ALTER TABLE `message_reactions` DISABLE KEYS */;
INSERT INTO `message_reactions` VALUES (37,1,'😡','2026-10-08 08:38:52'),(37,33,'😡','2026-10-08 08:39:30');
/*!40000 ALTER TABLE `message_reactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `notification_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `actor_id` int NOT NULL,
  `type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ref_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`notification_id`),
  KEY `ix_notifications_user` (`user_id`,`is_read`,`created_at`),
  KEY `ix_notifications_actor` (`actor_id`),
  KEY `ix_notifications_ref` (`user_id`,`ref_key`),
  CONSTRAINT `fk_notifications_actor` FOREIGN KEY (`actor_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=98 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1,1,2,'LIKE','da thich bai viet cua ban.','/feed#post-1',1,'2026-09-08 23:33:00',NULL),(2,1,3,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-1',1,'2026-09-08 23:33:00',NULL),(3,1,4,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-7',1,'2026-09-12 23:33:00',NULL),(4,1,9,'FRIEND_REQUEST','da gui cho ban mot loi moi ket ban.','/friends',1,'2026-09-12 23:33:00',NULL),(5,1,5,'LIKE','da thich bai viet cua ban.','/feed#post-15',1,'2026-09-14 23:33:00',NULL),(6,1,6,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-15',1,'2026-09-14 23:33:00',NULL),(7,2,1,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-2',1,'2026-09-09 23:33:00',NULL),(8,2,7,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-2',1,'2026-09-10 23:33:00',NULL),(9,2,3,'LIKE','da thich bai viet cua ban.','/feed#post-11',1,'2026-09-14 23:33:00',NULL),(10,3,1,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-3',0,'2026-09-10 23:33:00',NULL),(11,3,8,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-3',0,'2026-09-12 23:33:00',NULL),(12,3,5,'LIKE','da thich bai viet cua ban.','/feed#post-14',0,'2026-09-14 23:33:00',NULL),(13,4,1,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-4',1,'2026-09-10 23:33:00',NULL),(14,4,3,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-4',0,'2026-09-12 23:33:00',NULL),(15,4,2,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-12',0,'2026-09-14 23:33:00',NULL),(16,5,1,'LIKE','da thich bai viet cua ban.','/feed#post-9',1,'2026-09-14 23:33:00',NULL),(17,5,2,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-9',1,'2026-09-14 23:33:00',NULL),(18,6,1,'LIKE','da thich bai viet cua ban.','/feed#post-5',1,'2026-09-11 23:33:00',NULL),(19,6,4,'COMMENT','da binh luan ve bai viet cua ban.','/feed#post-13',1,'2026-09-14 23:33:00',NULL),(20,1,2,'FRIEND_ACCEPT','da chap nhan loi moi ket ban cua ban.','/profile?userId=2',1,'2026-08-16 23:33:00',NULL),(21,2,3,'FRIEND_ACCEPT','da chap nhan loi moi ket ban cua ban.','/profile?userId=3',1,'2026-08-28 23:33:00',NULL),(22,5,1,'FRIEND_REQUEST','đã gửi cho bạn một lời mời kết bạn.','/friends',1,'2026-09-14 23:38:07',NULL),(23,1,5,'FRIEND_ACCEPT','đã chấp nhận lời mời kết bạn của bạn.','/profile?userId=5',1,'2026-09-14 23:39:08',NULL),(24,6,1,'LIKE','đã thích bài viết của bạn.','/feed#post-13',1,'2026-09-15 00:48:18',NULL),(25,6,1,'LIKE','đã thích bài viết của bạn.','/feed#post-13',1,'2026-09-15 00:48:47',NULL),(26,6,1,'LIKE','đã thích bài viết của bạn.','/feed#post-13',1,'2026-09-15 00:49:07',NULL),(27,6,1,'COMMENT','đã bình luận vào bài viết của bạn: \"test lần nữa\"','/feed#post-13',1,'2026-09-15 01:36:59',NULL),(28,6,1,'COMMENT','đã bình luận vào bài viết của bạn: \"Test lần nữa nữa\"','/feed#post-13',1,'2026-09-15 01:37:16',NULL),(29,7,1,'FRIEND_REQUEST','đã gửi cho bạn một lời mời kết bạn.','/friends',1,'2026-09-15 01:38:34',NULL),(30,1,7,'FRIEND_ACCEPT','đã chấp nhận lời mời kết bạn của bạn.','/profile?userId=7',1,'2026-09-15 01:44:12',NULL),(31,3,1,'COMMENT','đã bình luận vào bài viết của bạn: \"okay\"','/feed#post-14',0,'2026-09-17 08:06:25',NULL),(32,4,27,'FRIEND_REQUEST','đã gửi cho bạn một lời mời kết bạn.','/friends',0,'2026-09-18 08:33:59',NULL),(33,4,16,'FRIEND_REQUEST','đã gửi cho bạn một lời mời kết bạn.','/friends',0,'2026-09-17 18:33:59',NULL),(34,4,22,'LIKE','đã thích bài viết của bạn.','/feed',0,'2026-09-18 13:48:59',NULL),(35,4,18,'COMMENT','đã bình luận vào bài viết của bạn.','/feed',1,'2026-09-18 09:33:59',NULL),(36,4,15,'LIKE','đã thích bài viết của bạn.','/feed',1,'2026-09-18 02:33:59',NULL),(37,19,1,'LIKE','đã thích bài viết của bạn.','/feed#post-40',0,'2026-10-01 08:51:36',NULL),(38,1,1,'ACCOUNT','Đăng nhập từ thiết bị mới: Chrome trên Windows lúc 09:15 02/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',1,'2026-10-02 09:15:11','login:Chrome trên Windows'),(39,11,11,'ACCOUNT','Đăng nhập từ thiết bị mới: Chrome trên Windows lúc 09:18 02/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',1,'2026-10-02 09:18:35','login:Chrome trên Windows'),(40,32,32,'ACCOUNT','Đăng nhập từ thiết bị mới: Chrome trên Windows lúc 09:18 02/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',0,'2026-10-02 09:18:57','login:Chrome trên Windows'),(41,14,14,'ACCOUNT','Đăng nhập từ thiết bị mới: Chrome trên Windows lúc 10:12 02/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',0,'2026-10-02 10:12:55','login:Chrome trên Windows'),(42,14,14,'ACCOUNT','Mật khẩu của bạn vừa được đặt lại bằng mã xác nhận gửi qua email (Chrome trên Windows). Nếu không phải bạn, hãy liên hệ quản trị viên ngay.','/settings?tab=account',0,'2026-10-05 08:45:25',NULL),(43,14,14,'ACCOUNT','Mật khẩu tài khoản của bạn vừa được thay đổi (Chrome trên Windows). Nếu không phải bạn, hãy liên hệ quản trị viên ngay.','/settings?tab=account',0,'2026-10-05 08:46:14',NULL),(46,33,14,'FRIEND_ACCEPT','đã chấp nhận lời mời kết bạn của bạn.','/profile?userId=14',1,'2026-10-08 08:18:00','fa:14'),(47,33,1,'FRIEND_ACCEPT','đã chấp nhận lời mời kết bạn của bạn.','/profile?userId=1',1,'2026-10-08 08:18:22','fa:1'),(48,33,33,'ACCOUNT','Đăng nhập từ thiết bị mới: Chrome trên Windows lúc 08:18 08/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',1,'2026-10-08 08:18:48','login:Chrome trên Windows'),(49,1,33,'SHARE','đã chia sẻ bài viết của bạn.','/profile?userId=33#profile-post-48',1,'2026-10-08 08:21:02',NULL),(50,4,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',0,'2026-10-08 08:22:14',NULL),(51,6,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',0,'2026-10-08 08:22:14',NULL),(52,10,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',0,'2026-10-08 08:22:14',NULL),(53,14,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',1,'2026-10-08 08:22:14',NULL),(54,18,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',0,'2026-10-08 08:22:14',NULL),(55,22,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',0,'2026-10-08 08:22:14',NULL),(56,26,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',0,'2026-10-08 08:22:14',NULL),(57,2,33,'GROUP_POST','đã đăng bài trong nhóm Việc làm & Thực tập IT.','/groups/view?id=10#post-49',0,'2026-10-08 08:22:14',NULL),(58,14,33,'MESSAGE','đã gửi cho bạn một tin nhắn mới.','/chat?c=12',1,'2026-10-08 08:23:27','conv:12'),(59,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:02',NULL),(60,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:02',NULL),(61,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:03',NULL),(62,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:04',NULL),(63,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:04',NULL),(64,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:05',NULL),(65,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:05',NULL),(66,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:05',NULL),(67,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:06',NULL),(68,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:06',NULL),(69,2,1,'LIKE','đã thích bài viết của bạn.','/feed#post-11',0,'2026-10-08 08:27:08',NULL),(70,33,1,'LIKE','đã thích bài viết của bạn.','/feed#post-48',1,'2026-10-08 08:27:40',NULL),(71,2,34,'MESSAGE','và mọi người đã gửi 5 tin nhắn mới trong nhóm \"web\".','/chat?c=13',0,'2026-10-18 16:48:55','conv:13'),(72,3,34,'MESSAGE','và mọi người đã gửi 5 tin nhắn mới trong nhóm \"web\".','/chat?c=13',0,'2026-10-18 16:48:56','conv:13'),(73,4,1,'MESSAGE','và mọi người đã gửi 2 tin nhắn mới trong nhóm \"web\".','/chat?c=13',1,'2026-10-08 08:38:38','conv:13'),(74,5,34,'MESSAGE','và mọi người đã gửi 5 tin nhắn mới trong nhóm \"web\".','/chat?c=13',0,'2026-10-18 16:48:58','conv:13'),(75,33,1,'MESSAGE','và mọi người đã gửi 2 tin nhắn mới trong nhóm \"web\".','/chat?c=13',1,'2026-10-08 08:38:38','conv:13'),(76,2,1,'COMMENT','đã bình luận vào bài viết của bạn: \"like\"','/feed#post-11',0,'2026-10-08 09:03:01',NULL),(77,2,1,'SHARE','đã chia sẻ bài viết của bạn.','/profile?userId=1#profile-post-50',0,'2026-10-08 09:03:12',NULL),(78,6,1,'MESSAGE','đã gửi tin nhắn mới trong nhóm \"Test web\".','/chat?c=14',0,'2026-10-08 09:08:03','conv:14'),(79,7,1,'MESSAGE','đã gửi tin nhắn mới trong nhóm \"Test web\".','/chat?c=14',0,'2026-10-08 09:08:03','conv:14'),(80,33,1,'MESSAGE','đã gửi tin nhắn mới trong nhóm \"Test web\".','/chat?c=14',0,'2026-10-08 09:08:03','conv:14'),(81,4,4,'ACCOUNT','Đăng nhập từ thiết bị mới: Edge trên Windows lúc 13:31 12/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',0,'2026-10-12 13:31:43','login:Edge trên Windows'),(82,1,4,'MESSAGE','đã gửi tin nhắn mới trong nhóm \"web\".','/chat?c=13',1,'2026-10-12 13:33:39','conv:13'),(83,33,34,'MESSAGE','và mọi người đã gửi 3 tin nhắn mới trong nhóm \"web\".','/chat?c=13',0,'2026-10-18 16:48:59','conv:13'),(84,14,14,'ACCOUNT','Đăng nhập từ thiết bị mới: Edge trên Windows lúc 16:26 18/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',0,'2026-10-18 16:26:39','login:Edge trên Windows'),(86,1,14,'FRIEND_ACCEPT','đã chấp nhận lời mời kết bạn của bạn.','/profile?userId=14',1,'2026-10-18 16:27:34','fa:14'),(87,14,1,'MESSAGE','đã gửi cho bạn một tin nhắn mới.','/chat?c=17',1,'2026-10-18 16:28:15','conv:17'),(88,1,14,'MESSAGE','đã gửi cho bạn một tin nhắn mới.','/chat?c=17',1,'2026-10-18 16:28:25','conv:17'),(89,14,14,'ACCOUNT','Đăng nhập từ thiết bị mới: Chrome trên Android lúc 16:43 18/10/2026. Nếu không phải bạn, hãy đổi mật khẩu ngay.','/settings?tab=account',0,'2026-10-18 16:43:02','login:Chrome trên Android'),(91,34,1,'FRIEND_ACCEPT','đã chấp nhận lời mời kết bạn của bạn.','/profile?userId=1',0,'2026-10-18 16:47:25','fa:1'),(92,34,1,'MESSAGE','đã gửi cho bạn một tin nhắn mới.','/chat?c=18',1,'2026-10-18 16:47:59','conv:18'),(93,1,34,'MESSAGE','đã gửi cho bạn 2 tin nhắn mới.','/chat?c=18',1,'2026-10-18 16:48:16','conv:18'),(94,34,1,'MESSAGE','đã thêm bạn vào nhóm chat \"web\".','/chat?c=13',1,'2026-10-18 16:48:19','conv:13'),(95,4,34,'MESSAGE','và mọi người đã gửi 2 tin nhắn mới trong nhóm \"web\".','/chat?c=13',0,'2026-10-18 16:48:57','conv:13'),(96,34,1,'MESSAGE','đã gửi tin nhắn mới trong nhóm \"web\".','/chat?c=13',1,'2026-10-18 16:48:42','conv:13'),(97,1,34,'MESSAGE','đã gửi tin nhắn mới trong nhóm \"web\".','/chat?c=13',1,'2026-10-18 16:48:54','conv:13');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `posts`
--

DROP TABLE IF EXISTS `posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `posts` (
  `post_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `image_path` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `visibility` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'public',
  `media_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `video_path` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `video_duration_sec` int NOT NULL DEFAULT '0',
  `like_count` int NOT NULL DEFAULT '0',
  `comment_count` int NOT NULL DEFAULT '0',
  `share_count` int NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `shared_post_id` int DEFAULT NULL,
  `group_id` int DEFAULT NULL,
  `moderation_status` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE',
  `is_hidden_by_owner` tinyint(1) NOT NULL DEFAULT '0',
  `sentiment` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sentiment_score` double DEFAULT NULL,
  `sentiment_source` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `media_mode` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `model_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `captions_vtt` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`post_id`),
  KEY `ix_posts_user_id` (`user_id`),
  KEY `ix_posts_shared_post_id` (`shared_post_id`),
  KEY `ix_posts_group_id` (`group_id`),
  KEY `ix_posts_sentiment` (`sentiment`,`created_at`),
  CONSTRAINT `fk_posts_group` FOREIGN KEY (`group_id`) REFERENCES `groups_tbl` (`group_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_posts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `ck_posts_media_mode` CHECK (((`media_mode` is null) or (`media_mode` in (_utf8mb4'PANORAMA',_utf8mb4'DEPTH',_utf8mb4'MODEL3D')))),
  CONSTRAINT `ck_posts_sentiment` CHECK (((`sentiment` is null) or (`sentiment` in (_utf8mb4'POSITIVE',_utf8mb4'NEUTRAL',_utf8mb4'NEGATIVE'))))
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `posts`
--

LOCK TABLES `posts` WRITE;
/*!40000 ALTER TABLE `posts` DISABLE KEYS */;
INSERT INTO `posts` VALUES (1,1,'Do an IoT cuoi ky da hoan thanh! Cam on anh em da chien dau cung nhau 2 thang. He thong theo doi nhiet do phong hoc real-time qua app. #IoT #HCMUTE','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617063/uterspace_uploads/post_img_1.jpg','public','IMAGE',NULL,0,15,9,0,'2026-09-07 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.905,'LEXICON',NULL,NULL,NULL),(2,2,'Phat hien quan cafe moi mo goc duong Vo Van Ngan, view sieu chill cho mua deadline. Ai muon di cung khong? Ly ca phe trung ngon hon ca Ha Noi! #coffee','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617068/uterspace_uploads/post_img_2.jpg','public','IMAGE',NULL,0,15,11,0,'2026-09-08 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.922,'LEXICON',NULL,NULL,NULL),(3,3,'Test thu mo hinh robot do line cho cuoc thi cuoi tuan. Chay muot hon nho thay cam bien IR sang lidar mini! #Robotics #Maker #CLBRobotics','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617069/uterspace_uploads/post_img_3.jpg','public','IMAGE',NULL,0,16,10,0,'2026-09-09 23:33:00',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(4,4,'Goc hoc tap chuan bi cho tuan thi cuoi ky. Quyet tam hoc bong hoc ky nay! Moi nguoi chia se meo hoc bai hieu qua nha. #StudySpace #HCMUTE','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617069/uterspace_uploads/post_img_4.jpg','public','IMAGE',NULL,0,15,12,0,'2026-09-09 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.852,'LEXICON',NULL,NULL,NULL),(5,6,'Ca team vua chot xong requirement cho do an Phan tich thiet ke he thong. Co len anh em, con 3 tuan nua la demo roi! #TeamWork #SoftwareEngineering','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617071/uterspace_uploads/post_img_5.jpg','public','IMAGE',NULL,0,16,8,0,'2026-09-10 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.53,'LEXICON',NULL,NULL,NULL),(6,7,'Ngay cuoi thuc tap tai cty phan mem. 3 thang nhieu ky niem dep, hoc duoc rat nhieu. Cam on anh chi mentor da huong dan nhiet tinh! #Intern #Career','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617072/uterspace_uploads/post_img_6.jpg','public','IMAGE',NULL,0,16,11,0,'2026-09-10 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.952,'LEXICON',NULL,NULL,NULL),(7,1,'Cho minh hoi thu vien trung tam HCMUTE chu nhat co mo cua khong? Can tim mot so sach tham khao cho bao cao do an. Cam on!',NULL,'public',NULL,NULL,0,11,10,0,'2026-09-11 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.747,'LEXICON',NULL,NULL,NULL),(8,8,'Vua solve xong challenge Web Exploitation tren HackTheBox sau 2 ngay ngoi. Flag cuoi cung hien len khong khac gi len dinh Everest! #CTF #Cybersecurity',NULL,'public',NULL,NULL,0,15,12,0,'2026-09-11 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.747,'LEXICON',NULL,NULL,NULL),(9,5,'Sharing tai nguyen hoc IELTS mien phi: Cambridge 1-18 PDF, E2IELTS YouTube, British Council app. Cu DM minh neu can them nha! #IELTS #English',NULL,'public',NULL,NULL,0,16,13,0,'2026-09-12 23:33:00',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(10,9,'Hoan thanh ban phac thao concept nha o xa hoi than thien moi truong. Moi nguoi thay sao? Minh muon tich hop vuon dung tren mat dung phia Nam. #Architecture',NULL,'public',NULL,NULL,0,13,9,0,'2026-09-12 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.832,'LEXICON',NULL,NULL,NULL),(11,2,'Tong hop 10 quan an sinh vien ngon re gan HCMUTE. Tu 20k den 40k, an no an ngon. Full list trong comment ben duoi! #FoodReview #HCMUTELife',NULL,'public',NULL,NULL,0,16,14,1,'2026-09-13 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.905,'LEXICON',NULL,NULL,NULL),(12,4,'UI Design challenge: Redesign app dat xe cho thi truong VN. Dung Figma de mockup trong 4 gio. Feedback chan thanh tu anh em nhe! #UIDesign #UX #Figma',NULL,'public',NULL,NULL,0,14,9,0,'2026-09-13 23:33:00',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(13,6,'Vua hoan thanh cai dat home server voi RPi 4B: NAS luu tru, VPN, Pi-hole chan quang cao va Home Assistant. Tat ca chay on dinh 24/7. AMA! #RaspberryPi',NULL,'public',NULL,NULL,0,15,13,0,'2026-09-14 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.905,'LEXICON',NULL,NULL,NULL),(14,3,'CLB Robotics dang tuyen them thanh vien moi! Khong can kinh nghiem, chi can dam me. Workshop thu 7 tai C206. Tag ban be vao day nha! #Robotics',NULL,'public',NULL,NULL,0,16,15,0,'2026-09-14 23:33:00',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(15,1,'Cam on moi nguoi da support kenh code cua minh. 100 followers dau tien! Sap toi lam series Spring Boot va microservices. Stay tuned! #SpringBoot #Java',NULL,'public',NULL,NULL,0,16,17,1,'2026-09-14 23:33:00',NULL,NULL,'ACTIVE',0,'POSITIVE',0.781,'LEXICON',NULL,NULL,NULL),(16,1,'Hello cả nha','','public',NULL,NULL,0,10,8,0,'2026-09-15 00:55:02',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(18,22,'Vừa hoàn thành giao diện trang chủ cho đồ án môn Lập trình Web. Lần đầu tự tay làm responsive mà không copy template, mừng muốn khóc! #WebProgramming #Frontend','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617073/uterspace_uploads/post_img_7.jpg','public',NULL,NULL,0,10,8,0,'2026-09-18 12:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(19,18,'Mẹo nhỏ cho các bạn học Java: đừng học thuộc cú pháp, hãy hiểu vì sao người ta thiết kế như vậy. Mình mất 2 năm mới ngộ ra điều này. #Java #HocTap',NULL,'public',NULL,NULL,0,11,7,0,'2026-09-18 10:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.447,'LEXICON',NULL,NULL,NULL),(20,15,'Ngày đầu đi thực tập tại công ty fintech. Được anh mentor giao task nhỏ mà hồi hộp như thi cuối kỳ. Cố lên nào!','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617073/uterspace_uploads/post_img_8.jpg','public',NULL,NULL,0,9,7,0,'2026-09-18 08:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.747,'LEXICON',NULL,NULL,NULL),(21,25,'Có bạn nào đang học React không cho mình join team với. Mình đang làm một app quản lý chi tiêu cho sinh viên, cần thêm người cùng làm cho vui. #React #TimTeam',NULL,'public',NULL,NULL,0,11,8,0,'2026-09-18 05:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.707,'LEXICON',NULL,NULL,NULL),(22,28,'Lịch học nhóm IELTS Speaking tuần này: thứ 3 và thứ 6, 18h tại thư viện tầng 3. Bạn nào muốn tham gia thì nhắn mình nhé, hoàn toàn miễn phí!',NULL,'public',NULL,NULL,0,10,7,0,'2026-09-18 02:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(23,23,'Săn được học bổng trao đổi ngắn hạn 2 tuần tại Singapore. Kinh nghiệm: nộp sớm, viết luận thật, đừng cố make up câu chuyện. #HocBong #KinhTe','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617075/uterspace_uploads/post_img_9.jpg','public',NULL,NULL,0,9,8,0,'2026-09-17 22:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.894,'LEXICON',NULL,NULL,NULL),(24,19,'Mạch cảm biến nhiệt độ của nhóm mình chạy ổn định sau 3 lần cháy linh kiện. Ai làm phần cứng chắc hiểu cảm giác này. #IoT #DienTu','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617063/uterspace_uploads/post_img_10.jpg','public',NULL,NULL,0,10,6,0,'2026-09-17 18:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.447,'LEXICON',NULL,NULL,NULL),(25,20,'Bản vẽ mặt bằng cuối cùng cũng xong sau 3 đêm thức trắng. AutoCAD ơi là AutoCAD. #XayDung #DoAn',NULL,'public',NULL,NULL,0,9,8,0,'2026-09-17 14:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(26,22,'Quán cà phê mới mở gần cổng sau: yên tĩnh, ổ cắm nhiều, nước uống 25k. Rất hợp để ngồi làm đồ án cả buổi chiều. #CaPhe #HCMUTE','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617065/uterspace_uploads/post_img_11.jpg','public',NULL,NULL,0,11,6,0,'2026-09-17 08:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.447,'LEXICON',NULL,NULL,NULL),(27,21,'Chia sẻ bộ tài liệu ôn thi Vi xử lý mình tổng hợp suốt học kỳ. Link Drive để dưới bình luận, các bạn cứ lấy dùng thoải mái nha. #TaiLieu #ViXuLy','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617066/uterspace_uploads/post_img_12.jpg','public',NULL,NULL,0,10,7,0,'2026-09-17 04:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.707,'LEXICON',NULL,NULL,NULL),(28,27,'Xưởng cơ khí hôm nay đông kinh khủng, chờ máy tiện gần 2 tiếng. Nhưng mà thành phẩm ra đẹp nên cũng đáng. #CoKhi',NULL,'public',NULL,NULL,0,10,8,0,'2026-09-16 22:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(29,24,'Cuối tuần theo mấy anh khóa trên ra gara học tháo lắp động cơ. Học ở xưởng một buổi bằng đọc sách cả tuần thật sự. #OTo','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617066/uterspace_uploads/post_img_13.jpg','public',NULL,NULL,0,10,7,0,'2026-09-16 16:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(30,16,'Bộ sưu tập đồ án tốt nghiệp của mình lấy cảm hứng từ áo dài truyền thống. Đang phác thảo mẫu thứ 12 rồi mà vẫn chưa ưng. #ThoiTrang #DoAnCuoiKy',NULL,'public',NULL,NULL,0,10,8,0,'2026-09-16 10:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.832,'LEXICON',NULL,NULL,NULL),(31,26,'CLB Sách tuần này đọc chung cuốn \"Nhà giả kim\". Buổi thảo luận 19h thứ 5 tại phòng A3-204, mọi người tới đông nha!',NULL,'public',NULL,NULL,0,10,6,0,'2026-09-16 04:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(32,17,'Vừa đi tour thực tế ở Vũng Tàu về. Ngành Du lịch cái hay là bài tập nhiều khi là... đi chơi rồi viết báo cáo. #DuLich','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617067/uterspace_uploads/post_img_14.jpg','public',NULL,NULL,0,9,8,0,'2026-09-15 20:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(33,15,'Hôm nay được review code lần đầu. 27 comment. Mà anh mentor nói vậy là ít so với người mới. Về đọc lại Clean Code đây. #ThucTap',NULL,'public',NULL,NULL,0,9,6,0,'2026-09-15 14:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.707,'LEXICON',NULL,NULL,NULL),(34,18,'Docker Compose thật sự cứu mạng khi làm đồ án nhóm. Không còn cảnh \"máy tao chạy được mà máy mày lỗi\" nữa. #Docker #DevOps',NULL,'public',NULL,NULL,0,11,7,0,'2026-09-15 06:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.447,'LEXICON',NULL,NULL,NULL),(35,25,'Góc học tập mới setup xong. Bàn 1m2, đèn vàng, một chậu sen đá. Ngồi học tự dưng thấy siêng hơn hẳn. #StudySetup','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617067/uterspace_uploads/post_img_15.jpg','public',NULL,NULL,0,9,8,0,'2026-09-14 20:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.447,'LEXICON',NULL,NULL,NULL),(36,23,'Kinh nghiệm thuyết trình mà mình rút ra sau 4 học kỳ: chuẩn bị kỹ phần mở đầu, 30 giây đầu quyết định cả bài. #KyNangMem',NULL,'public',NULL,NULL,0,10,7,0,'2026-09-14 10:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(37,28,'Chúc mừng các bạn khóa 2022 vừa hoàn thành kỳ thi giữa kỳ. Nghỉ ngơi một chút rồi chiến tiếp nhé!',NULL,'public',NULL,NULL,0,10,8,0,'2026-09-13 22:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.934,'LEXICON',NULL,NULL,NULL),(38,19,'Team mình vừa nộp báo cáo đồ án IoT lúc 23h58, sát nút deadline 2 phút. Cảm giác vừa mệt vừa sung sướng.','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617054/uterspace_uploads/group_cover_12.jpg','public',NULL,NULL,0,10,6,0,'2026-09-13 08:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',-0.243,'LEXICON',NULL,NULL,NULL),(39,20,'Ai có tài liệu môn Sức bền vật liệu cho mình xin với. Đổi lại mình có full slide môn Cơ học kết cấu nha. #TaiLieu',NULL,'public',NULL,NULL,0,11,8,0,'2026-09-12 18:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(40,19,'Vlog: một ngày làm đồ án ở phòng Lab Điện tử — từ 7h sáng tới 10h tối','iot_project.jpg','public','VIDEO','https://res.cloudinary.com/yjjoybu5/video/upload/v1791617076/uterspace_uploads/post_video_1.mp4',10,11,7,0,'2026-09-18 09:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(41,22,'Hướng dẫn dựng giao diện trang đăng nhập bằng HTML + CSS thuần trong 15 phút','study_setup.jpg','public','VIDEO','https://res.cloudinary.com/yjjoybu5/video/upload/v1791617080/uterspace_uploads/post_video_2.mp4',10,11,7,0,'2026-09-18 00:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(42,24,'Demo tháo lắp động cơ 4 kỳ — bài thực hành môn Công nghệ Ô tô','robot_demo.jpg','public','VIDEO','https://res.cloudinary.com/yjjoybu5/video/upload/v1791617081/uterspace_uploads/post_video_3.mp4',10,9,8,0,'2026-09-17 10:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(43,18,'Chia sẻ: cách mình chuẩn bị cho vòng phỏng vấn thực tập Java Backend','intern_last_day.jpg','public','VIDEO','https://res.cloudinary.com/yjjoybu5/video/upload/v1791617082/uterspace_uploads/post_video_4.mp4',10,9,6,0,'2026-09-16 18:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(44,17,'Tour thực tế Vũng Tàu cùng lớp Du lịch K21 — bản đầy đủ','cover_hcmute.jpg','public','VIDEO','https://res.cloudinary.com/yjjoybu5/video/upload/v1791617083/uterspace_uploads/post_video_5.mp4',10,11,7,0,'2026-09-15 16:33:58',NULL,NULL,'ACTIVE',0,'POSITIVE',0.447,'LEXICON',NULL,NULL,NULL),(45,26,'Talkshow CLB Sách: đọc sách thế nào để không quên sau một tuần','cafe_review.jpg','public','VIDEO','https://res.cloudinary.com/yjjoybu5/video/upload/v1791617084/uterspace_uploads/post_video_6.mp4',10,10,6,0,'2026-09-14 14:33:58',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(47,33,'xin chào cả nha, tôi muốn tìm hiểu thông tin về đại hội này','uploads/posts/99fa4751-1d69-4a33-b1c8-d522b19ffc5e.png','public','IMAGE',NULL,0,0,0,0,'2026-10-08 08:20:07',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(48,33,'oke bạn nhó',NULL,'public',NULL,NULL,0,1,0,0,'2026-10-08 08:21:02',15,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(49,33,'Tôi muốn tìm việc làm part time!!!',NULL,'public',NULL,NULL,0,0,0,0,'2026-10-08 08:22:14',NULL,10,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(50,1,'',NULL,'public',NULL,NULL,0,0,0,0,'2026-10-08 09:03:12',11,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL),(51,1,'ảnh trái đất','uploads/posts/a3a55f22-cde5-465b-b5d8-2bb254350903.jpg','public','IMAGE',NULL,0,0,0,0,'2026-10-08 09:04:28',NULL,NULL,'ACTIVE',0,'NEUTRAL',0,'LEXICON',NULL,NULL,NULL);
/*!40000 ALTER TABLE `posts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reports`
--

DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reports` (
  `report_id` int NOT NULL AUTO_INCREMENT,
  `reporter_id` int NOT NULL,
  `target_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_id` int NOT NULL,
  `reason` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `detail` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `handled_by` int DEFAULT NULL,
  `handled_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`report_id`),
  UNIQUE KEY `uq_reports_once` (`reporter_id`,`target_type`,`target_id`),
  KEY `ix_reports_queue` (`status`,`target_type`,`target_id`),
  KEY `ix_reports_handled_by` (`handled_by`),
  CONSTRAINT `fk_reports_handler` FOREIGN KEY (`handled_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_reports_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reports`
--

LOCK TABLES `reports` WRITE;
/*!40000 ALTER TABLE `reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `saved_posts`
--

DROP TABLE IF EXISTS `saved_posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `saved_posts` (
  `saved_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `post_id` int NOT NULL,
  `saved_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`saved_id`),
  UNIQUE KEY `uq_saved` (`user_id`,`post_id`),
  KEY `ix_saved_posts_post` (`post_id`),
  CONSTRAINT `fk_saved_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_saved_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `saved_posts`
--

LOCK TABLES `saved_posts` WRITE;
/*!40000 ALTER TABLE `saved_posts` DISABLE KEYS */;
INSERT INTO `saved_posts` VALUES (1,1,2,'2026-09-09 23:33:00'),(2,1,9,'2026-09-13 23:33:00'),(3,1,8,'2026-09-12 23:33:00'),(4,2,9,'2026-09-13 23:33:00'),(5,2,11,'2026-09-14 23:33:00'),(6,3,14,'2026-09-14 23:33:00'),(7,4,9,'2026-09-13 23:33:00'),(8,4,12,'2026-09-14 23:33:00'),(9,5,9,'2026-09-13 23:33:00'),(10,6,13,'2026-09-14 23:33:00'),(11,7,11,'2026-09-14 23:33:00'),(12,8,15,'2026-09-14 23:33:00'),(13,4,18,'2026-09-17 20:33:58'),(14,4,19,'2026-09-17 19:33:58'),(15,4,40,'2026-09-16 22:33:58'),(16,4,20,'2026-09-17 18:33:58'),(17,4,21,'2026-09-17 17:33:58'),(18,4,22,'2026-09-17 16:33:58');
/*!40000 ALTER TABLE `saved_posts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `search_history`
--

DROP TABLE IF EXISTS `search_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `search_history` (
  `search_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `query` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`search_id`),
  KEY `ix_search_history_user` (`user_id`,`created_at` DESC),
  CONSTRAINT `fk_search_history_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `search_history`
--

LOCK TABLES `search_history` WRITE;
/*!40000 ALTER TABLE `search_history` DISABLE KEYS */;
INSERT INTO `search_history` VALUES (5,1,'Khuê Lê','2026-10-18 16:27:15'),(6,11,'IoT','2026-10-18 18:58:14');
/*!40000 ALTER TABLE `search_history` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stories`
--

DROP TABLE IF EXISTS `stories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stories` (
  `story_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `media_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `media_type` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `caption` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `duration_sec` int DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` datetime NOT NULL,
  PRIMARY KEY (`story_id`),
  KEY `ix_stories_user_expires` (`user_id`,`expires_at`),
  KEY `ix_stories_expires` (`expires_at`),
  KEY `ix_stories_user_created` (`user_id`,`created_at` DESC),
  CONSTRAINT `fk_stories_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stories`
--

LOCK TABLES `stories` WRITE;
/*!40000 ALTER TABLE `stories` DISABLE KEYS */;
/*!40000 ALTER TABLE `stories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `story_reactions`
--

DROP TABLE IF EXISTS `story_reactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_reactions` (
  `story_id` int NOT NULL,
  `user_id` int NOT NULL,
  `emoji` varchar(8) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '❤️',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`story_id`,`user_id`),
  KEY `ix_story_reactions_user` (`user_id`),
  CONSTRAINT `fk_story_reactions_story` FOREIGN KEY (`story_id`) REFERENCES `stories` (`story_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_story_reactions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `story_reactions`
--

LOCK TABLES `story_reactions` WRITE;
/*!40000 ALTER TABLE `story_reactions` DISABLE KEYS */;
/*!40000 ALTER TABLE `story_reactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `story_views`
--

DROP TABLE IF EXISTS `story_views`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `story_views` (
  `story_id` int NOT NULL,
  `viewer_id` int NOT NULL,
  `viewed_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`story_id`,`viewer_id`),
  KEY `ix_story_views_viewer` (`viewer_id`),
  CONSTRAINT `fk_story_views_story` FOREIGN KEY (`story_id`) REFERENCES `stories` (`story_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_story_views_viewer` FOREIGN KEY (`viewer_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `story_views`
--

LOCK TABLES `story_views` WRITE;
/*!40000 ALTER TABLE `story_views` DISABLE KEYS */;
/*!40000 ALTER TABLE `story_views` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_blocks`
--

DROP TABLE IF EXISTS `user_blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_blocks` (
  `blocker_id` int NOT NULL,
  `blocked_id` int NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`blocker_id`,`blocked_id`),
  KEY `ix_user_blocks_blocked` (`blocked_id`),
  CONSTRAINT `fk_user_blocks_blocked` FOREIGN KEY (`blocked_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_blocks_blocker` FOREIGN KEY (`blocker_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_blocks`
--

LOCK TABLES `user_blocks` WRITE;
/*!40000 ALTER TABLE `user_blocks` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_blocks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_dids`
--

DROP TABLE IF EXISTS `user_dids`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_dids` (
  `user_id` int NOT NULL,
  `did` varchar(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `public_key` varbinary(64) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `ux_user_dids_did` (`did`),
  CONSTRAINT `fk_user_dids_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_dids`
--

LOCK TABLES `user_dids` WRITE;
/*!40000 ALTER TABLE `user_dids` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_dids` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_settings`
--

DROP TABLE IF EXISTS `user_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_settings` (
  `user_id` int NOT NULL,
  `friend_request_policy` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'EVERYONE',
  `message_policy` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'EVERYONE',
  `show_online` tinyint(1) NOT NULL DEFAULT '1',
  `notif_friend` tinyint(1) NOT NULL DEFAULT '1',
  `notif_interaction` tinyint(1) NOT NULL DEFAULT '1',
  `notif_group` tinyint(1) NOT NULL DEFAULT '1',
  `notif_message` tinyint(1) NOT NULL DEFAULT '1',
  `push_friend` tinyint(1) NOT NULL DEFAULT '1',
  `push_interaction` tinyint(1) NOT NULL DEFAULT '0',
  `push_group` tinyint(1) NOT NULL DEFAULT '0',
  `push_message` tinyint(1) NOT NULL DEFAULT '1',
  `push_account` tinyint(1) NOT NULL DEFAULT '1',
  `updated_at` datetime DEFAULT NULL,
  `archive_stories` tinyint(1) NOT NULL DEFAULT '1',
  `feed_mode` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SMART',
  `hide_negative` tinyint(1) NOT NULL DEFAULT '0',
  `content_filter` varchar(2000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_user_settings_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `ck_us_feed_mode` CHECK ((`feed_mode` in (_utf8mb4'SMART',_utf8mb4'LATEST')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_settings`
--

LOCK TABLES `user_settings` WRITE;
/*!40000 ALTER TABLE `user_settings` DISABLE KEYS */;
INSERT INTO `user_settings` VALUES (14,'EVERYONE','EVERYONE',1,1,1,1,1,1,0,0,1,1,'2026-10-18 16:21:08',1,'LATEST',0,NULL);
/*!40000 ALTER TABLE `user_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `user_id` int NOT NULL AUTO_INCREMENT,
  `first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'USER',
  `bio` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `location` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `website` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cover_image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ACTIVE',
  `locked_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_active_at` datetime DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uq_users_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Duc Huy','Nguyen','duy@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617040/uterspace_uploads/avatar_1.jpg','USER','Yeu code, thich ca phe. Dang lam do an IoT.','Thu Duc, Ho Chi Minh City',NULL,'uploads/covers/f4c1c1e8-878b-417f-8e1a-6c778aae3448.jpg','2026-09-14 23:33:00','ACTIVE',NULL,'2026-10-18 16:59:12'),(2,'Lan Anh','Tran','lananh@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617046/uterspace_uploads/avatar_2.jpg','USER','Me du lich, doc sach va review do an.','Quan 1, HCM',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(3,'Gia Bao','Le','giabao@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617047/uterspace_uploads/avatar_3.jpg','USER','Dam me Robot va xe co gioi. Leader CLB Robotics.','Quan 9, HCM',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(4,'Minh Ha','Pham','minhha@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617048/uterspace_uploads/avatar_4.jpg','USER','Thich ve va thiet ke UI/UX. Mo lam tai Google.','Go Vap, HCM',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,'2026-10-12 13:57:11'),(5,'Ngoc Han','Bui','ngochan@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617048/uterspace_uploads/avatar_5.jpg','USER','Biet 3 ngoai ngu. Dich thuat la dam me.','Binh Thanh, HCM',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(6,'Tan Phat','Vo','tanphat@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617049/uterspace_uploads/avatar_6.jpg','USER','Maker chinh hieu. Nghien Arduino va Raspberry Pi.','Thu Duc, HCM',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(7,'Thao My','Dang','thaomy@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617050/uterspace_uploads/avatar_7.jpg','USER','Yeu mau hong, ghet su gia doi. Drama-free zone.','Quan 3, HCM',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(8,'Hoang Nam','Trinh','hoangnam@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617051/uterspace_uploads/avatar_8.jpg','USER','Tim hieu ve cybersecurity va pentesting. CTF player.','Binh Duong',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(9,'Thu Hang','Vu','thuhang@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617051/uterspace_uploads/avatar_9.jpg','USER','Phac thao moi luc moi noi. Yeu khong gian xanh.','Quan 7, HCM',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(10,'Quoc Bao','Ly','quocbao@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617042/uterspace_uploads/avatar_10.jpg','USER','Co dong vien bong da cuong nhiet. Man Utd fan.','Long An',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,NULL),(11,'Admin','UTEr','admin@uterspace.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617043/uterspace_uploads/avatar_11.jpg','ADMIN','Quan tri vien he thong UTErSpace.','HCMUTE Campus',NULL,NULL,'2026-09-14 23:33:00','ACTIVE',NULL,'2026-10-08 09:07:27'),(14,'Khuê','Lê','nhatkhue2006@gmail.com','$2a$12$5a7zLOpvowTZsDSA.md/reA3JyfTQTk/FzOfqVuyZFL6HC48akb4y',NULL,'USER',NULL,NULL,NULL,NULL,'2026-09-17 08:55:48','ACTIVE',NULL,'2026-10-18 19:41:09'),(15,'Anh Tuấn','Lâm','anhtuan@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617044/uterspace_uploads/avatar_12.jpg','USER','CNTT. Đang thực tập tại một công ty fintech ở Quận 1.','Quận 12, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(16,'Bảo Ngọc','Lý','baongoc@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617044/uterspace_uploads/avatar_13.jpg','USER','Công nghệ May & Thời trang. Mình vẽ phác thảo mỗi ngày.','Bình Tân, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(17,'Diễm Quỳnh','Võ','diemquynh@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617045/uterspace_uploads/avatar_14.jpg','USER','Du lịch & Lữ hành. Đi được 18/63 tỉnh thành rồi!','Quận 5, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(18,'Đức Anh','Hoàng','ducanh@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW','https://res.cloudinary.com/yjjoybu5/image/upload/v1791617046/uterspace_uploads/avatar_15.jpg','USER','CNTT K20. Backend Java, đang học thêm Docker.','Biên Hòa, Đồng Nai','https://linkedin.com/in/ducanh',NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(19,'Gia Huy','Phạm','giahuy@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Điện tử viễn thông. Thích làm mạch và quay vlog quá trình.','Thủ Đức, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(20,'Hải Yến','Trương','haiyen@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Xây dựng K22. Mê vẽ AutoCAD hơn mê ngủ nướng.','Gò Vấp, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(21,'Hữu Thắng','Đinh','huuthang@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Điện - Điện tử. Đang nghịch ESP32 và mấy con cảm biến.','Thủ Đức, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(22,'Khánh Linh','Nguyễn','khanhlinh@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Sinh viên CNTT năm 3. Mê front-end và mấy cái animation mượt mượt.','Tân Bình, HCM','https://github.com/khanhlinh',NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(23,'Mai Phương','Đỗ','maiphuong@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Kinh tế K21. Thích đọc sách và săn học bổng trao đổi.','Quận 10, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(24,'Minh Quân','Đặng','minhquan@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Công nghệ Ô tô. Cuối tuần hay ra gara phụ mấy anh khóa trên.','Thủ Đức, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(25,'Nhật Minh','Trần','nhatminh@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','CNTT K22. Mới bắt đầu học React, ai cùng team không?','Thuận An, Bình Dương',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(26,'Thanh Trúc','Nguyễn','thanhtruc@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Kế toán K21. Chủ nhiệm CLB Sách của trường.','Tân Phú, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(27,'Trọng Nghĩa','Phan','trongnghia@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Khoa Cơ khí. Ngày làm đồ án, tối chạy bộ quanh ký túc xá.','Dĩ An, Bình Dương',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(28,'Tuyết Nhi','Cao','tuyetnhi@student.hcmute.edu.vn','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Sư phạm Anh văn. Nhận kèm IELTS cho các bạn cùng trường nha.','Quận 4, HCM',NULL,NULL,'2026-09-18 14:33:58','ACTIVE',NULL,NULL),(29,'Test','A','a@test.com','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Tài khoản test A','HCMUTE',NULL,NULL,'2026-10-01 08:09:07','ACTIVE',NULL,NULL),(30,'Test','B','b@test.com','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Tài khoản test B','HCMUTE',NULL,NULL,'2026-10-01 08:09:07','ACTIVE',NULL,NULL),(31,'Test','C','c@test.com','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'USER','Tài khoản test C','HCMUTE',NULL,NULL,'2026-10-01 08:09:07','ACTIVE',NULL,NULL),(32,'Test','Admin','admin@test.com','$2a$12$.lofQbX.atVB95OGo1KiNei8afk5KyNOWs6WjkxGLlIs3ofTBfKyW',NULL,'ADMIN','Tài khoản quản trị dùng để test','HCMUTE',NULL,NULL,'2026-10-01 08:09:07','ACTIVE',NULL,'2026-10-18 19:42:42'),(33,'Nguyễn Hữu','Phú','24110122@student.hcmute.edu.vn','$2a$12$zuEaUHzW4Taa9RgYA.74l.fWLpZr8QhtV0mJ32x4o6umJ8eS5wnRu','uploads/avatars/f640015f-0592-4a06-82b7-58dfc2c57b0c.jpg','USER',NULL,NULL,NULL,NULL,'2026-10-08 08:15:18','ACTIVE',NULL,'2026-10-08 08:42:54'),(34,'Nguyễn','Khang','nguyenqbkhang@gmail.com','$2a$12$FRVbAHx0gqv8ABoQJe1wY.mr52MeSI9dnQrswz1SLw5jxWdO.M.Ni',NULL,'USER',NULL,NULL,NULL,NULL,'2026-10-18 16:46:34','ACTIVE',NULL,'2026-10-18 16:57:05');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `webauthn_credentials`
--

DROP TABLE IF EXISTS `webauthn_credentials`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `webauthn_credentials` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `credential_id` varchar(700) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `public_key` varbinary(1024) NOT NULL,
  `alg` int NOT NULL,
  `sign_count` bigint NOT NULL DEFAULT '0',
  `label` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ux_webauthn_credential` (`credential_id`),
  KEY `ix_webauthn_user` (`user_id`),
  CONSTRAINT `fk_webauthn_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `webauthn_credentials`
--

LOCK TABLES `webauthn_credentials` WRITE;
/*!40000 ALTER TABLE `webauthn_credentials` DISABLE KEYS */;
/*!40000 ALTER TABLE `webauthn_credentials` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'defaultdb'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-19  0:46:42
