<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>

<!-- ============================================================
     FOOTER + GLOBAL JS
     Include at bottom of every page body
     ============================================================ -->

<footer style="text-align:center;padding:24px 16px 16px;font-size:12px;color:var(--ink-muted);border-top:1px solid var(--line);margin-top:40px;">
  © 2026 UTErSpace &nbsp;·&nbsp;
  <a href="#" style="color:var(--ink-muted);text-decoration:underline;">Điều khoản</a> &nbsp;·&nbsp;
  <a href="#" style="color:var(--ink-muted);text-decoration:underline;">Bảo mật</a>
</footer>

<!-- ============================================================
     GLOBAL JS — Toast, Dropdown, Modals
     ============================================================ -->
<script>
/* ---------- Toast ---------- */
function showToast(msg, type = '') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const toast = document.createElement('div');
  toast.className = 'toast' + (type ? ' ' + type : '');
  toast.textContent = msg;
  container.appendChild(toast);
  setTimeout(() => {
    toast.classList.add('hiding');
    toast.addEventListener('animationend', () => toast.remove());
  }, 3000);
}

/* ---------- Dropdown (close on outside click) ---------- */
document.addEventListener('click', function(e) {
  document.querySelectorAll('.dropdown-menu.open').forEach(menu => {
    if (!menu.closest('.dropdown').contains(e.target)) {
      menu.classList.remove('open');
    }
  });
});

function toggleUserMenu() {
  const menu = document.getElementById('user-menu');
  if (menu) menu.classList.toggle('open');
}

function toggleNotifDropdown() {
  const menu = document.getElementById('notif-dropdown');
  if (menu) menu.classList.toggle('open');
}

/* ---------- Modal helpers ---------- */
function openModal(id) {
  const overlay = document.getElementById(id);
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
}
function closeModal(id) {
  const overlay = document.getElementById(id);
  if (overlay) overlay.classList.remove('open');
  document.body.style.overflow = '';
}
// Close modal on overlay click
document.addEventListener('click', function(e) {
  if (e.target.classList.contains('modal-overlay')) {
    e.target.classList.remove('open');
    document.body.style.overflow = '';
  }
});
// Close modal on Escape
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    document.querySelectorAll('.modal-overlay.open').forEach(m => {
      m.classList.remove('open');
      document.body.style.overflow = '';
    });
  }
});

/* ---------- Hashtag ---------- */
// Cùng quy tắc với HashtagUtil.java: '#' đứng đầu hoặc sau khoảng trắng/dấu câu,
// theo sau là chữ (kể cả tiếng Việt có dấu), số hoặc '_'.
const HASHTAG_RE = /(^|[^\p{L}\p{M}\p{N}_&\/])#([\p{L}\p{M}\p{N}_]+)/gu;

// Biến "#tag" trong phần tử thành link tới trang /hashtag (chỉ đọc textContent → an toàn XSS)
function linkifyHashtags(el) {
  const text = el.textContent;
  const frag = document.createDocumentFragment();
  let last = 0, m;
  HASHTAG_RE.lastIndex = 0;
  while ((m = HASHTAG_RE.exec(text)) !== null) {
    const start = m.index + m[1].length;
    if (start > last) frag.appendChild(document.createTextNode(text.slice(last, start)));
    const a = document.createElement('a');
    a.className = 'hashtag';
    a.href = '${pageContext.request.contextPath}/hashtag?tag=' + encodeURIComponent(m[2]);
    a.textContent = '#' + m[2];
    frag.appendChild(a);
    last = start + 1 + m[2].length;
  }
  if (last === 0) return;
  if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
  el.textContent = '';
  el.appendChild(frag);
}
document.querySelectorAll('.post-caption-text, .shared-embed-text').forEach(linkifyHashtags);

/* ---------- Video: tự phát video đang ở giữa màn hình, mỗi lúc chỉ một video chạy ----------
   Trình duyệt chỉ cho autoplay khi muted → video có data-autoplay bắt đầu tắt tiếng
   (người xem bật tiếng bằng thanh điều khiển). Tiết kiệm băng thông và CPU. */
(function () {
  const videos = document.querySelectorAll('video[data-autoplay]');
  if (!videos.length) return;

  function autoPause(v) { if (!v.paused) { v._autoPause = true; v.pause(); } }

  videos.forEach(function (v) {
    v.addEventListener('play', function () {
      v._userPaused = false;
      videos.forEach(function (o) { if (o !== v) autoPause(o); });   // chỉ một video chạy
    });
    v.addEventListener('pause', function () {
      if (!v._autoPause && !v.ended) v._userPaused = true;           // người xem tự dừng → không tự phát lại
      v._autoPause = false;
    });
  });

  if (!('IntersectionObserver' in window)) return;
  const io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      const v = e.target;
      if (e.intersectionRatio >= 0.6) {
        if (!v._userPaused) v.play().catch(function () { /* bị chặn autoplay: để người xem tự bấm */ });
      } else {
        autoPause(v);
      }
    });
  }, { threshold: [0, 0.6] });
  videos.forEach(function (v) { io.observe(v); });
})();

// Ô tìm kiếm: gõ "#DoAnCuoiKy" → mở trang hashtag thay vì tìm thường
function searchHashtag(form) {
  const q = form.q.value.trim();
  if (q.charAt(0) !== '#') return true;
  const tag = q.replace(/^#+/, '');
  if (tag) window.location.href = '${pageContext.request.contextPath}/hashtag?tag=' + encodeURIComponent(tag);
  return false;
}
</script>

<c:if test="${not empty sessionScope.currentUser}">
<script>
/* ---------- Thanh tìm kiếm: gợi ý khi gõ + tìm kiếm gần đây ----------
   Gõ → chờ 200ms → GET /api/search/suggest (hủy request cũ bằng AbortController).
   ↑ ↓ chọn, Enter mở mục đang chọn (hoặc mở trang /search), Esc đóng.
   "Tìm kiếm gần đây" lưu trong localStorage của trình duyệt (chỉ là tiện ích, lỗi thì bỏ qua). */
var RECENT_SEARCH_KEY = 'uterspace.recentSearches';
function loadRecentSearches() {
  try { return JSON.parse(localStorage.getItem(RECENT_SEARCH_KEY)) || []; } catch (e) { return []; }
}
function saveRecentSearch(q) {
  q = (q || '').trim();
  if (!q) return;
  try {
    var list = loadRecentSearches().filter(function (x) { return x.toLowerCase() !== q.toLowerCase(); });
    list.unshift(q);
    localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(list.slice(0, 6)));
  } catch (e) { }
}
function submitGlobalSearch(form) {
  var q = form.q.value.trim();
  if (!q) { form.q.focus(); return false; }
  saveRecentSearch(q);
  return searchHashtag(form);
}

(function () {
  var input = document.getElementById('global-search');
  var box   = document.getElementById('search-suggest');
  if (!input || !box) return;
  var CTX = '${pageContext.request.contextPath}';
  var timer = null, ctrl = null, items = [], active = -1;

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function open()  { box.hidden = false; input.setAttribute('aria-expanded', 'true'); }
  function close() { box.hidden = true;  input.setAttribute('aria-expanded', 'false'); active = -1; input.removeAttribute('aria-activedescendant'); }

  function addItem(href, media, title, sub, saveQuery) {
    var a = el('a', 'suggest-item');
    a.href = href;
    a.id = 'suggest-opt-' + items.length;
    a.setAttribute('role', 'option');
    a.appendChild(media);
    var txt = el('span', 'suggest-text');
    txt.appendChild(el('span', 'suggest-title', title));
    if (sub) txt.appendChild(el('span', 'suggest-sub', sub));
    a.appendChild(txt);
    a.addEventListener('mousedown', function () { saveRecentSearch(saveQuery); });
    box.appendChild(a);
    items.push(a);
  }
  function iconMedia(symbol) {
    var m = el('span', 'suggest-media suggest-media--icon');
    m.innerHTML = '<svg class="icon" aria-hidden="true"><use href="#' + symbol + '"></use></svg>';   // chuỗi cố định, không có dữ liệu người dùng
    return m;
  }
  function section(label) { box.appendChild(el('p', 'suggest-section', label)); }

  function renderRecent() {
    var recent = loadRecentSearches();
    box.textContent = ''; items = []; active = -1;
    if (!recent.length) { close(); return; }
    var head = el('p', 'suggest-section', 'Tìm kiếm gần đây');
    var clear = el('button', 'suggest-clear', 'Xóa');
    clear.type = 'button';
    clear.addEventListener('mousedown', function (e) {
      e.preventDefault();
      try { localStorage.removeItem(RECENT_SEARCH_KEY); } catch (err) { }
      close();
    });
    head.appendChild(clear);
    box.appendChild(head);
    recent.forEach(function (q) {
      addItem(q.charAt(0) === '#' ? CTX + '/hashtag?tag=' + encodeURIComponent(q.replace(/^#+/, ''))
                                  : CTX + '/search?q=' + encodeURIComponent(q),
              iconMedia('i-clock'), q, null, q);
    });
    open();
  }

  function render(d) {
    box.textContent = ''; items = []; active = -1;
    var q = d.q;
    if (d.users.length) {
      section('Mọi người');
      d.users.forEach(function (u) {
        var m;
        if (u.avatar) { m = el('img', 'suggest-media'); m.src = CTX + u.avatar; m.alt = ''; }
        else          { m = el('span', 'suggest-media suggest-media--initials', u.initials); }
        addItem(CTX + '/profile?userId=' + u.id, m, u.name, u.sub, q);
      });
    }
    if (d.groups.length) {
      section('Nhóm');
      d.groups.forEach(function (g) {
        addItem(CTX + '/groups/view?id=' + g.id, el('span', 'suggest-media suggest-media--group', g.icon), g.name, g.sub, q);
      });
    }
    if (d.tags.length) {
      section('Hashtag');
      d.tags.forEach(function (t) {
        addItem(CTX + '/hashtag?tag=' + encodeURIComponent(t.tag), iconMedia('i-hashtag'), '#' + t.tag, t.count + ' bài viết', '#' + t.tag);
      });
    }
    // Mục cuối luôn có: mở trang kết quả đầy đủ (gồm cả bài viết)
    addItem(CTX + '/search?q=' + encodeURIComponent(q), iconMedia('i-search'),
            'Tìm “' + q + '”', 'Xem tất cả: mọi người, bài viết, nhóm, hashtag', q);
    items[items.length - 1].classList.add('suggest-item--all');
    open();
  }

  function query() {
    var q = input.value.trim();
    if (!q) { renderRecent(); return; }
    if (ctrl) ctrl.abort();
    ctrl = window.AbortController ? new AbortController() : null;
    fetch(CTX + '/api/search/suggest?q=' + encodeURIComponent(q),
          { headers: { 'Accept': 'application/json' }, signal: ctrl ? ctrl.signal : undefined })
      .then(function (r) { if (!r.ok) throw r.status; return r.json(); })
      .then(function (d) { if (d.q === input.value.trim().replace(/\s+/g, ' ')) render(d); })
      .catch(function () { /* bị hủy hoặc lỗi mạng: giữ nguyên gợi ý cũ */ });
  }

  function move(step) {
    if (!items.length) return;
    if (active >= 0) items[active].classList.remove('is-active');
    active = (active + step + items.length) % items.length;
    items[active].classList.add('is-active');
    items[active].scrollIntoView({ block: 'nearest' });
    input.setAttribute('aria-activedescendant', items[active].id);
  }

  input.addEventListener('input', function () {
    clearTimeout(timer);
    timer = setTimeout(query, 200);
  });
  input.addEventListener('focus', function () { if (!input.value.trim()) renderRecent(); else query(); });
  input.addEventListener('blur',  function () { setTimeout(close, 150); });
  input.addEventListener('keydown', function (e) {
    if (box.hidden) return;
    if (e.key === 'ArrowDown') { e.preventDefault(); move(1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); move(-1); }
    else if (e.key === 'Escape') { close(); }
    else if (e.key === 'Enter' && active >= 0) {
      e.preventDefault();
      saveRecentSearch(input.value);
      window.location.href = items[active].href;
    }
  });
})();
</script>
<%-- Kết nối thời gian thực (WebSocket + dự phòng /api/pulse), huy hiệu, toast thông báo, online, UTConfirm;
     nút quan hệ bạn bè dùng chung. Xem assets/js/realtime.js và relation.js --%>
<script>window.UT = { ctx: '${pageContext.request.contextPath}', me: ${sessionScope.currentUser.userId} };</script>
<script src="${pageContext.request.contextPath}/assets/js/realtime.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
<script src="${pageContext.request.contextPath}/assets/js/relation.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
</c:if>

<c:if test="${not empty extraJs}">
  <script src="${pageContext.request.contextPath}/assets/js/pages/${extraJs}?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
</c:if>

</body>
</html>
