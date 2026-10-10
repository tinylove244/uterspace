<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  index.jsp — Entry point của ứng dụng.
  Logic: Nếu đã login (có session currentUser) → redirect /feed
         Nếu chưa login → redirect /login
--%>
<c:choose>
  <c:when test="${not empty sessionScope.currentUser}">
    <c:redirect url="/feed"/>
  </c:when>
  <c:otherwise>
    <c:redirect url="/login"/>
  </c:otherwise>
</c:choose>
