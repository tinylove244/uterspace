<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- member-avatar.jsp — ảnh + tên một thành viên nhóm. Include TĨNH trong vòng lặp var="m" (GroupMember). --%>
<a class="member-user" href="${ctx}/profile?userId=${m.user.userId}">
  <c:choose>
    <c:when test="${not empty m.user.avatar}">
      <img src="${ctx}${m.user.avatarUrl}" alt="" width="42" height="42" loading="lazy">
    </c:when>
    <c:otherwise>
      <span class="member-initials" aria-hidden="true">${m.user.initials}</span>
    </c:otherwise>
  </c:choose>
  <span class="member-name"><c:out value="${m.user.fullName}"/></span>
</a>
