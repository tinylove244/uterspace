/* ============================================================
   realtime.js — kết nối thời gian thực dùng chung cho MỌI trang đã đăng nhập (nạp từ footer.jsp).

   1. WebSocket ws(s)://<host><ctx>/ws: server ĐẨY sự kiện xuống ngay khi có (tin nhắn, đang gõ, đã xem,
      thông báo, lời mời kết bạn, online/offline). Mỗi sự kiện được phát lại thành CustomEvent "rt:<type>"
      trên document để từng trang tự xử lý (chat.js, trang Bạn bè, trang Thông báo...).
   2. Mất kết nối → tự nối lại với thời gian chờ tăng dần (1s, 2s, 4s… tối đa 30s), nối lại ngay khi có mạng
      hoặc khi quay lại tab. Nối lại xong phát "rt:resync" để các trang tải bù dữ liệu bị lỡ.
   3. Dự phòng: /api/pulse mỗi 12 giây khi KHÔNG có WebSocket (60 giây khi có — chỉ để đồng bộ lại).
   4. Huy hiệu (data-badge="chat|notif|friend"), toast thông báo, thông báo màn hình (Notification API),
      chấm online (data-presence-user), hộp xác nhận dùng chung UTConfirm().
   Mọi chữ lấy từ server được gán bằng textContent (không innerHTML) → an toàn XSS.
   ============================================================ */
(function () {
  'use strict';
  var UT = window.UT || {};
  var CTX = UT.ctx || '';
  var baseTitle = document.title.replace(/^\(\d+\+?\)\s*/, '');

  function emit(type, detail) {
    document.dispatchEvent(new CustomEvent('rt:' + type, { detail: detail || {} }));
  }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  /* ---------------------------------------------------------- Huy hiệu */
  var counts = { chat: 0, notif: 0, friend: 0 };
  function applyBadge(kind, n) {
    counts[kind] = n;
    document.querySelectorAll('[data-badge="' + kind + '"]').forEach(function (b) {
      b.hidden = !(n > 0);
      (b.querySelector('[data-badge-num]') || b).textContent = n > 99 ? '99+' : n;
    });
  }
  function setBadges(d) {
    if (d.unreadChat != null) applyBadge('chat', d.unreadChat);
    if (d.unreadNotif != null) applyBadge('notif', d.unreadNotif);
    if (d.friendRequests != null) applyBadge('friend', d.friendRequests);
    var total = counts.chat + counts.notif;
    document.title = (total > 0 ? '(' + (total > 99 ? '99+' : total) + ') ' : '') + baseTitle;
    document.dispatchEvent(new CustomEvent('uterspace:pulse', { detail: d }));   // tên sự kiện cũ, giữ tương thích
  }
  document.addEventListener('rt:badge', function (e) { setBadges(e.detail); });

  /* ---------------------------------------------------------- WebSocket */
  var ws = null, retry = 0, reconnectTimer = null, pingTimer = null, state = 'connecting', everOpened = false;

  function setState(s) {
    state = s;
    document.documentElement.setAttribute('data-rt', s);
    emit('status', { state: s });
  }

  function connect() {
    clearTimeout(reconnectTimer);
    if (!('WebSocket' in window)) { setState('unsupported'); return; }
    if (ws && (ws.readyState === 0 || ws.readyState === 1)) return;
    setState('connecting');
    try {
      ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + CTX + '/ws');
    } catch (e) { scheduleReconnect(); return; }
    ws.onopen = function () {
      retry = 0;
      setState('open');
      clearInterval(pingTimer);
      pingTimer = setInterval(function () { send({ type: 'ping' }); }, 25000);
      if (everOpened) emit('resync', {});      // nối lại sau khi mất kết nối → các trang tải bù
      everOpened = true;
      schedulePulse();
    };
    ws.onmessage = function (e) {
      var d;
      try { d = JSON.parse(e.data); } catch (x) { return; }
      if (d && d.type) emit(d.type, d);
    };
    ws.onclose = function (ev) {
      clearInterval(pingTimer);
      setState(navigator.onLine === false ? 'offline' : 'closed');
      schedulePulse();
      if (ev.code === 1008) return;            // chưa đăng nhập / phiên đã hết: không thử lại (pulse sẽ đưa về trang đăng nhập)
      scheduleReconnect();
    };
    ws.onerror = function () { /* onclose sẽ chạy ngay sau */ };
  }

  function scheduleReconnect() {
    clearTimeout(reconnectTimer);
    var delay = Math.min(30000, 1000 * Math.pow(2, retry++)) + Math.floor(Math.random() * 400);
    reconnectTimer = setTimeout(connect, delay);
  }

  function send(obj) {
    if (ws && ws.readyState === 1) { ws.send(JSON.stringify(obj)); return true; }
    return false;
  }

  window.addEventListener('online', function () { retry = 0; connect(); pulse(); });
  window.addEventListener('offline', function () { setState('offline'); });

  /* ---------------------------------------------------------- Pulse dự phòng */
  var pulseTimer = null;
  function schedulePulse() {
    clearTimeout(pulseTimer);
    if (!document.hidden) pulseTimer = setTimeout(pulse, state === 'open' ? 60000 : 12000);
  }
  function pulse() {
    fetch(CTX + '/api/pulse', { headers: { 'Accept': 'application/json' } })
      .then(function (r) { if (!r.ok) throw r.status; return r.json(); })
      .then(function (d) { setBadges(d); schedulePulse(); })
      .catch(function (status) {
        // 401: hết phiên hoặc tài khoản vừa bị khóa → tải lại để AuthFilter đưa về trang đăng nhập (kèm lý do)
        if (status === 401) location.reload(); else schedulePulse();
      });
  }
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { clearTimeout(pulseTimer); return; }
    pulse();
    if (!ws || ws.readyState > 1) { retry = 0; connect(); }
  });

  /* ---------------------------------------------------------- Thông báo: toast + màn hình */
  function avatarNode(name, initials, avatar, cls) {
    var box = el('span', cls || 'rt-avatar');
    if (avatar) { var img = el('img'); img.src = CTX + avatar; img.alt = ''; box.appendChild(img); }
    else box.textContent = initials || (name ? name.charAt(0) : '?');
    return box;
  }

  function toastNotification(n) {
    var wrap = document.getElementById('rt-toasts');
    if (!wrap) { wrap = el('div', 'rt-toasts'); wrap.id = 'rt-toasts'; wrap.setAttribute('aria-live', 'polite'); document.body.appendChild(wrap); }
    while (wrap.children.length >= 3) wrap.removeChild(wrap.firstChild);
    var a = el('a', 'rt-toast');
    a.href = CTX + n.url;
    var av = avatarNode(n.actorName, n.actorInitials, n.actorAvatar);
    av.appendChild(el('span', 'rt-toast-icon', n.icon));
    a.appendChild(av);
    var body = el('span', 'rt-toast-body');
    var text = el('span', 'rt-toast-text');
    text.appendChild(el('b', null, n.actorName));
    text.appendChild(document.createTextNode(' ' + n.content));
    body.appendChild(text);
    body.appendChild(el('span', 'rt-toast-time', n.time || 'Vừa xong'));
    a.appendChild(body);
    var close = el('button', 'rt-toast-close', '×');
    close.type = 'button';
    close.setAttribute('aria-label', 'Đóng thông báo');
    close.addEventListener('click', function (e) { e.preventDefault(); a.remove(); });
    a.appendChild(close);
    wrap.appendChild(a);
    setTimeout(function () { a.classList.add('is-leaving'); setTimeout(function () { a.remove(); }, 300); }, 7000);
  }

  function desktop(n) {
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    try {
      var d = new Notification(n.actorName + ' · UTErSpace', {
        body: n.content,
        icon: n.actorAvatar ? CTX + n.actorAvatar : undefined,
        tag: 'ut-' + (n.refKey || n.id)          // cùng hội thoại → thay thông báo cũ thay vì chồng thêm
      });
      d.onclick = function () { window.focus(); location.href = CTX + n.url; d.close(); };
    } catch (e) { /* trình duyệt chặn: bỏ qua */ }
  }

  document.addEventListener('rt:notification', function (e) {
    var d = e.detail, n = d.notification;
    setBadges({ unreadNotif: d.unreadNotif });
    // Đang mở đúng hội thoại đó ở trang Tin nhắn → không làm phiền (tin đã hiện ngay trong khung chat)
    if (n.refKey && window.UTChat && n.refKey === 'conv:' + window.UTChat.activeId() && !document.hidden) return;
    if (!document.hidden) toastNotification(n);
    if (d.push && (document.hidden || !document.hasFocus())) desktop(n);
  });

  /* ---------------------------------------------------------- Online / offline */
  document.addEventListener('rt:presence', function (e) {
    var d = e.detail;
    document.querySelectorAll('[data-presence-user="' + d.userId + '"]').forEach(function (x) {
      x.classList.toggle('is-online', !!d.online);
      x.setAttribute('title', d.label || '');
    });
    document.querySelectorAll('[data-presence-label="' + d.userId + '"]').forEach(function (x) {
      x.textContent = d.label || '';
    });
  });

  /* ---------------------------------------------------------- Hộp xác nhận dùng chung */
  /** UTConfirm({title, message, ok, danger}) → Promise<boolean> */
  window.UTConfirm = function (opts) {
    return new Promise(function (resolve) {
      var overlay = el('div', 'modal-overlay open ut-confirm');
      overlay.setAttribute('role', 'alertdialog');
      overlay.setAttribute('aria-modal', 'true');
      var box = el('article', 'modal modal-compose');
      var head = el('header', 'modal-header');
      head.appendChild(el('h2', null, opts.title || 'Xác nhận'));
      box.appendChild(head);
      var body = el('div', 'modal-body');
      body.appendChild(el('p', 'ut-confirm-text', opts.message || ''));
      box.appendChild(body);
      var foot = el('footer', 'modal-footer');
      var cancel = el('button', 'btn-pill btn-pill--ghost', opts.cancel || 'Hủy');
      var ok = el('button', 'btn-pill' + (opts.danger ? ' btn-pill--accent' : ''), opts.ok || 'Đồng ý');
      cancel.type = ok.type = 'button';
      foot.appendChild(cancel);
      foot.appendChild(ok);
      box.appendChild(foot);
      overlay.appendChild(box);
      document.body.appendChild(overlay);
      ok.focus();
      function done(v) { overlay.remove(); document.removeEventListener('keydown', onKey); resolve(v); }
      function onKey(ev) { if (ev.key === 'Escape') done(false); }
      cancel.addEventListener('click', function () { done(false); });
      ok.addEventListener('click', function () { done(true); });
      overlay.addEventListener('click', function (ev) { if (ev.target === overlay) done(false); });
      document.addEventListener('keydown', onKey);
    });
  };

  /* ---------------------------------------------------------- Khởi động */
  window.RT = {
    send: send,
    isOpen: function () { return !!ws && ws.readyState === 1; },
    state: function () { return state; },
    wasOpen: function () { return everOpened; },   // đã từng kết nối được (phân biệt "đang kết nối lần đầu" với "mất kết nối")
    counts: counts,
    reconnect: function () { retry = 0; connect(); }
  };
  setState('connecting');
  connect();
  schedulePulse();
})();
