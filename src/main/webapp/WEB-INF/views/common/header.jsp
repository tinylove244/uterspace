<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><c:out value="${pageTitle != null ? pageTitle.concat(' — UTErSpace') : 'UTErSpace'}"/></title>
  <meta name="description" content="${not empty pageDescription ? pageDescription : 'UTErSpace — Mạng xã hội kết nối mọi người, chia sẻ khoảnh khắc và cùng nhau phát triển.'}">
  <meta name="theme-color" content="#0A3D8F">
  <%-- Token CSRF của phiên (AuthFilter đặt vào request) — JS gửi kèm header X-CSRF-Token khi POST /admin/*, /report/* --%>
  <c:if test="${not empty csrfToken}"><meta name="csrf-token" content="${csrfToken}"></c:if>
  <%-- Tự gắn header X-CSRF-Token vào MỌI fetch / XMLHttpRequest gửi dữ liệu (POST, PUT, DELETE) tới chính trang web này,
       nên mọi nút bấm hiện có đều qua được CsrfFilter mà không phải sửa từng chỗ gọi. GET không cần token. --%>
  <script>
  (function () {
    function token() { var m = document.querySelector('meta[name="csrf-token"]'); return m ? m.content : null; }
    function sameOrigin(u) { try { return new URL(u, location.href).origin === location.origin; } catch (e) { return false; } }
    if (window.fetch) {
      var nativeFetch = window.fetch;
      window.fetch = function (input, init) {
        init = init || {};
        var method = String(init.method || (input && input.method) || 'GET').toUpperCase();
        var url = typeof input === 'string' ? input : (input && input.url) || '';
        var t = token();
        if (t && method !== 'GET' && method !== 'HEAD' && sameOrigin(url)) {
          var h = new Headers(init.headers || (typeof input !== 'string' && input.headers) || {});
          if (!h.has('X-CSRF-Token')) h.set('X-CSRF-Token', t);
          init.headers = h;
        }
        return nativeFetch.call(this, input, init);
      };
    }
    var open = XMLHttpRequest.prototype.open, send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function (m, u) {
      this._csrf = String(m).toUpperCase() !== 'GET' && sameOrigin(u);
      return open.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function () {
      var t = token();
      if (this._csrf && t) { try { this.setRequestHeader('X-CSRF-Token', t); } catch (e) { } }
      return send.apply(this, arguments);
    };
  })();
  </script>
  <link rel="canonical" href="${pageContext.request.requestURL}">

  <!-- Open Graph / AEO -->
  <meta property="og:type"        content="website">
  <meta property="og:site_name"   content="UTErSpace">
  <meta property="og:locale"      content="vi_VN">
  <meta property="og:title"       content="<c:out value="${pageTitle != null ? pageTitle.concat(' — UTErSpace') : 'UTErSpace'}"/>">
  <meta property="og:description" content="${not empty pageDescription ? pageDescription : 'UTErSpace — Mạng xã hội kết nối mọi người, chia sẻ khoảnh khắc và cùng nhau phát triển.'}">
  <meta property="og:url"         content="${pageContext.request.requestURL}">
  <meta name="twitter:card"       content="summary_large_image">

  <!-- Fonts: Poppins -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet"
        href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap">

  <!-- CSS — ?v=assetVersion đổi sau mỗi lần deploy để tránh cache cũ (xem AppContextListener) -->
  <c:set var="assetV" value="${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}" />
  <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/global.css?v=${assetV}">
  <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/components.css?v=${assetV}">
  <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/app-shell.css?v=${assetV}">
  <c:if test="${not empty extraCss}">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/pages/${extraCss}?v=${assetV}">
  </c:if>
</head>
<body class="page-${not empty currentPage ? currentPage : 'default'}">

<a class="skip-link" href="#main-content">Bỏ qua điều hướng, tới nội dung chính</a>

<%-- Sprite Heroicons dùng chung cho toàn site --%>
<%@ include file="icons.jsp" %>

<%-- Trang có thanh điều hướng riêng (vd: Bảng tin) đặt hideTopbar = true --%>
<c:if test="${not hideTopbar}">
<!-- ============================================================
     TOPBAR
     ============================================================ -->
<nav class="topbar" id="topbar" role="navigation" aria-label="Thanh điều hướng chính">

  <!-- Logo -->
  <a href="${pageContext.request.contextPath}/feed" class="topbar-logo" id="topbar-logo">
    UTEr<span>Space</span>
  </a>

  <!-- Search -->
  <div class="topbar-search">
    <input type="text"
           id="global-search"
           placeholder="Tìm bạn bè, chủ đề, bài viết..."
           autocomplete="off"
           aria-label="Tìm kiếm">
  </div>

  <!-- Actions -->
  <div class="topbar-actions">

    <!-- Home -->
    <a href="${pageContext.request.contextPath}/feed"
       class="icon-btn ${currentPage == 'feed' ? 'active-nav' : ''}"
       id="topbar-home-btn"
       title="Bảng tin"
       aria-label="Bảng tin">🏠</a>

    <!-- Chat / Tin nhắn -->
    <a href="${pageContext.request.contextPath}/chat"
       class="icon-btn ${currentPage == 'chat' ? 'active-nav' : ''}"
       id="topbar-chat-btn"
       title="Tin nhắn"
       aria-label="Tin nhắn"
       style="position:relative;">💬
      <c:if test="${not empty unreadChatCount && unreadChatCount > 0}">
        <span class="notif-badge" id="chat-badge">${unreadChatCount}</span>
      </c:if>
    </a>

    <!-- Notifications -->
    <div class="dropdown topbar-notif-btn" id="notif-dropdown-wrap">
      <a href="${pageContext.request.contextPath}/notifications"
         class="icon-btn ${currentPage == 'notifications' ? 'active-nav' : ''}"
         id="topbar-notif-btn"
         title="Thông báo"
         aria-label="Thông báo"
         style="position:relative;display:inline-flex;align-items:center;justify-content:center;text-decoration:none;">🔔
        <c:if test="${not empty unreadNotifCount && unreadNotifCount > 0}">
          <span class="notif-badge" id="notif-badge">${unreadNotifCount}</span>
        </c:if>
        <c:if test="${empty unreadNotifCount}">
          <span class="notif-badge" id="notif-badge" style="display:none;">0</span>
        </c:if>
      </a>
    </div>

    <!-- User avatar menu -->
    <c:choose>
      <c:when test="${not empty sessionScope.currentUser}">
        <div class="dropdown" id="user-menu-wrap">
          <div class="avatar avatar-sm topbar-avatar-btn"
               id="topbar-user-avatar"
               title="${sessionScope.currentUser.firstName} ${sessionScope.currentUser.lastName}"
               onclick="toggleUserMenu()"
               style="cursor:pointer;">
            <c:choose>
              <c:when test="${not empty sessionScope.currentUser.avatar}">
                <img src="${pageContext.request.contextPath}${sessionScope.currentUser.avatarUrl}"
                     alt="Avatar">
              </c:when>
              <c:otherwise>
                ${sessionScope.currentUser.initials}
              </c:otherwise>
            </c:choose>
          </div>
          <div class="dropdown-menu" id="user-menu">
            <a href="${pageContext.request.contextPath}/profile?userId=${sessionScope.currentUser.userId}"
               class="dropdown-item" id="menu-profile">
              👤 Trang cá nhân
            </a>
            <a href="${pageContext.request.contextPath}/friends"
               class="dropdown-item" id="menu-friends">
              👥 Bạn bè
            </a>
            <a href="${pageContext.request.contextPath}/video"
               class="dropdown-item" id="menu-video">
              🎬 Video
            </a>
            <a href="${pageContext.request.contextPath}/groups"
               class="dropdown-item" id="menu-groups">
              🏷️ Nhóm
            </a>
            <a href="${pageContext.request.contextPath}/saved"
               class="dropdown-item" id="menu-saved">
              🔖 Bài viết đã lưu
            </a>
            <a href="${pageContext.request.contextPath}/chat"
               class="dropdown-item" id="menu-chat">
              💬 Tin nhắn
            </a>
            <c:if test="${requestScope.authUser.admin}">
            <a href="${pageContext.request.contextPath}/admin" class="dropdown-item" id="menu-admin">
              🛡️ Quản trị
            </a>
            </c:if>
            <div class="dropdown-divider"></div>
            <a href="${pageContext.request.contextPath}/logout" class="dropdown-item danger" id="menu-logout">
              🚪 Đăng xuất
            </a>
          </div>
        </div>
      </c:when>
      <c:otherwise>
        <a href="${pageContext.request.contextPath}/login" class="btn btn-accent btn-sm" id="topbar-login-btn">
          Đăng nhập
        </a>
      </c:otherwise>
    </c:choose>

  </div>
</nav>
</c:if>

<!-- Toast container (toàn cục) -->
<div id="toast-container" aria-live="polite"></div>
