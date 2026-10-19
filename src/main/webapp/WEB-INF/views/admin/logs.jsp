<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- admin/logs.jsp — Nhật ký quản trị: ai làm gì, với đối tượng nào, lúc nào, từ IP nào (AdminController.logs) --%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<jsp:include page="layout.jsp" />

<div class="adm-head">
  <div>
    <h1>Nhật ký quản trị</h1>
    <p class="sub">Mọi thao tác của quản trị viên đều được ghi lại — không thể sửa hay xóa</p>
  </div>
  <span class="count-pill ok">${total} bản ghi</span>
</div>

<form class="toolbar" method="get" action="${ctx}/admin/logs">
  <label class="u-sr" for="log-action">Lọc theo thao tác</label>
  <select class="field" id="log-action" name="action" style="max-width:260px" onchange="this.form.submit()">
    <option value="">Tất cả thao tác</option>
    <c:forEach var="a" items="${actions}">
      <option value="${a.key}" ${a.key == action ? 'selected' : ''}><c:out value="${a.value}"/></option>
    </c:forEach>
  </select>
  <noscript><button class="btn btn-soft" type="submit">Lọc</button></noscript>
</form>

<c:choose>
  <c:when test="${empty logs}">
    <div class="empty"><div class="empty-ico" aria-hidden="true"><svg class="icon"><use href="#i-clipboard"></use></svg></div><h2>Chưa có bản ghi nào</h2><p>Các thao tác khóa, ẩn, xóa, bỏ qua báo cáo… sẽ hiện ở đây.</p></div>
  </c:when>
  <c:otherwise>
    <div class="table-wrap">
      <table class="adm-table">
        <thead><tr><th scope="col">Thời gian</th><th scope="col">Quản trị viên</th><th scope="col">Thao tác</th><th scope="col">Đối tượng</th><th scope="col">Chi tiết</th><th scope="col">IP</th></tr></thead>
        <tbody>
        <c:forEach var="l" items="${logs}">
          <tr>
            <td class="nowrap"><span title="${l.formattedCreatedAt}" style="font-weight:500">${l.timeAgo}</span><div class="muted" style="font-size:12px">${l.formattedCreatedAt}</div></td>
            <td class="nowrap"><div class="user-cell"><span class="avatar avatar--sm"><c:out value="${l.admin.initials}"/></span><c:out value="${l.admin.fullName}"/></div></td>
            <td class="nowrap"><span class="tag ${l.actionTone == 'ok' ? 'ok' : 'danger'}"><svg class="icon" aria-hidden="true"><use href="#i-${l.actionIcon}"></use></svg><c:out value="${l.actionLabel}"/></span></td>
            <td class="nowrap"><c:choose>
              <c:when test="${l.targetType == 'USER'}"><c:out value="${l.targetLabel}"/></c:when>
              <c:otherwise><c:out value="${l.targetLabel}"/></c:otherwise>
            </c:choose></td>
            <td style="max-width:360px; overflow-wrap:anywhere"><c:out value="${empty l.detail ? '—' : l.detail}"/></td>
            <td class="nowrap muted"><code><c:out value="${empty l.ipAddress ? '—' : l.ipAddress}"/></code></td>
          </tr>
        </c:forEach>
        </tbody>
      </table>
    </div>
    <c:url var="pagerBase" value="/admin/logs"><c:param name="action" value="${action}"/></c:url>
    <c:set var="pagerBase" value="${pagerBase}" scope="request" />
    <jsp:include page="pager.jsp" />
  </c:otherwise>
</c:choose>

<jsp:include page="layout-end.jsp" />
</body>
</html>
