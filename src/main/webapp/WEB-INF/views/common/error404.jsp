<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>404 — Không tìm thấy trang · UTErSpace</title>
  <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/global.css?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}">
  <style>
    body { display:flex; align-items:center; justify-content:center; min-height:100vh; flex-direction:column; text-align:center; padding:20px; }
    .error-emoji { font-size:80px; margin-bottom:24px; }
    h1 { font-family:'Fraunces',serif; font-size:32px; margin-bottom:12px; }
    p  { color:var(--ink-soft); font-size:15px; margin-bottom:28px; line-height:1.6; }
    .code-badge { background:var(--bg); border:1px solid var(--line); border-radius:8px; padding:4px 14px; font-size:13px; color:var(--ink-soft); margin-bottom:20px; display:inline-block; }
  </style>
</head>
<body>
  <div class="error-emoji">🔍</div>
  <div class="code-badge">404 Not Found</div>
  <h1>Trang không tồn tại</h1>
  <p>Đường dẫn bạn truy cập không tồn tại hoặc đã bị xóa.<br>Kiểm tra lại URL hoặc quay về trang chủ nhé!</p>
  <a href="${pageContext.request.contextPath}/" class="btn btn-primary">🏠 Về trang chủ</a>
</body>
</html>
