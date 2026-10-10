<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>

<c:set var="pageTitle"       value="Nhóm" />
<c:set var="pageDescription" value="Tham gia và khám phá nhóm học tập, câu lạc bộ của sinh viên HCMUTE trên UTErSpace." />
<c:set var="extraCss"        value="groups.css" />
<c:set var="currentPage"     value="groups" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>

<c:set var="ctx" value="${pageContext.request.contextPath}" />

<div class="app-shell">

  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">

    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section">
      <header class="page-head">
        <hgroup>
          <h1><svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg> Nhóm</h1>
          <p>Nhóm học tập, câu lạc bộ và cộng đồng chuyên môn tại HCMUTE</p>
        </hgroup>
        <p class="page-head-actions">
          <button type="button" class="btn-pill" onclick="openModal('group-form-modal')">
            <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Tạo nhóm mới
          </button>
        </p>
      </header>

      <nav aria-label="Bộ lọc nhóm">
        <ul class="pill-tabs">
          <li>
            <a class="pill-tab" href="${ctx}/groups?tab=mine" aria-selected="${activeTab == 'mine'}">
              <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg>
              Nhóm của bạn <span class="pill-count">${fn:length(myGroups)}</span>
            </a>
          </li>
          <li>
            <a class="pill-tab" href="${ctx}/groups?tab=explore" aria-selected="${activeTab == 'explore'}">
              <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg>
              Khám phá <span class="pill-count">${exploreTotal}</span>
            </a>
          </li>
        </ul>
      </nav>

      <c:choose>
        <%-- ================= NHÓM CỦA BẠN ================= --%>
        <c:when test="${activeTab == 'mine'}">
          <c:if test="${not empty pendingGroups}">
            <section class="group-pending" aria-labelledby="pending-title">
              <h2 class="group-subtitle" id="pending-title">Đang chờ duyệt</h2>
              <ul class="group-pending-list">
                <c:forEach var="group" items="${pendingGroups}">
                  <li>
                    <a href="${ctx}/groups/view?id=${group.groupId}"><span aria-hidden="true"><c:out value="${group.iconDisplay}"/></span> <c:out value="${group.name}"/></a>
                    <button type="button" class="btn-pill btn-pill--ghost"
                            onclick="groupAction('leave', ${group.groupId}, null, this)">Hủy yêu cầu</button>
                  </li>
                </c:forEach>
              </ul>
            </section>
          </c:if>

          <c:choose>
            <c:when test="${empty myGroups}">
              <p class="state-empty">
                <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg>
                <strong>Bạn chưa tham gia nhóm nào</strong>
                Khám phá các nhóm học tập và câu lạc bộ đang hoạt động, hoặc tự tạo nhóm của riêng bạn.
                <a class="btn-pill" href="${ctx}/groups?tab=explore">Khám phá nhóm</a>
              </p>
            </c:when>
            <c:otherwise>
              <ul class="card-grid card-grid--wide">
                <c:forEach var="group" items="${myGroups}">
                  <li><%@ include file="group-card.jsp" %></li>
                </c:forEach>
              </ul>
            </c:otherwise>
          </c:choose>
        </c:when>

        <%-- ================= KHÁM PHÁ ================= --%>
        <c:otherwise>
          <form class="inline-search" role="search" action="${ctx}/groups" method="get">
            <input type="hidden" name="tab" value="explore">
            <label class="u-visually-hidden" for="group-search">Tìm nhóm</label>
            <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
            <input type="search" id="group-search" name="q" value="<c:out value='${groupQuery}'/>"
                   placeholder="Tìm nhóm theo tên hoặc mô tả..." autocomplete="off">
          </form>

          <c:choose>
            <c:when test="${empty exploreGroups}">
              <p class="state-empty">
                <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
                <c:choose>
                  <c:when test="${not empty groupQuery}">
                    <strong>Không tìm thấy nhóm phù hợp</strong>
                    Thử từ khóa khác, hoặc tạo một nhóm mới.
                  </c:when>
                  <c:otherwise>
                    <strong>Không còn nhóm nào để gợi ý</strong>
                    Bạn đã tham gia tất cả các nhóm hiện có.
                  </c:otherwise>
                </c:choose>
              </p>
            </c:when>
            <c:otherwise>
              <ul class="card-grid card-grid--wide">
                <c:forEach var="group" items="${exploreGroups}">
                  <li><%@ include file="group-card.jsp" %></li>
                </c:forEach>
              </ul>

              <c:if test="${explorePages > 1}">
                <nav class="pager" aria-label="Phân trang nhóm">
                  <c:url var="prevUrl" value="/groups"><c:param name="tab" value="explore"/><c:param name="q" value="${groupQuery}"/><c:param name="page" value="${explorePage - 1}"/></c:url>
                  <c:url var="nextUrl" value="/groups"><c:param name="tab" value="explore"/><c:param name="q" value="${groupQuery}"/><c:param name="page" value="${explorePage + 1}"/></c:url>
                  <a class="btn-pill btn-pill--ghost" href="${prevUrl}" ${explorePage <= 1 ? 'aria-disabled="true" tabindex="-1"' : ''}>← Trước</a>
                  <span class="pager-info">Trang <b>${explorePage}</b> / ${explorePages}</span>
                  <a class="btn-pill btn-pill--ghost" href="${nextUrl}" ${explorePage >= explorePages ? 'aria-disabled="true" tabindex="-1"' : ''}>Sau →</a>
                </nav>
              </c:if>
            </c:otherwise>
          </c:choose>
        </c:otherwise>
      </c:choose>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>
<%@ include file="group-form-modal.jsp" %>

<script>
/* Bộ lọc dùng thẻ <a> nên chuẩn hoá aria-selected về "true"/"false" */
document.querySelectorAll('.pill-tab[aria-selected]').forEach(function (el) {
  if (el.getAttribute('aria-selected') !== 'true') el.setAttribute('aria-selected', 'false');
});
</script>
<%@ include file="group-actions.jsp" %>

<%@ include file="../common/footer.jsp" %>
