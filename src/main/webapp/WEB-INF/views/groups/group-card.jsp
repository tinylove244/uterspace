<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  group-card.jsp — Thẻ một nhóm ở trang /groups. Include TĨNH trong vòng lặp var="group".
  group.myMembership: null (chưa vào) | ACTIVE | PENDING (chờ duyệt) | BANNED (bị xóa khỏi nhóm)
--%>
<c:set var="gm" value="${group.myMembership}" />
<article class="group-card ${group.categoryClass}" id="gcard-${group.groupId}">
  <a class="group-cover" href="${ctx}/groups/view?id=${group.groupId}" tabindex="-1" aria-hidden="true"
     <c:if test="${not empty group.coverImage}">style="background-image:url('${ctx}${group.coverUrl}')"</c:if>>
    <span class="group-icon"><c:out value="${group.iconDisplay}"/></span>
  </a>
  <div class="group-body">
    <h2 class="group-name"><a href="${ctx}/groups/view?id=${group.groupId}"><c:out value="${group.name}"/></a></h2>
    <p class="group-tags">
      <span class="group-tag">${group.categoryLabel}</span>
      <span class="group-privacy ${group.privateGroup ? 'is-private' : ''}">
        <svg class="icon" aria-hidden="true"><use href="${group.privateGroup ? '#i-lock' : '#i-globe'}"></use></svg>
        ${group.privacyLabel}
      </span>
      <c:if test="${gm.owner}"><span class="group-role">Chủ nhóm</span></c:if>
    </p>
    <c:if test="${not empty group.description}">
      <p class="group-desc"><c:out value="${group.description}"/></p>
    </c:if>
    <p class="group-meta">
      <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg>
      ${group.memberCount} thành viên
      <c:if test="${group.pendingCount > 0}">
        · <a class="group-pending-link" href="${ctx}/groups/view?id=${group.groupId}&amp;tab=members">${group.pendingCount} yêu cầu chờ duyệt</a>
      </c:if>
    </p>
    <c:choose>
      <c:when test="${empty gm}">
        <button type="button" class="btn-pill" onclick="groupAction('join', ${group.groupId}, null, this)">
          <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg>
          ${group.privateGroup ? 'Xin vào nhóm' : 'Tham gia'}
        </button>
      </c:when>
      <c:when test="${gm.pending}">
        <button type="button" class="btn-pill btn-pill--done" onclick="groupAction('leave', ${group.groupId}, null, this)"
                title="Bấm để hủy yêu cầu">
          <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> Đã gửi yêu cầu · Hủy
        </button>
      </c:when>
      <c:when test="${gm.banned}">
        <button type="button" class="btn-pill btn-pill--ghost" disabled>Không thể tham gia</button>
      </c:when>
      <c:otherwise>
        <a class="btn-pill btn-pill--ghost" href="${ctx}/groups/view?id=${group.groupId}">
          <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg> Vào nhóm
        </a>
      </c:otherwise>
    </c:choose>
  </div>
</article>
