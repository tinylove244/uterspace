/* ============================================================
   relation.js — nút quan hệ bạn bè DÙNG CHUNG cho mọi nơi hiển thị một người
   (trang cá nhân, kết quả tìm kiếm, gợi ý ở Bảng tin, trang Bạn bè, thông báo lời mời).

   Đánh dấu chỗ đặt nút bằng:
     <span class="rel-actions" data-relation-user="12" data-status="NONE|SENT|RECEIVED|FRIEND|BLOCKED|BLOCKED_BY|SELF"
           data-can-request="true" data-name="Lan Anh" data-variant="card|profile"></span>
   relation.js vẽ đúng các nút theo trạng thái, gọi POST /friends/<hành động> rồi vẽ lại theo trạng thái
   server trả về. Khi người KIA thay đổi (chấp nhận, hủy, chặn...), server đẩy sự kiện rt:friend → mọi khối
   của người đó trên trang tự cập nhật, không cần tải lại. Phát "relation:changed" cho trang nào cần thêm.
   ============================================================ */
(function () {
  'use strict';
  var CTX = (window.UT && window.UT.ctx) || '';

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function icon(name) {
    var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    s.setAttribute('class', 'icon');
    s.setAttribute('aria-hidden', 'true');
    var u = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    u.setAttribute('href', '#' + name);
    s.appendChild(u);
    return s;
  }
  function button(cls, iconName, text, onClick) {
    var b = el('button', 'btn-pill ' + (cls || ''));
    b.type = 'button';
    if (iconName) b.appendChild(icon(iconName));
    b.appendChild(document.createTextNode(text));
    if (onClick) b.addEventListener('click', onClick); else b.disabled = true;
    return b;
  }

  /** Menu thả xuống nhỏ (Hủy kết bạn / Chặn / Bỏ chặn) */
  function menu(trigger, items) {
    var wrap = el('span', 'rel-menu-wrap');
    var list = el('span', 'rel-menu');
    list.setAttribute('role', 'menu');
    list.hidden = true;
    items.forEach(function (it) {
      var b = el('button', 'rel-menu-item' + (it.danger ? ' is-danger' : ''));
      b.type = 'button';
      b.setAttribute('role', 'menuitem');
      if (it.icon) b.appendChild(icon(it.icon));
      b.appendChild(document.createTextNode(it.text));
      b.addEventListener('click', function () { list.hidden = true; it.run(); });
      list.appendChild(b);
    });
    trigger.setAttribute('aria-haspopup', 'true');
    trigger.addEventListener('click', function (e) {
      e.stopPropagation();
      document.querySelectorAll('.rel-menu').forEach(function (m) { if (m !== list) m.hidden = true; });
      list.hidden = !list.hidden;
    });
    wrap.appendChild(trigger);
    wrap.appendChild(list);
    return wrap;
  }
  document.addEventListener('click', function () {
    document.querySelectorAll('.rel-menu').forEach(function (m) { m.hidden = true; });
  });

  function render(box) {
    var uid = box.getAttribute('data-relation-user');
    var st = box.getAttribute('data-status') || 'NONE';
    var canRequest = box.getAttribute('data-can-request') !== 'false';
    var profile = box.getAttribute('data-variant') === 'profile';
    var name = box.getAttribute('data-name') || 'người này';
    box.textContent = '';
    box.setAttribute('data-state', st);
    var run = function (action) { return function () { act(box, action); }; };
    var blockItem = { text: 'Chặn', icon: 'i-lock', danger: true, run: run('block') };

    switch (st) {
      case 'SELF':
        return;
      case 'NONE':
        box.appendChild(canRequest ? button('', 'i-user-plus', 'Kết bạn', run('request'))
                                   : button('btn-pill--ghost', null, 'Không nhận lời mời', null));
        if (profile) box.appendChild(menu(button('btn-pill--ghost btn-pill--icon', 'i-dots', '', function () { }), [blockItem]));
        break;
      case 'SENT':
        box.appendChild(button('btn-pill--done', 'i-check', 'Đã gửi lời mời', null));
        box.appendChild(button('btn-pill--ghost', null, 'Thu hồi', run('cancel')));
        break;
      case 'RECEIVED':
        box.appendChild(button('', 'i-check', 'Chấp nhận', run('accept')));
        box.appendChild(button('btn-pill--ghost', null, 'Từ chối', run('decline')));
        break;
      case 'FRIEND':
        box.appendChild(menu(button('btn-pill--done', 'i-check', 'Bạn bè ▾', function () { }), [
          { text: 'Hủy kết bạn', icon: 'i-user-circle', danger: true, run: run('unfriend') },
          blockItem
        ]));
        break;
      case 'BLOCKED':
        box.appendChild(button('btn-pill--ghost', 'i-lock', 'Bỏ chặn', run('unblock')));
        break;
      case 'BLOCKED_BY':
        box.appendChild(button('btn-pill--ghost', null, 'Không khả dụng', null));
        break;
    }
    // Nút "Bạn bè ▾" và "..." là nút mở menu, không phải nút bị vô hiệu
    box.querySelectorAll('.rel-menu-wrap > .btn-pill').forEach(function (b) { b.disabled = false; });
    box.setAttribute('data-name', name);
  }

  var CONFIRM = {
    unfriend: function (n) { return { title: 'Hủy kết bạn?', message: 'Bạn và ' + n + ' sẽ không còn là bạn bè. Bạn vẫn có thể kết bạn lại sau.', ok: 'Hủy kết bạn', danger: true }; },
    block:    function (n) { return { title: 'Chặn ' + n + '?', message: 'Hai bạn sẽ không thấy bài viết, trang cá nhân và không nhắn tin được cho nhau. Quan hệ bạn bè (nếu có) sẽ bị hủy.', ok: 'Chặn', danger: true }; },
    cancel:   function (n) { return { title: 'Thu hồi lời mời?', message: 'Lời mời kết bạn gửi tới ' + n + ' sẽ bị gỡ.', ok: 'Thu hồi' }; }
  };

  function act(box, action) {
    var uid = box.getAttribute('data-relation-user');
    var name = box.getAttribute('data-name') || 'người này';
    var ask = CONFIRM[action] && window.UTConfirm ? window.UTConfirm(CONFIRM[action](name)) : Promise.resolve(true);
    ask.then(function (yes) {
      if (!yes) return;
      box.querySelectorAll('button').forEach(function (b) { b.disabled = true; });
      fetch(CTX + '/friends/' + action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
        body: 'userId=' + encodeURIComponent(uid)
      })
        .then(function (r) { return r.json().then(function (d) { return { ok: r.ok, d: d }; }); })
        .then(function (r) {
          update(uid, r.d.status, r.d.canRequest, 'local', action);
          showToast(r.ok ? r.d.message : (r.d.error || 'Không thực hiện được'), r.ok ? 'success' : 'error');
        })
        .catch(function () { render(box); showToast('Mất kết nối, thử lại nhé.', 'error'); });
    });
  }

  /** Cập nhật MỌI khối của userId trên trang (một người có thể xuất hiện ở nhiều chỗ) */
  function update(userId, status, canRequest, source, action) {
    document.querySelectorAll('[data-relation-user="' + userId + '"]').forEach(function (b) {
      if (status) b.setAttribute('data-status', status);
      if (canRequest != null) b.setAttribute('data-can-request', String(canRequest));
      render(b);
    });
    document.dispatchEvent(new CustomEvent('relation:changed', {
      detail: { userId: Number(userId), status: status, source: source, action: action }
    }));
  }

  // Người kia vừa thay đổi quan hệ (server đẩy) → cập nhật ngay
  document.addEventListener('rt:friend', function (e) {
    var d = e.detail;
    update(d.userId, d.status, d.status === 'NONE' ? true : null, 'remote', d.action);
  });

  window.UTRelation = {
    render: render,
    renderAll: function (root) { (root || document).querySelectorAll('[data-relation-user]').forEach(render); },
    update: update
  };
  window.UTRelation.renderAll();
})();
