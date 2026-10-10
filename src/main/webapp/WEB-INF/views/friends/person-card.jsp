<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  person-card.jsp — Thẻ một người ở trang Bạn bè. Include TĨNH trong vòng lặp var="p" (PersonCard).
  Yêu cầu: ctx, cardKind = requests | sent | suggestions | friends.
  data-* phục vụ ô tìm kiếm / bộ lọc / sắp xếp phía trình duyệt (friends.jsp).
  Nút trạng thái do relation.js vẽ theo data-status — cùng một component với trang cá nhân, tìm kiếm, thông báo.
--%>
<li class="user-card person-card" data-person="${p.user.userId}" data-kind="${cardKind}"
    data-name="<c:out value='${p.user.fullName}'/>" data-online="${p.online}" data-recent="${p.recent}"
    data-since="${p.sinceEpoch}">
  <a class="person-avatar" href="${ctx}/profile?userId=${p.user.userId}" aria-label="Trang cá nhân của <c:out value='${p.user.fullName}'/>">
    <c:choose>
      <c:when test="${not empty p.user.avatar}">
        <img class="user-card-avatar" src="${ctx}${p.user.avatarUrl}" alt="" width="74" height="74" loading="lazy">
      </c:when>
      <c:otherwise><span class="user-card-initials" aria-hidden="true"><c:out value="${p.user.initials}"/></span></c:otherwise>
    </c:choose>
    <span class="presence-dot ${p.online ? 'is-online' : ''}" data-presence-user="${p.user.userId}" title="<c:out value='${p.presence}'/>"></span>
  </a>
  <h3 class="user-card-name"><a class="user-card-name" href="${ctx}/profile?userId=${p.user.userId}"><c:out value="${p.user.fullName}"/></a></h3>

  <p class="user-card-meta person-meta">
    <c:choose>
      <c:when test="${cardKind == 'requests'}">
        <svg class="icon" aria-hidden="true"><use href="#i-clock"></use></svg> Gửi ${p.timeAgo}
      </c:when>
      <c:when test="${cardKind == 'sent'}">
        <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg> Đã gửi ${p.timeAgo}
      </c:when>
      <c:when test="${cardKind == 'suggestions'}">
        <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg> <c:out value="${p.reason}"/>
      </c:when>
      <c:otherwise>
        <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> Bạn bè từ ${p.sinceLabel}
      </c:otherwise>
    </c:choose>
  </p>
  <p class="person-sub">
    <c:choose>
      <c:when test="${cardKind == 'friends' and p.online}"><span class="presence-label" data-presence-label="${p.user.userId}">Đang hoạt động</span></c:when>
      <c:when test="${cardKind == 'friends' and not empty p.presence}"><span data-presence-label="${p.user.userId}"><c:out value="${p.presence}"/></span></c:when>
      <c:when test="${p.mutualCount > 0 and cardKind != 'suggestions'}">${p.mutualCount} bạn chung</c:when>
      <c:otherwise><c:out value="${not empty p.user.location ? p.user.location : 'Thành viên UTErSpace'}"/></c:otherwise>
    </c:choose>
  </p>

  <div class="user-card-actions person-actions">
    <span class="rel-actions" data-relation-user="${p.user.userId}" data-status="${empty p.status ? 'NONE' : p.status}"
          data-name="<c:out value='${p.user.firstName}'/>" data-variant="card"></span>
    <c:if test="${cardKind == 'friends'}">
      <a class="btn-pill btn-pill--ghost btn-pill--icon" href="${ctx}/chat?with=${p.user.userId}" aria-label="Nhắn tin" title="Nhắn tin">
        <svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg>
      </a>
    </c:if>
  </div>
</li>
