<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%--
  group-actions.jsp — JS thao tác nhóm dùng chung cho /groups và /groups/view.
  Mọi thao tác POST /groups/<action> (JSON); server kiểm quyền lại toàn bộ.
--%>
<script>
var GROUP_CTX = '${pageContext.request.contextPath}';

function groupRequest(action, params) {
  var body = Object.keys(params)
    .filter(function (k) { return params[k] !== null && params[k] !== undefined; })
    .map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]); })
    .join('&');
  return fetch(GROUP_CTX + '/groups/' + action, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body
  }).then(function (res) {
    return res.json().catch(function () { return {}; }).then(function (data) {
      if (!res.ok || data.success === false) throw new Error(data.error || 'Không thực hiện được, thử lại sau.');
      return data;
    });
  });
}

var GROUP_CONFIRM = {
  leave:    'Bạn chắc chắn muốn rời nhóm này?',
  kick:     'Xóa thành viên này khỏi nhóm? Người này sẽ không thể tự tham gia lại.',
  transfer: 'Chuyển quyền chủ nhóm cho thành viên này? Bạn sẽ trở thành thành viên thường.'
};

/* action: join | leave | approve | reject | kick | unban | transfer */
function groupAction(action, groupId, userId, btn) {
  var isCancel = action === 'leave' && btn && btn.classList.contains('btn-pill--done');
  if (GROUP_CONFIRM[action] && !isCancel && !confirm(GROUP_CONFIRM[action])) return;
  if (btn) btn.disabled = true;

  groupRequest(action, { groupId: groupId, userId: userId })
    .then(function (data) {
      var msg = {
        join:     data.status === 'PENDING' ? 'Đã gửi yêu cầu — chờ chủ nhóm duyệt ⏳' : 'Đã tham gia nhóm 🎉',
        leave:    data.wasPending ? 'Đã hủy yêu cầu tham gia.' : 'Đã rời nhóm.',
        approve:  'Đã duyệt thành viên ✅',
        reject:   'Đã từ chối yêu cầu.',
        kick:     'Đã xóa thành viên khỏi nhóm.',
        unban:    'Đã bỏ chặn — người này có thể xin vào lại.',
        transfer: 'Đã chuyển quyền chủ nhóm.'
      }[action];
      showToast(msg, 'success');
      setTimeout(function () { window.location.reload(); }, 700);
    })
    .catch(function (err) {
      showToast(err.message, 'error');
      if (btn) btn.disabled = false;
    });
}

/* Tạo nhóm / sửa nhóm (group-form-modal.jsp) */
function submitGroupForm(e) {
  e.preventDefault();
  var form = e.target;
  var btn = document.getElementById('group-form-submit');
  var params = {};
  new FormData(form).forEach(function (v, k) { params[k] = v; });
  var mode = form.getAttribute('data-mode');

  btn.disabled = true;
  groupRequest(mode === 'edit' ? 'edit' : 'create', params)
    .then(function (data) {
      closeModal('group-form-modal');
      if (mode === 'edit') {
        showToast('Đã lưu thông tin nhóm ✏️', 'success');
        setTimeout(function () { window.location.reload(); }, 600);
      } else {
        showToast('Đã tạo nhóm 🎉', 'success');
        setTimeout(function () { window.location.href = GROUP_CTX + '/groups/view?id=' + data.groupId; }, 600);
      }
    })
    .catch(function (err) {
      showToast(err.message, 'error');
      btn.disabled = false;
    });
  return false;
}
</script>
