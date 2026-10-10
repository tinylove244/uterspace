<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="legalTitle" value="Điều khoản sử dụng" />
<%@ include file="legal-head.jsp" %>

      <p class="legal-lead">
        Chào mừng bạn đến với <b>UTErSpace</b> — mạng xã hội dành cho sinh viên Trường Đại học Sư phạm Kỹ thuật TP.HCM (HCMUTE).
        Khi tạo tài khoản hoặc sử dụng bất kỳ tính năng nào của UTErSpace, bạn xác nhận đã đọc, hiểu và đồng ý với các điều khoản dưới đây
        cùng với <a href="${ctx}/privacy">Chính sách bảo mật</a>. Nếu không đồng ý, vui lòng không sử dụng dịch vụ.
      </p>

      <h2>1. Tài khoản của bạn</h2>
      <ul>
        <li>Bạn phải cung cấp họ tên và email thật khi đăng ký; mỗi người chỉ dùng <b>một</b> tài khoản cá nhân.</li>
        <li>Mật khẩu tối thiểu 8 ký tự, có chữ hoa và ký tự đặc biệt. Bạn chịu trách nhiệm giữ bí mật mật khẩu, khóa sinh trắc học (passkey) và khóa danh tính số (DID) của mình.</li>
        <li>Không mượn, bán, chuyển nhượng tài khoản. Phát hiện truy cập lạ, hãy đổi mật khẩu ngay trong <i>Cài đặt → Tài khoản &amp; bảo mật</i>.</li>
        <li>Quản trị viên có quyền khóa tài khoản vi phạm điều khoản; lý do khóa được hiển thị khi bạn đăng nhập.</li>
      </ul>

      <h2>2. Quy tắc cộng đồng</h2>
      <p>Bạn <b>không được</b> đăng, chia sẻ, bình luận hoặc nhắn tin các nội dung:</p>
      <ul>
        <li>Xúc phạm, bắt nạt, quấy rối, đe dọa, phân biệt đối xử về giới tính, vùng miền, tôn giáo, khuyết tật…</li>
        <li>Khiêu dâm, bạo lực, cổ súy hành vi tự gây hại, chất cấm hoặc hoạt động vi phạm pháp luật Việt Nam.</li>
        <li>Thông tin sai sự thật, lừa đảo, spam, quảng cáo trái phép, đường dẫn độc hại.</li>
        <li>Thông tin cá nhân của người khác (số điện thoại, địa chỉ, ảnh riêng tư…) khi chưa được họ đồng ý.</li>
        <li>Gian lận học thuật: mua bán bài thi, đáp án, đồ án, luận văn.</li>
      </ul>
      <p>Bạn có thể dùng nút <b>Báo cáo vi phạm</b> trên bài viết, bình luận hoặc trang cá nhân. Quản trị viên xem xét và có thể ẩn, xóa nội dung hoặc khóa tài khoản.</p>

      <h2>3. Nội dung bạn đăng</h2>
      <ul>
        <li>Bạn giữ quyền sở hữu nội dung của mình (bài viết, ảnh, video, tin, mô hình 3D). Khi đăng, bạn cho phép UTErSpace lưu trữ và hiển thị nội dung đó cho đúng đối tượng bạn chọn: <b>Công khai</b>, <b>Bạn bè</b> hoặc <b>Chỉ mình tôi</b>.</li>
        <li>Bạn chỉ đăng nội dung mình có quyền sử dụng; không vi phạm bản quyền, nhãn hiệu của người khác.</li>
        <li>Tin (Story) tự ẩn sau 24 giờ. Nếu bật <i>Lưu trữ tin</i>, tin hết hạn được giữ trong kho lưu trữ chỉ mình bạn xem; tắt tùy chọn này thì tin bị xóa vĩnh viễn sau khi hết hạn.</li>
        <li>Bài viết bị quản trị viên ẩn do vi phạm được giữ lại làm bằng chứng xử lý báo cáo và không thể tự xóa.</li>
        <li>Giới hạn tải lên: ảnh ≤ 10 MB, video ≤ 100 MB (tin ≤ 50 MB, ≤ 60 giây), mô hình 3D (.glb) ≤ 20 MB.</li>
      </ul>

      <h2>4. Tính năng trí tuệ nhân tạo (AI)</h2>
      <ul>
        <li><b>Trợ lý soạn bài</b> (viết chú thích, tóm tắt, dịch thuật, tạo ảnh nghệ thuật) chỉ chạy khi bạn chủ động bấm. Văn bản và ảnh bạn chọn có thể được gửi tới nhà cung cấp mô hình AI (Google Gemini hoặc Anthropic Claude, tùy cấu hình máy chủ) để xử lý; kết quả chỉ là gợi ý — bạn tự chịu trách nhiệm với nội dung cuối cùng mình đăng.</li>
        <li><b>Phân tích cảm xúc bài viết</b>: hệ thống tự gắn nhãn Tích cực / Trung tính / Tiêu cực cho bài viết để bạn có thể ẩn bớt nội dung tiêu cực khỏi bảng tin và để hỗ trợ kiểm duyệt. Nhãn được tạo tự động và có thể sai; nó <b>không</b> tự động khóa tài khoản hay xóa bài.</li>
        <li><b>Bảng tin cá nhân hóa</b> sắp xếp bài theo mức độ liên quan (tương tác với tác giả, chủ đề bạn quan tâm, độ mới, xu hướng). Bạn có thể chuyển về chế độ <i>Mới nhất</i> bất cứ lúc nào.</li>
        <li><b>Phụ đề tự động</b> cho video được nhận dạng giọng nói ngay trên trình duyệt của bạn; mô hình nhận dạng được tải về máy, âm thanh không gửi đi đâu.</li>
        <li>Ảnh nghệ thuật "tạo từ văn bản" là tranh trừu tượng do thuật toán vẽ trên máy bạn, không phải ảnh chụp thật.</li>
      </ul>

      <h2>5. Bảo mật, sinh trắc học và danh tính số</h2>
      <ul>
        <li><b>Xác thực sinh trắc học</b> dùng chuẩn WebAuthn (passkey): vân tay / khuôn mặt được thiết bị của bạn kiểm tra; UTErSpace <b>chỉ nhận khóa công khai</b>, không bao giờ nhận ảnh khuôn mặt hay dấu vân tay.</li>
        <li>Khi đã đăng ký sinh trắc học, các hành động nhạy cảm (đổi mật khẩu, mở Album ẩn) yêu cầu xác thực lại.</li>
        <li><b>Danh tính số (DID)</b> dạng <code>did:key</code>: cặp khóa được tạo trên trình duyệt của bạn; máy chủ chỉ lưu khóa công khai. Mất khóa riêng (xóa dữ liệu trình duyệt mà không sao lưu) thì không đăng nhập bằng DID được nữa — bạn vẫn đăng nhập bằng mật khẩu bình thường.</li>
        <li>Bạn có thể xuất toàn bộ dữ liệu cá nhân dưới dạng <i>Verifiable Credential</i> có chữ ký số để mang sang nền tảng khác.</li>
      </ul>

      <h2>6. Bộ lọc nội dung và sức khỏe tinh thần</h2>
      <p>Bạn có thể tự đặt danh sách từ khóa, cụm từ, biểu tượng cảm xúc không muốn thấy. Bài viết và bình luận chứa các từ này sẽ được thu gọn trên màn hình của bạn. Bộ lọc chỉ tác động tới những gì <b>bạn</b> nhìn thấy, không ảnh hưởng người khác.</p>

      <h2>7. Nhắn tin</h2>
      <ul>
        <li>Tin nhắn chỉ thành viên cuộc trò chuyện xem được. Bạn có thể thu hồi, xóa phía mình, chặn người khác hoặc giới hạn "Chỉ bạn bè được nhắn tin".</li>
        <li>Trả lời tin (Story) được gửi thành tin nhắn riêng tới chủ tin.</li>
        <li>Không gửi tệp chứa mã độc. Tệp đính kèm tối đa 20 MB.</li>
      </ul>

      <h2>8. Giới hạn trách nhiệm</h2>
      <p>UTErSpace là sản phẩm học tập, được cung cấp "nguyên trạng". Chúng tôi cố gắng duy trì dịch vụ ổn định nhưng không cam kết hoạt động liên tục, không mất dữ liệu.
         Chúng tôi không chịu trách nhiệm với nội dung do người dùng đăng tải, nhưng sẽ xử lý khi nhận được báo cáo hợp lệ.</p>

      <h2>9. Chấm dứt sử dụng</h2>
      <p>Bạn có thể ngừng sử dụng bất kỳ lúc nào. Chúng tôi có thể tạm khóa hoặc chấm dứt tài khoản vi phạm nghiêm trọng hoặc tái phạm các điều khoản này.</p>

      <h2>10. Thay đổi điều khoản</h2>
      <p>Điều khoản có thể được cập nhật khi có tính năng mới. Ngày cập nhật luôn ghi ở đầu trang; tiếp tục sử dụng sau ngày đó nghĩa là bạn đồng ý với phiên bản mới.</p>

<%@ include file="legal-foot.jsp" %>
