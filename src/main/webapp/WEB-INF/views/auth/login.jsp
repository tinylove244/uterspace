<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Đăng nhập — UTErSpace</title>
  <meta name="description" content="Đăng nhập vào UTErSpace — Mạng xã hội kết nối mọi người.">
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
      <div class="eyebrow">Kết nối mọi người, mọi nơi</div>
      <h1>Cùng nhau tạo nên một cộng đồng khỏe mạnh.</h1>
      <p>Chia sẻ câu chuyện, kết bạn mới, theo dõi các chủ đề bạn yêu thích và trò chuyện không giới hạn.</p>

      <div class="auth-features">
        <span class="auth-feature-chip">📸 Chia sẻ khoảnh khắc</span>
        <span class="auth-feature-chip">👥 Kết bạn mới</span>
        <span class="auth-feature-chip">🔔 Thông báo thời gian thực</span>
        <span class="auth-feature-chip">💬 Chat với bạn bè</span>
      </div>

      <div class="auth-quote">
        "UTErSpace giúp mình kết nối với rất nhiều người cùng sở thích, trải nghiệm tuyệt vời!"
        <b>— Minh Tuấn, thành viên UTErSpace</b>
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
      <h2>Chào mừng trở lại 👋</h2>
      <p class="auth-subtitle">Đăng nhập để tiếp tục vào UTErSpace</p>

      <!-- Thông báo thành công (vd: vừa đặt lại mật khẩu) -->
      <c:if test="${not empty successMessage}">
        <div class="auth-alert auth-alert--success" role="status">✅ <c:out value="${successMessage}"/></div>
      </c:if>

      <!-- Error message từ server -->
      <c:if test="${not empty errorMessage}">
        <div id="server-error"
             style="background:var(--accent-soft);color:var(--accent);padding:12px 14px;
                    border-radius:var(--r-sm);font-size:13.5px;margin-bottom:16px;border:1px solid var(--accent);">
          ⚠️ <c:out value="${errorMessage}"/>
        </div>
      </c:if>

      <form id="login-form"
            action="${pageContext.request.contextPath}/login"
            method="post"
            novalidate>

        <!-- Email -->
        <div class="field" id="field-email">
          <label for="login-email">Email</label>
          <input type="text"
                 id="login-email"
                 name="email"
                 placeholder="ban@email.com"
                 value="<c:out value='${not empty param.email ? param.email : prefillEmail}'/>"
                 autocomplete="email"
                 required>
          <div class="field-error-msg" id="email-error">Vui lòng nhập email hợp lệ</div>
        </div>

        <!-- Password -->
        <div class="field" id="field-password">
          <label for="login-password">Mật khẩu</label>
          <div style="position:relative;">
            <input type="password"
                   id="login-password"
                   name="password"
                   placeholder="Nhập mật khẩu"
                   autocomplete="current-password"
                   required>
            <button type="button"
                    id="toggle-password"
                    title="Hiện/ẩn mật khẩu"
                    style="position:absolute;right:12px;top:50%;transform:translateY(-50%);
                           background:none;border:none;cursor:pointer;font-size:16px;
                           color:var(--ink-soft);">👁</button>
          </div>
          <div class="field-error-msg" id="password-error">Vui lòng nhập mật khẩu</div>
        </div>

        <!-- Remember + Forgot -->
        <div class="auth-row-between">
          <label class="auth-remember">
            <input type="checkbox" id="remember-me" name="remember"> Ghi nhớ đăng nhập
          </label>
          <a href="${pageContext.request.contextPath}/forgot-password" class="auth-forgot" id="forgot-link">Quên mật khẩu?</a>
        </div>

        <!-- Submit -->
        <button type="submit" class="btn btn-accent btn-block btn-lg" id="login-submit-btn">
          Đăng nhập
        </button>

      </form>

      <%-- Đăng nhập không mật khẩu bằng danh tính số did:key (khóa Ed25519 trên trình duyệt) — DidLoginController --%>
      <div class="auth-divider"><span>hoặc</span></div>
      <button type="button" class="btn btn-block btn-did" id="did-login-btn">🪪 Đăng nhập bằng danh tính số (DID)</button>
      <label class="auth-did-restore" id="did-restore" hidden>
        Trình duyệt này chưa có khóa DID — <u>chọn tệp sao lưu khóa</u> (uterspace-did-key.json)
        <input type="file" accept=".json,application/json" id="did-file" hidden>
      </label>
      <label class="auth-did-remember" id="did-remember-row" hidden><input type="checkbox" id="did-remember"> Ghi nhớ khóa trên trình duyệt này (chỉ chọn trên máy riêng)</label>
      <p class="auth-did-msg" id="did-msg" role="status"></p>

      <p class="auth-switch-hint">
        Chưa có tài khoản?
        <a href="${pageContext.request.contextPath}/register" id="go-register">Đăng ký ngay</a>
      </p>
    </div>
  </div>

  <script>window.SEC_CTX = '${pageContext.request.contextPath}';</script>
  <script src="${pageContext.request.contextPath}/assets/js/security.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
  <script>
    (function () {
      var btn = document.getElementById('did-login-btn'), msg = document.getElementById('did-msg');
      var restore = document.getElementById('did-restore'), file = document.getElementById('did-file');
      function say(t, bad) { msg.textContent = t; msg.classList.toggle('is-error', !!bad); }
      function go(rec) {
        say('Đang ký thông điệp đăng nhập bằng ' + rec.did.slice(0, 22) + '…');
        return UTDid.login(rec).then(function (d) { say('✅ Xác thực thành công, đang chuyển trang…'); location.href = d.redirect; });
      }
      btn.addEventListener('click', function () {
        UTDid.supported().then(function (ok) {
          if (!ok) throw new Error('Trình duyệt chưa hỗ trợ khóa Ed25519 (cần Chrome/Edge 137+, Firefox 129+, Safari 17+).');
          return UTDid.load();
        }).then(function (rec) {
          if (rec) return go(rec);
          restore.hidden = false;
          document.getElementById('did-remember-row').hidden = false;
          say('Chưa tìm thấy khóa DID trên trình duyệt này.', true);
        }).catch(function (e) { say(e.message, true); });
      });
      file.addEventListener('change', function () {
        var f = file.files[0]; file.value = '';
        if (f) UTDid.restore(f, document.getElementById('did-remember').checked).then(go).catch(function (e) { say(e.message, true); });
      });
    })();
  </script>

  <!-- ============ JS: Client-side validation ============ -->
  <script>
    // Toggle show/hide password
    document.getElementById('toggle-password').addEventListener('click', function() {
      const input = document.getElementById('login-password');
      if (input.type === 'password') {
        input.type = 'text';
        this.textContent = '🙈';
      } else {
        input.type = 'password';
        this.textContent = '👁';
      }
    });

    // Form validation
    document.getElementById('login-form').addEventListener('submit', function(e) {
      let valid = true;

      const email    = document.getElementById('login-email');
      const password = document.getElementById('login-password');
      const fieldEmail = document.getElementById('field-email');
      const fieldPw    = document.getElementById('field-password');

      // Reset
      fieldEmail.classList.remove('error');
      fieldPw.classList.remove('error');

      if (!email.value.trim()) {
        fieldEmail.classList.add('error');
        valid = false;
      }
      if (!password.value.trim()) {
        fieldPw.classList.add('error');
        valid = false;
      }

      if (!valid) {
        e.preventDefault();
        // Shake the form box
        document.querySelector('.auth-form-box').classList.add('shake');
        setTimeout(() => document.querySelector('.auth-form-box').classList.remove('shake'), 500);
      }
    });

    // Auto-dismiss server error after 5s
    const serverErr = document.getElementById('server-error');
    if (serverErr) {
      setTimeout(() => {
        serverErr.style.transition = 'opacity 0.4s';
        serverErr.style.opacity = '0';
        setTimeout(() => serverErr.remove(), 400);
      }, 5000);
    }
  </script>

</body>
</html>
