/* ============================================================
   admin.js — tiện ích dùng chung cho khu quản trị
   Admin.post(url, params)  → Promise<json> (tự gắn X-CSRF-Token; lỗi → reject Error(message))
   Admin.ask(opts)          → Promise<string|null>: hộp xác nhận, có ô lý do tùy chọn (null = hủy)
   Admin.toast(msg, error)  → thông báo góc phải dưới
   Admin.setBadge(n)        → cập nhật số báo cáo chờ trên thanh bên
   Admin.icon(name)         → chuỗi <svg> dùng sprite #i-name (common/icons.jsp)
   Kèm: nút đổi giao diện sáng / tối, mở / đóng thanh bên trên màn hình hẹp.
   ============================================================ */
(function () {
  'use strict';
  var ctx = document.body.getAttribute('data-ctx') || '';

  function icon(name) {
    return '<svg class="icon" aria-hidden="true"><use href="#i-' + name + '"></use></svg>';
  }

  function csrf() {
    var m = document.querySelector('meta[name="csrf-token"]');
    return m ? m.content : '';
  }

  function post(url, params) {
    var body = new URLSearchParams();
    Object.keys(params || {}).forEach(function (k) { if (params[k] != null) body.append(k, params[k]); });
    return fetch(ctx + url, {
      method: 'POST',
      headers: { 'X-CSRF-Token': csrf(), 'Accept': 'application/json',
                 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
      body: body.toString(),
      credentials: 'same-origin'
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (j) {
        if (!r.ok || j.error) throw new Error(j.error || ('Lỗi máy chủ (' + r.status + ').'));
        return j;
      });
    }, function () { throw new Error('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'); });
  }

  var toasts;
  function toast(msg, error) {
    if (!toasts) {
      toasts = document.createElement('div');
      toasts.className = 'adm-toasts';
      toasts.setAttribute('role', 'status');
      toasts.setAttribute('aria-live', 'polite');
      document.body.appendChild(toasts);
    }
    var t = document.createElement('div');
    t.className = 'adm-toast' + (error ? ' error' : '');
    t.innerHTML = icon(error ? 'x-circle' : 'check-circle') + '<span></span>';
    t.querySelector('span').textContent = msg;
    toasts.appendChild(t);
    setTimeout(function () { t.remove(); }, error ? 6000 : 3500);
  }

  // ---------- Hộp xác nhận ----------
  var modal, lastFocus;
  function buildModal() {
    modal = document.createElement('div');
    modal.className = 'adm-modal';
    modal.hidden = true;
    modal.innerHTML =
      '<div class="adm-dialog" role="dialog" aria-modal="true" aria-labelledby="adm-dlg-title">' +
      '  <div class="dlg-ico">' + icon('warning') + '</div>' +
      '  <h2 id="adm-dlg-title"></h2><p class="dlg-text"></p>' +
      '  <div class="dlg-reason"><label for="adm-dlg-reason"></label>' +
      '    <textarea id="adm-dlg-reason" maxlength="200"></textarea><div class="quick"></div></div>' +
      '  <div class="err" aria-live="assertive"></div>' +
      '  <div class="foot"><button type="button" class="btn btn-dismiss" data-x="cancel">Hủy</button>' +
      '    <button type="button" class="btn" data-x="ok"></button></div>' +
      '</div>';
    document.body.appendChild(modal);
  }

  function ask(o) {
    if (!modal) buildModal();
    var $ = function (s) { return modal.querySelector(s); };
    $('#adm-dlg-title').textContent = o.title;
    $('.dlg-text').textContent = o.text || '';
    var reasonBox = $('.dlg-reason'), ta = $('#adm-dlg-reason'), quick = $('.quick'), err = $('.err');
    reasonBox.hidden = !o.reasonLabel;
    $('label').textContent = o.reasonLabel || '';
    ta.value = '';
    ta.placeholder = o.placeholder || '';
    err.textContent = '';
    quick.innerHTML = '';
    (o.quick || []).forEach(function (q) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = q;
      b.onclick = function () { ta.value = q; ta.focus(); };
      quick.appendChild(b);
    });
    var ok = $('[data-x="ok"]');
    ok.textContent = o.confirmLabel || 'Xác nhận';
    ok.className = 'btn ' + (o.tone === 'ok' ? 'btn-unlock' : 'btn-delete');
    var dlgIco = $('.dlg-ico');
    dlgIco.className = 'dlg-ico' + (o.tone === 'ok' ? ' ok' : '');
    dlgIco.innerHTML = icon(o.icon || (o.tone === 'ok' ? 'check-circle' : 'warning'));
    lastFocus = document.activeElement;
    modal.hidden = false;
    (o.reasonLabel ? ta : ok).focus();

    return new Promise(function (resolve) {
      function close(v) {
        modal.hidden = true;
        modal.removeEventListener('click', onClick);
        document.removeEventListener('keydown', onKey);
        if (lastFocus) lastFocus.focus();
        resolve(v);
      }
      function confirm() {
        var v = ta.value.trim();
        if (o.reasonLabel && o.reasonRequired && v.length < 3) {
          err.textContent = 'Vui lòng nhập lý do (ít nhất 3 ký tự).';
          ta.focus();
          return;
        }
        close(v);
      }
      function onClick(e) {
        if (e.target === modal || e.target.getAttribute('data-x') === 'cancel') close(null);
        else if (e.target.getAttribute('data-x') === 'ok') confirm();
      }
      function onKey(e) {
        if (e.key === 'Escape') close(null);
        else if (e.key === 'Enter' && (e.ctrlKey || e.target !== ta)) { e.preventDefault(); confirm(); }
        else if (e.key === 'Tab') {   // giữ focus trong hộp thoại
          var f = Array.prototype.filter.call(modal.querySelectorAll('button, textarea'), function (x) { return x.offsetParent; });
          if (!f.length) return;
          if (e.shiftKey && document.activeElement === f[0]) { e.preventDefault(); f[f.length - 1].focus(); }
          else if (!e.shiftKey && document.activeElement === f[f.length - 1]) { e.preventDefault(); f[0].focus(); }
        }
      }
      modal.addEventListener('click', onClick);
      document.addEventListener('keydown', onKey);
    });
  }

  function setBadge(n) {
    var b = document.getElementById('rail-report-badge');
    if (!b) return;
    b.textContent = n;
    b.hidden = !(n > 0);
  }

  // ---------- Giao diện sáng / tối ----------
  var themeBtn = document.getElementById('theme-toggle');
  if (themeBtn) themeBtn.addEventListener('click', function () {
    var dark = document.documentElement.getAttribute('data-theme') !== 'dark';
    if (dark) document.documentElement.setAttribute('data-theme', 'dark');
    else document.documentElement.removeAttribute('data-theme');
    try { localStorage.setItem('ut-admin-theme', dark ? 'dark' : 'light'); } catch (e) { /* bộ nhớ bị chặn */ }
  });

  // ---------- Thanh bên trên màn hình hẹp ----------
  document.querySelectorAll('[data-adm-menu]').forEach(function (el) {
    el.addEventListener('click', function () {
      var open = document.body.classList.toggle('adm-open');
      var btn = document.querySelector('.adm-menu-btn');
      if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && document.body.classList.contains('adm-open')) document.body.classList.remove('adm-open');
  });

  window.Admin = { post: post, ask: ask, toast: toast, setBadge: setBadge, icon: icon, ctx: ctx };
})();
