<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Đăng ký — UTErSpace</title>
  <meta name="description" content="Tạo tài khoản UTErSpace — Mạng xã hội kết nối mọi người.">
  <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/global.css?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}">
  <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/pages/auth.css?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}">
</head>
<body class="auth-page">

  <!-- ============ LEFT: BRAND PANEL ============ -->
  <div class="auth-brand">
    <div class="auth-brand-gear">⚙</div>

    <a href="${pageContext.request.contextPath}/" class="auth-brand-logo">
      UTEr<span>Space</span>
    </a>

    <div class="auth-brand-mid">
      <div class="eyebrow">Tham gia cộng đồng UTErSpace</div>
      <h1>Bắt đầu hành trình của bạn cùng UTErSpace.</h1>
      <p>Hàng ngàn người đang chia sẻ câu chuyện, kết bạn và khám phá điều mới mỗi ngày. Tham gia ngay!</p>

      <div class="auth-features">
        <span class="auth-feature-chip">🆓 Hoàn toàn miễn phí</span>
        <span class="auth-feature-chip">🔒 Bảo mật dữ liệu</span>
        <span class="auth-feature-chip">🌏 Mở cho tất cả mọi người</span>
      </div>

      <div class="auth-quote">
        "Kết nối với UTErSpace, mình cảm thấy thế giới gần gũi hơn hẳn!"
        <b>— Thảo My, thành viên UTErSpace</b>
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
    <div class="auth-form-box">
      <h2>Tạo tài khoản mới ✨</h2>
      <p class="auth-subtitle">Điền thông tin bên dưới để bắt đầu</p>

      <c:if test="${not empty errorMessage}">
        <div id="server-error"
             style="background:var(--accent-soft);color:var(--accent);padding:12px 14px;
                    border-radius:var(--r-sm);font-size:13.5px;margin-bottom:16px;border:1px solid var(--accent);">
          ⚠️ <c:out value="${errorMessage}"/>
        </div>
      </c:if>

      <form id="register-form"
            action="${pageContext.request.contextPath}/register"
            method="post"
            novalidate>

        <!-- Họ + Tên -->
        <div class="name-row">
          <div class="field" id="field-firstname">
            <label for="reg-firstname">Họ</label>
            <input type="text"
                   id="reg-firstname"
                   name="firstName"
                   placeholder="Nguyễn"
                   value="${not empty param.firstName ? param.firstName : ''}"
                   required>
            <div class="field-error-msg">Vui lòng nhập họ</div>
          </div>
          <div class="field" id="field-lastname">
            <label for="reg-lastname">Tên</label>
            <input type="text"
                   id="reg-lastname"
                   name="lastName"
                   placeholder="Văn A"
                   value="${not empty param.lastName ? param.lastName : ''}"
                   required>
            <div class="field-error-msg">Vui lòng nhập tên</div>
          </div>
        </div>

        <!-- Email -->
        <div class="field" id="field-email">
          <label for="reg-email">Email</label>
          <input type="text"
                 id="reg-email"
                 name="email"
                 placeholder="ban@email.com"
                 value="${not empty param.email ? param.email : ''}"
                 autocomplete="email"
                 required>
          <div class="field-error-msg" id="email-error-msg">Vui lòng nhập email hợp lệ</div>
        </div>

        <!-- Password -->
        <div class="field" id="field-password">
          <label for="reg-password">Mật khẩu</label>
          <div style="position:relative;">
            <input type="password"
                   id="reg-password"
                   name="password"
                   placeholder="Tối thiểu 8 ký tự, 1 hoa, 1 đặc biệt"
                   autocomplete="new-password"
                   required
                   oninput="checkPasswordStrength(this.value)">
            <button type="button"
                    onclick="togglePw('reg-password', this)"
                    style="position:absolute;right:12px;top:50%;transform:translateY(-50%);
                           background:none;border:none;cursor:pointer;font-size:16px;
                           color:var(--ink-soft);">👁</button>
          </div>
          <div class="pw-strength">
            <div class="pw-strength-bar" id="pw-bar"></div>
          </div>
          <div class="pw-strength-label" id="pw-label">Nhập mật khẩu để kiểm tra độ mạnh</div>
          <div class="field-error-msg" id="password-error-msg">Mật khẩu phải có ít nhất 8 ký tự, 1 chữ hoa và 1 ký tự đặc biệt</div>
        </div>

        <!-- Confirm Password -->
        <div class="field" id="field-confirm">
          <label for="reg-confirm">Xác nhận mật khẩu</label>
          <input type="password"
                 id="reg-confirm"
                 name="confirmPassword"
                 placeholder="Nhập lại mật khẩu"
                 autocomplete="new-password"
                 required>
          <div class="field-error-msg" id="confirm-error-msg">Mật khẩu xác nhận không khớp</div>
        </div>

        <!-- Terms -->
        <div style="margin-bottom:20px;">
          <label style="display:flex;align-items:flex-start;gap:8px;font-size:13px;color:var(--ink-soft);cursor:pointer;">
            <input type="checkbox" id="agree-terms" name="agreeTerms"
                   style="margin-top:2px;accent-color:var(--violet);flex-shrink:0;" required>
            <span>
              Tôi đồng ý với
              <a href="${pageContext.request.contextPath}/terms" target="_blank" rel="noopener" style="color:var(--violet);font-weight:600;">Điều khoản sử dụng</a>
              và
              <a href="${pageContext.request.contextPath}/privacy" target="_blank" rel="noopener" style="color:var(--violet);font-weight:600;">Chính sách bảo mật</a>
              của UTErSpace
            </span>
          </label>
          <div class="field-error-msg" id="terms-error" style="display:none;">Vui lòng đồng ý với điều khoản</div>
        </div>

        <button type="submit" class="btn btn-accent btn-block btn-lg" id="register-submit-btn">
          Tạo tài khoản
        </button>

      </form>

      <p class="auth-switch-hint">
        Đã có tài khoản?
        <a href="${pageContext.request.contextPath}/login" id="go-login">Đăng nhập ngay</a>
      </p>
    </div>
  </div>

  <!-- ============ JS ============ -->
  <script>
    function togglePw(inputId, btn) {
      const input = document.getElementById(inputId);
      if (input.type === 'password') { input.type = 'text'; btn.textContent = '🙈'; }
      else { input.type = 'password'; btn.textContent = '👁'; }
    }

    function checkPasswordStrength(val) {
      const bar   = document.getElementById('pw-bar');
      const label = document.getElementById('pw-label');
      if (!val) { bar.className = 'pw-strength-bar'; bar.style.width='0'; label.textContent='Nhập mật khẩu để kiểm tra độ mạnh'; return; }
      let score = 0;
      if (val.length >= 8)  score++;
      if (/[A-Z]/.test(val)) score++;
      if (/[0-9]/.test(val)) score++;
      if (/[^A-Za-z0-9]/.test(val)) score++;
      bar.className = 'pw-strength-bar';
      if (score <= 1) { bar.classList.add('weak');   label.textContent = 'Yếu — thêm chữ hoa, số hoặc ký tự đặc biệt'; }
      else if (score <= 2) { bar.classList.add('medium'); label.textContent = 'Trung bình'; }
      else { bar.classList.add('strong'); label.textContent = 'Mạnh ✓'; }
    }

    document.getElementById('register-form').addEventListener('submit', function(e) {
      let valid = true;
      const fields = ['firstname','lastname','email','password','confirm'];
      fields.forEach(f => document.getElementById('field-'+f)?.classList.remove('error'));
      document.getElementById('terms-error').style.display = 'none';

      const val = id => document.getElementById('reg-'+id)?.value.trim();

      if (!val('firstname')) { document.getElementById('field-firstname').classList.add('error'); valid=false; }
      if (!val('lastname'))  { document.getElementById('field-lastname').classList.add('error');  valid=false; }
      if (!val('email'))     { document.getElementById('field-email').classList.add('error');     valid=false; }

      const pw = document.getElementById('reg-password').value;
      // Cùng luật với máy chủ (PasswordUtil.policyError)
      if (pw.length < 8 || !/\p{Lu}/u.test(pw) || !/[^\p{L}\p{N}]/u.test(pw)) {
        document.getElementById('field-password').classList.add('error');
        document.getElementById('password-error-msg').textContent = 'Mật khẩu phải có ít nhất 8 ký tự, 1 chữ hoa và 1 ký tự đặc biệt';
        valid = false;
      }
      const confirm = document.getElementById('reg-confirm').value;
      if (pw !== confirm) {
        document.getElementById('field-confirm').classList.add('error');
        valid = false;
      }
      if (!document.getElementById('agree-terms').checked) {
        document.getElementById('terms-error').style.display = 'block';
        valid = false;
      }

      if (!valid) {
        e.preventDefault();
        document.querySelector('.auth-form-box').classList.add('shake');
        setTimeout(() => document.querySelector('.auth-form-box').classList.remove('shake'), 500);
      }
    });
  </script>

</body>
</html>
