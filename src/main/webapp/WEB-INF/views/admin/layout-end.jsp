<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%-- admin/layout-end.jsp — đóng khung mở ở layout.jsp và nạp admin.js. Script riêng của trang đặt SAU include này. --%>
  </main>
</div>
<script src="${pageContext.request.contextPath}/assets/js/admin.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
