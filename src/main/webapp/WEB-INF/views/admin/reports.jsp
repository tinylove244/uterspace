<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  admin/reports.jsp — Kiểm duyệt nội dung (AdminController.reports).
  Mỗi thẻ = MỘT đối tượng bị báo cáo (gom mọi báo cáo đang chờ về nó).
  Xử lý: bài viết → ẩn (khôi phục được ở "Bài viết ẩn") · bình luận → xóa · tài khoản → khóa. Bỏ qua → đóng báo cáo.
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<jsp:include page="layout.jsp" />

<div class="adm-head">
  <div>
    <h1>Báo cáo vi phạm</h1>
    <p class="sub">Hàng đợi báo cáo vi phạm từ người dùng — xem xét trước khi xử lý</p>
  </div>
  <span class="count-pill ${total == 0 ? 'ok is-good' : ''}" id="pending-pill">${total} đối tượng · ${reportCount} báo cáo đang chờ</span>
</div>

<div id="report-list">
<c:forEach var="g" items="${groups}">
  <c:set var="first" value="${g.reports[0].reporter}" />
  <article class="report-card" data-type="${g.targetType}" data-id="${g.targetId}" aria-labelledby="rc-${g.targetType}-${g.targetId}">
    <div class="report-top">
      <span class="report-type" aria-hidden="true"><svg class="icon"><use href="#i-${g.targetType == 'POST' ? 'document' : g.targetType == 'COMMENT' ? 'comment' : 'user-circle'}"></use></svg></span>
      <span class="reporter" id="rc-${g.targetType}-${g.targetId}"><b><c:out value="${first.fullName}"/></b><c:if test="${g.count > 1}"> và <b>${g.count - 1} người khác</b></c:if>
        đã báo cáo ${g.targetLabel} này · <span class="muted">${g.formattedLatestAt}</span></span>
      <span class="tags">
        <c:forEach var="lbl" items="${g.reasonLabels}"><span class="reason-tag"><c:out value="${lbl}"/></span></c:forEach>
        <c:if test="${g.count > 1}"><span class="count-tag">${g.count} báo cáo</span></c:if>
      </span>
    </div>

    <%-- Nội dung bị báo cáo --%>
    <c:choose>
      <c:when test="${g.targetMissing}">
        <div class="reported-content missing">Đối tượng này không còn tồn tại (đã bị xóa). Bạn có thể đóng các báo cáo.</div>
      </c:when>
      <c:when test="${g.targetType == 'POST'}">
        <div class="reported-content">
          <span class="author">Đăng bởi:
            <a href="${ctx}/profile?userId=${g.post.author.userId}" target="_blank" rel="noopener"><c:out value="${g.post.author.fullName}"/></a>
            <span class="muted">· ${g.post.formattedCreatedAt} · ${g.post.visibilityIcon} ${g.post.visibilityLabel}<c:if test="${not empty g.post.groupId}"> · trong nhóm</c:if></span>
            <c:if test="${g.post.moderationStatus == 'HIDDEN'}"><span class="tag warn"><svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>Đang bị ẩn</span></c:if>
          </span>
          <div class="body"><c:choose><c:when test="${not empty g.post.content}"><c:out value="${g.post.content}"/></c:when><c:when test="${g.post.share}"><span class="muted">[Chia sẻ lại một bài viết, không kèm lời bình]</span></c:when><c:otherwise><span class="muted">[Bài viết không có chữ]</span></c:otherwise></c:choose></div>
          <c:if test="${not empty g.post.imagePath and not g.post.video}"><img class="media" src="${ctx}${g.post.imageUrl}" alt="Ảnh trong bài viết bị báo cáo" loading="lazy"></c:if>
          <c:if test="${g.post.video and not empty g.post.videoUrl}"><video class="media" src="${ctx}${g.post.videoUrl}" controls preload="metadata"></video></c:if>
        </div>
      </c:when>
      <c:when test="${g.targetType == 'COMMENT'}">
        <div class="reported-content">
          <span class="author">Bình luận bởi:
            <a href="${ctx}/profile?userId=${g.comment.author.userId}" target="_blank" rel="noopener"><c:out value="${g.comment.author.fullName}"/></a>
            <span class="muted">· ${g.comment.formattedCreatedAt} · trong bài viết #${g.comment.postId}</span>
          </span>
          <div class="body"><c:out value="${g.comment.content}"/></div>
        </div>
      </c:when>
      <c:otherwise>
        <div class="reported-content">
          <span class="author">
            <span class="avatar avatar--sm"><c:choose>
              <c:when test="${not empty g.user.avatar}"><img src="${ctx}${g.user.avatarUrl}" alt="" loading="lazy"></c:when>
              <c:otherwise><c:out value="${g.user.initials}"/></c:otherwise>
            </c:choose></span>
            <a href="${ctx}/profile?userId=${g.user.userId}" target="_blank" rel="noopener"><c:out value="${g.user.fullName}"/></a>
            <span class="muted">· <c:out value="${g.user.email}"/> · tham gia ${g.user.formattedJoinDate}</span>
            <span class="role-badge ${g.user.admin ? 'admin' : 'user'}">${g.user.admin ? 'ADMIN' : 'USER'}</span>
            <c:if test="${g.user.locked}"><span class="tag danger">Đã khóa</span></c:if>
          </span>
          <div class="body"><c:choose><c:when test="${not empty g.user.bio}"><c:out value="${g.user.bio}"/></c:when><c:otherwise><span class="muted">[Chưa có giới thiệu]</span></c:otherwise></c:choose></div>
        </div>
      </c:otherwise>
    </c:choose>

    <details class="report-details" ${g.count <= 3 ? 'open' : ''}>
      <summary>Chi tiết ${g.count} báo cáo</summary>
      <ul>
        <c:forEach var="r" items="${g.reports}">
          <li>
            <span class="avatar avatar--sm"><c:out value="${r.reporter.initials}"/></span>
            <span><span class="who"><c:out value="${r.reporter.fullName}"/></span>
              <span class="why">· <c:out value="${r.reasonLabel}"/> · ${r.formattedCreatedAt}</span>
              <c:if test="${not empty r.detail}"><span class="note">“<c:out value="${r.detail}"/>”</span></c:if></span>
          </li>
        </c:forEach>
      </ul>
    </details>

    <div class="report-actions">
      <c:choose>
        <c:when test="${g.targetMissing}">
          <button type="button" class="btn btn-soft" data-act="resolve" data-label="đóng báo cáo">Đóng báo cáo</button>
        </c:when>
        <c:when test="${g.targetType == 'POST'}">
          <label class="u-sr" for="note-${g.targetType}-${g.targetId}">Ghi chú cho nhật ký</label>
          <input class="note-input" id="note-${g.targetType}-${g.targetId}" maxlength="200" placeholder="Ghi chú cho nhật ký (không bắt buộc)">
          <button type="button" class="btn btn-delete" data-act="resolve" data-label="ẩn bài viết" data-icon="eye-slash"><svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>Ẩn bài viết</button>
        </c:when>
        <c:when test="${g.targetType == 'COMMENT'}">
          <label class="u-sr" for="note-${g.targetType}-${g.targetId}">Ghi chú cho nhật ký</label>
          <input class="note-input" id="note-${g.targetType}-${g.targetId}" maxlength="200" placeholder="Ghi chú cho nhật ký (không bắt buộc)">
          <button type="button" class="btn btn-delete" data-act="resolve" data-label="xóa bình luận" data-icon="trash"><svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg>Xóa bình luận</button>
        </c:when>
        <c:when test="${g.user.locked}">
          <button type="button" class="btn btn-soft" data-act="resolve" data-label="đóng báo cáo">Đã khóa — đóng báo cáo</button>
        </c:when>
        <c:when test="${g.user.admin or g.user.userId == me.userId}">
          <button type="button" class="btn btn-delete" disabled data-locked><svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>Khóa tài khoản</button>
          <span class="hint">Không thể khóa quản trị viên.</span>
        </c:when>
        <c:otherwise>
          <label class="u-sr" for="note-${g.targetType}-${g.targetId}">Ghi chú thêm vào lý do khóa</label>
          <input class="note-input" id="note-${g.targetType}-${g.targetId}" maxlength="200" placeholder="Ghi chú thêm vào lý do khóa (không bắt buộc)">
          <button type="button" class="btn btn-delete" data-act="resolve" data-label="khóa tài khoản" data-icon="lock"><svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>Khóa tài khoản</button>
        </c:otherwise>
      </c:choose>
      <button type="button" class="btn btn-dismiss" data-act="dismiss"><svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg>Bỏ qua báo cáo</button>
    </div>
  </article>
</c:forEach>
</div>

<div class="empty" id="report-empty" ${empty groups ? '' : 'hidden'}>
  <div class="empty-ico green" aria-hidden="true"><svg class="icon"><use href="#i-check-badge"></use></svg></div>
  <h2>Không có vi phạm nào chờ xử lý</h2>
  <p>Cộng đồng đang rất ổn. Các báo cáo mới sẽ hiện ở đây.</p>
</div>

<c:url var="pagerBase" value="/admin/reports" />
<c:set var="pagerBase" value="${pagerBase}" scope="request" />
<jsp:include page="pager.jsp" />

<jsp:include page="layout-end.jsp" />
<script>
(function () {
  var list = document.getElementById('report-list');
  list.addEventListener('click', function (e) {
    var btn = e.target.closest('button[data-act]');
    if (!btn) return;
    var card = btn.closest('.report-card');
    var type = card.getAttribute('data-type'), id = card.getAttribute('data-id');
    var resolve = btn.getAttribute('data-act') === 'resolve';
    var noteEl = card.querySelector('.note-input');
    var what = { POST: 'bài viết', COMMENT: 'bình luận', USER: 'tài khoản' }[type];
    var opts = resolve ? {
      title: 'Xác nhận ' + btn.getAttribute('data-label') + '?',
      text: type === 'POST' ? 'Bài viết sẽ bị ẩn khỏi mọi người (trừ tác giả) và có thể khôi phục ở trang "Bài viết ẩn". Tác giả nhận thông báo.'
          : type === 'COMMENT' ? 'Bình luận sẽ bị xóa vĩnh viễn. Tác giả nhận thông báo.'
          : 'Tài khoản sẽ bị khóa và đăng xuất ngay trên mọi thiết bị.',
      confirmLabel: btn.textContent.trim(), icon: btn.getAttribute('data-icon') || 'warning'
    } : {
      title: 'Bỏ qua các báo cáo này?',
      text: 'Nội dung được giữ nguyên, các báo cáo về ' + what + ' này được đánh dấu "đã bỏ qua".',
      confirmLabel: 'Bỏ qua báo cáo', tone: 'ok', icon: 'check-circle'
    };
    Admin.ask(opts).then(function (ok) {
      if (ok === null) return;
      card.querySelectorAll('button, input').forEach(function (x) { x.disabled = true; });
      Admin.post('/admin/reports/' + (resolve ? 'resolve' : 'dismiss'),
                 { targetType: type, targetId: id, note: noteEl ? noteEl.value.trim() : '' })
        .then(function (j) {
          Admin.toast(j.message);
          Admin.setBadge(j.pending);
          var pill = document.getElementById('pending-pill');
          card.classList.add('is-done');
          setTimeout(function () {
            card.remove();
            if (!list.querySelector('.report-card')) {
              document.getElementById('report-empty').hidden = false;
              if (j.pending > 0) location.reload();   // còn ở trang sau → nạp lại
            }
          }, 260);
          pill.textContent = j.pending + ' đối tượng đang chờ';
          pill.classList.toggle('ok', j.pending === 0);
          pill.classList.toggle('is-good', j.pending === 0);
        })
        .catch(function (err) {
          Admin.toast(err.message, true);
          card.querySelectorAll('button:not([data-locked]), input').forEach(function (x) { x.disabled = false; });
        });
    });
  });
})();
</script>
</body>
</html>
