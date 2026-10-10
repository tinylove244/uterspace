<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  notifications.jsp — Trang Thông báo (NotificationController).
  Tab theo NHÓM CHỨC NĂNG (kèm số chưa đọc) · gom theo thời gian · mỗi mục: mở = đánh dấu đã đọc + đi tới nội dung,
  menu (...) đánh dấu đọc / chưa đọc / xóa · lời mời kết bạn có nút Chấp nhận / Từ chối ngay tại chỗ (relation.js).
  Thông báo mới tới qua WebSocket → danh sách tự làm mới (rt:notification).
--%>
<c:set var="pageTitle"       value="Thông báo" />
<c:set var="pageDescription" value="Thông báo về bạn bè, tương tác, nhóm, tin nhắn và bảo mật tài khoản trên UTErSpace." />
<c:set var="extraCss"        value="notifications.css" />
<c:set var="currentPage"     value="notifications" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>
<c:set var="ctx" value="${pageContext.request.contextPath}" />

<div class="app-shell">
  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">
    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section" id="notif-app" data-tab="${currentTab}">
      <header class="page-head">
        <hgroup>
          <h1><svg class="icon" aria-hidden="true"><use href="#i-bell"></use></svg> Thông báo</h1>
          <p>Cập nhật tức thì về bạn bè, tương tác, nhóm, tin nhắn và bảo mật tài khoản</p>
        </hgroup>
        <p class="page-head-actions">
          <button type="button" class="btn-pill btn-pill--ghost" onclick="notifBulk('read-all')" ${tabUnread['all'] > 0 ? '' : 'disabled'}>
            <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> Đánh dấu tất cả đã đọc
          </button>
          <button type="button" class="btn-pill btn-pill--ghost" onclick="notifBulk('delete-read')">
            <svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg> Xóa thông báo đã đọc
          </button>
          <a class="btn-pill btn-pill--ghost btn-pill--icon" href="${ctx}/settings?tab=notifications" title="Cài đặt thông báo" aria-label="Cài đặt thông báo">
            <svg class="icon" aria-hidden="true"><use href="#i-cog"></use></svg>
          </a>
        </p>
      </header>

      <nav aria-label="Phân loại thông báo">
        <ul class="pill-tabs">
          <c:forEach var="t" items="${['all','unread','friend','interaction','group','message','account']}">
            <c:set var="tabLabel" value="${t == 'all' ? 'Tất cả' : t == 'unread' ? 'Chưa đọc' : t == 'friend' ? 'Bạn bè' : t == 'interaction' ? 'Tương tác' : t == 'group' ? 'Nhóm' : t == 'message' ? 'Tin nhắn' : 'Tài khoản'}" />
            <li><a class="pill-tab" href="${ctx}/notifications?tab=${t}" aria-current="${currentTab == t ? 'page' : 'false'}">
              ${tabLabel}<c:if test="${tabUnread[t] > 0}"> <span class="pill-count pill-count--hot">${tabUnread[t]}</span></c:if></a></li>
          </c:forEach>
        </ul>
      </nav>

      <c:choose>
        <c:when test="${empty notifications}">
          <p class="state-empty">
            <svg class="icon" aria-hidden="true"><use href="#i-bell"></use></svg>
            <strong>${currentTab == 'unread' ? 'Bạn đã đọc hết thông báo' : 'Chưa có thông báo nào'}</strong>
            Thông báo mới sẽ hiện ở đây ngay khi có.
          </p>
        </c:when>
        <c:otherwise>
          <c:set var="lastGroup" value="" />
          <c:forEach var="n" items="${notifications}" varStatus="st">
            <c:if test="${n.timeGroup != lastGroup}">
              <c:if test="${not st.first}"></ul></c:if>
              <h2 class="notif-group-title">${n.timeGroup}</h2>
              <ul class="notif-list">
              <c:set var="lastGroup" value="${n.timeGroup}" />
            </c:if>
            <li class="notif-item ${n.read ? '' : 'is-unread'}" id="notif-${n.notificationId}" data-id="${n.notificationId}" data-category="${n.category}">
              <a class="notif-link" href="${ctx}/notifications/open?id=${n.notificationId}">
                <span class="notif-avatar">
                  <c:choose>
                    <c:when test="${n.type == 'ACCOUNT' or n.type == 'SYSTEM'}"><span class="notif-initials notif-initials--system" aria-hidden="true">🔐</span></c:when>
                    <c:when test="${not empty n.actor.avatar}"><img src="${ctx}${n.actor.avatarUrl}" alt="" width="48" height="48" loading="lazy"></c:when>
                    <c:otherwise><span class="notif-initials" aria-hidden="true"><c:out value="${n.actor.initials}"/></span></c:otherwise>
                  </c:choose>
                  <span class="notif-badge-icon" aria-hidden="true">${n.icon}</span>
                </span>
                <span class="notif-body">
                  <span class="notif-text">
                    <c:if test="${n.type != 'ACCOUNT' and n.type != 'SYSTEM'}"><b><c:out value="${n.actor.fullName}"/></b> </c:if><c:out value="${n.content}"/>
                  </span>
                  <span class="notif-time" title="${n.formattedCreatedAt}">${n.timeAgo}</span>
                </span>
                <c:if test="${!n.read}"><span class="notif-dot" aria-label="Chưa đọc"></span></c:if>
              </a>

              <%-- Lời mời kết bạn còn chờ → trả lời ngay tại đây --%>
              <c:if test="${n.type == 'FRIEND_REQUEST'}">
                <c:set var="rk">${n.actor.userId}</c:set>
                <div class="notif-actions">
                  <span class="rel-actions" data-relation-user="${n.actor.userId}" data-status="${relation[rk]}"
                        data-name="<c:out value='${n.actor.firstName}'/>" data-variant="card"></span>
                </div>
              </c:if>

              <div class="notif-more dropdown">
                <button type="button" class="notif-more-btn" aria-label="Tùy chọn thông báo" onclick="toggleNotifMenu(this)">
                  <svg class="icon" aria-hidden="true"><use href="#i-dots"></use></svg>
                </button>
                <div class="dropdown-menu notif-menu">
                  <button type="button" class="dropdown-item" onclick="notifAction('read', ${n.notificationId}, ${!n.read})">
                    <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> ${n.read ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc'}
                  </button>
                  <button type="button" class="dropdown-item danger" onclick="notifAction('delete', ${n.notificationId})">
                    <svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg> Xóa thông báo này
                  </button>
                  <c:if test="${n.category != 'account'}">
                    <a class="dropdown-item" href="${ctx}/settings?tab=notifications#cat-${n.category}">
                      <svg class="icon" aria-hidden="true"><use href="#i-cog"></use></svg> Tắt loại thông báo này
                    </a>
                  </c:if>
                </div>
              </div>
            </li>
            <c:if test="${st.last}"></ul></c:if>
          </c:forEach>

          <c:if test="${hasMore}">
            <p class="notif-more-wrap">
              <a class="btn-pill btn-pill--ghost" href="${ctx}/notifications?tab=${currentTab}&amp;page=${nextPage}">Xem thông báo cũ hơn</a>
            </p>
          </c:if>
        </c:otherwise>
      </c:choose>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>

<script>
var NOTIF_CTX = '${ctx}';

function toggleNotifMenu(btn) {
  var menu = btn.nextElementSibling;
  var open = menu.classList.contains('open');
  document.querySelectorAll('.notif-menu.open').forEach(function (m) { m.classList.remove('open'); });
  if (!open) menu.classList.add('open');
}

function postNotif(path, body) {
  return fetch(NOTIF_CTX + '/notifications/' + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
    body: body || ''
  }).then(function (r) { return r.json().then(function (d) { if (!r.ok) throw new Error(d.error || 'Lỗi'); return d; }); });
}

/** Đánh dấu đọc / chưa đọc hoặc xóa một thông báo — cập nhật ngay tại chỗ, không tải lại */
function notifAction(kind, id, read) {
  var item = document.getElementById('notif-' + id);
  var req = kind === 'delete' ? postNotif('delete', 'id=' + id) : postNotif('read', 'id=' + id + '&read=' + read);
  req.then(function () {
    if (kind === 'delete') {
      item.classList.add('is-removing');
      setTimeout(function () { item.remove(); refreshNotifs(); }, 250);
      showToast('Đã xóa thông báo.', 'success');
    } else {
      refreshNotifs();
    }
  }).catch(function (e) { showToast(e.message, 'error'); });
}

function notifBulk(kind) {
  var ask = kind === 'delete-read' && window.UTConfirm
    ? UTConfirm({ title: 'Xóa thông báo đã đọc?', message: 'Mọi thông báo bạn đã đọc sẽ bị xóa vĩnh viễn.', ok: 'Xóa', danger: true })
    : Promise.resolve(true);
  ask.then(function (yes) {
    if (!yes) return;
    postNotif(kind).then(function () {
      showToast(kind === 'read-all' ? 'Đã đánh dấu tất cả là đã đọc ✓' : 'Đã xóa các thông báo đã đọc.', 'success');
      refreshNotifs();
    }).catch(function (e) { showToast(e.message, 'error'); });
  });
}

/** Tải lại danh sách (giữ tab đang xem) — sau thao tác hoặc khi có thông báo mới qua WebSocket */
var notifTimer = null;
function refreshNotifs() {
  clearTimeout(notifTimer);
  notifTimer = setTimeout(function () {
    fetch(location.pathname + location.search, { headers: { 'Accept': 'text/html' } })
      .then(function (r) { return r.text(); })
      .then(function (html) {
        var fresh = new DOMParser().parseFromString(html, 'text/html').getElementById('notif-app');
        var app = document.getElementById('notif-app');
        if (fresh && app) { app.replaceWith(fresh); window.UTRelation.renderAll(fresh); }
      });
  }, 300);
}
document.addEventListener('rt:notification', refreshNotifs);
document.addEventListener('rt:resync', refreshNotifs);
document.addEventListener('relation:changed', refreshNotifs);
document.addEventListener('click', function (e) {
  if (!e.target.closest('.notif-more')) document.querySelectorAll('.notif-menu.open').forEach(function (m) { m.classList.remove('open'); });
});
</script>

<%@ include file="../common/footer.jsp" %>
