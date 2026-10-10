<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  settings.jsp — Cài đặt (SettingsController): Tài khoản · Quyền riêng tư · Thông báo · Bảng tin & bộ lọc ·
  Kho lưu trữ tin · Bảo mật nâng cao (sinh trắc học, Album ẩn) · Danh tính số (DID) · Đã chặn.
  Mọi form gửi bằng fetch (CSRF tự gắn ở header.jsp), lưu xong báo toast, không tải lại trang.
--%>
<c:set var="pageTitle"       value="Cài đặt" />
<c:set var="pageDescription" value="Bảo mật tài khoản, quyền riêng tư, tùy chọn thông báo và danh sách chặn." />
<c:set var="extraCss"        value="settings.css" />
<c:set var="currentPage"     value="settings" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="s"   value="${settings}" />

<div class="app-shell">
  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">
    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section">
      <header class="page-head">
        <hgroup>
          <h1><svg class="icon" aria-hidden="true"><use href="#i-cog"></use></svg> Cài đặt</h1>
          <p>Quản lý bảo mật, quyền riêng tư và cách UTErSpace thông báo cho bạn</p>
        </hgroup>
      </header>

      <div class="settings-layout">
        <nav class="settings-nav" aria-label="Mục cài đặt">
          <a href="?tab=account"       class="settings-link" data-tab="account"       ${activeTab == 'account' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg> Tài khoản & bảo mật</a>
          <a href="?tab=privacy"       class="settings-link" data-tab="privacy"       ${activeTab == 'privacy' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-shield"></use></svg> Quyền riêng tư</a>
          <a href="?tab=notifications" class="settings-link" data-tab="notifications" ${activeTab == 'notifications' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-bell"></use></svg> Thông báo</a>
          <a href="?tab=content"       class="settings-link" data-tab="content"       ${activeTab == 'content' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg> Bảng tin &amp; bộ lọc</a>
          <a href="?tab=archive"       class="settings-link" data-tab="archive"       ${activeTab == 'archive' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg> Kho lưu trữ tin</a>
          <a href="?tab=security"      class="settings-link" data-tab="security"      ${activeTab == 'security' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-shield"></use></svg> Bảo mật nâng cao
            <c:if test="${not empty passkeys}"><span class="pill-count pill-count--ok">${fn:length(passkeys)}</span></c:if></a>
          <a href="?tab=identity"      class="settings-link" data-tab="identity"      ${activeTab == 'identity' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-user-circle"></use></svg> Danh tính số (DID)</a>
          <a href="?tab=blocked"       class="settings-link" data-tab="blocked"       ${activeTab == 'blocked' ? 'aria-current="page"' : ''}>
            <svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg> Đã chặn
            <c:if test="${not empty blockedList}"><span class="pill-count">${fn:length(blockedList)}</span></c:if></a>
        </nav>

        <div class="settings-panels">
          <%-- ===================== TÀI KHOẢN ===================== --%>
          <section class="settings-card" id="panel-account" ${activeTab == 'account' ? '' : 'hidden'}>
            <h2>Tài khoản & bảo mật</h2>
            <dl class="settings-info">
              <div><dt>Họ tên</dt><dd><c:out value="${sessionScope.currentUser.fullName}"/></dd></div>
              <div><dt>Email đăng nhập</dt><dd><c:out value="${sessionScope.currentUser.email}"/></dd></div>
            </dl>
            <form class="settings-form" id="password-form" onsubmit="return saveSettings(event, 'password')">
              <h3>Đổi mật khẩu</h3>
              <label class="field-row"><span>Mật khẩu hiện tại</span>
                <input type="password" name="currentPassword" autocomplete="current-password" required></label>
              <label class="field-row"><span>Mật khẩu mới</span>
                <input type="password" name="newPassword" autocomplete="new-password" minlength="8" required>
                <small>Tối thiểu 8 ký tự, có ít nhất 1 chữ hoa và 1 ký tự đặc biệt.</small></label>
              <label class="field-row"><span>Nhập lại mật khẩu mới</span>
                <input type="password" name="confirmPassword" autocomplete="new-password" minlength="8" required></label>
              <p class="settings-actions"><button type="submit" class="btn-pill">Đổi mật khẩu</button></p>
            </form>
            <p class="settings-hint">
              <svg class="icon" aria-hidden="true"><use href="#i-shield"></use></svg>
              Khi có đăng nhập từ trình duyệt / thiết bị mới hoặc khi mật khẩu được đổi, bạn sẽ nhận một thông báo trong mục <a href="${ctx}/notifications?tab=account">Thông báo → Tài khoản</a>
              để kịp phát hiện truy cập lạ.
            </p>
            <p class="settings-hint">
              <svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>
              Quên mật khẩu hiện tại? Hãy <a href="${ctx}/logout">đăng xuất</a> rồi chọn <b>Quên mật khẩu?</b> ở trang đăng nhập để nhận mã xác nhận qua email.
              Đổi mật khẩu sẽ đăng xuất tài khoản khỏi mọi thiết bị khác.
            </p>
          </section>

          <%-- ===================== QUYỀN RIÊNG TƯ ===================== --%>
          <section class="settings-card" id="panel-privacy" ${activeTab == 'privacy' ? '' : 'hidden'}>
            <h2>Quyền riêng tư</h2>
            <form class="settings-form" onsubmit="return saveSettings(event, 'privacy')">
              <fieldset class="choice-group">
                <legend>Ai có thể gửi lời mời kết bạn cho bạn?</legend>
                <label class="choice"><input type="radio" name="friendRequestPolicy" value="EVERYONE" ${s.friendRequestPolicy == 'EVERYONE' ? 'checked' : ''}>
                  <span><b>Mọi người</b><small>Bất kỳ ai trên UTErSpace</small></span></label>
                <label class="choice"><input type="radio" name="friendRequestPolicy" value="FRIENDS_OF_FRIENDS" ${s.friendRequestPolicy == 'FRIENDS_OF_FRIENDS' ? 'checked' : ''}>
                  <span><b>Bạn của bạn bè</b><small>Chỉ người có ít nhất một bạn chung</small></span></label>
                <label class="choice"><input type="radio" name="friendRequestPolicy" value="NOBODY" ${s.friendRequestPolicy == 'NOBODY' ? 'checked' : ''}>
                  <span><b>Không ai</b><small>Bạn vẫn gửi lời mời cho người khác được</small></span></label>
              </fieldset>
              <fieldset class="choice-group">
                <legend>Ai có thể nhắn tin cho bạn?</legend>
                <label class="choice"><input type="radio" name="messagePolicy" value="EVERYONE" ${s.messagePolicy == 'EVERYONE' ? 'checked' : ''}>
                  <span><b>Mọi người</b><small>Trừ người bạn đã chặn</small></span></label>
                <label class="choice"><input type="radio" name="messagePolicy" value="FRIENDS" ${s.messagePolicy == 'FRIENDS' ? 'checked' : ''}>
                  <span><b>Chỉ bạn bè</b><small>Người khác không mở được cuộc trò chuyện mới với bạn</small></span></label>
              </fieldset>
              <label class="switch-row">
                <span><b>Hiển thị trạng thái hoạt động</b><small>Bạn bè thấy chấm xanh "Đang hoạt động" và "Hoạt động x phút trước" của bạn</small></span>
                <input type="checkbox" class="switch" name="showOnline" value="true" ${s.showOnline ? 'checked' : ''}>
              </label>
              <p class="settings-actions"><button type="submit" class="btn-pill">Lưu quyền riêng tư</button></p>
            </form>
          </section>

          <%-- ===================== THÔNG BÁO ===================== --%>
          <section class="settings-card" id="panel-notifications" ${activeTab == 'notifications' ? '' : 'hidden'}>
            <h2>Thông báo</h2>
            <div class="push-status" id="push-status">
              <span class="push-status-text" id="push-status-text">Đang kiểm tra quyền thông báo của trình duyệt…</span>
              <button type="button" class="btn-pill" id="push-enable" hidden onclick="enablePush()">Cho phép thông báo trên màn hình</button>
              <button type="button" class="btn-pill btn-pill--ghost" id="push-test" hidden onclick="testPush()">Gửi thử</button>
            </div>
            <form class="settings-form" onsubmit="return saveSettings(event, 'notifications')">
              <table class="notif-pref-table">
                <thead><tr><th scope="col">Nhóm thông báo</th><th scope="col">Trong ứng dụng</th><th scope="col">Trên màn hình</th></tr></thead>
                <tbody>
                  <tr id="cat-friend"><th scope="row"><b>👥 Bạn bè</b><small>Lời mời kết bạn, chấp nhận kết bạn</small></th>
                    <td><input type="checkbox" class="switch" name="notifFriend" value="true" ${s.notifFriend ? 'checked' : ''} aria-label="Bạn bè trong ứng dụng"></td>
                    <td><input type="checkbox" class="switch" name="pushFriend" value="true" ${s.pushFriend ? 'checked' : ''} aria-label="Bạn bè trên màn hình"></td></tr>
                  <tr id="cat-interaction"><th scope="row"><b>❤️ Tương tác</b><small>Thích, bình luận, chia sẻ bài viết của bạn</small></th>
                    <td><input type="checkbox" class="switch" name="notifInteraction" value="true" ${s.notifInteraction ? 'checked' : ''} aria-label="Tương tác trong ứng dụng"></td>
                    <td><input type="checkbox" class="switch" name="pushInteraction" value="true" ${s.pushInteraction ? 'checked' : ''} aria-label="Tương tác trên màn hình"></td></tr>
                  <tr id="cat-group"><th scope="row"><b>🏷️ Nhóm</b><small>Bài mới trong nhóm, yêu cầu tham gia, được duyệt</small></th>
                    <td><input type="checkbox" class="switch" name="notifGroup" value="true" ${s.notifGroup ? 'checked' : ''} aria-label="Nhóm trong ứng dụng"></td>
                    <td><input type="checkbox" class="switch" name="pushGroup" value="true" ${s.pushGroup ? 'checked' : ''} aria-label="Nhóm trên màn hình"></td></tr>
                  <tr id="cat-message"><th scope="row"><b>💌 Tin nhắn</b><small>Tin nhắn mới, được thêm vào nhóm chat</small></th>
                    <td><input type="checkbox" class="switch" name="notifMessage" value="true" ${s.notifMessage ? 'checked' : ''} aria-label="Tin nhắn trong ứng dụng"></td>
                    <td><input type="checkbox" class="switch" name="pushMessage" value="true" ${s.pushMessage ? 'checked' : ''} aria-label="Tin nhắn trên màn hình"></td></tr>
                  <tr id="cat-account"><th scope="row"><b>🔐 Tài khoản</b><small>Đăng nhập mới, đổi mật khẩu — luôn bật vì lý do bảo mật</small></th>
                    <td><input type="checkbox" class="switch" checked disabled aria-label="Tài khoản trong ứng dụng (luôn bật)"></td>
                    <td><input type="checkbox" class="switch" name="pushAccount" value="true" ${s.pushAccount ? 'checked' : ''} aria-label="Tài khoản trên màn hình"></td></tr>
                </tbody>
              </table>
              <p class="settings-note">"Trong ứng dụng": tạo thông báo ở trang Thông báo + huy hiệu + thông báo nổi góc màn hình.
                "Trên màn hình": thông báo của hệ điều hành khi bạn đang ở tab / ứng dụng khác.</p>
              <p class="settings-actions"><button type="submit" class="btn-pill">Lưu tùy chọn thông báo</button></p>
            </form>
          </section>

          <%-- ===================== BẢNG TIN & BỘ LỌC NỘI DUNG ===================== --%>
          <section class="settings-card" id="panel-content" ${activeTab == 'content' ? '' : 'hidden'}>
            <h2>Bảng tin &amp; bộ lọc nội dung</h2>
            <form class="settings-form" onsubmit="return saveSettings(event, 'content')">
              <fieldset class="choice-group">
                <legend>Sắp xếp bảng tin</legend>
                <label class="choice"><input type="radio" name="feedMode" value="SMART" ${s.feedMode != 'LATEST' ? 'checked' : ''}>
                  <span><b>✨ Dành cho bạn (cá nhân hóa)</b><small>Ưu tiên bài của người bạn hay tương tác, chủ đề bạn quan tâm, bài đang được chú ý — bài mới vẫn được cộng điểm</small></span></label>
                <label class="choice"><input type="radio" name="feedMode" value="LATEST" ${s.feedMode == 'LATEST' ? 'checked' : ''}>
                  <span><b>🕒 Mới nhất</b><small>Chỉ theo thời gian đăng, mới nhất ở trên</small></span></label>
              </fieldset>
              <label class="switch-row">
                <span><b>Ẩn bớt bài viết tiêu cực</b><small>Bài được AI gắn nhãn "Tiêu cực" sẽ thu gọn trên bảng tin của bạn (bấm để xem nếu muốn)</small></span>
                <input type="checkbox" class="switch" name="hideNegative" value="true" ${s.hideNegative ? 'checked' : ''}>
              </label>
              <label class="field-row filter-field">
                <span><b>Từ khóa, cụm từ, emoji không muốn thấy</b></span>
                <textarea name="contentFilter" id="content-filter" rows="6" maxlength="5200"
                          placeholder="Mỗi dòng một mục, ví dụ:&#10;thi rớt&#10;drama&#10;🤬"><c:out value="${s.contentFilter}"/></textarea>
                <small>Bài viết và bình luận chứa các mục này sẽ được thu gọn trên màn hình của <b>bạn</b> (không ảnh hưởng người khác).
                  Không phân biệt hoa thường, không phân biệt dấu. Tối đa 100 mục.</small>
              </label>
              <div class="filter-chips" id="filter-chips" aria-live="polite"></div>
              <p class="settings-actions"><button type="submit" class="btn-pill">Lưu cài đặt bảng tin</button></p>
            </form>
          </section>

          <%-- ===================== KHO LƯU TRỮ TIN ===================== --%>
          <section class="settings-card" id="panel-archive" ${activeTab == 'archive' ? '' : 'hidden'}>
            <h2>Kho lưu trữ tin</h2>
            <form class="settings-form" onsubmit="return saveSettings(event, 'archive')">
              <label class="switch-row">
                <span><b>Lưu tin vào kho lưu trữ</b><small>Tin hết hạn sau 24 giờ vẫn được giữ lại ở đây, chỉ mình bạn xem được.
                  Tắt đi thì tin hết hạn — kể cả các tin đang lưu trữ — sẽ bị xóa vĩnh viễn.</small></span>
                <input type="checkbox" class="switch" name="archiveStories" value="true" ${s.archiveStories ? 'checked' : ''} onchange="this.form.requestSubmit()">
              </label>
            </form>
            <p class="settings-note" id="archive-count">Đang tải kho lưu trữ…</p>
            <ul class="archive-grid" id="archive-grid"></ul>
            <p class="settings-actions"><button type="button" class="btn-pill btn-pill--ghost" id="archive-more" hidden onclick="loadArchive()">Xem thêm</button></p>
          </section>

          <%-- ===================== BẢO MẬT NÂNG CAO ===================== --%>
          <section class="settings-card" id="panel-security" ${activeTab == 'security' ? '' : 'hidden'}>
            <h2>Bảo mật nâng cao</h2>
            <h3 class="sec-subtitle">🖐️ Xác thực sinh trắc học (passkey)</h3>
            <p class="settings-note">Dùng <b>vân tay, khuôn mặt</b> (Windows Hello, Touch ID, Face ID, cảm biến Android) hoặc mã PIN của thiết bị
              để phê duyệt hành động nhạy cảm: <b>đổi mật khẩu</b>, <b>mở Album ẩn</b>, gỡ passkey. Chuẩn WebAuthn —
              thiết bị chỉ gửi chữ ký số, UTErSpace <b>không bao giờ</b> nhận ảnh khuôn mặt hay dấu vân tay.</p>
            <p class="sec-support" id="passkey-support"></p>
            <ul class="passkey-list" id="passkey-list">
              <c:forEach var="k" items="${passkeys}">
                <li class="passkey-row" data-id="${k.id}">
                  <span class="passkey-icon" aria-hidden="true">🔑</span>
                  <span class="passkey-text"><b><c:out value="${k.label}"/></b>
                    <small>Thêm lúc ${k.formattedCreatedAt} · Dùng gần nhất: ${k.formattedLastUsedAt}</small></span>
                  <button type="button" class="btn-pill btn-pill--ghost btn-pill--sm" onclick="removePasskey(${k.id}, this)">Gỡ</button>
                </li>
              </c:forEach>
            </ul>
            <p class="settings-actions">
              <button type="button" class="btn-pill" id="passkey-add" onclick="addPasskey()">＋ Thêm vân tay / khuôn mặt của thiết bị này</button>
              <button type="button" class="btn-pill btn-pill--ghost" id="passkey-test" ${empty passkeys ? 'hidden' : ''} onclick="testPasskey()">Thử xác thực</button>
            </p>

            <h3 class="sec-subtitle">🔒 Album ẩn</h3>
            <p class="settings-note">Ảnh và video trong các bài <b>"Chỉ mình tôi"</b> của bạn. Cần xác thực lại (sinh trắc học, hoặc mật khẩu nếu chưa bật) mỗi lần mở; tự khóa lại sau 5 phút.</p>
            <p class="settings-actions"><button type="button" class="btn-pill" id="album-open" onclick="openHiddenAlbum()">🔓 Mở Album ẩn</button>
              <span class="album-timer" id="album-timer" hidden></span></p>
            <ul class="archive-grid" id="album-grid" hidden></ul>
          </section>

          <%-- ===================== DANH TÍNH SỐ (DID) ===================== --%>
          <section class="settings-card" id="panel-identity" ${activeTab == 'identity' ? '' : 'hidden'}>
            <h2>Danh tính số phi tập trung (DID)</h2>
            <p class="settings-note">Một <b>danh tính số do chính bạn nắm giữ</b> theo chuẩn W3C DID (<code>did:key</code>, khóa Ed25519).
              Khóa riêng được tạo và cất <b>ngay trên trình duyệt này</b> — UTErSpace chỉ lưu khóa công khai, nên không có gì để rò rỉ.</p>

            <%-- Trạng thái tổng hợp: JS điền theo (DID trên máy chủ) × (khóa trên trình duyệt) --%>
            <div class="did-status" id="did-status" data-state="loading" role="status" aria-live="polite">
              <span class="did-status-icon" aria-hidden="true"><svg class="icon"><use href="#i-id-card"></use></svg></span>
              <span class="did-status-text"><b id="did-status-title">Đang kiểm tra khóa trên trình duyệt…</b>
                <small id="did-status-desc"></small></span>
            </div>

            <dl class="did-facts" id="did-facts" data-did="<c:out value='${myDid.did}'/>">
              <div>
                <dt>DID đã liên kết</dt>
                <dd>
                  <c:choose>
                    <c:when test="${empty myDid}"><span class="did-empty">Chưa liên kết</span></c:when>
                    <c:otherwise>
                      <code class="did-code" title="<c:out value='${myDid.did}'/>"><c:out value="${myDid.did}"/></code>
                      <button type="button" class="did-icon-btn" onclick="didCopy(this)" data-copy="<c:out value='${myDid.did}'/>" aria-label="Sao chép DID">
                        <svg class="icon" aria-hidden="true"><use href="#i-copy"></use></svg></button>
                    </c:otherwise>
                  </c:choose>
                </dd>
              </div>
              <c:if test="${not empty myDid}">
                <div><dt>Liên kết lúc</dt><dd>${myDid.formattedCreatedAt}</dd></div>
              </c:if>
              <div><dt>Khóa trên trình duyệt này</dt><dd><code class="did-code" id="did-local">Đang kiểm tra…</code></dd></div>
            </dl>

            <c:if test="${not empty myDid}">
              <p class="did-links">
                <a href="${ctx}/did/resolve?did=${fn:escapeXml(myDid.did)}" target="_blank" rel="noopener">
                  <svg class="icon" aria-hidden="true"><use href="#i-document"></use></svg> Xem DID Document</a>
                <a href="${ctx}/profile?userId=${sessionScope.currentUser.userId}">
                  <svg class="icon" aria-hidden="true"><use href="#i-check-badge"></use></svg> Huy hiệu trên trang cá nhân</a>
              </p>
            </c:if>

            <div class="did-group">
              <h3>Khóa của bạn</h3>
              <p class="did-actions">
                <button type="button" class="btn-pill" id="did-create" hidden onclick="didCreateAndLink()">
                  <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Tạo danh tính số &amp; liên kết</button>
                <button type="button" class="btn-pill" id="did-link" hidden onclick="didLink()">
                  <svg class="icon" aria-hidden="true"><use href="#i-link"></use></svg> <span>Liên kết khóa này với tài khoản</span></button>
                <button type="button" class="btn-pill btn-pill--ghost" id="did-backup" hidden onclick="didBackup()">
                  <svg class="icon" aria-hidden="true"><use href="#i-download"></use></svg> Sao lưu khóa</button>
                <label class="btn-pill btn-pill--ghost did-file" id="did-restore">
                  <svg class="icon" aria-hidden="true"><use href="#i-upload"></use></svg> Khôi phục từ tệp sao lưu
                  <input type="file" accept=".json,application/json" onchange="didRestore(this)" hidden></label>
              </p>
              <p class="did-actions did-actions--quiet">
                <button type="button" class="btn-pill btn-pill--ghost btn-pill--sm" id="did-forget" hidden onclick="didForget()">Xóa khóa khỏi trình duyệt này</button>
                <button type="button" class="btn-pill btn-pill--ghost btn-pill--sm btn-pill--danger" id="did-unlink" ${empty myDid ? 'hidden' : ''} onclick="didUnlink()">Hủy liên kết với tài khoản</button>
              </p>
              <p class="settings-note did-stepup-note">Liên kết, thay khóa hoặc hủy liên kết cần <b>xác thực lại</b> (vân tay / khuôn mặt nếu đã bật sinh trắc học, nếu chưa thì nhập mật khẩu).</p>
            </div>

            <div class="did-group">
              <h3>Chứng nhận hồ sơ (Verifiable Credential)</h3>
              <p class="settings-note">Xuất hồ sơ và bài viết thành tệp <code>.vc.json</code> có chữ ký số của DID (chuẩn W3C VC 2.0, <code>eddsa-jcs-2022</code>)
                để mang sang nền tảng khác. Ai cũng kiểm tra được tệp là của bạn và chưa bị sửa — không cần hỏi UTErSpace.</p>
              <p class="did-actions">
                <button type="button" class="btn-pill" id="vc-export" onclick="vcExport()">
                  <svg class="icon" aria-hidden="true"><use href="#i-check-badge"></use></svg> Xuất hồ sơ có chữ ký số</button>
                <label class="btn-pill btn-pill--ghost did-file">
                  <svg class="icon" aria-hidden="true"><use href="#i-shield"></use></svg> Kiểm tra tệp VC
                  <input type="file" accept=".json,application/json" onchange="vcImport(this)" hidden></label>
                <a class="btn-pill btn-pill--ghost" href="${ctx}/did/verify" target="_blank" rel="noopener">
                  <svg class="icon" aria-hidden="true"><use href="#i-external"></use></svg> Trang kiểm tra công khai</a>
              </p>
              <div class="vc-result" id="vc-result" aria-live="polite" hidden></div>
            </div>

            <ol class="did-howto" aria-label="Cách dùng danh tính số">
              <li><b>Tạo khóa</b><span>Khóa Ed25519 sinh ngay trên trình duyệt, không gửi lên máy chủ.</span></li>
              <li><b>Sao lưu</b><span>Tải tệp <code>uterspace-did-key.json</code> và cất ở nơi an toàn.</span></li>
              <li><b>Đăng nhập không mật khẩu</b><span>Ở trang đăng nhập chọn "Đăng nhập bằng danh tính số" — trên máy khác thì chọn tệp sao lưu.</span></li>
            </ol>
          </section>

          <%-- ===================== ĐÃ CHẶN ===================== --%>
          <section class="settings-card" id="panel-blocked" ${activeTab == 'blocked' ? '' : 'hidden'}>
            <h2>Người đã chặn</h2>
            <p class="settings-note">Hai bên không thấy bài viết, trang cá nhân, không tìm thấy nhau và không nhắn tin 1-1 được.</p>
            <c:choose>
              <c:when test="${empty blockedList}">
                <p class="state-empty"><svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>
                  <strong>Bạn chưa chặn ai</strong>Chặn từ trang cá nhân (nút …) hoặc menu "Bạn bè ▾".</p>
              </c:when>
              <c:otherwise>
                <ul class="blocked-list">
                  <c:forEach var="b" items="${blockedList}">
                    <li class="blocked-row" data-person="${b.blockedId}">
                      <span class="blocked-avatar">
                        <c:choose>
                          <c:when test="${not empty b.blocked.avatar}"><img src="${ctx}${b.blocked.avatarUrl}" alt="" width="42" height="42"></c:when>
                          <c:otherwise><c:out value="${b.blocked.initials}"/></c:otherwise>
                        </c:choose>
                      </span>
                      <span class="blocked-name"><b><c:out value="${b.blocked.fullName}"/></b><small>Đã chặn ngày ${b.formattedCreatedAt}</small></span>
                      <span class="rel-actions" data-relation-user="${b.blockedId}" data-status="BLOCKED"
                            data-name="<c:out value='${b.blocked.firstName}'/>" data-variant="profile"></span>
                    </li>
                  </c:forEach>
                </ul>
              </c:otherwise>
            </c:choose>
          </section>
        </div>
      </div>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>

<script>
var SET_CTX = '${ctx}';

/* Chuyển mục không tải lại trang */
document.querySelectorAll('.settings-link').forEach(function (a) {
  a.addEventListener('click', function (e) {
    e.preventDefault();
    var tab = a.getAttribute('data-tab');
    document.querySelectorAll('.settings-link').forEach(function (x) {
      if (x === a) x.setAttribute('aria-current', 'page'); else x.removeAttribute('aria-current');
    });
    ['account', 'privacy', 'notifications', 'content', 'archive', 'security', 'identity', 'blocked'].forEach(function (t) {
      document.getElementById('panel-' + t).hidden = t !== tab;
    });
    history.replaceState(null, '', SET_CTX + '/settings?tab=' + tab);
  });
});

/* Gửi form: checkbox chưa tick cũng gửi "false" để server ghi đúng */
function saveSettings(e, kind) {
  e.preventDefault();
  var form = e.target, btn = form.querySelector('button[type=submit]');
  var data = new URLSearchParams();
  form.querySelectorAll('input[name], textarea[name]').forEach(function (i) {
    if (i.type === 'radio') { if (i.checked) data.append(i.name, i.value); }
    else if (i.type === 'checkbox') data.append(i.name, i.checked ? 'true' : 'false');
    else data.append(i.name, i.value);
  });
  btn.disabled = true;
  fetch(SET_CTX + '/settings/' + kind, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
    body: data.toString()
  })
    .then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
    .then(function (r) {
      // Đã bật sinh trắc học → máy chủ yêu cầu quét vân tay / khuôn mặt trước khi đổi mật khẩu, xong tự gửi lại
      if (!r.ok && r.d.needStepUp && !form._retried) {
        form._retried = true;
        showToast('Xác thực vân tay / khuôn mặt để tiếp tục…');
        return UTPasskey.stepUp(r.d.method).then(function () { btn.disabled = false; form.requestSubmit(); })
          .catch(function (err) { showToast(err.message, 'error'); })
          .then(function () { setTimeout(function () { form._retried = false; }, 1000); });
      }
      showToast(r.ok ? r.d.message : r.d.error, r.ok ? 'success' : 'error');
      if (r.ok && kind === 'password') form.reset();
      if (r.ok && kind === 'archive') loadArchive(true);
    })
    .catch(function () { showToast('Mất kết nối, thử lại nhé.', 'error'); })
    .finally(function () { btn.disabled = false; });
  return false;
}

/* Quyền thông báo màn hình của trình duyệt (Notification API) */
function renderPush() {
  var text = document.getElementById('push-status-text'), en = document.getElementById('push-enable'), test = document.getElementById('push-test');
  var box = document.getElementById('push-status');
  if (!('Notification' in window)) { text.textContent = 'Trình duyệt này không hỗ trợ thông báo trên màn hình.'; return; }
  var p = Notification.permission;
  box.setAttribute('data-permission', p);
  en.hidden = p !== 'default';
  test.hidden = p !== 'granted';
  text.textContent = p === 'granted' ? '✅ Đã cho phép thông báo trên màn hình.'
                   : p === 'denied'  ? '⛔ Bạn đã chặn thông báo của trang này — mở lại trong cài đặt trang web của trình duyệt (biểu tượng ổ khóa trên thanh địa chỉ).'
                   : 'Cho phép trình duyệt hiện thông báo khi bạn đang ở tab khác.';
}
function enablePush() { Notification.requestPermission().then(renderPush); }
function testPush() {
  try { new Notification('UTErSpace', { body: 'Thông báo trên màn hình đã hoạt động 🎉' }); }
  catch (e) { showToast('Trình duyệt chặn thông báo thử.', 'error'); }
}
renderPush();

/* Bỏ chặn xong → bỏ dòng khỏi danh sách */
document.addEventListener('relation:changed', function (e) {
  if (e.detail.status && e.detail.status !== 'BLOCKED') {
    var row = document.querySelector('.blocked-row[data-person="' + e.detail.userId + '"]');
    if (row) row.remove();
  }
});
</script>

<script src="${ctx}/assets/js/security.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
<script>
/* ===================== Bộ lọc nội dung: xem trước dạng chip ===================== */
(function () {
  var ta = document.getElementById('content-filter'), box = document.getElementById('filter-chips');
  function render() {
    box.textContent = '';
    var seen = {};
    ta.value.split(/[\r\n,]+/).map(function (t) { return t.trim(); }).filter(function (t) {
      if (!t || seen[t.toLowerCase()]) return false; seen[t.toLowerCase()] = 1; return true;
    }).slice(0, 100).forEach(function (t) {
      var c = document.createElement('span'); c.className = 'filter-chip'; c.textContent = t; box.appendChild(c);
    });
  }
  ta.addEventListener('input', render);
  render();
})();

/* ===================== Kho lưu trữ tin ===================== */
var archivePage = 0, archiveLoading = false;
function loadArchive(reset) {
  if (archiveLoading) return;
  if (reset) { archivePage = 0; document.getElementById('archive-grid').textContent = ''; }
  archiveLoading = true;
  fetch(SET_CTX + '/stories/archive?page=' + (archivePage + 1), { headers: { Accept: 'application/json' } })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      archivePage = d.page;
      document.getElementById('archive-count').textContent = d.total
        ? d.total + ' tin trong kho lưu trữ. Bấm vào một tin để xem lại.'
        : 'Chưa có tin nào hết hạn trong kho lưu trữ.';
      var grid = document.getElementById('archive-grid');
      d.stories.forEach(function (st) { grid.appendChild(mediaTile(st, true)); });
      document.getElementById('archive-more').hidden = !d.hasMore;
    })
    .catch(function () { document.getElementById('archive-count').textContent = 'Không tải được kho lưu trữ.'; })
    .then(function () { archiveLoading = false; });
}

/** Ô ảnh / video trong lưới (kho lưu trữ tin hoặc Album ẩn) */
function mediaTile(it, isStory) {
  var li = document.createElement('li');
  li.className = 'archive-item';
  var btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'archive-thumb';
  btn.setAttribute('aria-label', (isStory ? 'Xem tin ngày ' : 'Xem ') + (it.date || ''));
  var m;
  if (it.type === 'VIDEO') { m = document.createElement('video'); m.src = it.url + '#t=0.5'; m.muted = true; m.preload = 'metadata'; }
  else { m = document.createElement('img'); m.src = it.url; m.alt = ''; m.loading = 'lazy'; }
  btn.appendChild(m);
  if (it.type === 'VIDEO') { var v = document.createElement('span'); v.className = 'archive-badge'; v.textContent = '▶'; btn.appendChild(v); }
  btn.addEventListener('click', function () { openMediaViewer(it, isStory, li); });
  li.appendChild(btn);
  var meta = document.createElement('span');
  meta.className = 'archive-meta';
  meta.textContent = isStory ? (it.date + ' · 👁 ' + it.views + ' · ❤️ ' + it.reactions) : it.date;
  li.appendChild(meta);
  return li;
}

function openMediaViewer(it, isStory, tile) {
  var ov = document.createElement('div');
  ov.className = 'media-viewer';
  ov.setAttribute('role', 'dialog');
  ov.setAttribute('aria-modal', 'true');
  var stage = document.createElement('figure');
  var m;
  if (it.type === 'VIDEO') { m = document.createElement('video'); m.controls = true; m.autoplay = true; m.playsInline = true; }
  else { m = document.createElement('img'); m.alt = it.caption || ''; }
  m.src = it.url;
  stage.appendChild(m);
  if (it.caption) { var cap = document.createElement('figcaption'); cap.textContent = it.caption; stage.appendChild(cap); }
  var bar = document.createElement('p');
  bar.className = 'media-viewer-bar';
  var dl = document.createElement('a'); dl.className = 'btn-pill btn-pill--ghost'; dl.href = it.url; dl.download = ''; dl.textContent = '⬇ Tải về';
  bar.appendChild(dl);
  if (isStory) {
    var del = document.createElement('button'); del.type = 'button'; del.className = 'btn-pill btn-pill--accent'; del.textContent = 'Xóa vĩnh viễn';
    del.addEventListener('click', function () {
      UTConfirm({ title: 'Xóa tin khỏi kho lưu trữ?', message: 'Tin và file ảnh / video sẽ bị xóa vĩnh viễn.', ok: 'Xóa', danger: true }).then(function (yes) {
        if (!yes) return;
        UTPasskey.post('/stories/delete', { id: it.id }).then(function () {
          tile.remove(); ov.remove(); showToast('Đã xóa tin khỏi kho lưu trữ.', 'success');
        }).catch(function (e) { showToast(e.message, 'error'); });
      });
    });
    bar.appendChild(del);
  }
  var close = document.createElement('button'); close.type = 'button'; close.className = 'btn-pill'; close.textContent = 'Đóng';
  close.addEventListener('click', function () { ov.remove(); });
  bar.appendChild(close);
  stage.appendChild(bar);
  ov.appendChild(stage);
  ov.addEventListener('click', function (e) { if (e.target === ov) ov.remove(); });
  document.addEventListener('keydown', function esc(e) { if (e.key === 'Escape') { ov.remove(); document.removeEventListener('keydown', esc); } });
  document.body.appendChild(ov);
}

/* ===================== Sinh trắc học ===================== */
function renderPasskeySupport() {
  var el = document.getElementById('passkey-support');
  if (!UTPasskey.supported()) {
    el.textContent = '⚠️ Trình duyệt / kết nối này chưa hỗ trợ WebAuthn (cần https hoặc http://localhost).';
    document.getElementById('passkey-add').disabled = true;
    return;
  }
  UTPasskey.platformAvailable().then(function (ok) {
    el.textContent = ok ? '✅ Thiết bị có cảm biến sinh trắc học / Windows Hello sẵn sàng.'
                        : 'ℹ️ Không thấy cảm biến sinh trắc học tích hợp — vẫn có thể dùng PIN thiết bị hoặc khóa bảo mật USB.';
  });
}
function addPasskey() {
  var btn = document.getElementById('passkey-add');
  btn.disabled = true;
  UTPasskey.register().then(function (d) {
    showToast(d.message + ' 🎉', 'success');
    setTimeout(function () { location.href = SET_CTX + '/settings?tab=security'; }, 700);
  }).catch(function (e) { showToast(e.message, 'error'); }).then(function () { btn.disabled = false; });
}
function testPasskey() {
  UTPasskey.verify().then(function () { showToast('Xác thực sinh trắc học thành công ✅ (mở khóa 5 phút)', 'success'); })
    .catch(function (e) { showToast(e.message, 'error'); });
}
function removePasskey(id, btn) {
  UTConfirm({ title: 'Gỡ passkey này?', message: 'Thiết bị này sẽ không còn dùng để xác thực sinh trắc học được nữa.', ok: 'Gỡ', danger: true })
    .then(function (yes) {
      if (!yes) return;
      UTPasskey.guarded(function () { return UTPasskey.post('/security/passkey/delete', { id: id }); })
        .then(function (d) { btn.closest('li').remove(); showToast(d.message, 'success'); })
        .catch(function (e) { showToast(e.message, 'error'); });
    });
}

/* ===================== Album ẩn ===================== */
var albumTimer = null;
function openHiddenAlbum() {
  var get = function () {
    return fetch(SET_CTX + '/security/hidden-album', { headers: { Accept: 'application/json' } }).then(function (r) {
      return r.json().then(function (d) { if (!r.ok) { var e = new Error(d.error); e.data = d; throw e; } return d; });
    });
  };
  UTPasskey.guarded(get).then(function (d) {
    var grid = document.getElementById('album-grid');
    grid.textContent = '';
    grid.hidden = false;
    if (!d.items.length) {
      var li = document.createElement('li'); li.className = 'archive-empty';
      li.textContent = 'Chưa có ảnh / video nào trong các bài "Chỉ mình tôi".';
      grid.appendChild(li);
    }
    d.items.forEach(function (it) { grid.appendChild(mediaTile(it, false)); });
    document.getElementById('album-open').hidden = true;
    startAlbumTimer(d.secondsLeft);
  }).catch(function (e) { showToast(e.message, 'error'); });
}
function startAlbumTimer(sec) {
  var t = document.getElementById('album-timer');
  t.hidden = false;
  clearInterval(albumTimer);
  albumTimer = setInterval(function () {
    sec--;
    t.textContent = '🔓 Tự khóa sau ' + Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
    if (sec <= 0) {
      clearInterval(albumTimer);
      document.getElementById('album-grid').textContent = '';
      document.getElementById('album-grid').hidden = true;
      document.getElementById('album-open').hidden = false;
      t.hidden = true;
      showToast('Album ẩn đã tự khóa lại 🔒');
    }
  }, 1000);
}

/* ===================== Danh tính số (DID) ===================== */
var didRec = null;
var DID_SERVER = (document.getElementById('did-facts').getAttribute('data-did') || '').trim();
var DID_STATES = {
  ok:       ['i-check-badge', 'Danh tính số đang hoạt động', 'Khóa trên trình duyệt này khớp với DID của tài khoản — bạn có thể đăng nhập bằng DID và xuất hồ sơ có chữ ký.'],
  none:     ['i-id-card', 'Chưa có danh tính số', 'Tạo khóa mới ngay trên trình duyệt này, hoặc khôi phục từ tệp sao lưu nếu đã có.'],
  remote:   ['i-key', 'Đã liên kết — trình duyệt này chưa có khóa', 'Khôi phục tệp sao lưu khóa để đăng nhập bằng DID và ký hồ sơ trên trình duyệt này.'],
  local:    ['i-link', 'Có khóa nhưng chưa liên kết', 'Liên kết khóa này với tài khoản để dùng đăng nhập không mật khẩu.'],
  mismatch: ['i-warning', 'Khóa trên trình duyệt khác DID đã liên kết', 'Khôi phục đúng tệp khóa của tài khoản, hoặc thay DID của tài khoản bằng khóa đang có trên trình duyệt này.'],
  nosupport:['i-warning', 'Trình duyệt chưa hỗ trợ khóa Ed25519', 'Cần Chrome / Edge 137+, Firefox 129+ hoặc Safari 17+, mở trang qua https hoặc localhost.']
};
function didBackedUp(did) { try { return localStorage.getItem('ut-did-backup:' + did) === '1'; } catch (e) { return true; } }
function didMarkBackedUp(did) { try { localStorage.setItem('ut-did-backup:' + did, '1'); } catch (e) { /* bộ nhớ bị chặn */ } }

function renderDid(state) {
  if (!state) {
    state = !didRec ? (DID_SERVER ? 'remote' : 'none')
          : !DID_SERVER ? 'local'
          : didRec.did === DID_SERVER ? 'ok' : 'mismatch';
  }
  var info = DID_STATES[state];
  var box = document.getElementById('did-status');
  box.setAttribute('data-state', state);
  box.querySelector('use').setAttribute('href', '#' + info[0]);
  document.getElementById('did-status-title').textContent = info[1];
  var desc = info[2];
  if (didRec && (state === 'ok' || state === 'local') && !didBackedUp(didRec.did)) {
    desc += ' Bạn chưa sao lưu khóa này — nếu xóa dữ liệu trình duyệt sẽ mất khóa.';
    box.setAttribute('data-state', 'warn-backup');
  }
  document.getElementById('did-status-desc').textContent = desc;

  var local = document.getElementById('did-local');
  local.textContent = didRec ? UTDid.shortDid(didRec.did) : (state === 'nosupport' ? 'Không khả dụng' : 'Chưa có');
  local.title = didRec ? didRec.did : '';

  var show = function (id, on) { document.getElementById(id).hidden = !on; };
  show('did-create', state === 'none');
  show('did-link', state === 'local' || state === 'mismatch');
  document.querySelector('#did-link span').textContent = state === 'mismatch' ? 'Thay DID của tài khoản bằng khóa này' : 'Liên kết khóa này với tài khoản';
  show('did-backup', !!didRec);
  show('did-forget', !!didRec);
  show('did-restore', state !== 'nosupport' && state !== 'ok');
  document.getElementById('vc-export').disabled = state !== 'ok';
  document.getElementById('vc-export').title = state === 'ok' ? '' : 'Cần khóa khớp với DID đã liên kết';
}
function didFail(e) { if (e && e.message !== 'Đã hủy.') showToast(e.message || String(e), 'error'); }
function didCopy(btn) {
  var text = btn.getAttribute('data-copy');
  (navigator.clipboard ? navigator.clipboard.writeText(text) : Promise.reject())
    .then(function () { showToast('Đã sao chép DID.', 'success'); })
    .catch(function () { window.prompt('Sao chép DID:', text); });
}
function didCreateAndLink() {
  UTDid.create().then(function (rec) { didRec = rec; renderDid(); return UTDid.link(rec); })
    .then(function (d) {
      showToast(d.message + ' Hãy sao lưu khóa ngay để dùng trên thiết bị khác.', 'success');
      return UTDid.backup(didRec).then(function () { didMarkBackedUp(didRec.did); });
    })
    .then(function () { setTimeout(function () { location.reload(); }, 1500); })
    .catch(function (e) { didFail(e); renderDid(); });
}
function didLink() {
  var replacing = DID_SERVER && didRec.did !== DID_SERVER;
  (replacing ? UTConfirm({ title: 'Thay danh tính số?', message: 'DID cũ của tài khoản sẽ không đăng nhập được nữa và các hồ sơ đã ký bằng nó không còn gắn với tài khoản.', ok: 'Thay bằng khóa này', danger: true })
             : Promise.resolve(true))
    .then(function (yes) {
      if (!yes) return;
      return UTDid.link(didRec).then(function (d) { showToast(d.message, 'success'); setTimeout(function () { location.reload(); }, 800); });
    }).catch(didFail);
}
function didBackup() {
  UTConfirm({ title: 'Sao lưu khóa riêng?', message: 'Tệp tải về chứa KHÓA RIÊNG của danh tính số. Ai có tệp này đều đăng nhập được bằng DID của bạn — hãy cất giữ cẩn thận, không gửi cho người khác.', ok: 'Tải tệp khóa' })
    .then(function (yes) {
      if (yes) UTDid.backup(didRec).then(function () { didMarkBackedUp(didRec.did); renderDid(); }).catch(didFail);
    });
}
function didRestore(input) {
  var f = input.files[0]; input.value = '';
  if (!f) return;
  UTDid.restore(f).then(function (rec) {
    didRec = rec;
    didMarkBackedUp(rec.did);   // khôi phục từ tệp → tệp sao lưu đã tồn tại
    renderDid();
    showToast(rec.did === DID_SERVER ? 'Đã khôi phục đúng khóa của tài khoản.' : 'Đã khôi phục khóa ' + UTDid.shortDid(rec.did), 'success');
  }).catch(function (e) { didFail(e instanceof SyntaxError ? new Error('Tệp không đọc được (không phải JSON).') : e); });
}
function didForget() {
  var linked = didRec && didRec.did === DID_SERVER;
  UTConfirm({ title: 'Xóa khóa khỏi trình duyệt này?',
              message: (didBackedUp(didRec.did) ? '' : 'Bạn CHƯA sao lưu khóa này — xóa là mất vĩnh viễn. ') +
                       (linked ? 'Tài khoản vẫn giữ liên kết DID; bạn có thể khôi phục từ tệp sao lưu bất cứ lúc nào.' : 'Khóa này chưa liên kết với tài khoản.'),
              ok: 'Xóa khóa', danger: true })
    .then(function (yes) {
      if (!yes) return;
      return UTDid.clear().then(function () { didRec = null; renderDid(); showToast('Đã xóa khóa khỏi trình duyệt.', 'success'); });
    }).catch(didFail);
}
function didUnlink() {
  UTConfirm({ title: 'Hủy liên kết danh tính số?', message: 'Bạn sẽ không đăng nhập bằng DID được nữa và hồ sơ đã ký bằng DID này không còn gắn với tài khoản (khóa trên trình duyệt vẫn giữ nguyên).', ok: 'Hủy liên kết', danger: true })
    .then(function (yes) {
      if (yes) return UTDid.unlink().then(function (d) { showToast(d.message, 'success'); setTimeout(function () { location.reload(); }, 700); });
    }).catch(didFail);
}
function vcExport() {
  if (!didRec) { showToast('Trình duyệt này chưa có khóa DID — hãy tạo hoặc khôi phục khóa trước.', 'error'); return; }
  UTDid.exportCredential(didRec).then(function (vc) {
    vcShow(true, 'Đã xuất hồ sơ có chữ ký', [
      ['Tệp', 'uterspace-profile.vc.json'],
      ['Nội dung', 'Hồ sơ + ' + vc.credentialSubject.posts.length + ' bài viết, ' + vc.credentialSubject.friendCount + ' bạn bè'],
      ['Ký bởi', vc.issuer]
    ]);
  }).catch(didFail);
}
/** Khung kết quả kiểm tra / xuất VC — dựng bằng DOM (nội dung tệp không được chèn dạng HTML) */
function vcShow(ok, title, rows) {
  var out = document.getElementById('vc-result');
  out.hidden = false;
  out.className = 'vc-result ' + (ok ? 'is-ok' : 'is-bad');
  out.textContent = '';
  var h = document.createElement('p');
  h.className = 'vc-result-title';
  h.innerHTML = '<svg class="icon" aria-hidden="true"><use href="#' + (ok ? 'i-check-circle' : 'i-x-circle') + '"></use></svg>';
  h.appendChild(document.createTextNode(title));
  out.appendChild(h);
  if (rows && rows.length) {
    var dl = document.createElement('dl');
    rows.forEach(function (r) {
      var d = document.createElement('div'), dt = document.createElement('dt'), dd = document.createElement('dd');
      dt.textContent = r[0]; dd.textContent = r[1] == null ? '—' : String(r[1]);
      d.appendChild(dt); d.appendChild(dd); dl.appendChild(d);
    });
    out.appendChild(dl);
  }
  return out;
}
function vcImport(input) {
  var f = input.files[0]; input.value = '';
  if (!f) return;
  var vc;
  f.text().then(function (t) {
    vc = JSON.parse(t);
    return UTDid.verifyCredential(vc);
  }).then(function (r) {
    var sub = vc.credentialSubject || {};
    if (!r.valid) { vcShow(false, r.reason || 'Chữ ký không hợp lệ.', [['Bên phát hành', r.issuer]]); return; }
    var own = r.issuer === DID_SERVER;
    var rows = [['Hồ sơ', sub.name], ['Nền tảng', sub.platform || 'Không rõ'], ['Phát hành bởi', r.issuer],
                ['Ngày ký', (vc.proof && vc.proof.created) || vc.validFrom]];
    if (r.legacy) rows.push(['Định dạng', 'Bản xuất cũ của UTErSpace (vẫn hợp lệ)']);
    var box = vcShow(true, own ? 'Chữ ký hợp lệ — đây là hồ sơ do chính DID của bạn ký' : 'Chữ ký hợp lệ', rows);
    if (!own) {
      UTDid.resolve(r.issuer).then(function (res) {
        var p = document.createElement('p');
        p.className = 'vc-result-foot';
        p.textContent = res.linkedAccount ? 'DID này thuộc tài khoản UTErSpace: ' + res.linkedAccount.name
                                          : 'DID này không liên kết với tài khoản UTErSpace nào.';
        box.appendChild(p);
      }).catch(function () { /* phân giải là thông tin phụ */ });
      return;
    }
    // Chỉ nhập hồ sơ từ VC do chính DID của tài khoản ký — không cho ghi đè hồ sơ bằng VC của người khác
    return UTConfirm({ title: 'Nhập hồ sơ từ chứng nhận này?', message: 'Cập nhật Giới thiệu, Nơi ở, Website theo hồ sơ đã xác minh?', ok: 'Nhập hồ sơ' })
      .then(function (yes) {
        if (!yes) return;
        var body = new URLSearchParams();
        if (sub.bio != null) body.append('bio', sub.bio);
        if (sub.location != null) body.append('location', sub.location);
        if (sub.website != null) body.append('website', sub.website);
        return fetch(SET_CTX + '/profile', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body.toString() })
          .then(function (res) {
            if (!res.ok) throw new Error('Không cập nhật được hồ sơ (lỗi ' + res.status + ').');
            showToast('Đã nhập hồ sơ từ Verifiable Credential.', 'success');
          });
      });
  }).catch(function (e) { vcShow(false, e instanceof SyntaxError ? 'Tệp không phải JSON hợp lệ.' : (e.message || 'Tệp không hợp lệ.')); });
}

/* Khởi động các mục mới */
(function () {
  loadArchive(true);
  renderPasskeySupport();
  if (UTPasskey) document.getElementById('passkey-test').hidden = !document.querySelector('.passkey-row');
  UTDid.supported().then(function (ok) {
    if (!ok) {
      renderDid('nosupport');
      document.querySelectorAll('#panel-identity .did-actions .btn-pill:not(a)').forEach(function (b) { b.classList.add('is-disabled'); b.disabled = true; });
      return;
    }
    return UTDid.load().then(function (rec) { didRec = rec || null; renderDid(); });
  }).catch(function () { renderDid(); });
})();
</script>

<%@ include file="../common/footer.jsp" %>
