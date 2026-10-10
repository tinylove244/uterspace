/* ============================================================
   post-media.js — Media nâng cao trên thẻ bài viết (post-media.jsp).

   [data-pano]    ảnh 360°: bấm "Xem ảnh 360°" → tải Pannellum (cdnjs) rồi dựng trình xem toàn cảnh tại chỗ;
                  kéo chuột / vuốt để xoay, điện thoại có nút la bàn để xoay theo hướng cầm máy.
   [data-depth]   ảnh 3D chiều sâu: lớp nền và lớp ảnh dịch chuyển ngược nhau + nghiêng phối cảnh theo chuột
                  hoặc góc nghiêng điện thoại (DeviceOrientation; iOS cần bấm cho phép).
   [data-model3d] vật thể 3D .glb: tải <model-viewer> (Google, jsDelivr) một lần khi có bài 3D trên trang;
                  nút AR mở ARCore (Android) / Quick Look (iOS) để đặt vật thể vào không gian thật.
   ============================================================ */
(function () {
  'use strict';

  function loadScript(src, attrs) {
    return new Promise(function (resolve, reject) {
      if (document.querySelector('script[src="' + src + '"]')) { resolve(); return; }
      var s = document.createElement('script');
      s.src = src;
      Object.keys(attrs || {}).forEach(function (k) { s.setAttribute(k, attrs[k]); });
      s.onload = resolve;
      s.onerror = function () { reject(new Error('Không tải được thư viện ' + src)); };
      document.head.appendChild(s);
    });
  }
  function loadCss(href) {
    if (document.querySelector('link[href="' + href + '"]')) return;
    var l = document.createElement('link');
    l.rel = 'stylesheet';
    l.href = href;
    document.head.appendChild(l);
  }

  /* ---------- Ảnh 360° ---------- */
  var PANNELLUM = 'https://cdnjs.cloudflare.com/ajax/libs/pannellum/2.5.6/';
  document.addEventListener('click', function (e) {
    var btn = e.target.closest('[data-pano-start]');
    if (!btn) return;
    var fig = btn.closest('[data-pano]');
    btn.disabled = true;
    btn.textContent = 'Đang tải trình xem 360°…';
    loadCss(PANNELLUM + 'pannellum.css');
    loadScript(PANNELLUM + 'pannellum.js').then(function () {
      var holder = document.createElement('div');
      holder.className = 'pano-viewer';
      fig.textContent = '';
      fig.appendChild(holder);
      var badge = document.createElement('span');
      badge.className = 'media-mode-badge';
      badge.textContent = '360°';
      fig.appendChild(badge);
      window.pannellum.viewer(holder, {
        type: 'equirectangular',
        panorama: fig.getAttribute('data-pano'),
        autoLoad: true,
        autoRotate: -2,
        showZoomCtrl: true,
        orientationOnByDefault: false,
        compass: false,
        strings: { loadingLabel: 'Đang tải ảnh…', bylineLabel: '' }
      });
    }).catch(function (err) {
      btn.disabled = false;
      btn.textContent = '🌐 Xem ảnh 360°';
      if (window.showToast) showToast(err.message, 'error');
    });
  });

  /* ---------- Ảnh 3D chiều sâu ---------- */
  var depthFigs = [];
  function tilt(fig, x, y) {           // x, y trong [-1, 1]
    var fg = fig.querySelector('.depth-fg'), bg = fig.querySelector('.depth-bg'), shine = fig.querySelector('.depth-shine');
    fig.style.transform = 'perspective(900px) rotateY(' + (x * 7) + 'deg) rotateX(' + (-y * 7) + 'deg)';
    fg.style.transform = 'translate3d(' + (x * 14) + 'px,' + (y * 14) + 'px, 40px) scale(1.04)';
    bg.style.transform = 'translate3d(' + (-x * 22) + 'px,' + (-y * 22) + 'px, 0) scale(1.18)';
    shine.style.background = 'radial-gradient(circle at ' + (50 + x * 40) + '% ' + (50 + y * 40) + '%, rgba(255,255,255,.22), transparent 55%)';
  }
  function initDepth(fig) {
    depthFigs.push(fig);
    fig.addEventListener('pointermove', function (e) {
      var r = fig.getBoundingClientRect();
      tilt(fig, ((e.clientX - r.left) / r.width) * 2 - 1, ((e.clientY - r.top) / r.height) * 2 - 1);
    });
    fig.addEventListener('pointerleave', function () { tilt(fig, 0, 0); });
    // Điện thoại: iOS 13+ phải xin quyền cảm biến bằng một cú bấm
    var touch = window.matchMedia && matchMedia('(pointer: coarse)').matches;
    if (touch && window.DeviceOrientationEvent && typeof DeviceOrientationEvent.requestPermission === 'function') {
      var b = fig.querySelector('[data-depth-motion]');
      b.hidden = false;
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        DeviceOrientationEvent.requestPermission().then(function (st) {
          if (st === 'granted') { listenOrientation(); b.hidden = true; }
        }).catch(function () { });
      });
    }
  }
  var listening = false;
  function listenOrientation() {
    if (listening || !window.DeviceOrientationEvent) return;
    listening = true;
    window.addEventListener('deviceorientation', function (e) {
      if (e.gamma == null) return;
      var x = Math.max(-1, Math.min(1, e.gamma / 30));
      var y = Math.max(-1, Math.min(1, (e.beta - 45) / 30));
      depthFigs.forEach(function (f) {
        var r = f.getBoundingClientRect();
        if (r.bottom > 0 && r.top < innerHeight) tilt(f, x, y);
      });
    });
  }

  /* ---------- Vật thể 3D / AR ---------- */
  var MODEL_VIEWER = 'https://cdn.jsdelivr.net/npm/@google/model-viewer@3.5.0/dist/model-viewer.min.js';

  function init(root) {
    (root || document).querySelectorAll('[data-depth]:not([data-ready])').forEach(function (f) { f.setAttribute('data-ready', ''); initDepth(f); });
    if (depthFigs.length && !(window.DeviceOrientationEvent && DeviceOrientationEvent.requestPermission)) listenOrientation();
    if ((root || document).querySelector('[data-model3d]')) {
      loadScript(MODEL_VIEWER, { type: 'module' }).catch(function () {
        document.querySelectorAll('[data-model3d] .media-mode-hint').forEach(function (h) { h.textContent = 'Không tải được trình xem 3D (cần mạng).'; });
      });
    }
  }
  window.UTPostMedia = { init: init, loadScript: loadScript, loadCss: loadCss };
  init();
})();
