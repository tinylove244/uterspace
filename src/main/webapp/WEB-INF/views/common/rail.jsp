<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  rail.jsp — Thanh điều hướng trái dùng chung cho các trang 2 cột.
--%>
<aside class="page-rail" id="page-rail" aria-label="Menu điều hướng">
  <nav>
    <a href="${pageContext.request.contextPath}/feed"
       class="rail-item ${currentPage == 'feed' ? 'active' : ''}"
       id="rail-feed">
      <span class="rail-icon">🏠</span> Bảng tin
    </a>
    <a href="${pageContext.request.contextPath}/friends"
       class="rail-item ${currentPage == 'friends' ? 'active' : ''}"
       id="rail-friends">
      <span class="rail-icon">👥</span> Bạn bè
    </a>
    <a href="${pageContext.request.contextPath}/video"
       class="rail-item ${currentPage == 'video' ? 'active' : ''}"
       id="rail-video">
      <span class="rail-icon">🎬</span> Video
    </a>
    <a href="${pageContext.request.contextPath}/saved"
       class="rail-item ${currentPage == 'saved' ? 'active' : ''}"
       id="rail-saved">
      <span class="rail-icon">🔖</span> Đã lưu
    </a>
    <a href="${pageContext.request.contextPath}/groups"
       class="rail-item ${currentPage == 'groups' ? 'active' : ''}"
       id="rail-groups">
      <span class="rail-icon">🏷️</span> Nhóm
    </a>
    <a href="${pageContext.request.contextPath}/chat"
       class="rail-item ${currentPage == 'chat' ? 'active' : ''}"
       id="rail-chat">
      <span class="rail-icon">💬</span> Chat
    </a>
    <div class="rail-divider"></div>
    <c:if test="${requestScope.authUser.admin}">
    <a href="${pageContext.request.contextPath}/admin" class="rail-item" id="rail-admin">
      <span class="rail-icon">🛡️</span> Quản trị
    </a>
    </c:if>
    <a href="${pageContext.request.contextPath}/settings" class="rail-item ${currentPage == 'settings' ? 'active' : ''}" id="rail-settings">
      <span class="rail-icon">⚙️</span> Cài đặt
    </a>
  </nav>
</aside>
