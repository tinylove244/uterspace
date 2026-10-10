<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  report-modal.jsp — Hộp thoại "Báo cáo vi phạm" + JS dùng chung (plan 6.4):
    reportPost(id) · reportComment(id) · reportUser(id)  → POST /report/create (JSON, kèm CSRF token)
    csrfHeaders()                                         → header X-CSRF-Token đọc từ <meta> trong header.jsp
  Include TĨNH một lần mỗi trang (post-support.jsp, profile.jsp). Yêu cầu: ctx.
--%>
<% request.setAttribute("reportReasons", com.uterspace.model.Report.REASONS); %>

<div class="modal-overlay" id="report-modal" role="dialog" aria-modal="true" aria-labelledby="report-modal-title">
  <article class="modal modal-compose report-modal">
    <header class="modal-header">
      <h2 id="report-modal-title">Báo cáo <span id="report-target-label">bài viết</span></h2>
      <button type="button" class="modal-close" onclick="closeModal('report-modal')" aria-label="Đóng hộp thoại">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>

    <form class="modal-body" id="report-form" onsubmit="return submitReport(event)">
      <input type="hidden" name="targetType" id="report-target-type">
      <input type="hidden" name="targetId"   id="report-target-id">

      <fieldset class="report-reasons">
        <legend>Vì sao bạn báo cáo nội dung này?</legend>
        <c:forEach var="r" items="${reportReasons}">
          <label class="report-reason">
            <input type="radio" name="reason" value="${r.key}" required>
            <span><c:out value="${r.value}"/></span>
          </label>
        </c:forEach>
      </fieldset>

      <label class="report-detail-label" for="report-detail">Mô tả thêm (không bắt buộc)</label>
      <textarea class="compose-textarea report-detail" id="report-detail" name="detail" rows="3" maxlength="500"
                placeholder="Thông tin giúp quản trị viên xử lý nhanh hơn..."></textarea>
      <p class="report-note">Báo cáo được gửi ẩn danh tới quản trị viên. Người bị báo cáo không biết ai đã báo cáo.</p>

      <footer class="modal-footer report-footer">
        <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('report-modal')">Hủy</button>
        <button type="submit" class="btn-pill btn-pill--accent" id="report-submit-btn">
          <svg class="icon" aria-hidden="true"><use href="#i-flag"></use></svg> Gửi báo cáo
        </button>
      </footer>
    </form>
  </article>
</div>

<script>
var ME_ID = Number('${sessionScope.currentUser.userId}') || 0;

/** Header CSRF cho fetch POST tới /admin/* và /report/* (CsrfFilter kiểm tra) */
function csrfHeaders(extra) {
  var h = extra || {};
  var meta = document.querySelector('meta[name="csrf-token"]');
  if (meta) h['X-CSRF-Token'] = meta.content;
  h['Accept'] = 'application/json';
  return h;
}

var REPORT_LABEL = { POST: 'bài viết', COMMENT: 'bình luận', USER: 'người dùng' };

function openReport(type, id) {
  document.querySelectorAll('.post-menu.open').forEach(function (m) { m.classList.remove('open'); });
  var form = document.getElementById('report-form');
  form.reset();
  document.getElementById('report-target-type').value = type;
  document.getElementById('report-target-id').value = id;
  document.getElementById('report-target-label').textContent = REPORT_LABEL[type];
  openModal('report-modal');
}
function reportPost(id)    { openReport('POST', id); }
function reportComment(id) { openReport('COMMENT', id); }
function reportUser(id)    { openReport('USER', id); }

function submitReport(e) {
  e.preventDefault();
  var form = e.target;
  var btn = document.getElementById('report-submit-btn');
  btn.disabled = true;
  fetch(CTX + '/report/create', {
    method: 'POST',
    headers: csrfHeaders({ 'Content-Type': 'application/x-www-form-urlencoded' }),
    body: new URLSearchParams(new FormData(form)).toString()
  })
    .then(function (res) { return res.json().then(function (d) { return { ok: res.ok, d: d }; }); })
    .then(function (r) {
      if (!r.ok) throw new Error(r.d.error || 'Không gửi được báo cáo');
      closeModal('report-modal');
      showToast(r.d.message || 'Đã gửi báo cáo. Cảm ơn bạn! 🚩', 'success');
    })
    .catch(function (err) { showToast(err.message || 'Không gửi được báo cáo', 'error'); })
    .finally(function () { btn.disabled = false; });
  return false;
}
</script>
