<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="legalTitle" value="Chính sách bảo mật" />
<%@ include file="legal-head.jsp" %>

      <p class="legal-lead">
        Chính sách này giải thích UTErSpace thu thập dữ liệu gì, dùng để làm gì và bạn kiểm soát dữ liệu của mình ra sao.
        Đọc kèm <a href="${ctx}/terms">Điều khoản sử dụng</a>.
      </p>

      <h2>1. Dữ liệu chúng tôi lưu</h2>
      <ul>
        <li><b>Tài khoản:</b> họ tên, email, mật khẩu (chỉ lưu dạng băm BCrypt), ảnh đại diện, ảnh bìa, giới thiệu, nơi ở, website.</li>
        <li><b>Nội dung:</b> bài viết, ảnh, video, phụ đề, mô hình 3D, tin, bình luận, lượt thích, bài đã lưu, tin nhắn và tệp đính kèm.</li>
        <li><b>Quan hệ:</b> bạn bè, lời mời kết bạn, nhóm, danh sách chặn.</li>
        <li><b>Hoạt động:</b> thời điểm hoạt động gần nhất, lượt xem tin, lượt thả tim tin, từ khóa bạn tìm kiếm (để gợi ý nội dung), địa chỉ IP của quản trị viên khi thao tác quản trị.</li>
        <li><b>Bảo mật:</b> khóa công khai của passkey (WebAuthn) và của danh tính số DID. <b>Không</b> lưu dữ liệu sinh trắc học.</li>
      </ul>

      <h2>2. Mục đích sử dụng</h2>
      <ul>
        <li>Hiển thị bảng tin, tin, nhóm, tin nhắn và thông báo theo đúng quyền riêng tư bạn chọn.</li>
        <li><b>Gợi ý &amp; cá nhân hóa:</b> gợi ý kết bạn (bạn chung, nhóm chung, cùng khu vực, sở thích giống nhau, danh bạ bạn tự nhập), gợi ý nhóm / hashtag / video, sắp xếp bảng tin theo mức độ quan tâm. Mọi tính toán chạy trên máy chủ UTErSpace.</li>
        <li><b>An toàn cộng đồng:</b> phân tích cảm xúc bài viết, xử lý báo cáo vi phạm, phát hiện đăng nhập lạ.</li>
      </ul>

      <h2>3. Danh bạ</h2>
      <p>Khi bạn dùng "Tìm bạn từ danh bạ", danh sách email bạn chọn chỉ được dùng <b>một lần</b> để đối chiếu với tài khoản đã đăng ký và <b>không được lưu lại</b>.</p>

      <h2>4. Chia sẻ dữ liệu với bên thứ ba</h2>
      <ul>
        <li>UTErSpace không bán dữ liệu của bạn.</li>
        <li>Khi bạn chủ động dùng Trợ lý AI (viết chú thích, tóm tắt, dịch), đoạn văn bản / ảnh bạn chọn được gửi tới nhà cung cấp AI do máy chủ cấu hình (Google Gemini API hoặc Anthropic Claude API) để xử lý. Nếu máy chủ chưa cấu hình AI, hệ thống dùng thuật toán nội bộ và không gửi gì ra ngoài.</li>
        <li>Phân tích cảm xúc của bài viết mới cũng có thể dùng Gemini / Claude API khi được cấu hình.</li>
        <li>Trình xem ảnh 360°, mô hình 3D/AR và mô hình nhận dạng giọng nói được tải từ CDN công khai (cdnjs, jsDelivr, Hugging Face); chỉ có mã nguồn / mô hình được tải về, nội dung của bạn không gửi đi.</li>
      </ul>

      <h2>5. Quyền của bạn</h2>
      <ul>
        <li>Chỉnh sửa, ẩn ("Chỉ mình tôi") hoặc xóa bài viết, tin và tin nhắn của mình bất cứ lúc nào.</li>
        <li>Tắt lưu trữ tin, bật / tắt bảng tin cá nhân hóa, ẩn bài tiêu cực, đặt bộ lọc từ khóa trong <i>Cài đặt</i>.</li>
        <li>Xuất dữ liệu cá nhân có chữ ký số (Verifiable Credential) trong <i>Cài đặt → Danh tính số</i>.</li>
        <li>Xóa passkey và hủy liên kết DID bất cứ lúc nào.</li>
      </ul>

      <h2>6. Lưu trữ và bảo vệ</h2>
      <ul>
        <li>Mật khẩu băm bằng BCrypt; mọi thao tác ghi đều có token chống giả mạo (CSRF); cookie phiên dùng SameSite=Lax.</li>
        <li>Tệp đính kèm tin nhắn nằm ngoài thư mục công khai, chỉ thành viên cuộc trò chuyện tải được.</li>
        <li>Tin hết hạn không còn hiển thị cho người khác; bản lưu trữ chỉ chủ tin xem được.</li>
      </ul>

      <h2>7. Liên hệ</h2>
      <p>Mọi câu hỏi về dữ liệu cá nhân, vui lòng gửi tới <a href="mailto:support@uterspace.local">support@uterspace.local</a> hoặc nhắn tin cho quản trị viên trên UTErSpace.</p>

<%@ include file="legal-foot.jsp" %>
