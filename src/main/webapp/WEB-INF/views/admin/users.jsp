<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- admin/users.jsp — Quản lý người dùng: tìm, lọc, khóa / mở khóa (AdminController.users) --%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<jsp:include page="layout.jsp" />

<div class="adm-head">
  <div>
    <h1>Quản lý Người dùng</h1>
    <p class="sub">Xem và quản lý toàn bộ tài khoản trong hệ thống</p>
  </div>
  <span class="count-pill ok">${total} tài khoản</span>
</div>

<form class="toolbar" method="get" action="${ctx}/admin/users" role="search">
  <input type="hidden" name="status" value="${status}">
  <label class="search-box"><span class="u-sr">Tìm theo tên hoặc email</span>
    <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
    <input type="search" name="q" value="<c:out value='${q}'/>" placeholder="Tìm theo tên hoặc email..." autocomplete="off">
  </label>
  <div class="chips" role="group" aria-label="Lọc theo trạng thái">
    <c:forEach var="f" items="all:Tất cả,active:Đang hoạt động,locked:Đã khóa,admin:Quản trị viên" varStatus="st">
      <c:set var="key" value="${f.split(':')[0]}" />
      <c:url var="chipUrl" value="/admin/users"><c:param name="status" value="${key}"/><c:param name="q" value="${q}"/></c:url>
      <a class="chip ${status == key ? 'active' : ''}" href="${chipUrl}" ${status == key ? 'aria-current="true"' : ''}>${f.split(':')[1]}<span class="n">${counts[st.index]}</span></a>
    </c:forEach>
  </div>
</form>

<c:choose>
  <c:when test="${empty users}">
    <div class="empty"><div class="empty-ico" aria-hidden="true"><svg class="icon"><use href="#i-search"></use></svg></div><h2>Không tìm thấy người dùng</h2><p>Thử từ khóa khác hoặc bỏ bộ lọc.</p></div>
  </c:when>
  <c:otherwise>
    <div class="table-wrap">
      <table class="adm-table" id="user-table">
        <thead><tr><th scope="col">Người dùng</th><th scope="col">Vai trò</th><th scope="col">Trạng thái</th><th scope="col">Ngày tham gia</th><th scope="col">Hành động</th></tr></thead>
        <tbody>
        <c:forEach var="u" items="${users}">
          <tr data-id="${u.userId}" data-name="<c:out value='${u.fullName}'/>">
            <td>
              <div class="user-cell">
                <span class="avatar avatar--lg"><c:choose>
                  <c:when test="${not empty u.avatar}"><img src="${ctx}${u.avatarUrl}" alt="" loading="lazy"></c:when>
                  <c:otherwise><c:out value="${u.initials}"/></c:otherwise>
                </c:choose></span>
                <div>
                  <a class="name" href="${ctx}/profile?userId=${u.userId}" target="_blank" rel="noopener"><c:out value="${u.fullName}"/></a><c:if test="${didUsers.contains(u.userId)}"><span class="did-tag" title="Đã liên kết danh tính số (DID)"><svg class="icon" aria-hidden="true"><use href="#i-check-badge"></use></svg><span class="u-sr">Đã liên kết danh tính số</span></span></c:if><c:if test="${u.userId == me.userId}"><span class="you-tag">Bạn</span></c:if>
                  <div class="email"><c:out value="${u.email}"/></div>
                </div>
              </div>
            </td>
            <td><span class="role-badge ${u.admin ? 'admin' : 'user'}"><c:if test="${u.admin}"><svg class="icon" aria-hidden="true"><use href="#i-shield"></use></svg></c:if>${u.admin ? 'Quản trị viên' : 'Thành viên'}</span></td>
            <td class="js-status">
              <c:choose>
                <c:when test="${u.locked}">
                  <span class="status-dot locked">Đã khóa</span>
                  <c:if test="${not empty u.lockedReason}"><span class="lock-reason" title="<c:out value='${u.lockedReason}'/>"><c:out value="${u.lockedReason}"/></span></c:if>
                </c:when>
                <c:otherwise><span class="status-dot active">Hoạt động</span></c:otherwise>
              </c:choose>
            </td>
            <td class="nowrap muted">${u.formattedJoinDate}</td>
            <td class="js-action">
              <c:choose>
                <c:when test="${u.locked}"><button type="button" class="btn-sm btn-unlock" data-act="unlock"><svg class="icon" aria-hidden="true"><use href="#i-lock-open"></use></svg>Mở khóa</button></c:when>
                <c:when test="${u.userId == me.userId}"><span class="muted" title="Bạn không thể tự khóa tài khoản của mình">—</span></c:when>
                <c:when test="${u.admin}"><span class="muted" title="Không thể khóa quản trị viên khác">—</span></c:when>
                <c:otherwise><button type="button" class="btn-sm btn-lock" data-act="lock"><svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>Khóa</button></c:otherwise>
              </c:choose>
            </td>
          </tr>
        </c:forEach>
        </tbody>
      </table>
    </div>
    <c:url var="pagerBase" value="/admin/users"><c:param name="status" value="${status}"/><c:param name="q" value="${q}"/></c:url>
    <c:set var="pagerBase" value="${pagerBase}" scope="request" />
    <jsp:include page="pager.jsp" />
  </c:otherwise>
</c:choose>

<jsp:include page="layout-end.jsp" />
<script>
(function () {
  var table = document.getElementById('user-table');
  if (!table) return;

  function render(row, locked, reason) {
    var st = row.querySelector('.js-status'), act = row.querySelector('.js-action');
    st.textContent = '';
    var dot = document.createElement('span');
    dot.className = 'status-dot ' + (locked ? 'locked' : 'active');
    dot.textContent = locked ? 'Đã khóa' : 'Hoạt động';
    st.appendChild(dot);
    if (locked && reason) {
      var r = document.createElement('span');
      r.className = 'lock-reason';
      r.textContent = reason;
      r.title = reason;
      st.appendChild(r);
    }
    act.textContent = '';
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'btn-sm ' + (locked ? 'btn-unlock' : 'btn-lock');
    b.setAttribute('data-act', locked ? 'unlock' : 'lock');
    b.innerHTML = Admin.icon(locked ? 'lock-open' : 'lock') + (locked ? 'Mở khóa' : 'Khóa');
    act.appendChild(b);
    row.classList.remove('flash'); void row.offsetWidth; row.classList.add('flash');
    b.focus();
  }

  table.addEventListener('click', function (e) {
    var btn = e.target.closest('button[data-act]');
    if (!btn) return;
    var row = btn.closest('tr'), id = row.getAttribute('data-id'), name = row.getAttribute('data-name');
    var lock = btn.getAttribute('data-act') === 'lock';
    Admin.ask(lock ? {
      title: 'Khóa tài khoản ' + name + '?',
      text: 'Người này sẽ bị đăng xuất ngay trên mọi thiết bị và không thể đăng nhập cho tới khi được mở khóa. Lý do sẽ hiện cho họ ở trang đăng nhập.',
      reasonLabel: 'Lý do khóa', reasonRequired: true, placeholder: 'VD: Spam quảng cáo nhiều lần',
      quick: ['Spam / quảng cáo', 'Ngôn từ xúc phạm', 'Quấy rối người khác', 'Mạo danh'],
      confirmLabel: 'Khóa tài khoản', icon: 'lock'
    } : {
      title: 'Mở khóa tài khoản ' + name + '?',
      text: 'Người này có thể đăng nhập và sử dụng UTErSpace bình thường trở lại.',
      confirmLabel: 'Mở khóa', tone: 'ok', icon: 'lock-open'
    }).then(function (reason) {
      if (reason === null) return;
      row.classList.add('is-busy');
      return Admin.post('/admin/users/' + (lock ? 'lock' : 'unlock'), { userId: id, reason: reason })
        .then(function (j) { render(row, lock, reason); Admin.toast(j.message); })
        .catch(function (err) { Admin.toast(err.message, true); })
        .then(function () { row.classList.remove('is-busy'); });
    });
  });
})();
</script>
</body>
</html>
