<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  app-sidebar.jsp — Cột trái dùng chung cho mọi trang trong khung .app-shell.
  Yêu cầu: sessionScope.currentUser, currentPage,
           myPostCount / myFriendCount / mySavedCount (xem LayoutSupport.java).
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="me"  value="${sessionScope.currentUser}" />

<aside class="app-sidebar" aria-label="Hồ sơ và điều hướng">

  <a class="brand" href="${ctx}/feed">
    <span class="brand-mark"><svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg></span>
    UTEr<span>Space</span>
  </a>

  <!-- Hồ sơ rút gọn -->
  <section class="profile-card">
    <a class="profile-avatar" href="${ctx}/profile?userId=${me.userId}"
       aria-label="Xem trang cá nhân của ${me.fullName}">
      <c:choose>
        <c:when test="${not empty me.avatar}">
          <c:set var="myAvatar" value="${ctx}${me.avatarUrl}" />
          <img src="${myAvatar}" alt="Ảnh đại diện của ${me.fullName}" width="94" height="94" style="border-radius:50%; object-fit:cover;">
        </c:when>
        <c:otherwise>
          <span class="nav-avatar-initials" aria-hidden="true" style="display:flex; justify-content:center; align-items:center; width:94px; height:94px; border-radius:50%; background:linear-gradient(135deg, var(--violet), var(--accent)); color:#fff; font-size:36px; font-weight:bold;">${me.initials}</span>
        </c:otherwise>
      </c:choose>
    </a>

    <h2 class="profile-name">${me.fullName}</h2>
    <p class="profile-handle">${not empty me.location ? me.location : me.email}</p>

    <dl class="profile-stats">
      <div class="profile-stat">
        <dt>Bài viết</dt>
        <dd>${not empty myPostCount ? myPostCount : 0}</dd>
      </div>
      <div class="profile-stat">
        <dt>Bạn bè</dt>
        <dd>${not empty myFriendCount ? myFriendCount : 0}</dd>
      </div>
      <div class="profile-stat">
        <dt>Đã lưu</dt>
        <dd>${not empty mySavedCount ? mySavedCount : 0}</dd>
      </div>
    </dl>

    <c:if test="${not empty me.bio}">
      <p class="profile-bio"><c:out value="${me.bio}"/></p>
    </c:if>
  </section>

  <!-- Lối tắt -->
  <section class="shortcuts">
    <h2 class="shortcuts-title">Lối tắt</h2>
    <ul class="shortcut-list">
      <li>
        <a class="shortcut" href="${ctx}/saved">
          <span class="shortcut-ring"><svg class="icon" aria-hidden="true"><use href="#i-bookmark"></use></svg></span>
          Đã lưu
        </a>
      </li>
      <li>
        <a class="shortcut" href="${ctx}/groups">
          <span class="shortcut-ring"><svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg></span>
          Nhóm
        </a>
      </li>
      <li>
        <a class="shortcut" href="${ctx}/video">
          <span class="shortcut-ring"><svg class="icon" aria-hidden="true"><use href="#i-video"></use></svg></span>
          Video
        </a>
      </li>
      <li>
        <a class="shortcut" href="${ctx}/friends">
          <span class="shortcut-ring"><svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg></span>
          Bạn bè
        </a>
      </li>
    </ul>
  </section>

  <!-- Điều hướng chính -->
  <nav class="side-nav" aria-label="Điều hướng chính">
    <h2 class="side-nav-title">Khám phá</h2>
    <ul>
      <li>
        <a class="side-link" href="${ctx}/feed" ${currentPage == 'feed' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-home"></use></svg> Bảng tin
        </a>
      </li>
      <li>
        <a class="side-link" href="${ctx}/friends" ${currentPage == 'friends' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg> Bạn bè
          <span class="side-link-count" data-badge="friend"
                ${not empty friendRequestCount and friendRequestCount > 0 ? '' : 'hidden'}><span data-badge-num>${friendRequestCount}</span><span class="u-visually-hidden"> lời mời kết bạn</span></span>
        </a>
      </li>
      <li>
        <a class="side-link" href="${ctx}/video" ${currentPage == 'video' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-video"></use></svg> Video
        </a>
      </li>
      <li class="side-item--secondary">
        <a class="side-link" href="${ctx}/groups" ${currentPage == 'groups' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg> Nhóm
        </a>
      </li>
      <li>
        <a class="side-link" href="${ctx}/chat" ${currentPage == 'chat' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg> Tin nhắn
          <span class="side-link-count" data-badge="chat"
                ${not empty unreadChatCount and unreadChatCount > 0 ? '' : 'hidden'}><span data-badge-num>${unreadChatCount}</span><span class="u-visually-hidden"> tin nhắn chưa đọc</span></span>
        </a>
      </li>
      <li class="side-item--secondary">
        <a class="side-link" href="${ctx}/saved" ${currentPage == 'saved' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-bookmark"></use></svg> Đã lưu
        </a>
      </li>
      <li>
        <a class="side-link" href="${ctx}/profile?userId=${me.userId}" ${currentPage == 'profile' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-user-circle"></use></svg> Trang cá nhân
        </a>
      </li>
    </ul>
  </nav>

  <!-- Cài đặt / Đăng xuất -->
  <nav class="side-foot" aria-label="Tài khoản">
    <ul>
      <%-- Chỉ quản trị viên (authUser = bản đọc từ DB mỗi request, xem AuthFilter) --%>
      <c:if test="${requestScope.authUser.admin}">
      <li>
        <a class="side-link side-link--admin" href="${ctx}/admin">
          <svg class="icon" aria-hidden="true"><use href="#i-shield"></use></svg> Quản trị
        </a>
      </li>
      </c:if>
      <li>
        <a class="side-link" href="${ctx}/settings" ${currentPage == 'settings' ? 'aria-current="page"' : ''}>
          <svg class="icon" aria-hidden="true"><use href="#i-cog"></use></svg> Cài đặt
        </a>
      </li>
      <li>
        <a class="side-link side-link--danger" href="${ctx}/logout">
          <svg class="icon" aria-hidden="true"><use href="#i-logout"></use></svg> Đăng xuất
        </a>
      </li>
    </ul>
    <p class="side-legal">
      <a href="${ctx}/terms">Điều khoản</a> · <a href="${ctx}/privacy">Quyền riêng tư</a> · © 2026 UTErSpace
    </p>
  </nav>
</aside>
