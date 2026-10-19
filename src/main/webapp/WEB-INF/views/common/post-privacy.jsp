<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%--
  post-privacy.jsp — JS dùng chung cho chế độ "Chỉ mình tôi" (chủ bài tự ẩn bài, cờ is_hidden_by_owner):
    togglePostHidden(id, hidden)  → menu (...) "Ẩn bài viết / Hiện lại", nút "Hiện lại" ở trang cá nhân
    fillEditPrivacy / readEditPrivacy / applyEditPrivacy → lựa chọn "🔒 Chỉ mình tôi" trong hộp sửa bài
  Thẻ bài viết mang sẵn data-visibility, data-hidden, data-group (post-card.jsp, profile.jsp).
  Include TĨNH một lần mỗi trang (post-support.jsp, profile.jsp). Yêu cầu: CTX, showToast.
--%>
<script>
function findPostCard(postId) {
  return document.getElementById('post-' + postId) || document.getElementById('profile-post-' + postId);
}

function isProfilePage() { return document.body.classList.contains('page-profile'); }

/** Chủ bài tự ẩn / hiện lại. Trang cá nhân: tải lại để hiện nhãn; nơi khác: gỡ thẻ bài khỏi danh sách. */
function togglePostHidden(postId, hidden) {
  document.querySelectorAll('.post-menu.open').forEach(function (m) { m.classList.remove('open'); });
  fetch(CTX + '/feed/hide', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
    body: 'postId=' + encodeURIComponent(postId) + '&hidden=' + hidden
  })
    .then(function (res) { return res.json().then(function (d) { return { ok: res.ok, d: d }; }); })
    .then(function (r) {
      if (!r.ok) throw new Error(r.d.error || 'Không thể cập nhật bài viết');
      afterPrivacyChange(postId, hidden);
    })
    .catch(function (err) { showToast(err.message, 'error'); });
}

function afterPrivacyChange(postId, hidden) {
  if (isProfilePage()) {
    showToast(hidden ? 'Đã ẩn bài viết 🔒' : 'Đã hiện lại bài viết 👁️', 'success');
    setTimeout(function () { location.reload(); }, 600);
    return;
  }
  if (hidden && window.PostViewer) PostViewer.closeIfShowing(postId);   // bài đang mở trong hộp xem bài (post-support.jsp)
  var card = findPostCard(postId);
  if (hidden && card) {
    card.style.transition = 'opacity .3s ease, transform .3s ease';
    card.style.opacity = '0';
    card.style.transform = 'translateY(-10px)';
    setTimeout(function () { card.remove(); }, 300);
  }
  showToast(hidden ? 'Đã ẩn bài viết. Bạn vẫn xem và hiện lại được ở trang cá nhân.' : 'Đã hiện lại bài viết.', 'success');
}

/** Mở hộp sửa: chọn sẵn Công khai / Bạn bè / Chỉ mình tôi theo trạng thái hiện tại của bài */
function fillEditPrivacy(postId) {
  var card = findPostCard(postId);
  var sel  = document.getElementById('edit-post-visibility');
  if (!card || !sel) return;
  var inGroup = !!card.getAttribute('data-group');
  var priv = sel.querySelector('option[value="private"]');
  if (priv) priv.disabled = inGroup;   // bài trong nhóm theo quyền của nhóm, không có chế độ ẩn
  sel.value = card.getAttribute('data-hidden') === 'true' && !inGroup
            ? 'private' : (card.getAttribute('data-visibility') || 'public');
  syncPrivacyHint(sel, 'edit-privacy-hint');
}

/** Đọc lựa chọn trong hộp sửa → { visibility, hidden } gửi lên /feed/edit (hidden = null: không đổi) */
function readEditPrivacy(postId) {
  var card = findPostCard(postId);
  var v = document.getElementById('edit-post-visibility').value;
  if (card && card.getAttribute('data-group')) return { visibility: 'public', hidden: null };
  if (v === 'private') {
    // Giữ phạm vi cũ để khi "Hiện lại" bài trở về đúng Công khai / Bạn bè như trước
    return { visibility: (card && card.getAttribute('data-visibility')) || 'friends', hidden: true };
  }
  return { visibility: v, hidden: false };
}

/** Sau khi lưu: cập nhật data-* của thẻ; nếu trạng thái ẩn đổi thì xử lý như ẩn/hiện. Trả true nếu đã xử lý. */
function applyEditPrivacy(postId, data) {
  var card = findPostCard(postId);
  if (!card) return false;
  var wasHidden = card.getAttribute('data-hidden') === 'true';
  card.setAttribute('data-visibility', data.visibility);
  card.setAttribute('data-hidden', String(!!data.hidden));
  if (!!data.hidden === wasHidden) return false;
  afterPrivacyChange(postId, !!data.hidden);
  return true;
}
</script>
