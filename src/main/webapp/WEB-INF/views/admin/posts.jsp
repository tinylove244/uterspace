<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  admin/posts.jsp — Bài viết bị ẩn / đang bị báo cáo / đã xóa (AdminController.posts).
  ACTIVE → Ẩn / Xóa · HIDDEN → Khôi phục / Xóa · DELETED (xóa mềm, không ai thấy) → Khôi phục.
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<jsp:include page="layout.jsp" />

<div class="adm-head">
  <div>
    <h1>Quản lý bài viết</h1>
    <p class="sub">Bài bị ẩn, đang bị báo cáo, bị đánh dấu tiêu cực hoặc đã xóa — khôi phục nếu xử lý nhầm</p>
  </div>
  <span class="count-pill ok">${total} bài viết</span>
</div>

<form class="toolbar" method="get" action="${ctx}/admin/posts" role="search">
  <input type="hidden" name="filter" value="${filter}">
  <label class="search-box"><span class="u-sr">Tìm theo nội dung, tên hoặc email tác giả</span>
    <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
    <input type="search" name="q" value="<c:out value='${q}'/>" placeholder="Tìm nội dung, tên / email tác giả..." autocomplete="off">
  </label>
  <div class="chips" role="group" aria-label="Lọc bài viết">
    <c:forEach var="f" items="hidden:Bị ẩn,reported:Bị báo cáo,negative:Tiêu cực (AI),deleted:Đã xóa,all:Tất cả" varStatus="st">
      <c:set var="key" value="${f.split(':')[0]}" />
      <c:url var="chipUrl" value="/admin/posts"><c:param name="filter" value="${key}"/><c:param name="q" value="${q}"/></c:url>
      <a class="chip ${filter == key ? 'active' : ''}" href="${chipUrl}" ${filter == key ? 'aria-current="true"' : ''}>${f.split(':')[1]}<span class="n">${counts[st.index]}</span></a>
    </c:forEach>
  </div>
</form>

<c:choose>
  <c:when test="${empty posts}">
    <div class="empty"><div class="empty-ico ${filter == 'hidden' ? 'green' : ''}" aria-hidden="true"><svg class="icon"><use href="#i-${filter == 'hidden' ? 'check-badge' : 'search'}"></use></svg></div>
      <h2>${filter == 'hidden' ? 'Không có bài viết nào đang bị ẩn' : 'Không có bài viết phù hợp'}</h2>
      <p>Thử bộ lọc khác hoặc từ khóa khác.</p></div>
  </c:when>
  <c:otherwise>
    <div class="table-wrap">
      <table class="adm-table" id="post-table">
        <thead><tr><th scope="col">Bài viết</th><th scope="col">Trạng thái</th><th scope="col">Báo cáo chờ</th><th scope="col">Hành động</th></tr></thead>
        <tbody>
        <c:forEach var="p" items="${posts}">
          <tr data-id="${p.postId}" data-status="${p.moderationStatus}">
            <td>
              <div class="user-cell post-cell">
                <c:choose>
                  <c:when test="${not empty p.imagePath and not p.video}"><img class="thumb" src="${ctx}${p.imageUrl}" alt="" loading="lazy"></c:when>
                  <c:when test="${p.video}"><span class="thumb thumb--video" aria-hidden="true"><svg class="icon"><use href="#i-video"></use></svg></span></c:when>
                </c:choose>
                <div style="min-width:0">
                  <div class="excerpt"><c:choose>
                    <c:when test="${not empty p.content}"><c:out value="${p.content}"/></c:when>
                    <c:when test="${p.share}"><span class="muted">[Chia sẻ lại một bài viết]</span></c:when>
                    <c:otherwise><span class="muted">[Không có chữ]</span></c:otherwise>
                  </c:choose></div>
                  <div class="meta">
                    <a href="<c:url value='/admin/users'><c:param name='q' value='${p.author.email}'/></c:url>" title="Xem trong Quản lý người dùng"><c:out value="${p.author.fullName}"/></a>
                    <span>#${p.postId}</span><span>${p.formattedCreatedAt}</span>
                    <c:if test="${p.hiddenByOwner}"><span class="tag muted" title="Chủ bài tự ẩn — chỉ chủ bài đổi được">Chủ bài tự ẩn</span></c:if>
                    <c:if test="${p.negative}"><span class="tag danger" title="Điểm cảm xúc ${p.sentimentScore} — nhận diện bởi ${p.sentimentSource == 'AI' ? 'AI (Gemini / Claude)' : 'từ điển cảm xúc'}"><svg class="icon" aria-hidden="true"><use href="#i-frown"></use></svg>Tiêu cực</span></c:if>
                    <c:if test="${p.positive}"><span class="tag ok">Tích cực</span></c:if>
                  </div>
                </div>
              </div>
            </td>
            <td class="js-status"></td>
            <td>
              <c:set var="rc" value="${reportCounts[p.postId]}" />
              <c:choose>
                <c:when test="${rc > 0}"><a class="tag danger" href="${ctx}/admin/reports"><svg class="icon" aria-hidden="true"><use href="#i-flag"></use></svg>${rc}</a></c:when>
                <c:otherwise><span class="muted">—</span></c:otherwise>
              </c:choose>
            </td>
            <td class="js-action"></td>
          </tr>
        </c:forEach>
        </tbody>
      </table>
    </div>
    <c:url var="pagerBase" value="/admin/posts"><c:param name="filter" value="${filter}"/><c:param name="q" value="${q}"/></c:url>
    <c:set var="pagerBase" value="${pagerBase}" scope="request" />
    <jsp:include page="pager.jsp" />
  </c:otherwise>
</c:choose>

<jsp:include page="layout-end.jsp" />
<script>
(function () {
  var table = document.getElementById('post-table');
  if (!table) return;
  var STATUS = {
    ACTIVE:  ['ok', 'Đang hiển thị'],
    HIDDEN:  ['warn', 'Bị admin ẩn'],
    DELETED: ['danger', 'Đã xóa']
  };
  var ACTIONS = {   // trạng thái → các nút [act, icon, nhãn, lớp]
    ACTIVE:  [['hide', 'eye-slash', 'Ẩn', 'btn-soft'], ['delete', 'trash', 'Xóa', 'btn-lock']],
    HIDDEN:  [['restore', 'arrow-path', 'Khôi phục', 'btn-unlock'], ['delete', 'trash', 'Xóa', 'btn-lock']],
    DELETED: [['restore', 'arrow-path', 'Khôi phục', 'btn-unlock']]
  };

  function render(row) {
    var s = row.getAttribute('data-status'), st = row.querySelector('.js-status'), act = row.querySelector('.js-action');
    var info = STATUS[s] || ['muted', s];
    st.innerHTML = '';
    var tag = document.createElement('span');
    tag.className = 'tag ' + info[0];
    tag.textContent = info[1];
    st.appendChild(tag);
    act.innerHTML = '';
    var wrap = document.createElement('div');
    wrap.className = 'actions';
    (ACTIONS[s] || []).forEach(function (a) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'btn-sm ' + a[3];
      b.setAttribute('data-act', a[0]);
      b.innerHTML = Admin.icon(a[1]) + a[2];
      wrap.appendChild(b);
    });
    act.appendChild(wrap);
  }
  table.querySelectorAll('tbody tr').forEach(render);

  table.addEventListener('click', function (e) {
    var btn = e.target.closest('button[data-act]');
    if (!btn) return;
    var row = btn.closest('tr'), id = row.getAttribute('data-id'), act = btn.getAttribute('data-act');
    var opts = {
      hide:    { title: 'Ẩn bài viết #' + id + '?', text: 'Mọi người (trừ tác giả) sẽ không còn thấy bài này. Tác giả nhận thông báo. Có thể khôi phục.',
                 reasonLabel: 'Lý do (gửi kèm thông báo cho tác giả)', placeholder: 'VD: Nội dung phản cảm',
                 quick: ['Spam / quảng cáo', 'Ngôn từ xúc phạm', 'Thông tin sai lệch', 'Nội dung không phù hợp'], confirmLabel: 'Ẩn bài viết', icon: 'eye-slash' },
      delete:  { title: 'Xóa bài viết #' + id + '?', text: 'Bài bị gỡ khỏi mọi nơi, kể cả trang của tác giả. Vẫn khôi phục được từ bộ lọc "Đã xóa".',
                 reasonLabel: 'Lý do (gửi kèm thông báo cho tác giả)', placeholder: 'VD: Vi phạm nghiêm trọng',
                 quick: ['Spam / quảng cáo', 'Ngôn từ xúc phạm', 'Thông tin sai lệch', 'Nội dung không phù hợp'], confirmLabel: 'Xóa bài viết', icon: 'trash' },
      restore: { title: 'Khôi phục bài viết #' + id + '?', text: 'Bài sẽ hiển thị lại bình thường theo quyền riêng tư tác giả đã chọn.',
                 confirmLabel: 'Khôi phục', tone: 'ok', icon: 'arrow-path' }
    }[act];
    Admin.ask(opts).then(function (reason) {
      if (reason === null) return;
      row.classList.add('is-busy');
      Admin.post('/admin/posts/' + act, { postId: id, reason: reason })
        .then(function (j) {
          row.setAttribute('data-status', j.status);
          render(row);
          Admin.setBadge(j.pending);
          if (j.status !== 'ACTIVE') {   // ẩn / xóa đã đóng các báo cáo đang chờ
            var rc = row.cells[2]; rc.innerHTML = '<span class="muted">—</span>';
          }
          row.classList.remove('flash'); void row.offsetWidth; row.classList.add('flash');
          Admin.toast(j.message);
        })
        .catch(function (err) { Admin.toast(err.message, true); })
        .then(function () { row.classList.remove('is-busy'); });
    });
  });
})();
</script>
</body>
</html>
