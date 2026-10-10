/* ============================================================
   chat.js — trang Tin nhắn.

   Dữ liệu: JSON nhúng sẵn trong trang (#chat-convs, #chat-boot) + sự kiện WebSocket từ realtime.js:
     rt:chat.message   tin mới        rt:chat.update  sửa / thu hồi / cảm xúc / ghim
     rt:chat.receipt   đã nhận / xem  rt:chat.typing  đang gõ        rt:chat.remove  xóa phía mình
     rt:chat.conv      hội thoại đổi  rt:presence     online         rt:resync       vừa nối lại → tải bù
   Không có WebSocket (bị chặn / mất kết nối) → tự chuyển sang hỏi định kỳ /chat/messages mỗi 4 giây.

   Gửi tin chịu lỗi:
     - mỗi tin có clientId do trình duyệt sinh → gửi lại sau lỗi mạng KHÔNG tạo tin trùng (server khử trùng);
     - đang offline → tin vào hàng chờ "Đang chờ mạng…", tự gửi lần lượt khi có mạng lại;
     - gửi lỗi → bong bóng đỏ "Gửi lỗi · Thử lại / Xóa".
   Mọi chữ từ người dùng gán bằng textContent → không chèn được HTML / script.
   ============================================================ */
(function () {
  'use strict';
  var CTX = (window.UT && window.UT.ctx) || '';
  var ME = (window.UT && window.UT.me) || 0;
  var EMOJIS = ['😀','😁','😂','🤣','😊','😍','😘','😎','🤔','😴','😅','🙂','🤗','🥳','😢','😭','😡','😮',
                '👍','👎','👏','🙏','💪','🎉','🔥','❤️','💯','✅','❌','📌','📚','💻','☕','🍜','⚽','🎮','🎵','📷','✨','🌟'];
  var REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '😡'];
  var EDIT_MINUTES = 15;

  var $ = function (id) { return document.getElementById(id); };
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function icon(name) {
    var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    s.setAttribute('class', 'icon'); s.setAttribute('aria-hidden', 'true');
    var u = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    u.setAttribute('href', '#' + name); s.appendChild(u);
    return s;
  }
  function fold(s) {
    return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase();
  }
  function fmtSize(n) { return n >= 1048576 ? (n / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(n / 1024)) + ' KB'; }
  function uid() { return 'c' + Date.now().toString(36) + Math.random().toString(36).slice(2, 10); }
  function avatar(name, initials, url, cls) {
    var a = el('span', cls || 'av');
    if (url) { var img = el('img'); img.src = CTX + url; img.alt = ''; img.loading = 'lazy'; a.appendChild(img); }
    else a.textContent = initials || (name || '?').charAt(0);
    return a;
  }
  function readJson(id) {
    try { var t = $(id).textContent.trim(); return t && t !== 'null' ? JSON.parse(t) : null; } catch (e) { return null; }
  }
  function api(path, body, opts) {
    opts = opts || {};
    var init = { headers: { 'Accept': 'application/json' } };
    if (body !== undefined) {
      init.method = 'POST';
      if (body instanceof FormData) init.body = body;
      else { init.body = new URLSearchParams(body).toString(); init.headers['Content-Type'] = 'application/x-www-form-urlencoded'; }
    }
    return fetch(CTX + '/chat/' + path, init).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) { var e = new Error(d.error || ('Lỗi ' + r.status)); e.status = r.status; throw e; }
        return d;
      });
    });
  }

  /* ============================================================ Trạng thái */
  var S = {
    convs: readJson('chat-convs') || [],
    conv: null,              // thông tin hội thoại đang mở (members, receipts, canSend...)
    msgs: [],                // tin đang hiển thị (đã sắp theo id), kể cả tin tạm (pending) ở cuối
    byId: {},
    pending: {},             // clientId → tin tạm
    outbox: [],              // clientId đang chờ mạng
    hasMore: false,
    pinned: [],
    detached: false,         // đang xem quanh một tin cũ (nhảy từ tìm kiếm) → tin mới không tự chèn
    newWhileDetached: 0,
    replyTo: null,
    editing: null,
    file: null,
    typing: {},              // userId → {name, timer}
    convFilter: 'all',
    convQuery: ''
  };
  var boot = readJson('chat-boot');

  function activeId() { return S.conv ? S.conv.id : null; }

  /* ============================================================ Danh sách hội thoại */
  function renderConvs() {
    var list = $('conv-list');
    list.textContent = '';
    var q = fold(S.convQuery.trim()), shown = 0;
    S.convs.forEach(function (c) {
      if (q && fold(c.name).indexOf(q) < 0) return;
      if (S.convFilter === 'unread' && !(c.unread > 0)) return;
      if (S.convFilter === 'group' && !c.group) return;
      shown++;
      var li = el('li');
      var a = el('a', 'conv-item' + (c.conversationId === activeId() ? ' is-active' : '') + (c.unread > 0 ? ' is-unread' : ''));
      a.href = CTX + '/chat?c=' + c.conversationId;
      a.setAttribute('data-conv', c.conversationId);
      a.addEventListener('click', function (e) {
        if (e.ctrlKey || e.metaKey) return;
        e.preventDefault();
        openConversation(c.conversationId);
      });
      var av = avatar(c.name, c.initials, c.avatar, 'conv-avatar' + (c.group ? ' is-group' : ''));
      if (!c.group) {
        var dot = el('span', 'presence-dot' + (c.online ? ' is-online' : ''));
        dot.setAttribute('data-presence-user', c.partnerId);
        av.appendChild(dot);
      }
      a.appendChild(av);
      var body = el('span', 'conv-body');
      var top = el('span', 'conv-top');
      top.appendChild(el('span', 'conv-name', c.name));
      top.appendChild(el('span', 'conv-time', c.time || ''));
      var bottom = el('span', 'conv-bottom');
      var snippet = c.lastMessage || (c.group ? c.memberCount + ' thành viên' : '');
      var prefix = c.lastMessageMine ? 'Bạn: ' : (c.group && c.lastSender ? c.lastSender + ': ' : '');
      bottom.appendChild(el('span', 'conv-snippet', prefix + snippet));
      if (c.unread > 0) bottom.appendChild(el('span', 'conv-unread', c.unread > 99 ? '99+' : String(c.unread)));
      body.appendChild(top);
      body.appendChild(bottom);
      a.appendChild(body);
      li.appendChild(a);

      // Menu nhanh: đánh dấu đọc / chưa đọc, xóa cuộc trò chuyện
      var more = el('button', 'conv-more');
      more.type = 'button';
      more.setAttribute('aria-label', 'Tùy chọn cuộc trò chuyện');
      more.appendChild(icon('i-dots'));
      more.addEventListener('click', function (e) { e.preventDefault(); e.stopPropagation(); convMenu(more, c); });
      li.appendChild(more);
      list.appendChild(li);
    });
    if (q && S.convFilter === 'all') renderFriendMatches(list, q, shown);
    else if (q && !shown) list.appendChild(el('li', 'search-none', 'Không có cuộc trò chuyện phù hợp.'));
    $('conv-empty').hidden = S.convs.length > 0 || !!q;
  }

  /* Ô tìm kiếm: ngoài các cuộc trò chuyện đã có, hiện thêm bạn bè CHƯA từng nhắn tin khớp tên
     → bấm vào là mở /chat?with=<id> (server tự tạo hội thoại 1-1). Danh sách bạn tải 1 lần khi gõ lần đầu. */
  var friendCache = null, friendLoading = false;
  function renderFriendMatches(list, q, shownConvs) {
    if (!friendCache) {
      if (!friendLoading) {
        friendLoading = true;
        api('friends').then(function (d) { friendCache = d.friends || []; })
          .catch(function () { friendCache = []; })
          .then(function () { friendLoading = false; renderConvs(); });
      }
      list.appendChild(el('li', 'search-none', 'Đang tìm bạn bè…'));
      return;
    }
    var hasDirect = {};
    S.convs.forEach(function (c) { if (!c.group && c.partnerId) hasDirect[c.partnerId] = true; });
    var matches = friendCache.filter(function (f) { return !hasDirect[f.id] && fold(f.name).indexOf(q) >= 0; });
    if (matches.length) {
      list.appendChild(el('li', 'conv-section', 'Bạn bè'));
      matches.slice(0, 20).forEach(function (f) {
        var li = el('li');
        var a = el('a', 'conv-item conv-item--friend');
        a.href = CTX + '/chat?with=' + f.id;
        a.appendChild(avatar(f.name, f.initials, f.avatar, 'conv-avatar'));
        var body = el('span', 'conv-body');
        var top = el('span', 'conv-top');
        top.appendChild(el('span', 'conv-name', f.name));
        body.appendChild(top);
        body.appendChild(el('span', 'conv-bottom')).appendChild(el('span', 'conv-snippet', 'Bắt đầu trò chuyện'));
        a.appendChild(body);
        li.appendChild(a);
        list.appendChild(li);
      });
    }
    if (!shownConvs && !matches.length) list.appendChild(el('li', 'search-none', 'Không tìm thấy cuộc trò chuyện hoặc bạn bè phù hợp.'));
  }

  function convMenu(anchor, c) {
    closeMenus();
    var m = el('div', 'msg-menu conv-menu');
    var add = function (label, fn, danger) {
      var b = el('button', 'msg-menu-item' + (danger ? ' is-danger' : ''), label);
      b.type = 'button';
      b.addEventListener('click', function () { closeMenus(); fn(); });
      m.appendChild(b);
    };
    if (c.unread > 0) add('Đánh dấu đã đọc', function () {
      api('read', { conversationId: c.conversationId, upToId: 2147483647 }).then(refreshConvs);
    });
    else add('Đánh dấu chưa đọc', function () {
      api('unread', { conversationId: c.conversationId }).then(function () {
        if (c.conversationId === activeId()) closeThread();
        refreshConvs();
      }).catch(toastError);
    });
    add('Xóa cuộc trò chuyện', function () { clearHistory(c.conversationId); }, true);
    anchor.parentNode.appendChild(m);
  }

  function refreshConvs() {
    return api('conversations').then(function (d) { S.convs = d.conversations; renderConvs(); updateHeaderPresence(); });
  }

  function bumpConv(m) {
    var c = S.convs.find(function (x) { return x.conversationId === m.conversationId; });
    if (!c) { refreshConvs(); return; }
    c.lastMessage = m.recalled ? 'Tin nhắn đã được thu hồi' : (m.content || (m.attachment ? (m.attachment.type === 'IMAGE' ? '📷 Hình ảnh' : '📎 ' + m.attachment.name) : ''));
    c.lastMessageMine = m.senderId === ME;
    c.lastSender = m.type === 'SYSTEM' ? null : m.senderFirst;
    c.time = m.time;
    var viewing = m.conversationId === activeId() && !document.hidden;
    if (m.senderId !== ME && m.type !== 'SYSTEM' && !viewing) c.unread = (c.unread || 0) + 1;
    S.convs.splice(S.convs.indexOf(c), 1);
    S.convs.unshift(c);
    renderConvs();
  }

  /* ============================================================ Mở hội thoại */
  function openConversation(cid) {
    if (activeId() === cid) return;
    // Tải trang /chat?c= để có dữ liệu mới nhất từ server (một luồng duy nhất, dễ kiểm chứng quyền truy cập)
    api('info?conversationId=' + cid).then(function (d) {
      return api('history?conversationId=' + cid + '&beforeId=2147483647').then(function (h) {
        return api('pinned?conversationId=' + cid).then(function (p) {
          load({ conversation: d.conversation, messages: h.messages, hasMore: h.hasMore, pinned: p.pinned });
          history.replaceState(null, '', CTX + '/chat?c=' + cid);
        });
      });
    }).catch(toastError);
  }

  function load(b) {
    S.conv = b.conversation;
    S.msgs = []; S.byId = {}; S.pending = {};
    S.hasMore = b.hasMore; S.detached = false; S.newWhileDetached = 0;
    S.pinned = b.pinned || [];
    S.replyTo = null; S.editing = null; S.file = null;
    Object.keys(S.typing).forEach(function (k) { clearTimeout(S.typing[k].timer); });
    S.typing = {};
    b.messages.forEach(addMessage);
    $('thread-empty').hidden = true;
    $('thread').hidden = false;
    $('thread-search').hidden = true;
    renderHeader();
    renderMessages(true);
    renderPinnedBar();
    renderComposerState();
    renderInfo();
    var c = S.convs.find(function (x) { return x.conversationId === S.conv.id; });
    if (c) c.unread = 0;
    renderConvs();
    markRead();
    $('composer-input').focus();
  }

  function closeThread() {
    S.conv = null;
    $('thread').hidden = true;
    $('thread-empty').hidden = false;
    $('chat-info').hidden = true;
    renderConvs();
  }

  /* ============================================================ Đầu khung + thông tin */
  function memberById(id) {
    return S.conv ? S.conv.members.find(function (m) { return m.id === id; }) : null;
  }

  function renderHeader() {
    var c = S.conv;
    var av = $('thread-avatar');
    av.textContent = '';
    av.className = 'thread-avatar' + (c.group ? ' is-group' : '');
    if (c.avatar) { var img = el('img'); img.src = CTX + c.avatar; img.alt = ''; av.appendChild(img); }
    else av.textContent = c.initials;
    if (!c.group) {
      var partner = memberById(c.partnerId);
      var dot = el('span', 'presence-dot' + (partner && partner.online ? ' is-online' : ''));
      dot.setAttribute('data-presence-user', c.partnerId);
      av.appendChild(dot);
    }
    $('thread-user').href = c.group ? '#' : CTX + '/profile?userId=' + c.partnerId;
    $('thread-name').textContent = c.title;
    updateHeaderPresence();
  }

  function updateHeaderPresence() {
    if (!S.conv) return;
    var sub = $('thread-sub');
    if (S.conv.group) {
      var online = S.conv.members.filter(function (m) { return m.online && m.id !== ME; }).length;
      sub.textContent = S.conv.members.length + ' thành viên' + (online ? ' · ' + online + ' đang hoạt động' : '');
      sub.classList.toggle('is-online', online > 0);
    } else {
      var p = memberById(S.conv.partnerId);
      var label = p && p.online ? 'Đang hoạt động' : (S.conv.presence || S.conv.partnerLocation || 'Thành viên UTErSpace');
      sub.textContent = label;
      sub.classList.toggle('is-online', !!(p && p.online));
    }
  }

  function renderComposerState() {
    var denied = !S.conv.canSend;
    $('composer-denied').hidden = !denied;
    $('composer-denied').textContent = denied ? '🔒 ' + (S.conv.denyReason || 'Bạn không thể gửi tin trong cuộc trò chuyện này.') : '';
    $('composer-form').hidden = denied;
    renderContext();
    renderFileChip();
  }

  /* ============================================================ Tin nhắn: lưu + vẽ */
  function addMessage(m) {
    if (S.byId[m.id]) { Object.assign(S.byId[m.id], m); return S.byId[m.id]; }
    S.byId[m.id] = m;
    S.msgs.push(m);
    S.msgs.sort(function (a, b) {
      if (a.pending && b.pending) return a.seq - b.seq;
      if (a.pending) return 1;
      if (b.pending) return -1;
      return a.id - b.id;
    });
    return m;
  }

  function dayLabel(date) {
    if (!date) return '';
    var d = new Date(date + 'T00:00:00'), today = new Date();
    today.setHours(0, 0, 0, 0);
    var diff = Math.round((today - d) / 86400000);
    if (diff === 0) return 'Hôm nay';
    if (diff === 1) return 'Hôm qua';
    var p = date.split('-');
    return p[2] + '/' + p[1] + '/' + p[0];
  }

  function nearBottom() {
    var sc = $('thread-scroll');
    return sc.scrollHeight - sc.scrollTop - sc.clientHeight < 120;
  }
  function scrollBottom() { var sc = $('thread-scroll'); sc.scrollTop = sc.scrollHeight; }

  function renderMessages(toBottom) {
    var ol = $('messages');
    var stick = toBottom || nearBottom();
    ol.textContent = '';
    if (!S.msgs.length) {
      var hello = el('li', 'thread-hello');
      hello.textContent = S.conv.group ? '👋 Nhóm đã sẵn sàng — hãy gửi lời chào mọi người!' : '👋 Hãy gửi lời chào tới ' + S.conv.title;
      ol.appendChild(hello);
    }
    var lastDay = null;
    S.msgs.forEach(function (m, i) {
      var day = m.date || (m.pending ? new Date().toISOString().slice(0, 10) : null);
      if (day && day !== lastDay) { ol.appendChild(el('li', 'day-sep', dayLabel(day))); lastDay = day; }
      var prev = S.msgs[i - 1], next = S.msgs[i + 1];
      var sameAsPrev = prev && prev.senderId === m.senderId && prev.type !== 'SYSTEM' && (prev.date === m.date || prev.pending);
      var sameAsNext = next && next.senderId === m.senderId && next.type !== 'SYSTEM' && (next.date === m.date || next.pending);
      ol.appendChild(renderMessage(m, !sameAsPrev, !sameAsNext));
    });
    renderStatusLine();
    $('history-loader').hidden = !S.hasMore;
    if (stick) scrollBottom();
  }

  function renderMessage(m, firstOfGroup, lastOfGroup) {
    if (m.type === 'SYSTEM') {
      var sys = el('li', 'sys-msg', m.content);
      sys.setAttribute('data-id', m.id);
      return sys;
    }
    var mine = m.senderId === ME;
    var li = el('li', 'msg ' + (mine ? 'is-mine' : 'is-theirs') + (lastOfGroup ? ' is-last' : '') + (firstOfGroup ? ' is-first' : ''));
    li.setAttribute('data-id', m.id || '');
    if (m.pending) li.classList.add('is-pending');
    if (m.failed) li.classList.add('is-failed');

    if (!mine) {
      var avSlot = el('span', 'msg-avatar-slot');
      if (lastOfGroup) avSlot.appendChild(avatar(m.senderName, m.senderInitials, m.senderAvatar, 'msg-avatar'));
      li.appendChild(avSlot);
    }
    var col = el('div', 'msg-col');
    if (!mine && S.conv.group && firstOfGroup) col.appendChild(el('span', 'msg-sender', m.senderName));

    // Trích dẫn tin được trả lời
    if (m.reply) {
      var q = el('button', 'msg-quote');
      q.type = 'button';
      q.appendChild(el('b', null, '↩ ' + (m.reply.senderName || '')));
      q.appendChild(el('span', null, m.reply.recalled ? 'Tin nhắn đã được thu hồi' : m.reply.preview));
      q.addEventListener('click', function () { jumpTo(m.reply.id); });
      col.appendChild(q);
    }

    var bubble = el('div', 'bubble' + (m.recalled ? ' is-recalled' : ''));
    bubble.title = m.fullTime || '';
    if (m.recalled) {
      bubble.textContent = mine ? 'Bạn đã thu hồi một tin nhắn' : 'Tin nhắn đã được thu hồi';
    } else {
      if (m.attachment) bubble.appendChild(renderAttachment(m));
      if (m.content) bubble.appendChild(linkify(m.content));
      if (m.edited) bubble.appendChild(el('span', 'msg-edited', ' (đã chỉnh sửa)'));
    }
    if (m.pinned && !m.recalled) bubble.appendChild(el('span', 'msg-pin-flag', '📌'));
    col.appendChild(bubble);

    // Cảm xúc
    if (m.reactions && m.reactions.length) {
      var rx = el('div', 'msg-reactions');
      m.reactions.forEach(function (r) {
        var chip = el('button', 'reaction-chip' + (r.users.some(function (u) { return u.id === ME; }) ? ' is-mine' : ''), r.emoji + ' ' + r.count);
        chip.type = 'button';
        chip.title = r.users.map(function (u) { return u.name; }).join(', ');
        chip.addEventListener('click', function () { react(m, r.emoji); });
        rx.appendChild(chip);
      });
      col.appendChild(rx);
    }

    if (m.failed) {
      var f = el('div', 'msg-failed');
      f.appendChild(document.createTextNode(m.error || 'Gửi lỗi.'));
      var retryBtn = el('button', null, 'Thử lại');
      retryBtn.type = 'button';
      retryBtn.addEventListener('click', function () { retry(m.clientId); });
      var delBtn = el('button', null, 'Xóa');
      delBtn.type = 'button';
      delBtn.addEventListener('click', function () { discard(m.clientId); });
      f.appendChild(retryBtn); f.appendChild(delBtn);
      col.appendChild(f);
    } else if (lastOfGroup) {
      col.appendChild(el('time', 'msg-time', m.pending ? (m.queued ? 'Đang chờ mạng…' : 'Đang gửi…') : m.time));
    }
    li.appendChild(col);

    if (!m.pending && !m.recalled) li.appendChild(renderTools(m, mine));
    return li;
  }

  /** Link http(s) trong tin nhắn thành thẻ <a> an toàn (chỉ dựng DOM, không innerHTML) */
  function linkify(text) {
    var span = el('span', 'msg-text');
    var re = /\bhttps?:\/\/[^\s<>"]+/g, last = 0, mt;
    while ((mt = re.exec(text))) {
      if (mt.index > last) span.appendChild(document.createTextNode(text.slice(last, mt.index)));
      var a = el('a', null, mt[0]);
      a.href = mt[0]; a.target = '_blank'; a.rel = 'noopener noreferrer nofollow';
      span.appendChild(a);
      last = mt.index + mt[0].length;
    }
    if (last < text.length) span.appendChild(document.createTextNode(text.slice(last)));
    return span;
  }

  function renderAttachment(m) {
    var a = m.attachment;
    if (a.type === 'IMAGE') {
      var img = el('img', 'msg-image');
      img.src = a.localUrl || (CTX + a.url);
      img.alt = a.name || 'Hình ảnh';
      img.loading = 'lazy';
      if (!m.pending) img.addEventListener('click', function () { openLightbox(CTX + a.url); });
      return img;
    }
    var card = el(m.pending ? 'span' : 'a', 'msg-file');
    if (!m.pending) { card.href = CTX + a.url; card.setAttribute('download', a.name); }
    var ext = (a.name.split('.').pop() || 'FILE').toUpperCase().slice(0, 4);
    card.appendChild(el('span', 'file-ext', ext));
    var info = el('span', 'file-info');
    info.appendChild(el('b', null, a.name));
    info.appendChild(el('small', null, fmtSize(a.size || 0) + (m.pending ? '' : ' · Bấm để tải về')));
    card.appendChild(info);
    return card;
  }

  /** Thanh công cụ khi rê chuột vào tin: cảm xúc, trả lời, thêm (…) */
  function renderTools(m, mine) {
    var tools = el('div', 'msg-tools');
    var reactBtn = el('button', 'msg-tool', '😊');
    reactBtn.type = 'button'; reactBtn.title = 'Thả cảm xúc';
    reactBtn.addEventListener('click', function (e) { e.stopPropagation(); reactionPicker(reactBtn, m); });
    var replyBtn = el('button', 'msg-tool', '↩');
    replyBtn.type = 'button'; replyBtn.title = 'Trả lời';
    replyBtn.addEventListener('click', function () { startReply(m); });
    var moreBtn = el('button', 'msg-tool');
    moreBtn.type = 'button'; moreBtn.title = 'Thêm';
    moreBtn.appendChild(icon('i-dots'));
    moreBtn.addEventListener('click', function (e) { e.stopPropagation(); messageMenu(moreBtn, m, mine); });
    tools.appendChild(reactBtn); tools.appendChild(replyBtn); tools.appendChild(moreBtn);
    return tools;
  }

  function closeMenus() {
    document.querySelectorAll('.msg-menu, .reaction-picker').forEach(function (x) { x.remove(); });
  }
  document.addEventListener('click', function (e) {
    if (!e.target.closest('.msg-menu, .reaction-picker, .msg-tool, .conv-more')) closeMenus();
    if (!e.target.closest('.emoji-wrap')) $('emoji-picker').hidden = true;
  });

  function reactionPicker(anchor, m) {
    closeMenus();
    var p = el('div', 'reaction-picker');
    REACTIONS.forEach(function (r) {
      var b = el('button', null, r);
      b.type = 'button';
      b.addEventListener('click', function () { closeMenus(); react(m, r); });
      p.appendChild(b);
    });
    anchor.parentNode.appendChild(p);
  }

  function messageMenu(anchor, m, mine) {
    closeMenus();
    var menu = el('div', 'msg-menu');
    function add(label, fn, danger) {
      var b = el('button', 'msg-menu-item' + (danger ? ' is-danger' : ''), label);
      b.type = 'button';
      b.addEventListener('click', function () { closeMenus(); fn(); });
      menu.appendChild(b);
    }
    if (m.content) add('Sao chép', function () {
      (navigator.clipboard ? navigator.clipboard.writeText(m.content) : Promise.reject())
        .then(function () { showToast('Đã sao chép.', 'success'); }, function () { showToast('Trình duyệt chặn sao chép.', 'error'); });
    });
    add('Trả lời', function () { startReply(m); });
    var age = (Date.now() - parseTime(m)) / 60000;
    if (mine && !m.attachment && age < EDIT_MINUTES) add('Chỉnh sửa', function () { startEdit(m); });
    add(m.pinned ? 'Bỏ ghim' : 'Ghim tin nhắn', function () { pin(m, !m.pinned); });
    if (mine) add('Thu hồi với mọi người', function () { recall(m); }, true);
    add('Xóa ở phía bạn', function () { hide(m); }, true);
    anchor.parentNode.appendChild(menu);
  }

  /** "HH:mm, dd/MM/yyyy" → thời điểm (ms) — để biết còn trong hạn sửa tin không */
  function parseTime(m) {
    var r = /(\d{2}):(\d{2}), (\d{2})\/(\d{2})\/(\d{4})/.exec(m.fullTime || '');
    return r ? new Date(+r[5], +r[4] - 1, +r[3], +r[1], +r[2]).getTime() : Date.now();
  }

  /** Dòng trạng thái dưới tin CUỐI CÙNG của mình: Đã gửi / Đã nhận / Đã xem (nhóm: Đã xem bởi ...) */
  function renderStatusLine() {
    var old = document.querySelector('.msg-status');
    if (old) old.remove();
    var mineList = S.msgs.filter(function (m) { return m.senderId === ME && m.type !== 'SYSTEM' && !m.pending && !m.failed; });
    if (!mineList.length) return;
    var last = mineList[mineList.length - 1];
    var later = S.msgs.slice(S.msgs.indexOf(last) + 1).some(function (m) { return m.senderId !== ME && m.type !== 'SYSTEM'; });
    if (later) return;    // người khác đã trả lời sau đó → không cần dòng trạng thái
    var others = S.conv.members.filter(function (mb) { return mb.id !== ME; });
    var rc = S.conv.receipts || {};
    var seen = others.filter(function (mb) { return rc[mb.id] && rc[mb.id].read >= last.id; });
    var got = others.filter(function (mb) { return rc[mb.id] && rc[mb.id].delivered >= last.id; });
    var text, cls = 'msg-status';
    if (!S.conv.group) {
      if (seen.length) { text = '✓✓ Đã xem'; cls += ' is-seen'; }
      else if (got.length) text = '✓✓ Đã nhận';
      else text = '✓ Đã gửi';
    } else {
      if (seen.length) {
        text = '✓✓ Đã xem bởi ' + (seen.length === others.length ? 'tất cả' : seen.map(function (s) { return s.first || s.name; }).slice(0, 3).join(', ') + (seen.length > 3 ? ' và ' + (seen.length - 3) + ' người khác' : ''));
        cls += ' is-seen';
      } else text = got.length ? '✓✓ Đã nhận' : '✓ Đã gửi';
    }
    var li = document.querySelector('.msg[data-id="' + last.id + '"]');
    if (!li) return;
    var st = el('span', cls, text);
    li.querySelector('.msg-col').appendChild(st);
  }

  /* ============================================================ Gửi tin (chịu lỗi mạng) */
  var seq = 0;
  function sendCurrent() {
    if (!S.conv || !S.conv.canSend) return;
    var input = $('composer-input');
    var text = input.value.trim();
    if (S.editing) { saveEdit(text); return; }
    if (!text && !S.file) return;
    var clientId = uid();
    var m = {
      id: 'p-' + clientId, clientId: clientId, pending: true, seq: ++seq,
      conversationId: S.conv.id, type: 'TEXT', senderId: ME, content: text,
      date: new Date().toISOString().slice(0, 10), reactions: [],
      reply: S.replyTo ? { id: S.replyTo.id, senderName: S.replyTo.senderName, preview: S.replyTo.content || '📎 Tệp đính kèm', recalled: false } : null,
      replyToId: S.replyTo ? S.replyTo.id : null,
      file: S.file ? S.file.file : null,
      attachment: S.file ? { type: S.file.isImage ? 'IMAGE' : 'FILE', name: S.file.file.name, size: S.file.file.size, localUrl: S.file.url } : null
    };
    S.pending[clientId] = m;
    addMessage(m);
    input.value = '';
    autosize();
    S.replyTo = null; S.file = null;
    renderContext(); renderFileChip();
    sendTyping(false);
    if (S.detached) jumpLatest();
    renderMessages(true);
    deliver(clientId);
  }

  function deliver(clientId) {
    var m = S.pending[clientId];
    if (!m) return;
    if (navigator.onLine === false) {
      m.queued = true;
      if (S.outbox.indexOf(clientId) < 0) S.outbox.push(clientId);
      renderMessages();
      showConn();
      return;
    }
    m.queued = false; m.failed = false;
    var fd = new FormData();
    fd.append('conversationId', m.conversationId);
    fd.append('content', m.content);
    fd.append('clientId', clientId);
    if (m.replyToId) fd.append('replyToId', m.replyToId);
    if (m.file) fd.append('file', m.file);
    api('send', fd).then(function (d) {
      confirmSent(clientId, d.message);
    }).catch(function (err) {
      if (!S.pending[clientId]) return;
      // Lỗi mạng (không có mã HTTP) và đang offline → đưa vào hàng chờ; lỗi từ server → báo lỗi, cho thử lại
      if (!err.status && navigator.onLine === false) { m.queued = true; S.outbox.push(clientId); }
      else { m.failed = true; m.error = err.status ? err.message : 'Không gửi được (mất kết nối).'; }
      renderMessages();
    });
  }

  function confirmSent(clientId, real) {
    var tmp = S.pending[clientId];
    delete S.pending[clientId];
    if (tmp) {
      var i = S.msgs.indexOf(tmp);
      if (i >= 0) S.msgs.splice(i, 1);
      delete S.byId[tmp.id];
      if (tmp.attachment && tmp.attachment.localUrl) URL.revokeObjectURL(tmp.attachment.localUrl);
    }
    if (real && real.conversationId === activeId()) addMessage(real);
    if (real) bumpConv(real);
    renderMessages();
  }

  function retry(clientId) { var m = S.pending[clientId]; if (m) { m.failed = false; renderMessages(); deliver(clientId); } }
  function discard(clientId) {
    var m = S.pending[clientId];
    if (!m) return;
    delete S.pending[clientId];
    S.msgs.splice(S.msgs.indexOf(m), 1);
    delete S.byId[m.id];
    renderMessages();
  }
  function flushOutbox() {
    var list = S.outbox.slice();
    S.outbox = [];
    list.forEach(function (cid, i) { setTimeout(function () { deliver(cid); }, i * 150); });
  }
  window.addEventListener('online', function () { flushOutbox(); showConn(); resync(); });
  window.addEventListener('offline', showConn);
  window.addEventListener('beforeunload', function (e) {
    if (Object.keys(S.pending).length) { e.preventDefault(); e.returnValue = ''; }
  });

  /* ============================================================ Trả lời / sửa / file */
  function startReply(m) {
    S.editing = null;
    S.replyTo = m;
    renderContext();
    $('composer-input').focus();
  }
  function startEdit(m) {
    S.replyTo = null;
    S.editing = m;
    $('composer-input').value = m.content || '';
    autosize();
    renderContext();
    $('composer-input').focus();
  }
  function renderContext() {
    var box = $('composer-context'), text = $('composer-context-text');
    if (S.replyTo) {
      box.hidden = false; box.className = 'composer-context is-reply';
      text.textContent = '↩ Đang trả lời ' + (S.replyTo.senderId === ME ? 'chính bạn' : S.replyTo.senderName) + ': ' +
                         (S.replyTo.content || '📎 Tệp đính kèm').slice(0, 80);
    } else if (S.editing) {
      box.hidden = false; box.className = 'composer-context is-edit';
      text.textContent = '✏️ Đang chỉnh sửa tin nhắn — Enter để lưu, Esc để hủy';
    } else box.hidden = true;
  }
  function clearContext() {
    if (S.editing) $('composer-input').value = '';
    S.replyTo = null; S.editing = null;
    autosize();
    renderContext();
  }
  function saveEdit(text) {
    var m = S.editing;
    if (!text) { showToast('Nội dung không được để trống.', 'error'); return; }
    api('edit', { messageId: m.id, content: text }).then(function (d) {
      applyUpdate(d.message);
      clearContext();
      $('composer-input').value = '';
      autosize();
    }).catch(toastError);
  }

  var IMAGE_MAX = 10 * 1024 * 1024, FILE_MAX = 20 * 1024 * 1024;
  var DOC_EXT = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'zip', 'rar', '7z', 'md', 'json', 'sql', 'java'];
  function pickFile(file) {
    if (!file || !S.conv) return;
    var isImage = /^image\/(jpeg|png|gif|webp)$/.test(file.type);
    var ext = (file.name.split('.').pop() || '').toLowerCase();
    if (!isImage && DOC_EXT.indexOf(ext) < 0) { showToast('Chỉ gửi được ảnh hoặc tài liệu PDF, Word, Excel, PowerPoint, TXT, CSV, ZIP/RAR/7Z.', 'error'); return; }
    if (isImage && file.size > IMAGE_MAX) { showToast('Ảnh tối đa 10 MB.', 'error'); return; }
    if (!isImage && file.size > FILE_MAX) { showToast('Tệp tối đa 20 MB.', 'error'); return; }
    if (S.file && S.file.url) URL.revokeObjectURL(S.file.url);
    S.file = { file: file, isImage: isImage, url: isImage ? URL.createObjectURL(file) : null };
    renderFileChip();
    $('composer-input').focus();
  }
  function renderFileChip() {
    var box = $('composer-file');
    box.textContent = '';
    if (!S.file) { box.hidden = true; return; }
    box.hidden = false;
    if (S.file.isImage) { var img = el('img'); img.src = S.file.url; img.alt = ''; box.appendChild(img); }
    else box.appendChild(el('span', 'file-ext', (S.file.file.name.split('.').pop() || '').toUpperCase().slice(0, 4)));
    var info = el('span', 'file-info');
    info.appendChild(el('b', null, S.file.file.name));
    info.appendChild(el('small', null, fmtSize(S.file.file.size)));
    box.appendChild(info);
    var x = el('button', 'composer-context-close', '×');
    x.type = 'button';
    x.setAttribute('aria-label', 'Bỏ tệp');
    x.addEventListener('click', function () { if (S.file.url) URL.revokeObjectURL(S.file.url); S.file = null; renderFileChip(); });
    box.appendChild(x);
  }

  /* ============================================================ Thao tác trên tin */
  function react(m, emoji) { api('react', { messageId: m.id, emoji: emoji }).then(function (d) { applyUpdate(d.message); }).catch(toastError); }
  function pin(m, pinned) {
    api('pin', { messageId: m.id, pinned: pinned }).then(function (d) {
      applyUpdate(d.message);
      showToast(pinned ? 'Đã ghim tin nhắn 📌' : 'Đã bỏ ghim.', 'success');
    }).catch(toastError);
  }
  function recall(m) {
    UTConfirm({ title: 'Thu hồi tin nhắn?', message: 'Tin nhắn (và tệp đính kèm) sẽ bị gỡ với tất cả mọi người trong cuộc trò chuyện.', ok: 'Thu hồi', danger: true })
      .then(function (yes) { if (yes) api('recall', { messageId: m.id }).catch(toastError); });
  }
  function hide(m) {
    UTConfirm({ title: 'Xóa ở phía bạn?', message: 'Tin nhắn chỉ bị xóa khỏi màn hình của bạn, người khác vẫn thấy.', ok: 'Xóa', danger: true })
      .then(function (yes) { if (yes) api('hide', { messageId: m.id }).then(function () { removeLocal(m.id); }).catch(toastError); });
  }
  function clearHistory(cid) {
    UTConfirm({ title: 'Xóa cuộc trò chuyện?', message: 'Toàn bộ tin nhắn hiện có sẽ bị xóa ở phía bạn. Người khác vẫn giữ lịch sử của họ.', ok: 'Xóa', danger: true })
      .then(function (yes) {
        if (!yes) return;
        api('clear', { conversationId: cid }).then(function () {
          if (cid === activeId()) { S.msgs = []; S.byId = {}; S.pinned = []; renderMessages(true); renderPinnedBar(); }
          refreshConvs();
          showToast('Đã xóa cuộc trò chuyện ở phía bạn.', 'success');
        }).catch(toastError);
      });
  }
  function removeLocal(id) {
    var m = S.byId[id];
    if (!m) return;
    S.msgs.splice(S.msgs.indexOf(m), 1);
    delete S.byId[id];
    S.pinned = S.pinned.filter(function (p) { return p.id !== id; });
    renderMessages();
    renderPinnedBar();
  }
  function applyUpdate(m) {
    if (m.conversationId !== activeId()) return;
    if (S.byId[m.id]) Object.assign(S.byId[m.id], m);
    S.pinned = S.pinned.filter(function (p) { return p.id !== m.id; });
    if (m.pinned && !m.recalled) S.pinned.unshift(m);
    renderMessages();
    renderPinnedBar();
  }

  /* ============================================================ Đã xem / đang gõ */
  var readTimer = null;
  function markRead() {
    clearTimeout(readTimer);
    readTimer = setTimeout(function () {
      if (!S.conv || document.hidden || S.detached) return;
      var real = S.msgs.filter(function (m) { return !m.pending; });
      if (!real.length) return;
      var lastId = real[real.length - 1].id;
      var mine = S.conv.receipts[ME];
      if (mine && mine.read >= lastId) return;
      if (mine) mine.read = lastId;
      api('read', { conversationId: S.conv.id, upToId: lastId }).catch(function () { });
    }, 300);
  }

  var typingSentAt = 0, typingStopTimer = null;
  function sendTyping(on) {
    if (!S.conv || !window.RT) return;
    if (on) {
      if (Date.now() - typingSentAt > 3000) { RT.send({ type: 'typing', conversationId: S.conv.id, typing: true }); typingSentAt = Date.now(); }
      clearTimeout(typingStopTimer);
      typingStopTimer = setTimeout(function () { sendTyping(false); }, 4000);
    } else if (typingSentAt) {
      RT.send({ type: 'typing', conversationId: S.conv.id, typing: false });
      typingSentAt = 0;
      clearTimeout(typingStopTimer);
    }
  }
  function renderTyping() {
    // Tên gọi (first) của thành viên — họ tên đầy đủ trong dữ liệu mẫu có thể theo thứ tự "Duc Huy Nguyen"
    var names = Object.keys(S.typing).map(function (k) {
      var m = memberById(Number(k));
      return (m && m.first) || S.typing[k].name;
    });
    var box = $('typing');
    box.hidden = !names.length;
    $('typing-text').textContent = names.length === 1 ? names[0] + ' đang soạn tin…'
                                 : names.length ? names.slice(0, 2).join(', ') + (names.length > 2 ? ' và người khác' : '') + ' đang soạn tin…' : '';
    if (names.length && nearBottom()) scrollBottom();
  }

  /* ============================================================ Ghim / tìm kiếm / nhảy tới tin */
  function renderPinnedBar() {
    var bar = $('pinned-bar');
    if (!S.pinned.length) { bar.hidden = true; return; }
    bar.hidden = false;
    var p = S.pinned[0];
    $('pinned-preview').textContent = (p.senderFirst ? p.senderFirst + ': ' : '') + (p.content || (p.attachment ? '📎 ' + p.attachment.name : ''));
    $('pinned-count').textContent = S.pinned.length > 1 ? '+' + (S.pinned.length - 1) : '';
  }

  function showPinned() {
    if (!S.conv) return;
    var panel = $('chat-info');
    panel.hidden = false;
    panel.textContent = '';
    panel.appendChild(infoHeader('📌 Tin đã ghim'));
    if (!S.pinned.length) panel.appendChild(el('p', 'info-empty', 'Chưa có tin nào được ghim. Rê chuột vào tin nhắn → … → Ghim tin nhắn.'));
    var ul = el('ul', 'info-list');
    S.pinned.forEach(function (p) {
      var li = el('li');
      var b = el('button', 'info-pin');
      b.type = 'button';
      b.appendChild(el('b', null, p.senderName + ' · ' + p.time));
      b.appendChild(el('span', null, p.content || (p.attachment ? '📎 ' + p.attachment.name : '')));
      b.addEventListener('click', function () { jumpTo(p.id); });
      li.appendChild(b);
      ul.appendChild(li);
    });
    panel.appendChild(ul);
  }
  function jumpToPinned() { if (S.pinned.length) jumpTo(S.pinned[0].id); }

  function toggleSearch() {
    var box = $('thread-search');
    box.hidden = !box.hidden;
    if (!box.hidden) $('msg-search').focus();
  }
  var searchTimer = null;
  function doSearch(q) {
    clearTimeout(searchTimer);
    var ul = $('search-results');
    if (!q.trim()) { ul.textContent = ''; return; }
    searchTimer = setTimeout(function () {
      api('search?conversationId=' + S.conv.id + '&q=' + encodeURIComponent(q)).then(function (d) {
        ul.textContent = '';
        if (!d.results.length) { ul.appendChild(el('li', 'search-none', 'Không tìm thấy tin nhắn phù hợp.')); return; }
        ul.appendChild(el('li', 'search-count', d.results.length + ' kết quả'));
        d.results.forEach(function (m) {
          var li = el('li');
          var b = el('button', 'search-hit');
          b.type = 'button';
          b.appendChild(el('b', null, m.senderName + ' · ' + m.fullTime));
          b.appendChild(highlight(m.content || (m.attachment ? m.attachment.name : ''), q));
          b.addEventListener('click', function () { jumpTo(m.id); });
          li.appendChild(b);
          ul.appendChild(li);
        });
      }).catch(toastError);
    }, 250);
  }
  /** Tô sáng từ khóa không phân biệt dấu (chỉ dựng text node + <mark>) */
  function highlight(text, q) {
    var span = el('span');
    var ft = '', map = [];
    for (var i = 0; i < text.length; i++) { var f = fold(text[i]); for (var k = 0; k < f.length; k++) { ft += f[k]; map.push(i); } }
    var at = ft.indexOf(fold(q.trim()));
    if (at < 0) { span.textContent = text; return span; }
    var s = map[at], e = map[at + fold(q.trim()).length - 1] + 1;
    span.appendChild(document.createTextNode(text.slice(0, s)));
    span.appendChild(el('mark', null, text.slice(s, e)));
    span.appendChild(document.createTextNode(text.slice(e)));
    return span;
  }

  function jumpTo(id) {
    var li = document.querySelector('.msg[data-id="' + id + '"], .sys-msg[data-id="' + id + '"]');
    if (li) { flash(li); return; }
    // Tin chưa tải → tải khoảng tin quanh nó, chuyển sang chế độ "đang xem tin cũ"
    api('around?conversationId=' + S.conv.id + '&messageId=' + id).then(function (d) {
      S.msgs = []; S.byId = {};
      d.messages.forEach(addMessage);
      S.hasMore = d.hasMore;
      S.detached = true;
      S.newWhileDetached = 0;
      renderMessages();
      $('jump-latest').hidden = false;
      $('jump-latest-text').textContent = 'Về tin nhắn mới nhất';
      var target = document.querySelector('.msg[data-id="' + id + '"]');
      if (target) flash(target);
    }).catch(toastError);
  }
  function flash(li) {
    li.scrollIntoView({ block: 'center', behavior: 'smooth' });
    li.classList.add('is-flash');
    setTimeout(function () { li.classList.remove('is-flash'); }, 1800);
  }
  function jumpLatest() {
    $('jump-latest').hidden = true;
    if (!S.detached) { scrollBottom(); return; }
    api('history?conversationId=' + S.conv.id + '&beforeId=2147483647').then(function (h) {
      var pend = Object.keys(S.pending).map(function (k) { return S.pending[k]; });
      S.msgs = []; S.byId = {};
      h.messages.forEach(addMessage);
      pend.forEach(addMessage);
      S.hasMore = h.hasMore;
      S.detached = false;
      renderMessages(true);
      markRead();
    });
  }

  /* ============================================================ Cuộn lên tải tin cũ */
  var loadingOlder = false;
  function loadOlder() {
    if (!S.conv || !S.hasMore || loadingOlder) return;
    var first = S.msgs.find(function (m) { return !m.pending; });
    if (!first) return;
    loadingOlder = true;
    var sc = $('thread-scroll'), before = sc.scrollHeight;
    api('history?conversationId=' + S.conv.id + '&beforeId=' + first.id).then(function (d) {
      d.messages.forEach(addMessage);
      S.hasMore = d.hasMore;
      renderMessages();
      sc.scrollTop = sc.scrollHeight - before;     // giữ nguyên vị trí đang đọc
    }).finally(function () { loadingOlder = false; });
  }

  /* ============================================================ Thông tin hội thoại / nhóm */
  function infoHeader(title) {
    var h = el('header', 'info-head');
    h.appendChild(el('h3', null, title));
    var x = el('button', 'icon-btn-round', '×');
    x.type = 'button';
    x.setAttribute('aria-label', 'Đóng');
    x.addEventListener('click', function () { $('chat-info').hidden = true; });
    h.appendChild(x);
    return h;
  }
  function toggleInfo() {
    var p = $('chat-info');
    if (!p.hidden && p.getAttribute('data-mode') === 'info') { p.hidden = true; return; }
    p.hidden = false;
    renderInfo();
  }
  function renderInfo() {
    var p = $('chat-info');
    if (p.hidden || !S.conv) return;
    p.setAttribute('data-mode', 'info');
    p.textContent = '';
    var c = S.conv;
    p.appendChild(infoHeader(c.group ? 'Thông tin nhóm' : 'Thông tin'));
    var hero = el('div', 'info-hero');
    hero.appendChild(avatar(c.title, c.initials, c.avatar, 'info-avatar' + (c.group ? ' is-group' : '')));
    hero.appendChild(el('b', null, c.title));
    hero.appendChild(el('small', null, c.group ? c.members.length + ' thành viên' : ($('thread-sub').textContent || '')));
    p.appendChild(hero);

    var actions = el('div', 'info-actions');
    function act(label, fn, danger) {
      var b = el('button', 'info-action' + (danger ? ' is-danger' : ''), label);
      b.type = 'button';
      b.addEventListener('click', fn);
      actions.appendChild(b);
    }
    if (!c.group) {
      var prof = el('a', 'info-action', '👤 Xem trang cá nhân');
      prof.href = CTX + '/profile?userId=' + c.partnerId;
      actions.appendChild(prof);
    }
    act('🔍 Tìm trong cuộc trò chuyện', function () { $('thread-search').hidden = false; $('msg-search').focus(); });
    act('📌 Tin đã ghim (' + S.pinned.length + ')', showPinned);
    act('✉️ Đánh dấu chưa đọc', function () {
      api('unread', { conversationId: c.id }).then(function () { closeThread(); refreshConvs(); }).catch(toastError);
    });
    if (c.group) {
      act('✏️ Đổi tên nhóm', renameGroup);
      act('➕ Thêm thành viên', function () { openGroupModal(true); });
    }
    act('🗑 Xóa cuộc trò chuyện', function () { clearHistory(c.id); }, true);
    if (c.group) act('🚪 Rời nhóm', leaveGroup, true);
    p.appendChild(actions);

    if (c.group) {
      p.appendChild(el('h4', 'info-sub', 'Thành viên'));
      var ul = el('ul', 'info-members');
      c.members.forEach(function (m) {
        var li = el('li');
        var av = avatar(m.name, m.initials, m.avatar, 'member-avatar');
        var dot = el('span', 'presence-dot' + (m.online ? ' is-online' : ''));
        dot.setAttribute('data-presence-user', m.id);
        av.appendChild(dot);
        li.appendChild(av);
        var nm = el('a', 'member-name', m.name + (m.id === ME ? ' (bạn)' : ''));
        nm.href = CTX + '/profile?userId=' + m.id;
        li.appendChild(nm);
        if (m.role === 'OWNER') li.appendChild(el('span', 'member-role', 'Trưởng nhóm'));
        if (c.owner && m.id !== ME) {
          var rm = el('button', 'member-remove', 'Xóa');
          rm.type = 'button';
          rm.addEventListener('click', function () { removeMember(m); });
          li.appendChild(rm);
        }
        ul.appendChild(li);
      });
      p.appendChild(ul);
    } else {
      var rel = el('span', 'rel-actions');
      rel.setAttribute('data-relation-user', c.partnerId);
      rel.setAttribute('data-status', 'FRIEND');
      rel.setAttribute('data-name', c.title);
      rel.setAttribute('data-variant', 'profile');
      // Trạng thái thật lấy từ server rồi mới vẽ nút (Kết bạn / Bạn bè ▾ / Bỏ chặn...)
      fetch(CTX + '/friends/status?userId=' + c.partnerId, { headers: { Accept: 'application/json' } })
        .then(function (r) { return r.json(); })
        .then(function (d) { rel.setAttribute('data-status', d.status); rel.setAttribute('data-can-request', d.canRequest); window.UTRelation.render(rel); });
      var wrap = el('div', 'info-relation');
      wrap.appendChild(rel);
      p.appendChild(wrap);
    }
  }

  function refreshInfo() {
    if (!S.conv) return Promise.resolve();
    return api('info?conversationId=' + S.conv.id).then(function (d) {
      S.conv = d.conversation;
      renderHeader(); renderComposerState(); renderInfo(); renderStatusLine();
    }).catch(function (err) {
      if (err.status === 403) { closeThread(); refreshConvs(); showToast('Bạn không còn ở trong cuộc trò chuyện này.', 'error'); }
    });
  }

  function renameGroup() {
    var title = prompt('Tên nhóm mới:', S.conv.title);
    if (title == null) return;
    api('group/rename', { conversationId: S.conv.id, title: title }).then(function () { showToast('Đã đổi tên nhóm.', 'success'); }).catch(toastError);
  }
  function leaveGroup() {
    UTConfirm({ title: 'Rời nhóm "' + S.conv.title + '"?', message: 'Bạn sẽ không nhận tin nhắn của nhóm nữa. Nếu bạn là trưởng nhóm, quyền sẽ chuyển cho thành viên vào sớm nhất.', ok: 'Rời nhóm', danger: true })
      .then(function (yes) {
        if (!yes) return;
        api('group/leave', { conversationId: S.conv.id }).then(function () { closeThread(); refreshConvs(); showToast('Đã rời nhóm.', 'success'); }).catch(toastError);
      });
  }
  function removeMember(m) {
    UTConfirm({ title: 'Xóa ' + m.name + ' khỏi nhóm?', message: 'Người này sẽ không xem và gửi tin trong nhóm được nữa.', ok: 'Xóa khỏi nhóm', danger: true })
      .then(function (yes) { if (yes) api('group/remove', { conversationId: S.conv.id, userId: m.id }).catch(toastError); });
  }

  /* ---------- Hộp tạo nhóm / thêm thành viên ---------- */
  var picker = { friends: [], picked: {}, addMode: false };
  function openGroupModal(addMode) {
    picker.addMode = !!addMode;
    picker.picked = {};
    $('group-modal-title').textContent = addMode ? 'Thêm thành viên vào "' + S.conv.title + '"' : 'Tạo nhóm chat';
    $('group-title-field').hidden = !!addMode;
    $('group-title').value = '';
    $('group-submit').textContent = addMode ? 'Thêm vào nhóm' : 'Tạo nhóm';
    $('picker-note').textContent = addMode ? 'Chỉ thêm được bạn bè của bạn.' : 'Chọn ít nhất 2 người bạn. Chỉ thêm được bạn bè của bạn.';
    $('picker-filter').value = '';
    api('friends').then(function (d) {
      var existing = addMode ? S.conv.members.map(function (m) { return m.id; }) : [];
      picker.friends = d.friends.filter(function (f) { return existing.indexOf(f.id) < 0; });
      renderPicker();
      openModal('group-modal');
      $('picker-filter').focus();
    }).catch(toastError);
  }
  function renderPicker() {
    var q = fold($('picker-filter').value.trim());
    var ul = $('picker-list');
    ul.textContent = '';
    picker.friends.forEach(function (f) {
      if (q && fold(f.name).indexOf(q) < 0) return;
      var li = el('li');
      var lab = el('label', 'picker-item' + (picker.picked[f.id] ? ' is-picked' : ''));
      var cb = el('input');
      cb.type = 'checkbox';
      cb.checked = !!picker.picked[f.id];
      cb.addEventListener('change', function () {
        if (cb.checked) picker.picked[f.id] = f; else delete picker.picked[f.id];
        renderPicker();
      });
      lab.appendChild(cb);
      lab.appendChild(avatar(f.name, f.initials, f.avatar, 'member-avatar'));
      lab.appendChild(el('span', null, f.name));
      li.appendChild(lab);
      ul.appendChild(li);
    });
    if (!ul.children.length) ul.appendChild(el('li', 'search-none', picker.friends.length ? 'Không có bạn bè phù hợp.' : 'Bạn chưa có bạn bè nào để thêm.'));
    var chips = $('picked-list');
    chips.textContent = '';
    Object.keys(picker.picked).forEach(function (id) {
      var f = picker.picked[id];
      var chip = el('button', 'picked-chip', f.name + ' ×');
      chip.type = 'button';
      chip.addEventListener('click', function () { delete picker.picked[id]; renderPicker(); });
      chips.appendChild(chip);
    });
    var n = Object.keys(picker.picked).length;
    $('group-submit').disabled = picker.addMode ? n < 1 : n < 2;
  }
  function submitGroup() {
    var ids = Object.keys(picker.picked).join(',');
    var btn = $('group-submit');
    btn.disabled = true;
    var req = picker.addMode ? api('group/add', { conversationId: S.conv.id, memberIds: ids })
                             : api('group/create', { title: $('group-title').value, memberIds: ids });
    req.then(function (d) {
      closeModal('group-modal');
      if (picker.addMode) { showToast('Đã thêm thành viên.', 'success'); refreshInfo(); }
      else { showToast('Đã tạo nhóm chat 🎉', 'success'); refreshConvs().then(function () { openConversation(d.conversationId); }); }
    }).catch(function (e) { btn.disabled = false; toastError(e); });
  }

  /* ============================================================ Ảnh lớn */
  function openLightbox(src) {
    $('lightbox-img').src = src;
    $('lightbox-download').href = src + '&download=1';
    $('lightbox').hidden = false;
  }

  /* ============================================================ Kết nối & đồng bộ */
  function showConn() {
    var b = $('conn-banner');
    var st = window.RT ? RT.state() : 'open';
    if (navigator.onLine === false) {
      b.hidden = false; b.className = 'conn-banner is-offline';
      b.textContent = '⚠ Bạn đang ngoại tuyến — tin nhắn mới sẽ được gửi khi có mạng trở lại' + (S.outbox.length ? ' (' + S.outbox.length + ' tin đang chờ)' : '') + '.';
    } else if (st === 'closed' || (st === 'connecting' && window.RT && RT.wasOpen())) {
      b.hidden = false; b.className = 'conn-banner';
      b.textContent = '↻ Đang kết nối lại máy chủ… tin nhắn vẫn gửi được, cập nhật có thể chậm vài giây.';
    } else b.hidden = true;
  }

  /** Tải bù tin bị lỡ (sau khi mất kết nối / quay lại tab) */
  function resync() {
    refreshConvs();
    if (!S.conv || S.detached) return;
    var real = S.msgs.filter(function (m) { return !m.pending; });
    var after = real.length ? real[real.length - 1].id : 0;
    api('messages?conversationId=' + S.conv.id + '&afterId=' + after).then(function (d) {
      d.messages.forEach(function (m) { addMessage(m); });
      S.conv.receipts = d.receipts;
      renderMessages();
      markRead();
    }).catch(function (err) { if (err.status === 403) { closeThread(); refreshConvs(); } });
  }

  // Dự phòng khi không có WebSocket: hỏi định kỳ
  setInterval(function () {
    if (document.hidden) return;
    if (!window.RT || !RT.isOpen()) resync();
  }, 4000);

  /* ============================================================ Sự kiện realtime */
  document.addEventListener('rt:chat.message', function (e) {
    var m = e.detail.message;
    if (m.senderId === ME && m.clientId && S.pending[m.clientId]) { confirmSent(m.clientId, m); return; }
    if (m.conversationId === activeId()) {
      delete S.typing[m.senderId];
      renderTyping();
      if (S.detached) {
        S.newWhileDetached++;
        $('jump-latest').hidden = false;
        $('jump-latest-text').textContent = S.newWhileDetached + ' tin nhắn mới';
      } else {
        var wasNear = nearBottom();
        addMessage(m);
        renderMessages(wasNear || m.senderId === ME);
        if (!wasNear && m.senderId !== ME) { $('jump-latest').hidden = false; $('jump-latest-text').textContent = 'Tin nhắn mới'; }
        markRead();
      }
      if (m.type === 'SYSTEM') refreshInfo();
    }
    bumpConv(m);
  });
  document.addEventListener('rt:chat.update', function (e) {
    applyUpdate(e.detail.message);
    if (e.detail.message.recalled) {
      var c = S.convs.find(function (x) { return x.conversationId === e.detail.conversationId; });
      if (c) refreshConvs();
    }
  });
  document.addEventListener('rt:chat.remove', function (e) {
    if (e.detail.conversationId === activeId()) removeLocal(e.detail.messageId);
  });
  document.addEventListener('rt:chat.receipt', function (e) {
    var d = e.detail;
    if (d.userId === ME && d.read != null) {
      var c = S.convs.find(function (x) { return x.conversationId === d.conversationId; });
      if (c && c.unread) { c.unread = 0; renderConvs(); }
    }
    if (d.conversationId !== activeId()) return;
    var r = S.conv.receipts[d.userId] || (S.conv.receipts[d.userId] = { read: 0, delivered: 0 });
    if (d.read != null) r.read = Math.max(r.read, d.read);
    if (d.delivered != null) r.delivered = Math.max(r.delivered, d.delivered);
    renderStatusLine();
  });
  document.addEventListener('rt:chat.typing', function (e) {
    var d = e.detail;
    if (d.conversationId !== activeId()) return;
    if (S.typing[d.userId]) clearTimeout(S.typing[d.userId].timer);
    if (d.typing) {
      S.typing[d.userId] = { name: d.name, timer: setTimeout(function () { delete S.typing[d.userId]; renderTyping(); }, 6000) };
    } else delete S.typing[d.userId];
    renderTyping();
  });
  document.addEventListener('rt:chat.conv', function (e) {
    refreshConvs();
    if (e.detail.conversationId === activeId() && e.detail.action !== 'unread' && e.detail.action !== 'cleared') refreshInfo();
  });
  document.addEventListener('rt:presence', function (e) {
    var d = e.detail;
    S.convs.forEach(function (c) { if (!c.group && c.partnerId === d.userId) c.online = d.online; });
    if (S.conv) {
      S.conv.members.forEach(function (m) { if (m.id === d.userId) m.online = d.online; });
      if (!S.conv.group && S.conv.partnerId === d.userId && !d.online) S.conv.presence = d.label;
      updateHeaderPresence();
    }
  });
  document.addEventListener('rt:friend', function (e) { if (S.conv && !S.conv.group && e.detail.userId === S.conv.partnerId) refreshInfo(); });
  document.addEventListener('rt:resync', resync);
  document.addEventListener('rt:status', showConn);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) { markRead(); if (!window.RT || !RT.isOpen()) resync(); } });
  window.addEventListener('focus', markRead);

  /* ============================================================ Ô soạn tin */
  function autosize() {
    var t = $('composer-input');
    t.style.height = 'auto';
    t.style.height = Math.min(160, t.scrollHeight) + 'px';
  }
  function bindComposer() {
    var input = $('composer-input');
    $('composer-form').addEventListener('submit', function (e) { e.preventDefault(); sendCurrent(); });
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); sendCurrent(); }
      else if (e.key === 'Escape') clearContext();
      else if (e.key === 'ArrowUp' && !input.value) {
        // Mũi tên lên khi ô trống: sửa tin gần nhất của mình (như Messenger)
        var own = S.msgs.filter(function (m) { return m.senderId === ME && !m.pending && !m.recalled && !m.attachment && m.type !== 'SYSTEM'; });
        var last = own[own.length - 1];
        if (last && (Date.now() - parseTime(last)) / 60000 < EDIT_MINUTES) { e.preventDefault(); startEdit(last); }
      }
    });
    input.addEventListener('input', function () { autosize(); if (input.value.trim()) sendTyping(true); else sendTyping(false); });
    input.addEventListener('paste', function (e) {
      var items = (e.clipboardData || {}).items || [];
      for (var i = 0; i < items.length; i++) {
        if (items[i].kind === 'file') { var f = items[i].getAsFile(); if (f) { e.preventDefault(); pickFile(f); return; } }
      }
    });
    $('file-input').addEventListener('change', function () { pickFile(this.files[0]); this.value = ''; });

    // Kéo thả file vào khung chat
    var pane = $('thread'), overlay = $('drop-overlay'), depth = 0;
    pane.addEventListener('dragenter', function (e) { if (e.dataTransfer && Array.prototype.indexOf.call(e.dataTransfer.types, 'Files') >= 0) { depth++; overlay.hidden = false; } });
    pane.addEventListener('dragleave', function () { if (--depth <= 0) { depth = 0; overlay.hidden = true; } });
    pane.addEventListener('dragover', function (e) { e.preventDefault(); });
    pane.addEventListener('drop', function (e) { e.preventDefault(); depth = 0; overlay.hidden = true; if (e.dataTransfer.files[0]) pickFile(e.dataTransfer.files[0]); });

    // Bảng emoji
    var pickerBox = $('emoji-picker');
    EMOJIS.forEach(function (em) {
      var b = el('button', null, em);
      b.type = 'button';
      b.addEventListener('click', function () {
        var s = input.selectionStart || input.value.length, en = input.selectionEnd || input.value.length;
        input.value = input.value.slice(0, s) + em + input.value.slice(en);
        input.selectionStart = input.selectionEnd = s + em.length;
        input.focus();
        autosize();
      });
      pickerBox.appendChild(b);
    });
    $('emoji-btn').addEventListener('click', function () { pickerBox.hidden = !pickerBox.hidden; });

    $('thread-scroll').addEventListener('scroll', function () {
      if (this.scrollTop < 80) loadOlder();
      if (nearBottom() && !S.detached) { $('jump-latest').hidden = true; markRead(); }
    });
    $('msg-search').addEventListener('input', function () { doSearch(this.value); });
    $('conv-filter').addEventListener('input', function () { S.convQuery = this.value; renderConvs(); });
    document.querySelectorAll('.conv-tab').forEach(function (t) {
      t.addEventListener('click', function () {
        S.convFilter = t.getAttribute('data-conv-filter');
        document.querySelectorAll('.conv-tab').forEach(function (x) { x.classList.toggle('is-active', x === t); });
        renderConvs();
      });
    });
    $('picker-filter').addEventListener('input', renderPicker);
  }

  function toastError(e) { showToast((e && e.message) || 'Có lỗi xảy ra.', 'error'); }

  /* ============================================================ Khởi động */
  window.UTChat = {
    activeId: activeId,
    openGroupModal: function (addMode) { openGroupModal(addMode === true); },
    submitGroup: submitGroup,
    toggleSearch: toggleSearch,
    showPinned: showPinned,
    jumpToPinned: jumpToPinned,
    toggleInfo: toggleInfo,
    jumpLatest: jumpLatest,
    clearContext: clearContext
  };
  bindComposer();
  renderConvs();
  if (boot) {
    load(boot);
    history.replaceState(null, '', CTX + '/chat?c=' + boot.conversation.id);
  }
  showConn();
})();
