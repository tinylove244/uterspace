<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- admin/groups.jsp — Quản lý nhóm: tìm, giải tán nhóm vi phạm (AdminController.groups) --%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<jsp:include page="layout.jsp" />

<div class="adm-head">
  <div>
    <h1>Quản lý Nhóm</h1>
    <p class="sub">Danh sách mọi nhóm — giải tán nhóm vi phạm tiêu chuẩn cộng đồng</p>
  </div>
  <span class="count-pill ok" id="group-total" data-n="${total}">${total} nhóm</span>
</div>

<form class="toolbar" method="get" action="${ctx}/admin/groups" role="search">
  <label class="search-box"><span class="u-sr">Tìm nhóm theo tên hoặc mô tả</span>
    <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
    <input type="search" name="q" value="<c:out value='${q}'/>" placeholder="Tìm theo tên hoặc mô tả nhóm..." autocomplete="off">
  </label>
  <c:if test="${not empty q}"><a class="chip-clear" href="${ctx}/admin/groups"><svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>Bỏ tìm kiếm</a></c:if>
</form>

<c:choose>
  <c:when test="${empty groups}">
    <div class="empty"><div class="empty-ico" aria-hidden="true"><svg class="icon"><use href="#i-user-group"></use></svg></div><h2>Không có nhóm nào</h2><p>${empty q ? 'Chưa có nhóm nào được tạo.' : 'Thử từ khóa khác.'}</p></div>
  </c:when>
  <c:otherwise>
    <div class="table-wrap">
      <table class="adm-table" id="group-table">
        <thead><tr><th scope="col">Nhóm</th><th scope="col">Loại</th><th scope="col">Chủ nhóm</th><th scope="col">Thành viên</th><th scope="col">Ngày tạo</th><th scope="col">Hành động</th></tr></thead>
        <tbody>
        <c:forEach var="g" items="${groups}">
          <tr data-id="${g.groupId}" data-name="<c:out value='${g.name}'/>" data-members="${g.memberCount}">
            <td>
              <div class="user-cell">
                <span class="avatar avatar--lg avatar--square" aria-hidden="true"><c:choose>
                  <c:when test="${not empty g.coverImage}"><img src="${ctx}${g.coverUrl}" alt="" loading="lazy"></c:when>
                  <c:otherwise><c:out value="${g.iconDisplay}"/></c:otherwise>
                </c:choose></span>
                <div style="min-width:0">
                  <a class="name" href="<c:url value='/admin/groups'><c:param name='q' value='${g.name}'/></c:url>" title="Xem trong Quản lý nhóm"><c:out value="${g.name}"/></a>
                  <div class="email"><c:out value="${empty g.description ? 'Chưa có mô tả' : g.description}"/></div>
                </div>
              </div>
            </td>
            <td class="nowrap"><span class="tag violet"><c:out value="${g.categoryLabel}"/></span>
              <span class="tag ${g.privateGroup ? 'warn' : 'muted'}"><svg class="icon" aria-hidden="true"><use href="#i-${g.privateGroup ? 'lock' : 'globe'}"></use></svg><c:out value="${g.privacyLabel}"/></span></td>
            <td><c:choose>
              <c:when test="${not empty g.owner}"><a href="<c:url value='/admin/users'><c:param name='q' value='${g.owner.email}'/></c:url>" title="Xem trong Quản lý người dùng"><c:out value="${g.owner.fullName}"/></a></c:when>
              <c:otherwise><span class="muted">—</span></c:otherwise>
            </c:choose></td>
            <td>${g.memberCount}</td>
            <td class="nowrap muted">${g.formattedCreatedAt}</td>
            <td><button type="button" class="btn-sm btn-lock" data-act="delete"><svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg>Giải tán</button></td>
          </tr>
        </c:forEach>
        </tbody>
      </table>
    </div>
    <c:url var="pagerBase" value="/admin/groups"><c:param name="q" value="${q}"/></c:url>
    <c:set var="pagerBase" value="${pagerBase}" scope="request" />
    <jsp:include page="pager.jsp" />
  </c:otherwise>
</c:choose>

<jsp:include page="layout-end.jsp" />
<script>
(function () {
  var table = document.getElementById('group-table');
  if (!table) return;
  table.addEventListener('click', function (e) {
    var btn = e.target.closest('button[data-act="delete"]');
    if (!btn) return;
    var row = btn.closest('tr');
    var name = row.getAttribute('data-name'), members = row.getAttribute('data-members');
    Admin.ask({
      title: 'Giải tán nhóm "' + name + '"?',
      text: 'Nhóm cùng toàn bộ bài viết, bình luận trong nhóm sẽ bị xóa VĨNH VIỄN và không thể khôi phục. ' + members + ' thành viên sẽ nhận thông báo kèm lý do.',
      reasonLabel: 'Lý do giải tán', reasonRequired: true, placeholder: 'VD: Nhóm chuyên đăng nội dung quảng cáo',
      quick: ['Spam / quảng cáo', 'Nội dung vi phạm', 'Mạo danh tổ chức', 'Nhóm lừa đảo'],
      confirmLabel: 'Giải tán nhóm', icon: 'trash'
    }).then(function (reason) {
      if (reason === null) return;
      row.classList.add('is-busy');
      Admin.post('/admin/groups/delete', { groupId: row.getAttribute('data-id'), reason: reason })
        .then(function (j) {
          Admin.toast(j.message);
          row.remove();
          var pill = document.getElementById('group-total'), n = Math.max(0, +pill.getAttribute('data-n') - 1);
          pill.setAttribute('data-n', n);
          pill.textContent = n + ' nhóm';
          if (!table.querySelector('tbody tr')) location.reload();
        })
        .catch(function (err) { row.classList.remove('is-busy'); Admin.toast(err.message, true); });
    });
  });
})();
</script>
</body>
</html>
