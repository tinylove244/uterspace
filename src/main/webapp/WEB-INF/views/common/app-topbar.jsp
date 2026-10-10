<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  app-topbar.jsp — Thanh công cụ nằm trong khung .app-shell, đặt ngay đầu <main>.
  Nút "Tạo bài viết" mở hộp thoại trong common/post-modal.jsp.
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />

<%-- Trang hashtag hiện sẵn "#tag" trong ô tìm kiếm --%>
<c:set var="searchValue" value="${not empty hashtag ? '#'.concat(hashtag) : param.q}" />

<header class="app-topbar">
  <%-- Tìm kiếm toàn trang → /search (SearchController). "#tag" → /hashtag. Gợi ý khi gõ: footer.jsp (/api/search/suggest) --%>
  <form class="topbar-search" role="search" action="${ctx}/search" method="get"
        onsubmit="return submitGlobalSearch(this)">
    <label class="u-visually-hidden" for="global-search">Tìm bạn bè, #hashtag, nhóm hoặc bài viết</label>
    <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
    <input type="search" id="global-search" name="q"
           value="<c:out value='${not empty q ? q : searchValue}'/>"
           placeholder="Tìm bạn bè, #hashtag, nhóm, bài viết..." autocomplete="off"
           role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="search-suggest">
    <div class="search-suggest" id="search-suggest" role="listbox" aria-label="Gợi ý tìm kiếm" hidden></div>
  </form>

  <nav class="topbar-actions" aria-label="Lối tắt tài khoản">
    <a class="icon-action ${currentPage == 'notifications' ? 'is-active' : ''}"
       href="${ctx}/notifications"
       aria-label="Thông báo<c:if test='${not empty unreadNotifCount and unreadNotifCount > 0}'> (${unreadNotifCount} chưa đọc)</c:if>">
      <svg class="icon" aria-hidden="true"><use href="#i-bell"></use></svg>
      <%-- Luôn render, ẩn khi = 0: /api/pulse (footer.jsp) cập nhật số mà không cần tải lại trang --%>
      <span class="icon-action-count" aria-hidden="true" data-badge="notif"
            ${not empty unreadNotifCount and unreadNotifCount > 0 ? '' : 'hidden'}>${unreadNotifCount}</span>
    </a>
    <a class="icon-action ${currentPage == 'chat' ? 'is-active' : ''}"
       href="${ctx}/chat"
       aria-label="Tin nhắn<c:if test='${not empty unreadChatCount and unreadChatCount > 0}'> (${unreadChatCount} chưa đọc)</c:if>">
      <svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg>
      <span class="icon-action-count" aria-hidden="true" data-badge="chat"
            ${not empty unreadChatCount and unreadChatCount > 0 ? '' : 'hidden'}>${unreadChatCount}</span>
    </a>
    <button type="button" class="btn-create" id="btn-create-post" onclick="openModal('post-modal')">
      <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg>
      <span>Tạo bài viết</span>
    </button>
  </nav>
</header>
