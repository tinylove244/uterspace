<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  share-modal.jsp — Hộp thoại "Chia sẻ kèm bình luận" (Quote Share), dùng chung cho mọi trang có bài viết.
  Nút chia sẻ trên thẻ bài viết gọi openShareModal(this) và cần 2 thuộc tính:
    data-share-id    — id bài GỐC sẽ được chia sẻ (bài chia sẻ → id bài gốc của nó)
    data-share-state — ok | friends (bài chỉ bạn bè xem) | group (bài trong nhóm) | deleted (bài gốc đã xoá)
  Gửi về POST /feed/share rồi tải lại trang để bài chia sẻ mới hiện lên.
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="me"  value="${sessionScope.currentUser}" />

<div class="modal-overlay" id="share-modal" role="dialog" aria-modal="true" aria-labelledby="share-modal-title">
  <article class="modal modal-compose">
    <header class="modal-header">
      <h2 id="share-modal-title">Chia sẻ bài viết</h2>
      <button type="button" class="modal-close" onclick="closeModal('share-modal')" aria-label="Đóng hộp thoại">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>

    <div class="modal-body">
      <input type="hidden" id="share-post-id" value="">

      <p class="compose-author">
        <c:choose>
          <c:when test="${not empty me.avatar}">
            <img src="${ctx}${me.avatarUrl}"
                 alt="" width="42" height="42">
          </c:when>
          <c:otherwise>
            <span class="compose-initials" aria-hidden="true">${me.initials}</span>
          </c:otherwise>
        </c:choose>
        <span>
          <span class="compose-author-name">${me.fullName}</span><br>
          <label class="u-visually-hidden" for="share-visibility">Chế độ hiển thị</label>
          <select class="visibility-select" id="share-visibility">
            <option value="public">🌐 Công khai</option>
            <option value="friends">👥 Bạn bè</option>
            <option value="private">🔒 Chỉ mình tôi</option>
          </select>
        </span>
      </p>

      <label class="u-visually-hidden" for="share-content-input">Bình luận kèm theo (không bắt buộc)</label>
      <textarea class="compose-textarea share-textarea" id="share-content-input" rows="3"
                placeholder="Hãy nói gì đó về bài viết này... (không bắt buộc)"></textarea>

      <%-- Bản xem trước bài gốc, dựng bằng JS từ thẻ bài viết đang có trên trang --%>
      <div class="share-preview" id="share-preview" inert></div>
    </div>

    <footer class="modal-footer">
      <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('share-modal')">Hủy</button>
      <button type="button" class="btn-pill" id="share-submit-btn" onclick="submitShare()">
        <svg class="icon" aria-hidden="true"><use href="#i-share"></use></svg> Chia sẻ ngay
      </button>
    </footer>
  </article>
</div>

<script>
var SHARE_BLOCKED_MSG = {
  friends: 'Bài viết này chỉ hiển thị với bạn bè nên không thể chia sẻ.',
  deleted: 'Bài viết gốc đã bị xóa, không thể chia sẻ.',
  group:   'Bài viết trong nhóm không thể chia sẻ ra ngoài nhóm.'
};

function openShareModal(btn) {
  var state = btn.getAttribute('data-share-state');
  if (state !== 'ok') {
    showToast(SHARE_BLOCKED_MSG[state] || 'Không thể chia sẻ bài viết này.', 'error');
    return;
  }

  var preview = document.getElementById('share-preview');
  preview.textContent = '';
  preview.appendChild(buildSharePreview(btn.closest('.post-card')));

  document.getElementById('share-post-id').value = btn.getAttribute('data-share-id');
  document.getElementById('share-content-input').value = '';
  document.getElementById('share-visibility').value = 'public';
  document.getElementById('share-submit-btn').disabled = false;
  openModal('share-modal');
  document.getElementById('share-content-input').focus();
}

/* Dựng khung bài gốc từ DOM (clone node, không chèn chuỗi HTML nên an toàn với nội dung người dùng) */
function buildSharePreview(card) {
  // Thẻ là bài chia sẻ → chia sẻ tiếp bài gốc đang lồng bên trong
  var embedded = card.querySelector('.shared-embed');
  if (embedded) {
    var copy = embedded.cloneNode(true);
    copy.querySelectorAll('.post-more-text').forEach(function (b) { b.remove(); });
    return copy;
  }

  var box = document.createElement('div');
  box.className = 'shared-embed';

  var head = document.createElement('div');
  head.className = 'shared-embed-head';
  var avatar = card.querySelector('.post-avatar, .post-avatar-initials');
  if (avatar) {
    var av = avatar.cloneNode(true);
    av.className = avatar.tagName === 'IMG' ? 'shared-embed-avatar' : 'shared-embed-avatar shared-embed-initials';
    head.appendChild(av);
  }
  var name = document.createElement('span');
  name.className = 'shared-embed-name';
  var nameEl = card.querySelector('.post-author-name');
  name.textContent = nameEl ? nameEl.textContent.trim() : '';
  head.appendChild(name);
  var timeEl = card.querySelector('.post-time');
  if (timeEl) {
    var time = document.createElement('span');
    time.className = 'shared-embed-time';
    time.textContent = timeEl.textContent.trim();
    head.appendChild(time);
  }
  box.appendChild(head);

  var textEl = card.querySelector('.post-caption-text');
  if (textEl && textEl.textContent.trim()) {
    var body = document.createElement('p');
    body.className = 'shared-embed-body';
    var text = document.createElement('span');
    text.className = 'shared-embed-text';
    text.textContent = textEl.textContent.trim();
    body.appendChild(text);
    box.appendChild(body);
  }

  var img = card.querySelector('.post-media img');
  if (img) {
    var fig = document.createElement('figure');
    fig.className = 'shared-embed-media';
    var pic = document.createElement('img');
    pic.src = img.src;
    pic.alt = '';
    fig.appendChild(pic);
    box.appendChild(fig);
  }
  return box;
}

function submitShare() {
  var btn     = document.getElementById('share-submit-btn');
  var postId  = document.getElementById('share-post-id').value;
  var content = document.getElementById('share-content-input').value.trim();
  var visibility = document.getElementById('share-visibility').value;

  btn.disabled = true;
  fetch('${ctx}/feed/share', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    // "Chỉ mình tôi" = bài chia sẻ ở trạng thái chủ bài tự ẩn (giống hộp đăng bài); hiện lại thì về phạm vi Bạn bè
    body: 'postId=' + encodeURIComponent(postId) +
          '&content=' + encodeURIComponent(content) +
          '&visibility=' + encodeURIComponent(visibility === 'private' ? 'friends' : visibility) +
          (visibility === 'private' ? '&hidden=true' : '')
  })
    .then(function (res) {
      return res.json().catch(function () { return {}; }).then(function (data) {
        if (!res.ok || !data.success) throw new Error(data.error || 'Không thể chia sẻ bài viết');
        return data;
      });
    })
    .then(function (data) {
      var countEl = document.getElementById('share-count-' + data.originalId);
      if (countEl) countEl.textContent = data.shareCount;
      closeModal('share-modal');
      showToast(data.hidden ? 'Đã chia sẻ ở chế độ Chỉ mình tôi 🔒 — xem trong trang cá nhân.' : 'Đã chia sẻ bài viết! ↗', 'success');
      setTimeout(function () { window.location.reload(); }, 800);
    })
    .catch(function (err) {
      showToast(err.message, 'error');
      btn.disabled = false;
    });
}
</script>
