<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  chat.jsp — Tin nhắn (ChatController). Trang chỉ dựng khung; danh sách hội thoại và tin nhắn được vẽ bằng
  assets/js/chat.js từ dữ liệu JSON (nhúng sẵn lúc tải trang, sau đó cập nhật qua WebSocket) — một hàm vẽ duy nhất
  cho cả tin tải lúc đầu lẫn tin tới realtime. Dữ liệu người dùng luôn gán bằng textContent (chống XSS).
--%>
<c:set var="pageTitle"       value="Tin nhắn" />
<c:set var="pageDescription" value="Trò chuyện trực tiếp và nhóm chat với bạn bè trong cộng đồng UTErSpace." />
<c:set var="extraCss"        value="chat.css" />
<c:set var="currentPage"     value="chat" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>
<c:set var="ctx" value="${pageContext.request.contextPath}" />

<div class="app-shell">
  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">
    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section chat-section" aria-labelledby="chat-title">
      <h1 class="u-visually-hidden" id="chat-title">Tin nhắn</h1>

      <div class="chat-layout" id="chat-app">
        <%-- ================= DANH SÁCH HỘI THOẠI ================= --%>
        <section class="chat-list-pane" aria-label="Danh sách cuộc trò chuyện">
          <header class="chat-list-head">
            <div class="chat-list-title">
              <h2 class="section-title"><svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg> Tin nhắn</h2>
              <button type="button" class="icon-btn-round" onclick="UTChat.openGroupModal()" title="Tạo nhóm chat" aria-label="Tạo nhóm chat">
                <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg><span class="plus-mini">+</span>
              </button>
            </div>
            <label class="inline-search chat-search">
              <span class="u-visually-hidden">Tìm cuộc trò chuyện</span>
              <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
              <input type="search" id="conv-filter" placeholder="Tìm cuộc trò chuyện..." autocomplete="off">
            </label>
            <div class="conv-tabs" role="group" aria-label="Lọc hội thoại">
              <button type="button" class="conv-tab is-active" data-conv-filter="all">Tất cả</button>
              <button type="button" class="conv-tab" data-conv-filter="unread">Chưa đọc</button>
              <button type="button" class="conv-tab" data-conv-filter="group">Nhóm</button>
            </div>
          </header>
          <ul class="conv-list" id="conv-list" aria-label="Cuộc trò chuyện"></ul>
          <p class="state-empty conv-empty" id="conv-empty" hidden>
            <svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg>
            <strong>Chưa có cuộc trò chuyện</strong>
            Bấm "Nhắn tin" ở trang cá nhân bạn bè hoặc tạo nhóm chat.
          </p>
        </section>

        <%-- ================= KHUNG TRÒ CHUYỆN ================= --%>
        <section class="chat-thread-pane" id="thread-pane" aria-label="Khung trò chuyện">
          <div class="thread-placeholder state-empty" id="thread-empty">
            <svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg>
            <strong><c:out value="${not empty chatNotice ? chatNotice : 'Chọn một cuộc trò chuyện'}"/></strong>
            Chọn bạn bè ở danh sách bên trái, hoặc tạo nhóm chat mới.
          </div>

          <div class="thread" id="thread" hidden>
            <header class="thread-head">
              <a class="thread-user" id="thread-user" href="#">
                <span class="thread-avatar" id="thread-avatar"></span>
                <span class="thread-titles">
                  <span class="thread-name" id="thread-name"></span>
                  <span class="thread-sub" id="thread-sub"></span>
                </span>
              </a>
              <span class="thread-actions">
                <button type="button" class="icon-btn-round" onclick="UTChat.toggleSearch()" title="Tìm trong cuộc trò chuyện" aria-label="Tìm trong cuộc trò chuyện">
                  <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg></button>
                <button type="button" class="icon-btn-round" onclick="UTChat.showPinned()" title="Tin đã ghim" aria-label="Tin đã ghim">📌</button>
                <button type="button" class="icon-btn-round" onclick="UTChat.toggleInfo()" title="Thông tin cuộc trò chuyện" aria-label="Thông tin cuộc trò chuyện">
                  <svg class="icon" aria-hidden="true"><use href="#i-dots"></use></svg></button>
              </span>
            </header>

            <div class="conn-banner" id="conn-banner" hidden></div>

            <div class="thread-search" id="thread-search" hidden>
              <label class="inline-search">
                <span class="u-visually-hidden">Tìm tin nhắn</span>
                <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
                <input type="search" id="msg-search" placeholder="Tìm tin nhắn (không cần dấu)..." autocomplete="off">
              </label>
              <ul class="search-results" id="search-results"></ul>
            </div>

            <button type="button" class="pinned-bar" id="pinned-bar" hidden onclick="UTChat.jumpToPinned()">
              <span class="pinned-icon">📌</span>
              <span class="pinned-text"><b>Tin đã ghim</b><span id="pinned-preview"></span></span>
              <span class="pinned-count" id="pinned-count"></span>
            </button>

            <div class="thread-scroll" id="thread-scroll">
              <div class="history-loader" id="history-loader" hidden>Đang tải tin cũ hơn…</div>
              <ol class="thread-body" id="messages" aria-live="polite"></ol>
              <div class="typing-indicator" id="typing" hidden><span class="typing-dots"><i></i><i></i><i></i></span><span id="typing-text"></span></div>
            </div>
            <button type="button" class="jump-latest" id="jump-latest" hidden onclick="UTChat.jumpLatest()">↓ <span id="jump-latest-text">Tin nhắn mới</span></button>

            <div class="drop-overlay" id="drop-overlay" hidden>Thả file vào đây để gửi</div>

            <footer class="composer" id="composer">
              <div class="composer-context" id="composer-context" hidden>
                <span class="composer-context-text" id="composer-context-text"></span>
                <button type="button" class="composer-context-close" onclick="UTChat.clearContext()" aria-label="Hủy">×</button>
              </div>
              <div class="composer-file" id="composer-file" hidden></div>
              <p class="composer-denied" id="composer-denied" hidden></p>
              <form class="composer-row" id="composer-form" autocomplete="off">
                <input type="file" id="file-input" hidden
                       accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.zip,.rar,.7z,.md,.json,.sql,.java">
                <button type="button" class="compose-tool" onclick="document.getElementById('file-input').click()" title="Gửi ảnh / tệp" aria-label="Gửi ảnh hoặc tệp">
                  <svg class="icon" aria-hidden="true"><use href="#i-photo"></use></svg></button>
                <span class="emoji-wrap">
                  <button type="button" class="compose-tool" id="emoji-btn" title="Biểu tượng cảm xúc" aria-label="Chèn biểu tượng cảm xúc">
                    <svg class="icon" aria-hidden="true"><use href="#i-smile"></use></svg></button>
                  <span class="emoji-picker" id="emoji-picker" hidden></span>
                </span>
                <label class="u-visually-hidden" for="composer-input">Nhập tin nhắn</label>
                <textarea id="composer-input" rows="1" maxlength="4000" placeholder="Nhập tin nhắn... (Enter để gửi, Shift+Enter xuống dòng)"></textarea>
                <button type="submit" class="send-btn" id="send-btn" aria-label="Gửi">
                  <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg></button>
              </form>
            </footer>
          </div>
        </section>

        <%-- ================= BẢNG THÔNG TIN (thành viên, tùy chọn) ================= --%>
        <aside class="chat-info" id="chat-info" hidden aria-label="Thông tin cuộc trò chuyện"></aside>
      </div>
    </section>
  </main>
</div>

<%-- Hộp tạo nhóm / thêm thành viên --%>
<div class="modal-overlay" id="group-modal" role="dialog" aria-modal="true" aria-labelledby="group-modal-title">
  <article class="modal modal-compose group-modal">
    <header class="modal-header">
      <h2 id="group-modal-title">Tạo nhóm chat</h2>
      <button type="button" class="modal-close" onclick="closeModal('group-modal')" aria-label="Đóng">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg></button>
    </header>
    <div class="modal-body">
      <label class="group-title-field" id="group-title-field">
        <span>Tên nhóm <small>(không bắt buộc)</small></span>
        <input type="text" id="group-title" maxlength="100" placeholder="VD: Nhóm đồ án Web — HK1">
      </label>
      <div class="picked-list" id="picked-list"></div>
      <label class="inline-search picker-search">
        <span class="u-visually-hidden">Tìm bạn bè</span>
        <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
        <input type="search" id="picker-filter" placeholder="Tìm bạn bè để thêm..." autocomplete="off">
      </label>
      <ul class="picker-list" id="picker-list"></ul>
      <p class="picker-note" id="picker-note">Chọn ít nhất 2 người bạn. Chỉ thêm được bạn bè của bạn.</p>
    </div>
    <footer class="modal-footer">
      <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('group-modal')">Hủy</button>
      <button type="button" class="btn-pill" id="group-submit" onclick="UTChat.submitGroup()" disabled>Tạo nhóm</button>
    </footer>
  </article>
</div>

<%-- Xem ảnh lớn --%>
<div class="lightbox" id="lightbox" hidden onclick="if (event.target === this) this.hidden = true">
  <button type="button" class="lightbox-close" onclick="document.getElementById('lightbox').hidden = true" aria-label="Đóng">×</button>
  <img id="lightbox-img" alt="">
  <a class="btn-pill" id="lightbox-download" href="#">Tải ảnh về</a>
</div>

<%@ include file="../common/post-modal.jsp" %>

<%-- Dữ liệu ban đầu (JSON do server dựng bằng ChatJson, đã escape) --%>
<script type="application/json" id="chat-convs">${convJson}</script>
<script type="application/json" id="chat-boot">${chatBootstrap}</script>

<%@ include file="../common/footer.jsp" %>
<script src="${ctx}/assets/js/chat.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
