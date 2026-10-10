<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- admin/dashboard.jsp — Bảng điều khiển: lời chào + việc cần làm, 4 chỉ số chính, biểu đồ 7 ngày,
     tình trạng cộng đồng, dòng thời gian hoạt động (AdminController.dashboard) --%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<jsp:include page="layout.jsp" />

<section class="welcome" aria-label="Lời chào">
  <div class="welcome-text">
    <span class="welcome-date"><svg class="icon" aria-hidden="true"><use href="#i-calendar"></use></svg> ${todayLabel}</span>
    <h1>Xin chào, <c:out value="${me.firstName}"/></h1>
    <p><c:choose>
      <c:when test="${reportCount == 0}">Cộng đồng đang yên ổn — không có báo cáo nào chờ xử lý. Dưới đây là tình hình 7 ngày qua.</c:when>
      <c:otherwise>Có <b>${reportCount}</b> báo cáo về <b>${pendingReportCount}</b> đối tượng đang chờ bạn xem xét.</c:otherwise>
    </c:choose></p>
  </div>
  <c:choose>
    <c:when test="${reportCount == 0}"><a class="welcome-cta is-calm" href="${ctx}/admin/logs"><span class="dot" aria-hidden="true"></span> Xem nhật ký quản trị</a></c:when>
    <c:otherwise><a class="welcome-cta" href="${ctx}/admin/reports"><span class="dot" aria-hidden="true"></span> Xử lý báo cáo ngay</a></c:otherwise>
  </c:choose>
</section>

<section class="stat-grid" aria-label="Chỉ số chính">
  <a class="stat-card" href="${ctx}/admin/users">
    <div class="stat-top"><span class="stat-label">Người dùng</span>
      <span class="stat-ico" aria-hidden="true"><svg class="icon"><use href="#i-users"></use></svg></span></div>
    <div class="stat-num">${userCount}</div>
    <div class="stat-foot"><span class="delta ${newUsers7 == 0 ? 'flat' : ''}">+${newUsers7}</span> trong 7 ngày qua</div>
  </a>
  <a class="stat-card" href="${ctx}/admin/posts?filter=all">
    <div class="stat-top"><span class="stat-label">Bài viết</span>
      <span class="stat-ico green" aria-hidden="true"><svg class="icon"><use href="#i-document"></use></svg></span></div>
    <div class="stat-num">${postCount}</div>
    <div class="stat-foot"><span class="delta ${newPosts7 == 0 ? 'flat' : ''}">+${newPosts7}</span> trong 7 ngày qua</div>
  </a>
  <a class="stat-card" href="${ctx}/admin/reports">
    <div class="stat-top"><span class="stat-label">Báo cáo chờ xử lý</span>
      <span class="stat-ico ${reportCount == 0 ? 'green' : 'red'}" aria-hidden="true"><svg class="icon"><use href="#i-flag"></use></svg></span></div>
    <div class="stat-num">${reportCount}</div>
    <div class="stat-foot"><c:choose>
      <c:when test="${reportCount == 0}"><span class="delta">Ổn định</span> không có vi phạm mới</c:when>
      <c:otherwise><span class="delta bad">${pendingReportCount} đối tượng</span> cần xem xét</c:otherwise>
    </c:choose></div>
  </a>
  <a class="stat-card" href="${ctx}/admin/groups">
    <div class="stat-top"><span class="stat-label">Nhóm hoạt động</span>
      <span class="stat-ico amber" aria-hidden="true"><svg class="icon"><use href="#i-user-group"></use></svg></span></div>
    <div class="stat-num">${groupCount}</div>
    <div class="stat-foot">Quản lý và giải tán nhóm vi phạm</div>
  </a>
</section>

<div class="dash-grid">
  <section class="panel" aria-labelledby="chart-title">
    <div class="panel-head">
      <div><h2 id="chart-title">Tăng trưởng 7 ngày qua</h2><p class="sub">Tài khoản đăng ký và bài viết mới mỗi ngày</p></div>
      <div class="chart-legend">
        <span><i style="background:var(--series-1)"></i>Tài khoản mới <b>${newUsers7}</b></span>
        <span><i style="background:var(--series-2)"></i>Bài viết mới <b>${newPosts7}</b></span>
      </div>
    </div>
    <div class="panel-body">
      <div class="chart">
        <div class="chart-y" aria-hidden="true">
          <c:forEach var="t" items="${chartTicks}" varStatus="st"><span style="bottom:${(4 - st.index) * 25}%">${t}</span></c:forEach>
        </div>
        <div class="chart-plot">
          <c:forEach begin="0" end="4" var="g"><span class="chart-grid ${g == 0 ? 'base' : ''}" style="bottom:${g * 25}%" aria-hidden="true"></span></c:forEach>
          <div class="chart-cols" role="list" aria-label="Số tài khoản mới và bài viết mới theo ngày">
            <c:forEach var="d" items="${chartDays}">
              <div class="chart-col" role="listitem" tabindex="0" aria-label="${d.weekday}: ${d.users} tài khoản mới, ${d.posts} bài viết mới">
                <span class="chart-bar s1" style="height:${d.usersPct}%"></span>
                <span class="chart-bar s2" style="height:${d.postsPct}%"></span>
                <span class="chart-tip" aria-hidden="true"><b>${d.weekday}</b>
                  <i style="background:var(--series-1)"></i>Tài khoản mới <em>${d.users}</em><br>
                  <i style="background:var(--series-2)"></i>Bài viết mới <em>${d.posts}</em></span>
              </div>
            </c:forEach>
          </div>
        </div>
      </div>
      <div class="chart-x" aria-hidden="true">
        <c:forEach var="d" items="${chartDays}" varStatus="st"><span class="${st.last ? 'today' : ''}">${d.label}</span></c:forEach>
      </div>
      <details class="chart-table">
        <summary>Xem bảng số liệu</summary>
        <table>
          <thead><tr><th scope="col">Ngày</th><th scope="col">Tài khoản mới</th><th scope="col">Bài viết mới</th></tr></thead>
          <tbody><c:forEach var="d" items="${chartDays}"><tr><td>${d.weekday}</td><td>${d.users}</td><td>${d.posts}</td></tr></c:forEach></tbody>
        </table>
      </details>
    </div>
  </section>

  <section class="panel" aria-labelledby="health-title">
    <div class="panel-head"><div><h2 id="health-title">Tình trạng cộng đồng</h2><p class="sub">Các chỉ số cần theo dõi</p></div></div>
    <ul class="health">
      <li><a href="${ctx}/admin/users?status=locked">
        <span class="h-ico red" aria-hidden="true"><svg class="icon"><use href="#i-lock"></use></svg></span>
        <span class="h-text"><b>Tài khoản bị khóa</b><small>Đang bị chặn đăng nhập</small></span>
        <span class="h-num">${lockedCount}</span><svg class="icon chev" aria-hidden="true"><use href="#i-chevron-right"></use></svg></a></li>
      <li><a href="${ctx}/admin/posts?filter=hidden">
        <span class="h-ico amber" aria-hidden="true"><svg class="icon"><use href="#i-eye-slash"></use></svg></span>
        <span class="h-text"><b>Bài viết đang bị ẩn</b><small>Có thể khôi phục nếu xử lý nhầm</small></span>
        <span class="h-num">${hiddenPostCount}</span><svg class="icon chev" aria-hidden="true"><use href="#i-chevron-right"></use></svg></a></li>
      <li><a href="${ctx}/admin/posts?filter=negative">
        <span class="h-ico" aria-hidden="true"><svg class="icon"><use href="#i-frown"></use></svg></span>
        <span class="h-text"><b>Bài viết tiêu cực</b><small>Phát hiện bởi phân tích cảm xúc</small></span>
        <svg class="icon chev" aria-hidden="true"><use href="#i-chevron-right"></use></svg></a></li>
      <li><div>
        <span class="h-ico blue" aria-hidden="true"><svg class="icon"><use href="#i-id-card"></use></svg></span>
        <span class="h-text"><b>Tài khoản dùng danh tính số</b><small>Đã liên kết DID — đăng nhập không mật khẩu</small></span>
        <span class="h-num">${didCount}</span></div></li>
      <li><a href="${ctx}/admin/users?status=admin">
        <span class="h-ico green" aria-hidden="true"><svg class="icon"><use href="#i-shield"></use></svg></span>
        <span class="h-text"><b>Đội ngũ quản trị</b><small>Xem danh sách quản trị viên</small></span>
        <svg class="icon chev" aria-hidden="true"><use href="#i-chevron-right"></use></svg></a></li>
    </ul>
  </section>
</div>

<section class="panel" aria-labelledby="act-title">
  <div class="panel-head">
    <div><h2 id="act-title">Hoạt động gần đây</h2><p class="sub">Đăng ký mới, báo cáo và thao tác của quản trị viên</p></div>
    <a class="panel-link" href="${ctx}/admin/logs">Toàn bộ nhật ký <svg class="icon" aria-hidden="true"><use href="#i-chevron-right"></use></svg></a>
  </div>
  <c:choose>
    <c:when test="${empty activities}">
      <div class="panel-body muted">Chưa có hoạt động nào.</div>
    </c:when>
    <c:otherwise>
      <ol class="timeline">
        <c:forEach var="a" items="${activities}">
          <c:set var="row">
            <span class="tl-ico ${a.tone}" aria-hidden="true"><svg class="icon"><use href="#i-${a.icon}"></use></svg></span>
            <span class="tl-text"><b><c:out value="${a.actor}"/></b> <c:out value="${a.text}"/></span>
            <span class="tl-time">${a.timeAgo}</span>
          </c:set>
          <li><c:choose>
            <c:when test="${not empty a.url}"><a class="tl-row" href="<c:out value='${ctx}${a.url}'/>">${row}</a></c:when>
            <c:otherwise><div class="tl-row">${row}</div></c:otherwise>
          </c:choose></li>
        </c:forEach>
      </ol>
    </c:otherwise>
  </c:choose>
</section>

<jsp:include page="layout-end.jsp" />
</body>
</html>
