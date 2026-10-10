<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%--
  story-viewer.jsp — Trình xem Tin toàn màn hình (kiểu Instagram/Facebook).
    - Thanh tiến trình chia đoạn ở trên; ảnh hiện 5 giây, video chạy hết thời lượng rồi tự sang tin kế.
    - Bấm nửa trái / phải (hoặc phím ← →) để lùi / tới; hết tin của một người thì sang người kế trên thanh Tin.
    - Giữ chuột / ngón tay trên tin hoặc phím Space để tạm dừng; Esc để đóng.
    - Xem tin của bạn bè → POST /stories/view (vòng tròn chuyển xám). Chủ tin: xem danh sách người đã xem, xóa tin.
    - Người xem: thả ❤️ (nút tim hoặc phím L) và trả lời tin — câu trả lời gửi thành tin nhắn riêng tới chủ tin.
    - Chủ tin: số người xem + số tim; danh sách người xem đưa người đã thả tim lên đầu kèm ❤️.
  Thứ tự người lấy từ các nút [data-story-user] trên thanh Tin. Mọi chữ từ người dùng gán bằng textContent.
  Yêu cầu: ctx.
--%>
<div class="story-viewer" id="story-viewer" role="dialog" aria-modal="true" aria-label="Xem tin" hidden>
  <button type="button" class="sv-close" onclick="closeStories()" aria-label="Đóng (Esc)">
    <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
  </button>
  <button type="button" class="sv-nav sv-nav--prev" onclick="storyPrev()" aria-label="Tin trước">‹</button>

  <div class="sv-stage" id="sv-stage">
    <div class="sv-progress" id="sv-progress" aria-hidden="true"></div>

    <header class="sv-head">
      <a class="sv-author" id="sv-author" href="#">
        <span class="sv-avatar" id="sv-avatar"></span>
        <span class="sv-author-text">
          <b id="sv-name"></b>
          <time id="sv-time"></time>
        </span>
      </a>
      <span class="sv-tools">
        <button type="button" class="sv-tool" id="sv-mute" onclick="toggleStoryMute()" aria-label="Bật/tắt tiếng" hidden>🔊</button>
        <button type="button" class="sv-tool" id="sv-pause" onclick="toggleStoryPause()" aria-label="Tạm dừng (Space)">❚❚</button>
        <button type="button" class="sv-tool" id="sv-delete" onclick="deleteCurrentStory()" aria-label="Xóa tin này" hidden>
          <svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg>
        </button>
      </span>
    </header>

    <div class="sv-media" id="sv-media"></div>
    <%-- Vùng bấm: trái = lùi, phải = tới; giữ để tạm dừng --%>
    <div class="sv-tap sv-tap--left"  data-dir="-1"></div>
    <div class="sv-tap sv-tap--right" data-dir="1"></div>

    <p class="sv-caption" id="sv-caption" hidden></p>

    <footer class="sv-foot" id="sv-foot" hidden>
      <button type="button" class="sv-viewers-btn" id="sv-viewers-btn" onclick="showStoryViewers()">
        <svg class="icon" aria-hidden="true"><use href="#i-eye"></use></svg>
        <span id="sv-views">0 người đã xem</span>
        <span class="sv-hearts" id="sv-hearts" hidden>❤️ <b id="sv-hearts-n">0</b></span>
      </button>
    </footer>

    <%-- Người xem (không phải chủ tin): trả lời + thả tim --%>
    <form class="sv-reply" id="sv-reply" hidden onsubmit="return sendStoryReply(event)">
      <label class="u-visually-hidden" for="sv-reply-input">Trả lời tin</label>
      <input type="text" id="sv-reply-input" maxlength="500" autocomplete="off" placeholder="Trả lời tin…">
      <button type="submit" class="sv-reply-send" id="sv-reply-send" aria-label="Gửi trả lời" hidden>
        <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg>
      </button>
      <button type="button" class="sv-heart" id="sv-heart" onclick="toggleStoryHeart()" aria-pressed="false" aria-label="Thả tim tin này">
        <svg class="icon" aria-hidden="true"><use href="#i-heart"></use></svg>
      </button>
    </form>
    <span class="sv-heart-burst" id="sv-heart-burst" aria-hidden="true">❤️</span>

    <section class="sv-viewers" id="sv-viewers" hidden aria-label="Người đã xem tin">
      <header>
        <b>Người đã xem</b>
        <button type="button" onclick="hideStoryViewers()" aria-label="Đóng danh sách">
          <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
        </button>
      </header>
      <ul id="sv-viewers-list"></ul>
    </section>
  </div>

  <button type="button" class="sv-nav sv-nav--next" onclick="storyNext()" aria-label="Tin tiếp theo">›</button>
</div>

<script>
(function () {
  var CTXS = '${ctx}';
  var IMAGE_MS = 5000;
  var viewer = document.getElementById('story-viewer');
  var mediaBox = document.getElementById('sv-media');
  var S = { userId: null, own: false, stories: [], idx: 0, now: null, raf: null,
            startedAt: 0, elapsed: 0, paused: false, holdPaused: false, video: null, muted: false };

  function order() {
    return Array.prototype.map.call(document.querySelectorAll('[data-story-user]'),
                                    function (b) { return Number(b.getAttribute('data-story-user')); });
  }
  function ago(createdAt) {
    var diff = Math.max(0, (new Date(S.now) - new Date(createdAt)) / 1000);
    if (diff < 60) return 'vừa xong';
    if (diff < 3600) return Math.floor(diff / 60) + ' phút trước';
    return Math.floor(diff / 3600) + ' giờ trước';
  }
  function avatarNode(a) {
    var box = document.getElementById('sv-avatar');
    box.textContent = '';
    if (a.avatar) { var img = document.createElement('img'); img.src = a.avatar; img.alt = ''; box.appendChild(img); }
    else box.textContent = a.initials;
  }

  /* ---------- Mở tin của một người ---------- */
  window.openStories = function (userId, fromEnd) {
    fetch(CTXS + '/stories/user?id=' + encodeURIComponent(userId), { headers: { 'Accept': 'application/json' } })
      .then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
      .then(function (r) {
        if (!r.ok) throw new Error(r.d.error || 'Không mở được tin');
        if (!r.d.stories.length) { showToast('Tin đã hết hạn hoặc đã bị xóa.', 'error'); return; }
        S.userId = userId; S.own = r.d.own; S.stories = r.d.stories; S.now = r.d.now;
        // Bắt đầu từ tin đầu tiên chưa xem (xem hết rồi thì từ đầu); lùi từ người sau → tin cuối
        var first = 0;
        if (fromEnd) first = S.stories.length - 1;
        else for (var i = 0; i < S.stories.length; i++) { if (!S.stories[i].seen) { first = i; break; } }
        buildProgress();
        viewer.hidden = false;
        document.body.style.overflow = 'hidden';
        show(first);
      })
      .catch(function (err) { showToast(err.message, 'error'); });
  };

  window.closeStories = function () {
    stop();
    viewer.hidden = true;
    hideStoryViewers();
    document.body.style.overflow = '';
    refreshRing(S.userId);
  };

  function buildProgress() {
    var bar = document.getElementById('sv-progress');
    bar.textContent = '';
    S.stories.forEach(function () {
      var seg = document.createElement('span');
      seg.appendChild(document.createElement('i'));
      bar.appendChild(seg);
    });
  }
  function setProgress(i, frac) {
    var segs = document.querySelectorAll('#sv-progress i');
    segs.forEach(function (s, k) { s.style.width = (k < i ? 100 : k > i ? 0 : Math.min(100, frac * 100)) + '%'; });
  }

  function stop() {
    cancelAnimationFrame(S.raf);
    if (S.video) { S.video.pause(); S.video = null; }
    mediaBox.textContent = '';
  }

  /* ---------- Hiện tin thứ i ---------- */
  function show(i) {
    stop();
    S.idx = i; S.elapsed = 0; S.paused = false; S.holdPaused = false;
    var st = S.stories[i];
    avatarNode(st.author);
    document.getElementById('sv-name').textContent = st.author.name;
    document.getElementById('sv-author').href = CTXS + '/profile?userId=' + st.author.id;
    document.getElementById('sv-time').textContent = ago(st.createdAt);
    var cap = document.getElementById('sv-caption');
    cap.textContent = st.caption || '';
    cap.hidden = !st.caption;
    document.getElementById('sv-delete').hidden = !S.own;
    document.getElementById('sv-foot').hidden = !S.own;
    document.getElementById('sv-views').textContent = st.views + ' người đã xem';
    document.getElementById('sv-hearts').hidden = !S.own || !st.reactions;
    document.getElementById('sv-hearts-n').textContent = st.reactions || 0;
    document.getElementById('sv-reply').hidden = S.own;
    document.getElementById('sv-reply-input').value = '';
    document.getElementById('sv-reply-send').hidden = true;
    renderHeart(st);
    document.getElementById('sv-mute').hidden = st.type !== 'VIDEO';
    document.getElementById('sv-pause').textContent = '❚❚';
    hideStoryViewers();
    setProgress(i, 0);

    if (st.type === 'VIDEO') {
      var v = document.createElement('video');
      v.src = st.url; v.playsInline = true; v.preload = 'auto'; v.muted = S.muted;
      v.addEventListener('ended', function () { storyNext(); });
      v.addEventListener('error', function () { showToast('Không phát được video này.', 'error'); });
      mediaBox.appendChild(v);
      S.video = v;
      // Mở tin là một cú bấm của người dùng nên được phát kèm tiếng; trình duyệt chặn thì phát không tiếng
      v.play().catch(function () { v.muted = true; S.muted = true; updateMute(); v.play().catch(function () { }); });
      updateMute();
    } else {
      var img = document.createElement('img');
      img.src = st.url; img.alt = st.caption ? st.caption : 'Tin của ' + st.author.name;
      mediaBox.appendChild(img);
    }
    S.startedAt = performance.now();
    tick();

    if (!S.own && !st.seen) {
      st.seen = true;
      fetch(CTXS + '/stories/view', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
        body: 'id=' + st.id
      }).catch(function () { });
    }
    // Tải trước tin kế tiếp cho mượt
    var nx = S.stories[i + 1];
    if (nx && nx.type === 'IMAGE') { var pre = new Image(); pre.src = nx.url; }
  }

  function tick() {
    var st = S.stories[S.idx];
    if (!S.paused && !S.holdPaused) {
      if (st.type === 'VIDEO' && S.video) {
        var d = S.video.duration;
        setProgress(S.idx, d ? S.video.currentTime / d : 0);
      } else {
        var t = S.elapsed + (performance.now() - S.startedAt);
        setProgress(S.idx, t / IMAGE_MS);
        if (t >= IMAGE_MS) { storyNext(); return; }
      }
    }
    S.raf = requestAnimationFrame(tick);
  }

  function pause(on) {
    var st = S.stories[S.idx];
    if (on) {
      if (st.type !== 'VIDEO') S.elapsed += performance.now() - S.startedAt;
      if (S.video) S.video.pause();
    } else {
      S.startedAt = performance.now();
      if (S.video) S.video.play().catch(function () { });
    }
  }
  window.toggleStoryPause = function () {
    S.paused = !S.paused;
    pause(S.paused);
    document.getElementById('sv-pause').textContent = S.paused ? '▶' : '❚❚';
  };
  function updateMute() { document.getElementById('sv-mute').textContent = S.muted ? '🔇' : '🔊'; }
  window.toggleStoryMute = function () {
    S.muted = !S.muted;
    if (S.video) S.video.muted = S.muted;
    updateMute();
  };

  /* ---------- Điều hướng ---------- */
  function neighbour(step) {
    var list = order(), at = list.indexOf(S.userId);
    return at >= 0 ? list[at + step] : undefined;
  }
  window.storyNext = function () {
    if (S.idx < S.stories.length - 1) { show(S.idx + 1); return; }
    var nextUser = neighbour(1);
    refreshRing(S.userId);
    if (nextUser !== undefined) { stop(); openStories(nextUser); } else closeStories();
  };
  window.storyPrev = function () {
    if (S.idx > 0) { show(S.idx - 1); return; }
    var prevUser = neighbour(-1);
    if (prevUser !== undefined) { stop(); refreshRing(S.userId); openStories(prevUser, true); }
    else show(0);
  };

  /* Vùng bấm: chạm nhanh = chuyển tin, giữ lâu (> 250ms) = tạm dừng tới khi thả */
  document.querySelectorAll('.sv-tap').forEach(function (zone) {
    var downAt = 0, holdTimer = null;
    zone.addEventListener('pointerdown', function () {
      downAt = Date.now();
      holdTimer = setTimeout(function () { S.holdPaused = true; pause(true); }, 250);
    });
    zone.addEventListener('pointerup', function () {
      clearTimeout(holdTimer);
      if (S.holdPaused) { S.holdPaused = false; if (!S.paused) pause(false); return; }
      if (Date.now() - downAt < 250) { zone.getAttribute('data-dir') === '1' ? storyNext() : storyPrev(); }
    });
    zone.addEventListener('pointerleave', function () {
      clearTimeout(holdTimer);
      if (S.holdPaused) { S.holdPaused = false; if (!S.paused) pause(false); }
    });
  });

  document.addEventListener('keydown', function (e) {
    if (viewer.hidden || e.target.id === 'sv-reply-input') return;
    if (e.key === 'Escape') closeStories();
    else if (e.key === 'ArrowRight') storyNext();
    else if (e.key === 'ArrowLeft') storyPrev();
    else if (e.key === ' ') { e.preventDefault(); toggleStoryPause(); }
    else if (e.key === 'l' || e.key === 'L') toggleStoryHeart();
  });
  // Bấm vùng tối bên ngoài khung tin để đóng
  viewer.addEventListener('click', function (e) { if (e.target === viewer) closeStories(); });

  /* ---------- Người xem: thả tim + trả lời ---------- */
  function renderHeart(st) {
    var b = document.getElementById('sv-heart');
    b.classList.toggle('is-active', !!st.liked);
    b.setAttribute('aria-pressed', String(!!st.liked));
    b.setAttribute('aria-label', st.liked ? 'Bỏ tim tin này' : 'Thả tim tin này');
  }
  function burst() {
    var h = document.getElementById('sv-heart-burst');
    h.classList.remove('is-on'); void h.offsetWidth; h.classList.add('is-on');
  }
  window.toggleStoryHeart = function (forceLike) {
    var st = S.stories[S.idx];
    if (!st || S.own) return;
    if (forceLike && st.liked) { burst(); return; }   // nhấp đúp khi đã thích: chỉ hiệu ứng
    st.liked = !st.liked;
    renderHeart(st);
    if (st.liked) burst();
    fetch(CTXS + '/stories/react', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
      body: 'id=' + st.id
    })
      .then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
      .then(function (r) {
        if (!r.ok) throw new Error(r.d.error || 'Không thả tim được');
        st.liked = r.d.liked; st.seen = true;
        renderHeart(st);
      })
      .catch(function (err) { st.liked = !st.liked; renderHeart(st); showToast(err.message, 'error'); });
  };
  window.sendStoryReply = function (e) {
    e.preventDefault();
    var st = S.stories[S.idx], input = document.getElementById('sv-reply-input');
    var text = input.value.trim();
    if (!text) return false;
    input.disabled = true;
    fetch(CTXS + '/stories/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
      body: 'id=' + st.id + '&content=' + encodeURIComponent(text)
    })
      .then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
      .then(function (r) {
        if (!r.ok) throw new Error(r.d.error || 'Không gửi được');
        input.value = '';
        document.getElementById('sv-reply-send').hidden = true;
        showToast('Đã gửi trả lời tới ' + st.author.name + ' 💬', 'success');
      })
      .catch(function (err) { showToast(err.message, 'error'); })
      .then(function () { input.disabled = false; input.blur(); if (S.paused && S.replyPaused) { S.replyPaused = false; toggleStoryPause(); } });
    return false;
  };
  (function () {
    var input = document.getElementById('sv-reply-input');
    // Đang gõ trả lời → tạm dừng tin để không bị chuyển mất; rời ô (chưa gõ gì) → chạy tiếp
    input.addEventListener('focus', function () { if (!S.paused) { S.replyPaused = true; toggleStoryPause(); } });
    input.addEventListener('blur', function () {
      if (!input.value.trim() && S.replyPaused && S.paused) { S.replyPaused = false; toggleStoryPause(); }
    });
    input.addEventListener('input', function () { document.getElementById('sv-reply-send').hidden = !input.value.trim(); });
    input.addEventListener('keydown', function (e) { e.stopPropagation(); if (e.key === 'Escape') input.blur(); });
  })();

  /* ---------- Chủ tin: người đã xem, xóa tin ---------- */
  window.showStoryViewers = function () {
    var st = S.stories[S.idx];
    if (!S.paused) toggleStoryPause();
    var list = document.getElementById('sv-viewers-list');
    list.textContent = '';
    document.getElementById('sv-viewers').hidden = false;
    fetch(CTXS + '/stories/viewers?id=' + st.id, { headers: { 'Accept': 'application/json' } })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d.viewers || !d.viewers.length) {
          var li = document.createElement('li');
          li.className = 'sv-viewers-empty';
          li.textContent = 'Chưa có ai xem tin này.';
          list.appendChild(li);
          return;
        }
        d.viewers.forEach(function (v) {
          var li = document.createElement('li');
          var a = document.createElement('a');
          a.href = CTXS + '/profile?userId=' + v.id;
          var av = document.createElement('span');
          av.className = 'sv-avatar';
          if (v.avatar) { var img = document.createElement('img'); img.src = CTXS + v.avatar; img.alt = ''; av.appendChild(img); }
          else av.textContent = v.initials;
          var name = document.createElement('b'); name.textContent = v.name;
          var t = document.createElement('small'); t.textContent = ago(v.viewedAt);
          a.appendChild(av); a.appendChild(name); a.appendChild(t);
          if (v.liked) {
            var heart = document.createElement('span');
            heart.className = 'sv-viewer-heart';
            heart.textContent = '❤️';
            heart.title = v.name + ' đã thả tim';
            a.appendChild(heart);
          }
          li.appendChild(a);
          list.appendChild(li);
        });
      });
  };
  window.hideStoryViewers = function () { document.getElementById('sv-viewers').hidden = true; };

  window.deleteCurrentStory = function () {
    var st = S.stories[S.idx];
    if (!S.paused) toggleStoryPause();
    if (!confirm('Xóa tin này? Không thể hoàn tác.')) { toggleStoryPause(); return; }
    fetch(CTXS + '/stories/delete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
      body: 'id=' + st.id
    })
      .then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
      .then(function (r) {
        if (!r.ok) throw new Error(r.d.error || 'Không xóa được tin');
        showToast('Đã xóa tin.', 'success');
        S.stories.splice(S.idx, 1);
        if (!S.stories.length) { closeStories(); setTimeout(function () { location.reload(); }, 500); return; }
        buildProgress();
        show(Math.min(S.idx, S.stories.length - 1));
      })
      .catch(function (err) { showToast(err.message, 'error'); });
  };

  /** Xem hết tin của một người → vòng tròn của họ trên thanh Tin chuyển xám */
  function refreshRing(userId) {
    if (S.own || userId == null) return;
    var allSeen = S.stories.every(function (s) { return s.seen; });
    var btn = document.querySelector('[data-story-user="' + userId + '"] .story-ring');
    if (btn && allSeen) btn.classList.add('is-seen');
  }
})();

/* Thông báo "đã thả tim tin của bạn" trỏ tới /feed?story=<id> → mở luôn tin của người đó nếu còn trên thanh Tin */
(function () {
  var m = /[?&]story=(\d+)/.exec(location.search);
  if (m && document.querySelector('[data-story-user="' + m[1] + '"]')) openStories(Number(m[1]));
})();
</script>
