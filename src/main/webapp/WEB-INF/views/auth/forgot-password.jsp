<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  auth/forgot-password.jsp — Quên mật khẩu 3 bước (ForgotPasswordController):
    step = email  → nhập email, gửi mã OTP
    step = otp    → nhập mã 6 số (đếm ngược hiệu lực, gửi lại sau 60 giây, đổi email)
    step = reset  → đặt mật khẩu mới (kiểm tra luật mật khẩu ngay khi gõ)
  Thông báo: fpError (đỏ), fpInfo (xanh dương), fpOk (xanh lá), fpDev (vàng — máy chủ chưa cấu hình email).
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="assetV" value="${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}" />
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="robots" content="noindex">
  <title><c:out value="${pageTitle}"/> — UTErSpace</title>
  <link rel="stylesheet" href="${ctx}/assets/css/global.css?v=${assetV}">
  <link rel="stylesheet" href="${ctx}/assets/css/pages/auth.css?v=${assetV}">
</head>
<body class="auth-page">

  <!-- ============ LEFT: BRAND PANEL ============ -->
  <div class="auth-brand">
    <div class="auth-brand-gear">⚙</div>
    <a href="${ctx}/" class="auth-brand-logo">UTEr<span>Space</span></a>
    <div class="auth-brand-mid">
      <div class="eyebrow">Kết nối mọi người, mọi nơi</div>
      <h1>Lấy lại quyền truy cập an toàn.</h1>
      <p>Chúng tôi gửi một mã xác nhận gồm 6 chữ số tới email của bạn. Chỉ người giữ hộp thư đó mới đặt lại được mật khẩu.</p>
      <div class="auth-features">
        <span class="auth-feature-chip">📧 Mã gửi qua email</span>
        <span class="auth-feature-chip">⏱ Hiệu lực 5 phút</span>
        <span class="auth-feature-chip">🔒 Đăng xuất mọi thiết bị cũ</span>
      </div>
    </div>
    <div class="auth-brand-footer">
      <span>© 2026 UTErSpace</span>
      <a href="${pageContext.request.contextPath}/terms">Điều khoản</a>
      <a href="${pageContext.request.contextPath}/privacy">Bảo mật</a>
    </div>
  </div>

  <!-- ============ RIGHT: FORM PANEL ============ -->
  <div class="auth-form-panel">
    <main class="auth-form-box">
      <ol class="fp-steps" aria-label="Các bước đặt lại mật khẩu">
        <li class="${step == 'email' ? 'current' : 'done'}" ${step == 'email' ? 'aria-current="step"' : ''}>Email</li>
        <li class="${step == 'otp' ? 'current' : (step == 'reset' ? 'done' : '')}" ${step == 'otp' ? 'aria-current="step"' : ''}>Mã xác nhận</li>
        <li class="${step == 'reset' ? 'current' : ''}" ${step == 'reset' ? 'aria-current="step"' : ''}>Mật khẩu mới</li>
      </ol>

      <h2><c:out value="${pageTitle}"/></h2>
      <p class="auth-subtitle">
        <c:choose>
          <c:when test="${step == 'otp'}">Nhập mã gồm 6 chữ số đã gửi tới <b><c:out value="${maskedEmail}"/></b>.</c:when>
          <c:when test="${step == 'reset'}">Tạo mật khẩu mới đủ mạnh cho tài khoản <b><c:out value="${maskedEmail}"/></b>.</c:when>
          <c:otherwise>Nhập email bạn đã dùng để đăng ký. Chúng tôi sẽ gửi mã xác nhận để đặt lại mật khẩu.</c:otherwise>
        </c:choose>
      </p>

      <div aria-live="polite">
        <c:if test="${not empty fpError}"><div class="auth-alert auth-alert--error" role="alert">⚠️ <c:out value="${fpError}"/></div></c:if>
        <c:if test="${not empty fpOk}"><div class="auth-alert auth-alert--success">✅ <c:out value="${fpOk}"/></div></c:if>
        <c:if test="${not empty fpInfo}"><div class="auth-alert auth-alert--info">📧 <c:out value="${fpInfo}"/></div></c:if>
        <c:if test="${not empty fpDev}"><div class="auth-alert auth-alert--dev">🛠 <c:out value="${fpDev}"/></div></c:if>
      </div>

      <c:choose>
        <%-- ===== BƯỚC 1: EMAIL ===== --%>
        <c:when test="${step == 'email'}">
          <form method="post" action="${ctx}/forgot-password" class="js-busy" novalidate>
            <input type="hidden" name="action" value="sendOtp">
            <div class="field" id="field-email">
              <label for="fp-email">Email</label>
              <input type="email" id="fp-email" name="email" placeholder="ban@email.com" autocomplete="email"
                     maxlength="100" required autofocus value="<c:out value='${fpEmail}'/>">
              <div class="field-error-msg">Vui lòng nhập email hợp lệ</div>
            </div>
            <button type="submit" class="btn btn-accent btn-block btn-lg" data-busy="Đang gửi mã…">Gửi mã xác nhận</button>
          </form>
        </c:when>

        <%-- ===== BƯỚC 2: MÃ OTP ===== --%>
        <c:when test="${step == 'otp'}">
          <form method="post" action="${ctx}/forgot-password" class="js-busy" id="otp-form" novalidate>
            <input type="hidden" name="action" value="verifyOtp">
            <div class="field" id="field-otp">
              <label for="fp-otp">Mã xác nhận (6 chữ số)</label>
              <input type="text" id="fp-otp" name="otp" class="otp-input" inputmode="numeric" pattern="[0-9]{6}" maxlength="6"
                     autocomplete="one-time-code" placeholder="••••••" required autofocus
                     ${otpSecondsLeft > 0 ? '' : 'disabled'} aria-describedby="otp-timer">
              <div class="field-error-msg">Mã xác nhận gồm đúng 6 chữ số</div>
              <div class="fp-meta">
                <span id="otp-timer" data-left="${otpSecondsLeft}" aria-live="off">
                  <c:choose>
                    <c:when test="${otpSecondsLeft > 0}">Mã hết hạn sau ${otpSecondsLeft} giây</c:when>
                    <c:otherwise><span class="expired">Mã đã hết hạn hoặc bị hủy — hãy gửi lại mã.</span></c:otherwise>
                  </c:choose>
                </span>
                <c:if test="${otpSecondsLeft > 0}"><span>Còn ${attemptsLeft} lần thử</span></c:if>
              </div>
            </div>
            <button type="submit" class="btn btn-accent btn-block btn-lg" id="btn-verify" data-busy="Đang kiểm tra…"
                    ${otpSecondsLeft > 0 ? '' : 'disabled'}>Xác nhận</button>
          </form>
          <div class="fp-actions-row">
            <form method="post" action="${ctx}/forgot-password" class="js-busy">
              <input type="hidden" name="action" value="resend">
              <button type="submit" class="link-btn" id="btn-resend" data-wait="${resendSecondsLeft}"
                      ${resendSecondsLeft > 0 ? 'disabled' : ''}>Gửi lại mã</button>
            </form>
            <form method="post" action="${ctx}/forgot-password">
              <input type="hidden" name="action" value="restart">
              <button type="submit" class="link-btn">Dùng email khác</button>
            </form>
          </div>
        </c:when>

        <%-- ===== BƯỚC 3: MẬT KHẨU MỚI ===== --%>
        <c:otherwise>
          <form method="post" action="${ctx}/forgot-password" class="js-busy" id="reset-form" novalidate>
            <input type="hidden" name="action" value="resetPassword">
            <%-- Giúp trình quản lý mật khẩu lưu đúng tài khoản --%>
            <input type="text" name="username" autocomplete="username" value="<c:out value='${resetEmail}'/>" hidden>
            <div class="field" id="field-password">
              <label for="fp-password">Mật khẩu mới</label>
              <div style="position:relative;">
                <input type="password" id="fp-password" name="password" autocomplete="new-password" maxlength="64"
                       placeholder="Tối thiểu 8 ký tự, 1 hoa, 1 đặc biệt" required autofocus aria-describedby="pw-rules">
                <button type="button" class="js-toggle-pw" data-for="fp-password" aria-label="Hiện mật khẩu"
                        style="position:absolute;right:12px;top:50%;transform:translateY(-50%);background:none;border:none;cursor:pointer;font-size:16px;color:var(--ink-soft);">👁</button>
              </div>
              <div class="pw-strength"><div class="pw-strength-bar" id="pw-bar"></div></div>
              <ul class="pw-rules" id="pw-rules">
                <li data-rule="len">Ít nhất 8 ký tự</li>
                <li data-rule="upper">Có chữ in hoa (A–Z)</li>
                <li data-rule="special">Có ký tự đặc biệt (! @ # $ …)</li>
              </ul>
              <div class="field-error-msg"><c:out value="${passwordPolicy}"/></div>
            </div>
            <div class="field" id="field-confirm">
              <label for="fp-confirm">Nhập lại mật khẩu mới</label>
              <input type="password" id="fp-confirm" name="confirmPassword" autocomplete="new-password" maxlength="64"
                     placeholder="Nhập lại mật khẩu" required>
              <div class="field-error-msg">Mật khẩu xác nhận không khớp</div>
            </div>
            <button type="submit" class="btn btn-accent btn-block btn-lg" data-busy="Đang lưu…">Đổi mật khẩu</button>
          </form>
          <div class="fp-actions-row">
            <form method="post" action="${ctx}/forgot-password">
              <input type="hidden" name="action" value="restart">
              <button type="submit" class="link-btn">Hủy, làm lại từ đầu</button>
            </form>
          </div>
        </c:otherwise>
      </c:choose>

      <p class="auth-switch-hint">
        Đã nhớ ra mật khẩu? <a href="${ctx}/login">Quay lại Đăng nhập</a>
      </p>
    </main>
  </div>

  <script>
  (function () {
    // Nút "đang xử lý" — gửi email mất vài giây, tránh bấm nhiều lần
    document.querySelectorAll('form.js-busy').forEach(function (f) {
      f.addEventListener('submit', function (e) {
        if (e.defaultPrevented) return;
        var b = f.querySelector('[type="submit"]');
        if (b && b.getAttribute('data-busy')) { b.setAttribute('aria-busy', 'true'); b.textContent = b.getAttribute('data-busy'); }
      });
    });

    function shake() {
      var box = document.querySelector('.auth-form-box');
      box.classList.add('shake');
      setTimeout(function () { box.classList.remove('shake'); }, 500);
    }

    // ---- Bước 1: email ----
    var email = document.getElementById('fp-email');
    if (email) {
      email.form.addEventListener('submit', function (e) {
        var ok = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value.trim());
        document.getElementById('field-email').classList.toggle('error', !ok);
        if (!ok) { e.preventDefault(); shake(); email.focus(); }
      }, true);
    }

    // ---- Bước 2: mã OTP ----
    var otp = document.getElementById('fp-otp');
    if (otp) {
      otp.addEventListener('input', function () {
        otp.value = otp.value.replace(/\D/g, '').slice(0, 6);
        document.getElementById('field-otp').classList.remove('error');
        if (otp.value.length === 6) otp.form.requestSubmit ? otp.form.requestSubmit() : otp.form.submit();   // tự xác nhận khi đủ 6 số
      });
      otp.form.addEventListener('submit', function (e) {
        if (!/^\d{6}$/.test(otp.value)) { e.preventDefault(); document.getElementById('field-otp').classList.add('error'); shake(); otp.focus(); }
      }, true);

      var timer = document.getElementById('otp-timer'), left = +timer.getAttribute('data-left');
      var end = Date.now() + left * 1000;   // tính theo đồng hồ máy chủ gửi xuống, không phụ thuộc giờ máy người dùng
      function tick() {
        var s = Math.max(0, Math.round((end - Date.now()) / 1000));
        if (s <= 0) {
          timer.innerHTML = '<span class="expired">Mã đã hết hạn — hãy bấm "Gửi lại mã".</span>';
          otp.disabled = true;
          document.getElementById('btn-verify').disabled = true;
          return;
        }
        timer.textContent = 'Mã hết hạn sau ' + Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
        setTimeout(tick, 1000);
      }
      if (left > 0) tick();
    }
    var resend = document.getElementById('btn-resend');
    if (resend) {
      var wait = +resend.getAttribute('data-wait'), until = Date.now() + wait * 1000;
      (function cd() {
        var s = Math.max(0, Math.round((until - Date.now()) / 1000));
        resend.disabled = s > 0;
        resend.textContent = s > 0 ? 'Gửi lại mã sau ' + s + ' giây' : 'Gửi lại mã';
        if (s > 0) setTimeout(cd, 1000);
      })();
    }

    // ---- Bước 3: mật khẩu mới (luật giống máy chủ: PasswordUtil.policyError) ----
    var pw = document.getElementById('fp-password');
    if (pw) {
      var confirm = document.getElementById('fp-confirm');
      var rules = {
        len: function (v) { return v.length >= 8; },
        upper: function (v) { return /\p{Lu}/u.test(v); },
        special: function (v) { return /[^\p{L}\p{N}]/u.test(v); }
      };
      function check() {
        var v = pw.value, score = 0;
        document.querySelectorAll('#pw-rules li').forEach(function (li) {
          var ok = rules[li.getAttribute('data-rule')](v);
          li.classList.toggle('ok', ok);
          if (ok) score++;
        });
        if (/\d/.test(v)) score++;
        var bar = document.getElementById('pw-bar');
        bar.className = 'pw-strength-bar' + (!v ? '' : score <= 1 ? ' weak' : score <= 3 ? ' medium' : ' strong');
        return Object.keys(rules).every(function (k) { return rules[k](v); });
      }
      pw.addEventListener('input', function () { check(); document.getElementById('field-password').classList.remove('error'); });
      confirm.addEventListener('input', function () { document.getElementById('field-confirm').classList.remove('error'); });
      pw.form.addEventListener('submit', function (e) {
        var okPw = check(), okConfirm = pw.value === confirm.value;
        document.getElementById('field-password').classList.toggle('error', !okPw);
        document.getElementById('field-confirm').classList.toggle('error', okPw && !okConfirm);
        if (!okPw || !okConfirm) { e.preventDefault(); shake(); (okPw ? confirm : pw).focus(); }
      }, true);
      document.querySelectorAll('.js-toggle-pw').forEach(function (b) {
        b.addEventListener('click', function () {
          var show = pw.type === 'password';
          pw.type = confirm.type = show ? 'text' : 'password';
          b.textContent = show ? '🙈' : '👁';
          b.setAttribute('aria-label', show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu');
        });
      });
    }
  })();
  </script>
</body>
</html>
