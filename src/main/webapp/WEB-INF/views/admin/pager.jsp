<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%-- admin/pager.jsp — phân trang. Cần: page, totalPages, pagerBase (URL đã kèm bộ lọc, từ <c:url>). --%>
<c:if test="${totalPages > 1}">
  <c:set var="sep" value="${fn:contains(pagerBase, '?') ? '&amp;' : '?'}" />
  <nav class="pager" aria-label="Phân trang">
    <c:if test="${page > 1}"><a href="${pagerBase}${sep}page=${page - 1}" rel="prev">‹ Trước</a></c:if>
    <c:forEach var="i" begin="1" end="${totalPages}">
      <c:choose>
        <c:when test="${i == page}"><span class="cur" aria-current="page">${i}</span></c:when>
        <c:when test="${i == 1 or i == totalPages or (i >= page - 2 and i <= page + 2)}">
          <a href="${pagerBase}${sep}page=${i}">${i}</a>
        </c:when>
        <c:when test="${i == page - 3 or i == page + 3}"><span class="gap" aria-hidden="true">…</span></c:when>
      </c:choose>
    </c:forEach>
    <c:if test="${page < totalPages}"><a href="${pagerBase}${sep}page=${page + 1}" rel="next">Sau ›</a></c:if>
  </nav>
</c:if>
