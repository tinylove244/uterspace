<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  post-support.jsp — Phần đi kèm post-card.jsp: dữ liệu bình luận (ẩn), hộp thoại chia sẻ,
  hộp thoại sửa bài và JS thích / bình luận / lưu / menu / sửa / xóa bài.
  Include TĨNH một lần, sau vòng lặp bài viết. Yêu cầu: ctx, me, posts.
--%>
<%@ include file="/WEB-INF/views/common/share-modal.jsp" %>
<%@ include file="/WEB-INF/views/common/report-modal.jsp" %>
<%@ include file="/WEB-INF/views/common/post-privacy.jsp" %>

<!-- ============================================================
     DỮ LIỆU BÌNH LUẬN (ẩn) — tránh nhúng chuỗi người dùng vào JS
     ============================================================ -->
<div id="comments-data-store" hidden>
  <c:forEach var="post" items="${posts}">
    <div class="post-comments-data" data-post-id="${post.postId}">
      <c:forEach var="comment" items="${post.comments}">
        <div class="comment-data"
             data-id="${comment.commentId}"
             data-author-id="${comment.author.userId}"
             data-author="<c:out value="${comment.author.firstName} ${comment.author.lastName}"/>"
             data-initials="<c:out value="${comment.author.initials}"/>"
             data-avatar="<c:out value="${comment.author.avatarUrl}"/>"
             data-time="${comment.createdAt}"><c:out value="${comment.content}"/></div>
      </c:forEach>
    </div>
  </c:forEach>
</div>

<%-- ============================================================
     HỘP XEM BÀI VIẾT (kiểu Facebook) — PostViewer bên dưới chuyển chính thẻ bài vào .post-viewer-body
     và ô bình luận của thẻ vào .post-viewer-foot (luôn nằm ở đáy hộp), đóng thì trả về chỗ cũ.
     ============================================================ --%>
<div class="post-viewer" id="post-viewer" role="dialog" aria-modal="true" aria-labelledby="post-viewer-title" hidden>
  <div class="post-viewer-dialog">
    <header class="post-viewer-head">
      <h2 id="post-viewer-title">Bài viết</h2>
      <button type="button" class="post-viewer-close" aria-label="Đóng bài viết">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>
    <div class="post-viewer-body" id="post-viewer-body"></div>
    <div class="post-viewer-foot" id="post-viewer-foot" hidden></div>
  </div>
</div>

<script>
var CTX = '${ctx}';

/* ---------- Thời gian tương đối ---------- */
function relativeTime(raw) {
  var d = new Date(raw);
  if (isNaN(d)) return raw;
  var diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60)      return 'vừa xong';
  if (diff < 3600)    return Math.floor(diff / 60) + ' phút trước';
  if (diff < 86400)   return Math.floor(diff / 3600) + ' giờ trước';
  if (diff < 2592000) return Math.floor(diff / 86400) + ' ngày trước';
  return d.toLocaleDateString('vi-VN');
}

document.querySelectorAll('.post-time, .shared-embed-time').forEach(function (el) {
  var raw = el.getAttribute('data-time');
  if (raw) el.textContent = relativeTime(raw);
});

/* ---------- Nút "Xem thêm" (hashtag được biến thành link trong footer.jsp) ----------
   Chỉ hiện khi chữ bị cắt. Gọi lại khi đổi kiểu hiển thị bảng tin (số dòng thu gọn khác nhau);
   bỏ qua thẻ đang mở trong hộp xem bài (ở đó chữ luôn hiện đủ). */
function refreshMoreText() {
  document.querySelectorAll('.post-caption, .shared-embed-body').forEach(function (box) {
    if (box.classList.contains('is-expanded') || box.closest('.is-in-viewer')) return;
    var textEl = box.querySelector('.post-caption-text, .shared-embed-text');
    var more = box.querySelector('.post-more-text');
    var clipped = !!textEl && textEl.scrollHeight - textEl.clientHeight > 4;
    if (clipped && !more) {
      more = document.createElement('button');
      more.type = 'button';
      more.className = 'post-more-text';
      more.textContent = '… Xem thêm';
      more.addEventListener('click', function () {
        box.classList.add('is-expanded');
        more.remove();
      });
      box.appendChild(more);
    } else if (!clipped && more) {
      more.remove();
    }
  });
}
refreshMoreText();

/* ---------- Thích ---------- */
function toggleLike(postId, btn) {
  btn.disabled = true;
  fetch(CTX + '/feed/like', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      btn.classList.toggle('is-active', data.liked);
      btn.setAttribute('aria-pressed', String(data.liked));
      document.getElementById('like-count-' + postId).textContent = data.likeCount;
      if (data.liked) showToast('Đã thích bài viết! ❤️', 'success');
    })
    .catch(function () { showToast('Lỗi hệ thống khi thả tim', 'error'); })
    .finally(function () { btn.disabled = false; });
}

/* ---------- Lưu bài viết ---------- */
function toggleSave(postId, btn) {
  var willSave = btn.getAttribute('aria-pressed') !== 'true';
  btn.disabled = true;
  fetch(CTX + (willSave ? '/saved/add' : '/saved/remove'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function () {
      btn.classList.toggle('is-active', willSave);
      btn.setAttribute('aria-pressed', String(willSave));
      showToast(willSave ? 'Đã lưu bài viết! 🔖' : 'Đã bỏ lưu bài viết.', 'success');
    })
    .catch(function () { showToast('Không thể cập nhật mục đã lưu', 'error'); })
    .finally(function () { btn.disabled = false; });
}

/* ---------- Bình luận ---------- */
function buildComment(data) {
  var li = document.createElement('li');
  li.className = 'comment';

  if (data.avatar) {
    var img = document.createElement('img');
    img.src = CTX + data.avatar;
    img.alt = '';
    img.width = 30; img.height = 30;
    li.appendChild(img);
  } else {
    var ini = document.createElement('span');
    ini.className = 'comment-initials';
    ini.setAttribute('aria-hidden', 'true');
    ini.textContent = data.initials || '?';
    li.appendChild(ini);
  }

  var bubble = document.createElement('p');
  bubble.className = 'comment-bubble';

  var author = document.createElement('span');
  author.className = 'comment-author';
  author.textContent = data.author;

  var text = document.createElement('span');
  text.className = 'comment-text';
  text.textContent = data.content;

  var time = document.createElement('time');
  time.className = 'comment-time';
  if (data.time) { time.dateTime = data.time; }
  time.textContent = data.time ? relativeTime(data.time) : '';

  bubble.appendChild(author);
  bubble.appendChild(document.createElement('br'));
  bubble.appendChild(text);
  bubble.appendChild(document.createElement('br'));
  bubble.appendChild(time);

  // Bình luận của người khác: nút "Báo cáo" nhỏ (report-modal.jsp)
  if (data.id && data.authorId && Number(data.authorId) !== ME_ID) {
    var flag = document.createElement('button');
    flag.type = 'button';
    flag.className = 'comment-report';
    flag.textContent = 'Báo cáo';
    flag.setAttribute('aria-label', 'Báo cáo bình luận của ' + data.author);
    flag.addEventListener('click', function () { reportComment(data.id); });
    bubble.appendChild(flag);
  }
  li.appendChild(bubble);

  // Bộ lọc nội dung cá nhân: bình luận của người khác chứa từ khóa bị chặn → thu gọn, bấm để xem (post-ai.js)
  var hit = window.UTFilter && Number(data.authorId) !== ME_ID ? UTFilter.match(data.content) : null;
  if (hit) {
    li.classList.add('is-filtered');
    var note = document.createElement('button');
    note.type = 'button';
    note.className = 'comment-filtered';
    note.textContent = '🙈 Bình luận được thu gọn theo bộ lọc của bạn (“' + hit + '”) · Xem';
    note.addEventListener('click', function () { li.classList.remove('is-filtered'); note.remove(); });
    li.appendChild(note);
  }
  return li;
}

function renderComments(postId) {
  var list = document.getElementById('comment-list-' + postId);
  if (list.dataset.rendered) return;
  list.dataset.rendered = 'true';

  var store = document.querySelector('.post-comments-data[data-post-id="' + postId + '"]');
  var rows  = store ? store.querySelectorAll('.comment-data') : [];

  if (!rows.length) {
    var empty = document.createElement('li');
    empty.className = 'comment-empty';
    empty.textContent = 'Chưa có bình luận nào. Hãy là người đầu tiên!';
    list.appendChild(empty);
    return;
  }

  rows.forEach(function (row) {
    list.appendChild(buildComment({
      id:       row.getAttribute('data-id'),
      authorId: row.getAttribute('data-author-id'),
      author:   row.getAttribute('data-author'),
      initials: row.getAttribute('data-initials'),
      avatar:   row.getAttribute('data-avatar'),
      time:     row.getAttribute('data-time'),
      content:  row.textContent.trim()
    }));
  });
}

function toggleComments(postId, btn) {
  // Như Facebook: nút Bình luận mở hộp xem bài (đang mở rồi thì chỉ đưa con trỏ vào ô bình luận)
  var card = document.getElementById('post-' + postId);
  if (window.PostViewer && card) {
    if (PostViewer.isOpen(postId)) PostViewer.focusComment();
    else PostViewer.open(card, { focusComment: true });
    return;
  }

  var section = document.getElementById('comments-' + postId);
  var isOpen  = !section.hasAttribute('hidden');

  if (isOpen) {
    section.setAttribute('hidden', '');
    btn.setAttribute('aria-expanded', 'false');
  } else {
    section.removeAttribute('hidden');
    btn.setAttribute('aria-expanded', 'true');
    renderComments(postId);
    var input = document.getElementById('comment-input-' + postId);
    if (input) input.focus();
  }
}

function submitComment(event, postId) {
  event.preventDefault();
  var input = document.getElementById('comment-input-' + postId);
  var text  = input.value.trim();
  if (!text) return false;

  input.disabled = true;
  fetch(CTX + '/feed/comment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId + '&content=' + encodeURIComponent(text)
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      var list = document.getElementById('comment-list-' + postId);
      list.dataset.rendered = 'true';
      var placeholder = list.querySelector('.comment-empty');
      if (placeholder) placeholder.remove();

      var li = buildComment({
        author:   data.authorName,
        initials: '${me.initials}',
        avatar:   '${me.avatarUrl}',
        time:     '',
        content:  data.content
      });
      list.appendChild(li);
      // Trong hộp xem bài: cuộn tới bình luận vừa gửi (ô nhập nằm cố định ở đáy hộp)
      if (window.PostViewer && PostViewer.isOpen(postId)) li.scrollIntoView({ block: 'nearest', behavior: 'smooth' });

      var countEl = document.getElementById('comment-count-' + postId);
      countEl.textContent = String(parseInt(countEl.textContent, 10) + 1);
      input.value = '';
      showToast('Đã bình luận! 💬', 'success');
    })
    .catch(function () { showToast('Không thể gửi bình luận', 'error'); })
    .finally(function () { input.disabled = false; input.focus(); });

  return false;
}

/* ---------- Menu bài viết ---------- */
function togglePostMenu(postId, btn) {
  var menu = document.getElementById('post-menu-' + postId);
  if (!menu) return;
  var willOpen = !menu.classList.contains('open');
  document.querySelectorAll('.post-menu.open').forEach(function (m) { m.classList.remove('open'); });
  menu.classList.toggle('open', willOpen);
  btn.setAttribute('aria-expanded', String(willOpen));
}

function deletePost(postId) {
  if (!confirm('Bạn có chắc muốn xóa bài viết này?')) return;
  fetch(CTX + '/feed/delete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      if (!data.success) throw new Error('failed');
      if (window.PostViewer) PostViewer.closeIfShowing(postId);   // trả thẻ về lưới rồi mới gỡ
      var card = document.getElementById('post-' + postId);
      if (card) {
        card.style.transition = 'opacity .3s, transform .3s';
        card.style.opacity = '0';
        card.style.transform = 'translateY(-10px)';
        setTimeout(function () { card.remove(); }, 300);
      }
      showToast('Đã xóa bài viết.', 'success');
    })
    .catch(function () { showToast('Không thể xóa bài viết', 'error'); });
}

function openEditModal(postId) {
  // Lấy nội dung hiện tại từ DOM
  var captionEl = document.querySelector('#caption-' + postId + ' .post-caption-text');
  var currentContent = captionEl ? captionEl.textContent.trim() : '';

  // Điền vào modal
  document.getElementById('edit-post-id').value = postId;
  document.getElementById('edit-post-content').value = currentContent;
  fillEditPrivacy(postId);   // chọn sẵn chế độ hiện tại của bài (post-privacy.jsp)

  // Đóng dropdown đang mở
  document.querySelectorAll('.post-menu.open').forEach(function (m) { m.classList.remove('open'); });

  openModal('edit-post-modal');
  document.getElementById('edit-post-content').focus();
}

function handleEditPost() {
  var postId  = document.getElementById('edit-post-id').value;
  var content = document.getElementById('edit-post-content').value.trim();
  var privacy = readEditPrivacy(postId);   // { visibility, hidden }
  var btn     = document.getElementById('edit-post-submit-btn');
  // Bài chia sẻ được phép để trống bình luận
  var isShare = !!document.querySelector('#post-' + postId + ' .shared-embed');

  if (!content && !isShare) {
    document.getElementById('edit-post-content').focus();
    showToast('Nội dung không được để trống!', 'error');
    return;
  }

  btn.disabled = true;
  fetch(CTX + '/feed/edit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId + '&content=' + encodeURIComponent(content) +
          '&visibility=' + privacy.visibility + (privacy.hidden === null ? '' : '&hidden=' + privacy.hidden)
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      if (!data.success) throw new Error('failed');
      // Cập nhật nội dung DOM tại chỗ
      var caption   = document.getElementById('caption-' + postId);
      var captionEl = caption ? caption.querySelector('.post-caption-text') : null;
      if (captionEl) {
        captionEl.textContent = data.content;
        linkifyHashtags(captionEl);
        caption.hidden = !data.content;
      }
      closeModal('edit-post-modal');
      if (applyEditPrivacy(postId, data)) return;   // đổi trạng thái ẩn → cập nhật/tải lại danh sách
      showToast('Đã cập nhật bài viết! ✏️', 'success');
    })
    .catch(function () { showToast('Không thể cập nhật bài viết', 'error'); })
    .finally(function () { btn.disabled = false; });
}

function copyPostLink(postId) {
  var url = window.location.origin + CTX + '/feed#post-' + postId;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(url).finally(function () {
      showToast('Đã sao chép liên kết! 🔗', 'success');
    });
  } else {
    showToast('Đã sao chép liên kết! 🔗', 'success');
  }
}

/* ---------- Hộp xem bài viết (kiểu Facebook) ----------
   Bấm vào thẻ bài (ảnh, chữ, số lượt thích, vùng trống) hoặc nút Bình luận → mở hộp: ảnh/video lớn,
   thông tin bài, toàn bộ bình luận, ô bình luận cố định ở đáy.
   CHUYỂN chính thẻ bài vào hộp chứ không nhân bản: giữ nguyên id nên thích / lưu / bình luận / menu /
   sửa / AI vẫn chạy như cũ, video phát tiếp đúng chỗ đang xem. Trong lưới để lại ô giữ chỗ cùng chiều cao
   để lưới không nhảy; đóng hộp thì trả thẻ về đúng chỗ.
   URL đổi thành #post-<id>: nút Back của trình duyệt / điện thoại đóng hộp; mở link /feed#post-<id>
   (Sao chép liên kết, trang Đã lưu) thì tự mở bài nếu bài có trên trang. */
var PostViewer = (function () {
  var root = document.getElementById('post-viewer');
  if (!root) return null;
  var body     = document.getElementById('post-viewer-body');
  var foot     = document.getElementById('post-viewer-foot');
  var title    = document.getElementById('post-viewer-title');
  var closeBtn = root.querySelector('.post-viewer-close');

  // Bấm vào các phần tử này trên thẻ thì làm việc riêng của nó, không mở hộp
  var NOT_OPENER = 'a, button, input, textarea, select, label, video, audio, iframe, model-viewer, [contenteditable], ' +
                   '.dropdown-menu, .post-comments, .post-ai-result, .post-ai-menu, .pano-viewer, [data-model3d]';

  var cur = null;          // bài đang mở: { card, id, placeholder, section, sectionHidden, form, formHidden, returnFocus, pushed }
  var skipPop = false;     // history.back() do chính hộp gọi khi đóng → bỏ qua popstate kế tiếp

  function idOf(card) { return card.id.replace('post-', ''); }

  function open(card, opts) {
    opts = opts || {};
    if (!card || cur || !card.parentNode) return;
    var id = idOf(card);

    var placeholder = document.createElement('div');
    placeholder.className = 'post-card-placeholder';
    placeholder.setAttribute('aria-hidden', 'true');
    placeholder.style.height = card.offsetHeight + 'px';
    card.parentNode.insertBefore(placeholder, card);

    var section  = document.getElementById('comments-' + id);
    var form     = section ? section.querySelector('.comment-form') : null;
    var actions  = card.querySelector('.post-actions');
    var readOnly = !!(actions && actions.hidden);     // người ngoài xem nhóm công khai: chỉ đọc bình luận

    cur = {
      card: card, id: id, placeholder: placeholder,
      section: section, sectionHidden: section ? section.hidden : true,
      form: form, formHidden: form ? form.hidden : true,
      returnFocus: document.activeElement, pushed: false
    };

    card.classList.add('is-in-viewer', 'is-moved');   // is-moved: không chạy lại hiệu ứng xuất hiện khi chuyển chỗ
    body.appendChild(card);
    if (section) { section.hidden = false; renderComments(id); }
    if (form && !readOnly) foot.appendChild(form);
    else if (form) form.hidden = true;
    foot.hidden = !form || readOnly;
    var cbtn = document.getElementById('comment-btn-' + id);
    if (cbtn) cbtn.setAttribute('aria-expanded', 'true');

    var nameEl = card.querySelector('.post-author-name');
    title.textContent = nameEl ? 'Bài viết của ' + nameEl.textContent.trim() : 'Bài viết';

    // Video khác trên trang (nằm sau lớp phủ) đang chạy → dừng, như Facebook
    document.querySelectorAll('video').forEach(function (v) {
      if (!card.contains(v) && !v.paused) { v._autoPause = true; v.pause(); }
    });

    root.hidden = false;
    document.documentElement.classList.add('has-post-viewer');
    body.scrollTop = 0;

    if (opts.fromHistory) cur.pushed = true;          // mở lại bằng nút Forward: mục lịch sử là của hộp
    else if (!opts.fromHash) {
      try { history.pushState({ utPost: id }, '', '#post-' + id); cur.pushed = true; } catch (e) { }
    }

    window.dispatchEvent(new Event('resize'));        // trình xem 360° / 3D co giãn theo khung lớn
    if (opts.focusComment && form && !readOnly) focusComment();
    else closeBtn.focus({ preventScroll: true });
  }

  function close(fromHistory) {
    if (!cur) return;
    var c = cur;
    cur = null;

    root.hidden = true;
    document.documentElement.classList.remove('has-post-viewer');
    if (c.form) {
      c.form.hidden = c.formHidden;
      if (c.form.parentNode !== c.section) c.section.insertBefore(c.form, c.section.firstChild);
    }
    if (c.section) c.section.hidden = c.sectionHidden;
    var cbtn = document.getElementById('comment-btn-' + c.id);
    if (cbtn) cbtn.setAttribute('aria-expanded', String(!c.sectionHidden));
    c.card.classList.remove('is-in-viewer');
    c.placeholder.parentNode.replaceChild(c.card, c.placeholder);
    window.dispatchEvent(new Event('resize'));

    if (!fromHistory) {
      if (c.pushed && history.state && history.state.utPost) { skipPop = true; history.back(); }
      else if (location.hash === '#post-' + c.id) {
        try { history.replaceState(null, '', location.pathname + location.search); } catch (e) { }
      }
    }
    var f = c.returnFocus;
    if (f && f !== document.body && document.contains(f) && f.focus) f.focus({ preventScroll: true });
  }

  function focusComment() {
    var input = foot.querySelector('.comment-input');
    if (input && !foot.hidden) input.focus();
  }

  /* Mở: bấm vào vùng không tương tác của thẻ bài */
  document.addEventListener('click', function (e) {
    if (cur || e.defaultPrevented || e.button !== 0 || e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) return;
    var card = e.target.closest('.post-card');
    if (!card || !/^post-\d+$/.test(card.id) || card.classList.contains('is-filtered')) return;
    if (e.target.closest(NOT_OPENER)) return;
    var sel = window.getSelection ? window.getSelection() : null;
    if (sel && String(sel) && card.contains(sel.anchorNode)) return;   // đang bôi đen chữ để chép
    open(card);
  });

  /* Đóng: nút X, bấm ra nền tối (nhấn chuột bắt đầu ở nền — kéo bôi đen chữ ra ngoài không tính), Esc, Back */
  closeBtn.addEventListener('click', function () { close(); });
  var downOnBackdrop = false;
  root.addEventListener('mousedown', function (e) { downOnBackdrop = e.target === root; });
  root.addEventListener('click', function (e) { if (e.target === root && downOnBackdrop) close(); });

  // Pha capture: chạy trước bộ xử lý Esc chung của footer.jsp. Đang mở hộp thoại con (chia sẻ, báo cáo, sửa bài),
  // menu "..." hay trình xem tin thì Esc đóng cái đó trước, chưa đóng bài.
  window.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape' || !cur) return;
    var menu = document.querySelector('.post-menu.open');
    if (menu) { menu.classList.remove('open'); return; }
    if (document.querySelector('.modal-overlay.open, .post-ai-menu, .story-viewer:not([hidden])')) return;
    e.preventDefault();
    close();
  }, true);

  window.addEventListener('popstate', function (e) {
    if (skipPop) { skipPop = false; return; }
    if (cur) { close(true); return; }
    var st = e.state;
    var card = st && st.utPost ? document.getElementById('post-' + st.utPost) : null;
    if (card) open(card, { fromHistory: true });
  });

  document.body.classList.add('post-viewable');     // con trỏ bàn tay trên ảnh / chữ của thẻ bài (app-shell.css)

  // Link /feed#post-<id>: mở luôn bài đó (sau khi trang vẽ xong để lưới có kích thước thật)
  var m = /^#post-(\d+)$/.exec(location.hash);
  if (m) {
    var target = document.getElementById('post-' + m[1]);
    if (target && target.classList.contains('post-card')) {
      window.addEventListener('load', function () { open(target, { fromHash: true }); });
    }
  }

  return {
    open: open,
    close: function () { close(); },
    focusComment: focusComment,
    isOpen: function (postId) { return !!cur && cur.id === String(postId); },
    closeIfShowing: function (postId) { if (cur && cur.id === String(postId)) close(); }
  };
})();

</script>

<%-- ============================================================
     MODAL CHỈNH SỬA BÀI VIẾT
     ============================================================ --%>
<div class="modal-overlay" id="edit-post-modal" role="dialog" aria-modal="true" aria-labelledby="edit-post-title">
  <article class="modal modal-compose">
    <header class="modal-header">
      <h2 id="edit-post-title">Chỉnh sửa bài viết</h2>
      <button type="button" class="modal-close" onclick="closeModal('edit-post-modal')" aria-label="Đóng">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>
    <div class="modal-body">
      <input type="hidden" id="edit-post-id" value="">
      <div class="field">
        <label class="u-visually-hidden" for="edit-post-content">Nội dung bài viết</label>
        <textarea class="compose-textarea" id="edit-post-content" rows="5"
                  placeholder="Chỉnh sửa nội dung..."></textarea>
      </div>
      <div class="field" style="margin-top:10px;">
        <label for="edit-post-visibility" style="font-size:0.85rem;color:var(--ink-muted);margin-bottom:4px;display:block;">Chế độ hiển thị</label>
        <select class="visibility-select" id="edit-post-visibility" onchange="syncPrivacyHint(this, 'edit-privacy-hint')">
          <option value="public">🌐 Công khai</option>
          <option value="friends">👥 Bạn bè</option>
          <option value="private">🔒 Chỉ mình tôi (ẩn bài)</option>
        </select>
        <p class="privacy-hint" id="edit-privacy-hint" hidden>
          <svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>
          Bài sẽ bị ẩn với mọi người, chỉ bạn còn thấy trong trang cá nhân.
        </p>
      </div>
    </div>
    <div class="modal-footer">
      <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('edit-post-modal')">Hủy</button>
      <button type="button" class="btn-pill" id="edit-post-submit-btn" onclick="handleEditPost()">
        <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> Lưu thay đổi
      </button>
    </div>
  </article>
</div>

<%-- Bộ lọc từ khóa của người xem (LayoutSupport) + công cụ AI trên bài + media nâng cao --%>
<script type="application/json" id="ut-filter-terms">${not empty filterTermsJson ? filterTermsJson : '[]'}</script>
<script src="${ctx}/assets/js/post-ai.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
<script src="${ctx}/assets/js/post-media.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
