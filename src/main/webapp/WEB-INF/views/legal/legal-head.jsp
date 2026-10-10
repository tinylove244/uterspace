<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  legal-head.jsp — Phần đầu dùng chung cho trang Điều khoản / Chính sách bảo mật (trang công khai, không cần đăng nhập).
  Trang gọi đặt sẵn legalTitle trước khi include. Đóng bằng legal-foot.jsp.
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="assetV" value="${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}" />
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><c:out value="${legalTitle}"/> — UTErSpace</title>
  <meta name="description" content="<c:out value="${legalTitle}"/> của mạng xã hội sinh viên UTErSpace.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap">
  <link rel="stylesheet" href="${ctx}/assets/css/global.css?v=${assetV}">
  <link rel="stylesheet" href="${ctx}/assets/css/pages/legal.css?v=${assetV}">
</head>
<body class="legal-page">
  <header class="legal-top">
    <a class="legal-brand" href="${ctx}/">UTEr<span>Space</span></a>
    <nav class="legal-tabs" aria-label="Văn bản pháp lý">
      <a href="${ctx}/terms"   ${legalPage == 'terms'   ? 'aria-current="page"' : ''}>Điều khoản sử dụng</a>
      <a href="${ctx}/privacy" ${legalPage == 'privacy' ? 'aria-current="page"' : ''}>Chính sách bảo mật</a>
    </nav>
    <c:choose>
      <c:when test="${not empty sessionScope.currentUser}"><a class="legal-back" href="${ctx}/feed">← Về Bảng tin</a></c:when>
      <c:otherwise><a class="legal-back" href="${ctx}/login">Đăng nhập</a></c:otherwise>
    </c:choose>
  </header>
  <main class="legal-main" id="main-content">
    <article class="legal-doc">
      <header class="legal-doc-head">
        <h1><c:out value="${legalTitle}"/></h1>
        <p>Cập nhật lần cuối: <time>${legalUpdatedAt}</time> · Áp dụng cho mọi tài khoản UTErSpace</p>
      </header>
