<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>500 — Lỗi máy chủ · UTErSpace</title>
  <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/global.css?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}">
  <style>
    body { display:flex; align-items:center; justify-content:center; min-height:100vh; flex-direction:column; text-align:center; padding:20px; }
    .error-emoji { font-size:80px; margin-bottom:24px; }
    h1 { font-family:'Fraunces',serif; font-size:32px; margin-bottom:12px; }
    p  { color:var(--ink-soft); font-size:15px; margin-bottom:28px; line-height:1.6; }
  </style>
</head>
<body>
  <div class="error-emoji">⚙️</div>
  <h1>Oops, có lỗi xảy ra!</h1>
  <p>Máy chủ gặp sự cố. Nhóm phát triển đang xem xét.<br>Vui lòng thử lại sau ít phút.</p>
  <a href="${pageContext.request.contextPath}/" class="btn btn-primary">🏠 Về trang chủ</a>
  
  <div style="margin-top: 40px; text-align: left; background: #fff; border: 1px solid red; padding: 15px; width: 80%; max-width: 800px; overflow-x: auto;">
    <h3 style="color: red; margin-top: 0;">🛠 Debug Info (Chỉ hiện khi dev):</h3>
    <pre style="font-size: 12px; color: #333; margin: 0; white-space: pre-wrap;">
Exception: <%= exception %>
<%
    if (exception != null) {
        exception.printStackTrace(new java.io.PrintWriter(out));
    }
%>
    </pre>
  </div>
</body>
</html>
