<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  admin/layout.jsp — phần ĐẦU khung quản trị: <head>, thanh bên (logo UTErSpace giống phía người dùng), topbar, mở <main>.
  Mỗi trang admin: include file này → nội dung → include layout-end.jsp.
  Cần (AdminController đặt): me, adminPage, pageTitle, pendingReportCount, csrfToken (AuthFilter).
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="assetV" value="${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}" />
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="robots" content="noindex, nofollow">
  <meta name="theme-color" content="#0A3D8F">
  <title><c:out value="${pageTitle}"/> — Quản trị UTErSpace</title>
  <c:if test="${not empty csrfToken}"><meta name="csrf-token" content="${csrfToken}"></c:if>
  <%-- Áp chế độ sáng / tối đã chọn TRƯỚC khi vẽ trang (tránh nháy màu) --%>
  <script>try { if (localStorage.getItem('ut-admin-theme') === 'dark') document.documentElement.setAttribute('data-theme', 'dark'); } catch (e) {}</script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap">
  <link rel="stylesheet" href="${ctx}/assets/css/pages/admin.css?v=${assetV}">
</head>
<body data-ctx="${ctx}" class="adm adm-${adminPage}">
<%@ include file="../common/icons.jsp" %>

<aside class="adm-sidebar" id="adm-sidebar" aria-label="Điều hướng quản trị">
  <a class="adm-brand" href="${ctx}/admin">
    <span class="adm-brand-mark"><svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg></span>
    UTEr<span>Space</span>
    <span class="adm-brand-tag">Admin</span>
  </a>

  <nav class="adm-nav">
    <div class="adm-nav-title">Tổng quan</div>
    <a class="nav-item ${adminPage == 'dashboard' ? 'active' : ''}" href="${ctx}/admin" ${adminPage == 'dashboard' ? 'aria-current="page"' : ''}>
      <svg class="icon" aria-hidden="true"><use href="#i-grid"></use></svg> Bảng điều khiển</a>

    <div class="adm-nav-title">Kiểm duyệt</div>
    <a class="nav-item ${adminPage == 'reports' ? 'active' : ''}" href="${ctx}/admin/reports" ${adminPage == 'reports' ? 'aria-current="page"' : ''}>
      <svg class="icon" aria-hidden="true"><use href="#i-flag"></use></svg> Báo cáo vi phạm
      <span class="nav-badge" id="rail-report-badge" ${pendingReportCount > 0 ? '' : 'hidden'}>${pendingReportCount}</span>
      <span class="u-sr"> đối tượng bị báo cáo đang chờ</span></a>
    <a class="nav-item ${adminPage == 'posts' ? 'active' : ''}" href="${ctx}/admin/posts" ${adminPage == 'posts' ? 'aria-current="page"' : ''}>
      <svg class="icon" aria-hidden="true"><use href="#i-document"></use></svg> Bài viết</a>

    <div class="adm-nav-title">Cộng đồng</div>
    <a class="nav-item ${adminPage == 'users' ? 'active' : ''}" href="${ctx}/admin/users" ${adminPage == 'users' ? 'aria-current="page"' : ''}>
      <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg> Người dùng</a>
    <a class="nav-item ${adminPage == 'groups' ? 'active' : ''}" href="${ctx}/admin/groups" ${adminPage == 'groups' ? 'aria-current="page"' : ''}>
      <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg> Nhóm</a>

    <div class="adm-nav-title">Hệ thống</div>
    <a class="nav-item ${adminPage == 'logs' ? 'active' : ''}" href="${ctx}/admin/logs" ${adminPage == 'logs' ? 'aria-current="page"' : ''}>
      <svg class="icon" aria-hidden="true"><use href="#i-clipboard"></use></svg> Nhật ký quản trị</a>
  </nav>

  <div class="adm-side-foot">
    <div class="adm-side-card">
      <b>Đang ở chế độ quản trị</b>
      Mọi thao tác đều được ghi vào nhật ký kèm thời gian và địa chỉ IP.
      <br><a href="${ctx}/logout"><svg class="icon" aria-hidden="true"><use href="#i-logout"></use></svg> Đăng xuất</a>
    </div>
    <%-- Tài khoản quản trị không có trang cá nhân / giao diện người dùng (AuthFilter chặn) → chỉ hiển thị --%>
    <div class="adm-me">
      <span class="avatar"><c:choose>
        <c:when test="${not empty me.avatar}"><img src="${ctx}${me.avatarUrl}" alt=""></c:when>
        <c:otherwise><c:out value="${me.initials}"/></c:otherwise>
      </c:choose></span>
      <span class="adm-me-text"><b><c:out value="${me.fullName}"/></b><small>Quản trị viên</small></span>
    </div>
  </div>
</aside>
<div class="adm-scrim" data-adm-menu></div>

<div class="adm-shell">
  <header class="adm-topbar">
    <button type="button" class="icon-btn adm-menu-btn" data-adm-menu aria-controls="adm-sidebar" aria-label="Mở menu quản trị">
      <svg class="icon" aria-hidden="true"><use href="#i-menu"></use></svg></button>
    <nav class="adm-crumbs" aria-label="Vị trí">
      <a href="${ctx}/admin">Quản trị</a>
      <svg class="icon" aria-hidden="true"><use href="#i-chevron-right"></use></svg>
      <b><c:out value="${pageTitle}"/></b>
    </nav>
    <div class="adm-top-actions">
      <button type="button" class="icon-btn theme-toggle" id="theme-toggle" aria-label="Đổi giao diện sáng / tối" title="Giao diện sáng / tối">
        <svg class="icon i-moon" aria-hidden="true"><use href="#i-moon"></use></svg>
        <svg class="icon i-sun" aria-hidden="true"><use href="#i-sun"></use></svg>
      </button>
      <a class="adm-back" href="${ctx}/logout"><svg class="icon" aria-hidden="true"><use href="#i-logout"></use></svg><span class="long">Đăng xuất</span></a>
    </div>
  </header>

  <main class="adm-main" id="main-content">
