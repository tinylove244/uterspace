<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  friends.jsp — Trang Bạn bè (FriendsController): 4 tab
    Lời mời (nhận được) · Đã gửi (chờ người kia) · Gợi ý (bạn chung, cùng khu vực) · Bạn bè (tìm kiếm, lọc, sắp xếp)
  Nút trạng thái mỗi thẻ: relation.js. Danh sách TỰ LÀM MỚI khi quan hệ đổi (mình bấm ở đây, ở tab khác,
  hoặc người kia chấp nhận / gửi lời mời — sự kiện realtime rt:friend) nên số đếm và vị trí thẻ luôn đúng.
--%>
<c:set var="pageTitle"       value="Bạn bè" />
<c:set var="pageDescription" value="Quản lý lời mời, khám phá gợi ý và xem danh sách bạn bè của bạn trên UTErSpace." />
<c:set var="extraCss"        value="friends.css" />
<c:set var="currentPage"     value="friends" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>

<c:set var="ctx" value="${pageContext.request.contextPath}" />

<div class="app-shell">
  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">
    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section" id="friends-app" data-active-tab="${activeTab}">
      <header class="page-head">
        <hgroup>
          <h1><svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg> Bạn bè</h1>
          <p>Kết nối và quản lý bạn bè trong cộng đồng UTErSpace · cập nhật tức thì khi có lời mời mới</p>
        </hgroup>
        <p class="page-head-actions">
          <a class="btn-pill btn-pill--ghost" href="${ctx}/settings?tab=privacy">
            <svg class="icon" aria-hidden="true"><use href="#i-cog"></use></svg> Quyền riêng tư
          </a>
        </p>
      </header>

      <ul class="pill-tabs" role="tablist" aria-label="Danh mục bạn bè">
        <li><button type="button" class="pill-tab" role="tab" data-tab="requests" aria-selected="${activeTab == 'requests'}" aria-controls="panel-requests">
          <svg class="icon" aria-hidden="true"><use href="#i-user-plus"></use></svg> Lời mời
          <span class="pill-count ${fn:length(requests) > 0 ? 'pill-count--hot' : ''}">${fn:length(requests)}</span></button></li>
        <li><button type="button" class="pill-tab" role="tab" data-tab="sent" aria-selected="${activeTab == 'sent'}" aria-controls="panel-sent">
          <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg> Đã gửi
          <span class="pill-count">${fn:length(sentList)}</span></button></li>
        <li><button type="button" class="pill-tab" role="tab" data-tab="suggestions" aria-selected="${activeTab == 'suggestions'}" aria-controls="panel-suggestions">
          <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg> Gợi ý
          <span class="pill-count">${fn:length(suggestions)}</span></button></li>
        <li><button type="button" class="pill-tab" role="tab" data-tab="friends" aria-selected="${activeTab == 'friends'}" aria-controls="panel-friends">
          <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg> Bạn bè
          <span class="pill-count">${fn:length(friendCards)}</span></button></li>
      </ul>

      <%-- ---------- Lời mời nhận được ---------- --%>
      <section id="panel-requests" role="tabpanel" ${activeTab == 'requests' ? '' : 'hidden'}>
        <c:choose>
          <c:when test="${empty requests}">
            <p class="state-empty"><svg class="icon" aria-hidden="true"><use href="#i-user-plus"></use></svg>
              <strong>Không có lời mời nào</strong>Khi ai đó gửi lời mời kết bạn, lời mời sẽ hiện ở đây ngay lập tức.</p>
          </c:when>
          <c:otherwise>
            <ul class="card-grid person-grid">
              <c:set var="cardKind" value="requests" />
              <c:forEach var="p" items="${requests}"><%@ include file="person-card.jsp" %></c:forEach>
            </ul>
          </c:otherwise>
        </c:choose>
      </section>

      <%-- ---------- Lời mời đã gửi ---------- --%>
      <section id="panel-sent" role="tabpanel" ${activeTab == 'sent' ? '' : 'hidden'}>
        <c:choose>
          <c:when test="${empty sentList}">
            <p class="state-empty"><svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg>
              <strong>Bạn chưa gửi lời mời nào</strong>Xem tab Gợi ý để tìm người quen.</p>
          </c:when>
          <c:otherwise>
            <ul class="card-grid person-grid">
              <c:set var="cardKind" value="sent" />
              <c:forEach var="p" items="${sentList}"><%@ include file="person-card.jsp" %></c:forEach>
            </ul>
          </c:otherwise>
        </c:choose>
      </section>

      <%-- ---------- Gợi ý ---------- --%>
      <section id="panel-suggestions" role="tabpanel" ${activeTab == 'suggestions' ? '' : 'hidden'}>
        <p class="panel-note">Gợi ý dựa trên <b>bạn chung</b> và <b>khu vực</b> — không gồm người đã chặn hoặc đặt "không nhận lời mời".</p>
        <c:choose>
          <c:when test="${empty suggestions}">
            <p class="state-empty"><svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg>
              <strong>Chưa có gợi ý mới</strong>Hãy quay lại sau nhé.</p>
          </c:when>
          <c:otherwise>
            <ul class="card-grid person-grid">
              <c:set var="cardKind" value="suggestions" />
              <c:forEach var="p" items="${suggestions}"><%@ include file="person-card.jsp" %></c:forEach>
            </ul>
          </c:otherwise>
        </c:choose>
      </section>

      <%-- ---------- Bạn bè: tìm kiếm + lọc + sắp xếp (phía trình duyệt) ---------- --%>
      <section id="panel-friends" role="tabpanel" ${activeTab == 'friends' ? '' : 'hidden'}>
        <div class="friends-toolbar">
          <label class="inline-search friends-search">
            <span class="u-visually-hidden">Tìm trong danh sách bạn bè</span>
            <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
            <input type="search" id="friend-filter" placeholder="Tìm bạn bè (không cần dấu)..." autocomplete="off">
          </label>
          <div class="chip-group" role="group" aria-label="Lọc bạn bè">
            <button type="button" class="filter-chip is-active" data-filter="all">Tất cả <b>${fn:length(friendCards)}</b></button>
            <button type="button" class="filter-chip" data-filter="online"><span class="chip-dot"></span> Đang hoạt động <b id="online-count">${onlineCount}</b></button>
            <button type="button" class="filter-chip" data-filter="recent">Mới kết bạn</button>
          </div>
          <label class="sort-select">
            <span class="u-visually-hidden">Sắp xếp</span>
            <select id="friend-sort">
              <option value="name">Tên A → Z</option>
              <option value="recent">Mới kết bạn nhất</option>
              <option value="online">Đang hoạt động trước</option>
            </select>
          </label>
        </div>
        <c:choose>
          <c:when test="${empty friendCards}">
            <p class="state-empty"><svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg>
              <strong>Bạn chưa có bạn bè nào</strong>Bắt đầu từ tab Gợi ý hoặc thanh tìm kiếm phía trên.</p>
          </c:when>
          <c:otherwise>
            <ul class="card-grid person-grid" id="friends-grid">
              <c:set var="cardKind" value="friends" />
              <c:forEach var="p" items="${friendCards}"><%@ include file="person-card.jsp" %></c:forEach>
            </ul>
            <p class="state-empty" id="friends-no-match" hidden><svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
              <strong>Không có bạn bè phù hợp</strong>Thử từ khóa hoặc bộ lọc khác.</p>
          </c:otherwise>
        </c:choose>
      </section>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>

<script>
(function () {
  var CTX = '${ctx}';
  var state = { filter: 'all', sort: 'name', q: '' };

  function fold(s) {
    return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase();
  }

  /* ---------- Tab (không tải lại trang; ghi ?tab= lên URL để F5 / chia sẻ link mở đúng tab) ---------- */
  function showTab(tab) {
    var app = document.getElementById('friends-app');
    app.setAttribute('data-active-tab', tab);
    app.querySelectorAll('.pill-tab[data-tab]').forEach(function (b) {
      b.setAttribute('aria-selected', String(b.getAttribute('data-tab') === tab));
    });
    ['requests', 'sent', 'suggestions', 'friends'].forEach(function (t) {
      document.getElementById('panel-' + t).hidden = t !== tab;
    });
    history.replaceState(null, '', CTX + '/friends?tab=' + tab);
  }

  /* ---------- Tìm kiếm / lọc / sắp xếp danh sách bạn bè ---------- */
  function applyFriendFilters() {
    var grid = document.getElementById('friends-grid');
    if (!grid) return;
    var cards = Array.prototype.slice.call(grid.children), shown = 0, q = fold(state.q.trim());
    cards.forEach(function (c) {
      var ok = (!q || fold(c.getAttribute('data-name')).indexOf(q) >= 0)
            && (state.filter !== 'online' || c.getAttribute('data-online') === 'true')
            && (state.filter !== 'recent' || c.getAttribute('data-recent') === 'true');
      c.hidden = !ok;
      if (ok) shown++;
    });
    cards.sort(function (a, b) {
      if (state.sort === 'recent') return Number(b.getAttribute('data-since')) - Number(a.getAttribute('data-since'));
      if (state.sort === 'online') {
        var d = (b.getAttribute('data-online') === 'true') - (a.getAttribute('data-online') === 'true');
        if (d) return d;
      }
      return fold(a.getAttribute('data-name')).localeCompare(fold(b.getAttribute('data-name')));
    }).forEach(function (c) { grid.appendChild(c); });
    var none = document.getElementById('friends-no-match');
    if (none) none.hidden = shown > 0;
  }

  function bind() {
    document.querySelectorAll('#friends-app .pill-tab[data-tab]').forEach(function (b) {
      b.addEventListener('click', function () { showTab(b.getAttribute('data-tab')); });
    });
    var input = document.getElementById('friend-filter');
    if (input) { input.value = state.q; input.addEventListener('input', function () { state.q = input.value; applyFriendFilters(); }); }
    document.querySelectorAll('#friends-app .filter-chip').forEach(function (c) {
      c.classList.toggle('is-active', c.getAttribute('data-filter') === state.filter);
      c.addEventListener('click', function () {
        state.filter = c.getAttribute('data-filter');
        document.querySelectorAll('#friends-app .filter-chip').forEach(function (x) { x.classList.toggle('is-active', x === c); });
        applyFriendFilters();
      });
    });
    var sort = document.getElementById('friend-sort');
    if (sort) { sort.value = state.sort; sort.addEventListener('change', function () { state.sort = sort.value; applyFriendFilters(); }); }
    applyFriendFilters();
  }

  /* ---------- Tự làm mới khi quan hệ thay đổi (giữ tab, từ khóa, bộ lọc đang chọn) ---------- */
  var refreshTimer = null;
  function refresh() {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(function () {
      var tab = document.getElementById('friends-app').getAttribute('data-active-tab');
      fetch(CTX + '/friends?tab=' + tab, { headers: { 'Accept': 'text/html' } })
        .then(function (r) { return r.text(); })
        .then(function (html) {
          var fresh = new DOMParser().parseFromString(html, 'text/html').getElementById('friends-app');
          if (!fresh) return;
          var app = document.getElementById('friends-app');
          app.replaceWith(fresh);
          showTab(tab);
          window.UTRelation.renderAll(fresh);
          bind();
        });
    }, 700);   // chờ toast / hiệu ứng nút xong rồi mới thay danh sách
  }
  document.addEventListener('relation:changed', refresh);
  document.addEventListener('rt:resync', refresh);
  document.addEventListener('rt:presence', function (e) {
    document.querySelectorAll('[data-person="' + e.detail.userId + '"]').forEach(function (c) {
      c.setAttribute('data-online', String(!!e.detail.online));
    });
    var n = document.querySelectorAll('#friends-grid [data-online="true"]').length;
    var oc = document.getElementById('online-count');
    if (oc) oc.textContent = n;
    if (state.filter === 'online' || state.sort === 'online') applyFriendFilters();
  });

  bind();
})();
</script>

<%@ include file="../common/footer.jsp" %>
