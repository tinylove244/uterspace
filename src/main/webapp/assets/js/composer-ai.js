/* ============================================================
   composer-ai.js — Trợ lý AI + media nâng cao trong hộp "Tạo bài viết" (post-modal.jsp).

   ✍️ Viết chú thích   POST /ai/caption (Gemini / Claude nhìn cả ảnh đính kèm; offline: mẫu câu theo giọng văn + hashtag)
   📝 Tóm tắt          POST /ai/summarize → thêm dòng "TL;DR" lên đầu bài dài
   🌐 Dịch             POST /ai/translate (Việt ⇄ Anh); máy chủ chưa có AI → Translator API của trình duyệt
   🎨 Tạo ảnh          tranh trừu tượng vẽ trên <canvas> — bảng màu theo cảm xúc của câu chữ, hình khối theo từ khóa,
                       cùng một câu luôn ra cùng một bức (hạt giống = băm văn bản). Không gửi gì ra ngoài.
   🧊 Vật thể 3D/AR    chọn file .glb; ảnh đính kèm làm ảnh bìa
   🌐 / 🧊 Kiểu ảnh    ảnh thường / 360° (tự gợi ý khi tỉ lệ 2:1) / 3D chiều sâu
   🎙️ Phụ đề tự động   Whisper (transformers.js, chạy WebAssembly trên máy) nhận dạng giọng nói trong video → WebVTT
   🗣️ Thuyết minh      đọc thử phụ đề bằng giọng đọc trình duyệt
   Trước khi đăng: /ai/sentiment — bài rất tiêu cực thì hỏi lại một lần (sức khỏe tinh thần cộng đồng).
   ============================================================ */
(function () {
  'use strict';
  function ctx() { return (window.UT && window.UT.ctx) || window.CTX || ''; }
  var $ = function (id) { return document.getElementById(id); };
  var undoStack = [];
  var modelFile = null;
  var aiOnline = null;

  function toast(m, t) { if (window.showToast) showToast(m, t); }
  function post(path, body) {
    var init = { method: 'POST', headers: { 'Accept': 'application/json' } };
    if (body instanceof FormData) init.body = body;
    else { init.body = new URLSearchParams(body).toString(); init.headers['Content-Type'] = 'application/x-www-form-urlencoded'; }
    return fetch(ctx() + path, init).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) throw new Error(d.error || ('Lỗi ' + r.status));
        return d;
      });
    });
  }
  function input() { return $('post-content-input'); }
  function setText(t, label) {
    undoStack.push(input().value);
    input().value = t;
    $('ai-undo').hidden = false;
    input().dispatchEvent(new Event('input'));
    if (label) toast(label, 'success');
  }
  function busy(btn, on, text) {
    if (!btn) return;
    if (on) { btn._t = btn.textContent; btn.textContent = text || 'Đang xử lý…'; btn.disabled = true; }
    else { btn.textContent = btn._t || btn.textContent; btn.disabled = false; }
  }
  var providerName = 'AI';
  function sourceNote(src) { return src === 'AI' ? ' (' + providerName + ')' : ' (chế độ offline)'; }

  /* ---------- Trạng thái AI máy chủ ---------- */
  function loadStatus() {
    if (aiOnline !== null) return;
    aiOnline = false;
    fetch(ctx() + '/ai/status', { headers: { Accept: 'application/json' } }).then(function (r) { return r.json(); })
      .then(function (d) {
        aiOnline = !!d.ai;
        var n = $('ai-mode-note');
        if (d.provider) providerName = d.provider;
        if (n) n.textContent = d.ai ? '· ' + d.provider : '· offline (chưa cấu hình API key)';
      }).catch(function () { });
  }
  document.addEventListener('click', function (e) { if (e.target.closest('[onclick*="post-modal"], .btn-create, .composer-open')) loadStatus(); }, true);

  /* ---------- Ảnh thu nhỏ gửi cho AI (≤ 1280px JPEG) ---------- */
  function shrinkImage(dataUrl) {
    return new Promise(function (resolve) {
      var img = new Image();
      img.onload = function () {
        var max = 1280, w = img.naturalWidth, h = img.naturalHeight, k = Math.min(1, max / Math.max(w, h));
        var c = document.createElement('canvas');
        c.width = Math.round(w * k); c.height = Math.round(h * k);
        c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        c.toBlob(function (b) { resolve(b); }, 'image/jpeg', 0.85);
      };
      img.onerror = function () { resolve(null); };
      img.src = dataUrl;
    });
  }

  var api = {};

  api.caption = function () {
    var btn = event && event.target;
    var fd = new FormData();
    fd.append('draft', input().value.trim());
    fd.append('tone', $('ai-tone').value);
    var imgEl = $('image-preview'), hasImg = !$('image-preview-wrap').hidden && imgEl.src;
    busy(btn, true, '✍️ Đang viết…');
    (hasImg ? shrinkImage(imgEl.src) : Promise.resolve(null)).then(function (blob) {
      if (blob) fd.append('image', blob, 'image.jpg');
      return post('/ai/caption', fd);
    }).then(function (d) {
      var cur = input().value.trim();
      // Đã có bài dài → chèn chú thích lên đầu thay vì xóa bài
      setText(cur.length > 200 ? d.text + '\n\n' + cur : d.text, 'Đã viết chú thích' + sourceNote(d.source));
    }).catch(function (e) { toast(e.message, 'error'); }).then(function () { busy(btn, false); });
  };

  api.summarize = function () {
    var btn = event && event.target, text = input().value.trim();
    if (text.length < 200) { toast('Bài còn ngắn (dưới 200 ký tự) — chưa cần tóm tắt.', 'error'); return; }
    busy(btn, true, '📝 Đang tóm tắt…');
    post('/ai/summarize', { text: text }).then(function (d) {
      setText('📝 Tóm tắt: ' + d.text + '\n\n' + text, 'Đã thêm tóm tắt' + sourceNote(d.source));
    }).catch(function (e) { toast(e.message, 'error'); }).then(function () { busy(btn, false); });
  };

  function looksVietnamese(t) { return /[ăâđêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]/i.test(t); }
  api.translate = function () {
    var btn = event && event.target, text = input().value.trim();
    if (!text) { toast('Chưa có nội dung để dịch.', 'error'); return; }
    var to = looksVietnamese(text) ? 'en' : 'vi';
    busy(btn, true, '🌐 Đang dịch…');
    post('/ai/translate', { text: text, to: to }).then(function (d) {
      if (!d.offline) { setText(d.text, 'Đã dịch sang ' + (to === 'en' ? 'tiếng Anh' : 'tiếng Việt') + sourceNote(d.source)); return; }
      if (!('Translator' in self)) throw new Error('Máy chủ chưa cấu hình AI và trình duyệt chưa có bộ dịch tích hợp (Chrome 138+).');
      return Translator.create({ sourceLanguage: to === 'en' ? 'vi' : 'en', targetLanguage: to })
        .then(function (tr) { return tr.translate(text); })
        .then(function (t) { setText(t, 'Đã dịch bằng bộ dịch của trình duyệt'); });
    }).catch(function (e) { toast(e.message, 'error'); }).then(function () { busy(btn, false); });
  };

  api.undo = function () {
    if (!undoStack.length) return;
    input().value = undoStack.pop();
    $('ai-undo').hidden = !undoStack.length;
  };

  /* ============================================================ Tạo ảnh nghệ thuật từ văn bản */
  function hash(str) {
    var h = 2166136261;
    for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  }
  function rng(seed) {   // mulberry32
    return function () {
      seed |= 0; seed = seed + 0x6D2B79F5 | 0;
      var t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  function fold(s) { return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').toLowerCase(); }
  /** Từ khóa → sắc độ (hue) gợi hình */
  var HUES = [   // khớp NGUYÊN TỪ trên văn bản đã bỏ dấu; mục đầu tiên khớp được dùng
    [/\b(bien|song bien|dai duong|ocean|sea|bau troi|sky)\b/, 205], [/\b(hoang hon|sunset|binh minh)\b/, 22],
    [/\b(rung|cay xanh|thien nhien|forest|nature|cong vien|nui)\b/, 125], [/\b(lua|chay|fire|dam me)\b/, 355],
    [/\b(nang|mat troi|mua he|sun|summer)\b/, 45], [/\b(hoa|hoa hong|anh dao|pink)\b/, 330],
    [/\b(dem|ngoi sao|vu tru|space|night|tinh van)\b/, 250], [/\b(tuyet|mua dong|lanh|winter|snow)\b/, 195],
    [/\b(ca phe|cafe|coffee|mua thu|autumn)\b/, 28], [/\b(code|lap trinh|may tinh|cong nghe|ai|robot|iot)\b/, 170],
    [/\b(hoc|thi|do an|thu vien|sach)\b/, 220], [/\b(yeu|tinh yeu|love)\b/, 340]
  ];
  var lastSeedBump = 0;
  api.openArt = function () {
    $('art-panel').hidden = false;
    lastSeedBump = 0;
    api.drawArt(false);
  };
  api.drawArt = function (reroll) {
    if (reroll) lastSeedBump++;
    var text = input().value.trim() || 'UTErSpace';
    var f = fold(text);
    var r = rng(hash(text) + lastSeedBump * 7919);
    var c = $('art-canvas'), g = c.getContext('2d'), W = c.width, H = c.height;
    // Cảm xúc → độ sáng / độ bão hòa (tích cực: rực rỡ; tiêu cực: trầm lạnh)
    var mood = 0;
    if (/vui|hanh phuc|tuyet|yeu|thich|cam on|chuc mung|thanh cong|dep|😍|🎉|❤/.test(f)) mood += 1;
    if (/buon|chan|met|ap luc|lo lang|that vong|khoc|ghet|😢|😭/.test(f)) mood -= 1;
    var base = Math.floor(r() * 360);
    for (var hi = 0; hi < HUES.length; hi++) { if (HUES[hi][0].test(f)) { base = HUES[hi][1] + Math.floor(r() * 20 - 10); break; } }
    var sat = mood > 0 ? 85 : mood < 0 ? 35 : 60, light = mood > 0 ? 60 : mood < 0 ? 32 : 50;
    function col(dh, a, dl) { return 'hsla(' + ((base + dh + 360) % 360) + ',' + sat + '%,' + Math.max(8, Math.min(90, light + (dl || 0))) + '%,' + a + ')'; }

    var bg = g.createLinearGradient(0, 0, W, H);
    bg.addColorStop(0, col(-30, 1, -25)); bg.addColorStop(1, col(40, 1, -10));
    g.globalCompositeOperation = 'source-over';
    g.fillStyle = bg; g.fillRect(0, 0, W, H);
    var style = $('art-style').value;
    var i, x, y, rad;
    if (style === 'nebula') {
      g.globalCompositeOperation = 'lighter';
      for (i = 0; i < 70; i++) {
        x = r() * W; y = r() * H; rad = 80 + r() * 380;
        var rg = g.createRadialGradient(x, y, 0, x, y, rad);
        rg.addColorStop(0, col(r() * 120 - 60, 0.22, 15)); rg.addColorStop(1, col(0, 0, 0));
        g.fillStyle = rg; g.beginPath(); g.arc(x, y, rad, 0, Math.PI * 2); g.fill();
      }
      for (i = 0; i < 400; i++) { g.fillStyle = 'rgba(255,255,255,' + (r() * 0.8) + ')'; g.fillRect(r() * W, r() * H, r() * 2.5, r() * 2.5); }
    } else if (style === 'waves') {
      for (i = 0; i < 14; i++) {
        g.beginPath();
        var y0 = H * (i / 14) + r() * 40, amp = 30 + r() * 90, freq = 0.004 + r() * 0.006, ph = r() * 10;
        g.moveTo(0, H);
        for (x = 0; x <= W; x += 8) g.lineTo(x, y0 + Math.sin(x * freq + ph) * amp);
        g.lineTo(W, H); g.closePath();
        g.fillStyle = col(i * 6 - 40, 0.18 + i * 0.03, i * 2 - 10);
        g.fill();
      }
    } else if (style === 'geo') {
      for (i = 0; i < 46; i++) {
        g.save();
        g.translate(r() * W, r() * H); g.rotate(r() * Math.PI);
        g.fillStyle = col(r() * 160 - 80, 0.25 + r() * 0.5, r() * 30 - 10);
        var sz = 60 + r() * 260, kind = Math.floor(r() * 3);
        g.beginPath();
        if (kind === 0) g.rect(-sz / 2, -sz / 2, sz, sz);
        else if (kind === 1) { g.moveTo(0, -sz / 2); g.lineTo(sz / 2, sz / 2); g.lineTo(-sz / 2, sz / 2); g.closePath(); }
        else g.arc(0, 0, sz / 2, 0, Math.PI * 2);
        g.fill();
        g.restore();
      }
    } else {   // bloom
      g.translate(W / 2, H / 2);
      var petals = 6 + Math.floor(r() * 10);
      for (var layer = 6; layer > 0; layer--) {
        for (i = 0; i < petals; i++) {
          g.save();
          g.rotate((Math.PI * 2 / petals) * i + layer * 0.3);
          g.beginPath();
          g.ellipse(0, -layer * 55, 40 + layer * 18, layer * 70, 0, 0, Math.PI * 2);
          g.fillStyle = col(layer * 14 - 40, 0.22, layer * 4 - 5);
          g.fill();
          g.restore();
        }
      }
      g.setTransform(1, 0, 0, 1, 0, 0);
    }
    g.globalCompositeOperation = 'source-over';
    if ($('art-text').checked) {
      var line = text.replace(/#\S+/g, '').replace(/\s+/g, ' ').trim().slice(0, 90) || 'UTErSpace';
      g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(0, H - 230, W, 230);
      g.fillStyle = '#fff'; g.textAlign = 'center';
      g.font = '600 52px Poppins, "Segoe UI", sans-serif';
      var words = line.split(' '), rows = [], cur = '';
      words.forEach(function (w) { if (g.measureText(cur + ' ' + w).width > W - 140) { rows.push(cur); cur = w; } else cur = (cur ? cur + ' ' : '') + w; });
      rows.push(cur);
      rows.slice(0, 3).forEach(function (t, k) { g.fillText(t, W / 2, H - 160 + k * 62); });
    }
    g.font = '500 24px Poppins, sans-serif'; g.textAlign = 'right'; g.fillStyle = 'rgba(255,255,255,.7)';
    g.fillText('🎨 UTErSpace Art', W - 30, 44);
  };
  api.useArt = function () {
    $('art-canvas').toBlob(function (blob) {
      var file = new File([blob], 'uterspace-art.png', { type: 'image/png' });
      var dt = new DataTransfer();
      dt.items.add(file);
      var inp = $('post-image-input');
      inp.files = dt.files;
      if (window.previewVideo) removeVideoPreview();
      previewImage(inp);
      $('art-panel').hidden = true;
      toast('Đã đính kèm ảnh nghệ thuật 🎨', 'success');
    }, 'image/png');
  };

  /* ============================================================ Kiểu ảnh: thường / 360° / 3D */
  api.onImage = function (dataUrl) {
    var pick = $('media-mode-pick');
    if (!pick) return;
    pick.hidden = !dataUrl;
    pick.querySelector('input[value=""]').checked = true;
    $('media-mode-hint').textContent = '';
    if (!dataUrl) return;
    var img = new Image();
    img.onload = function () {
      var ratio = img.naturalWidth / img.naturalHeight;
      if (Math.abs(ratio - 2) < 0.08) {
        pick.querySelector('input[value="PANORAMA"]').checked = true;
        $('media-mode-hint').textContent = 'Ảnh có tỉ lệ 2:1 — có vẻ là ảnh 360° (equirectangular), đã chọn sẵn.';
      }
    };
    img.src = dataUrl;
  };

  /* ============================================================ Vật thể 3D */
  api.pickModel = function (inp) {
    var f = inp.files && inp.files[0];
    inp.value = '';
    if (!f) return;
    if (!/\.glb$/i.test(f.name)) { toast('Chỉ nhận mô hình 3D định dạng .glb', 'error'); return; }
    if (f.size > 20 * 1024 * 1024) { toast('Mô hình 3D tối đa 20 MB.', 'error'); return; }
    modelFile = f;
    if (window.removeVideoPreview) removeVideoPreview();
    $('model-pick').hidden = false;
    $('model-pick-name').textContent = '🧊 ' + f.name + ' · ' + (f.size / 1048576).toFixed(1) + ' MB';
  };
  api.removeModel = function () { modelFile = null; $('model-pick').hidden = true; };

  /* ============================================================ Phụ đề tự động (Whisper trên trình duyệt) */
  var videoFile = null, asrCache = {};
  api.onVideo = function (file) {
    videoFile = file;
    var box = $('caption-tool');
    if (!box) return;
    box.hidden = !file;
    if (file) api.removeModel();
    $('cc-vtt').hidden = true; $('cc-vtt').value = '';
    $('cc-narrate').hidden = true;
    $('cc-status').textContent = 'Mô hình nhận dạng giọng nói được tải về máy bạn một lần; âm thanh không gửi đi đâu.';
  };

  function toVtt(chunks) {
    function ts(t) {
      t = Math.max(0, t || 0);
      var h = Math.floor(t / 3600), m = Math.floor(t % 3600 / 60), s = (t % 60).toFixed(3);
      return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0') + ':' + s.padStart(6, '0');
    }
    var out = 'WEBVTT\n\n', n = 0;
    chunks.forEach(function (c, i) {
      var text = (c.text || '').trim();
      if (!text) return;
      var start = c.timestamp[0], end = c.timestamp[1] != null ? c.timestamp[1] : start + 4;
      out += (++n) + '\n' + ts(start) + ' --> ' + ts(end) + '\n' + text + '\n\n';
    });
    return out;
  }

  api.autoCaption = function () {
    if (!videoFile) return;
    var btn = $('cc-run'), status = $('cc-status');
    var size = $('cc-model').value, lang = $('cc-lang').value;
    busy(btn, true, '🎙️ Đang xử lý…');
    status.textContent = 'Đang tách âm thanh từ video…';
    var AC = window.AudioContext || window.webkitAudioContext;
    videoFile.arrayBuffer().then(function (buf) {
      var ac = new AC();
      return ac.decodeAudioData(buf).then(function (audio) {
        ac.close();
        if (audio.duration > 600) throw new Error('Phụ đề tự động hỗ trợ video tối đa 10 phút.');
        // Trộn về mono 16 kHz (định dạng Whisper cần)
        var off = new OfflineAudioContext(1, Math.ceil(audio.duration * 16000), 16000);
        var src = off.createBufferSource();
        src.buffer = audio; src.connect(off.destination); src.start();
        return off.startRendering();
      });
    }).then(function (rendered) {
      status.textContent = 'Đang tải mô hình nhận dạng giọng nói (' + (size === 'tiny' ? '~40' : '~80') + ' MB, chỉ lần đầu)…';
      var key = size;
      if (!asrCache[key]) {
        asrCache[key] = import('https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.0.2').then(function (T) {
          return T.pipeline('automatic-speech-recognition', 'onnx-community/whisper-' + size, {
            dtype: 'q8',
            progress_callback: function (p) {
              if (p.status === 'progress' && p.file && /onnx/.test(p.file)) status.textContent = 'Đang tải mô hình… ' + Math.round(p.progress || 0) + '%';
            }
          });
        });
      }
      return asrCache[key].then(function (asr) {
        status.textContent = 'Đang nhận dạng giọng nói (' + Math.round(rendered.duration) + ' giây âm thanh)… có thể mất một lúc.';
        return asr(rendered.getChannelData(0), {
          language: lang, task: 'transcribe', return_timestamps: true, chunk_length_s: 30, stride_length_s: 5
        });
      });
    }).then(function (res) {
      var chunks = res.chunks && res.chunks.length ? res.chunks : [{ timestamp: [0, null], text: res.text }];
      var vtt = toVtt(chunks);
      $('cc-vtt').value = vtt;
      $('cc-vtt').hidden = false;
      $('cc-narrate').hidden = false;
      status.textContent = '✅ Đã tạo ' + chunks.length + ' câu phụ đề — bạn có thể sửa trực tiếp bên dưới trước khi đăng.';
    }).catch(function (e) {
      status.textContent = '❌ ' + (e && e.message ? e.message : 'Không tạo được phụ đề.') +
        (e && /decode/i.test(String(e.message)) ? ' (Video không có âm thanh hoặc trình duyệt không giải mã được.)' : '');
    }).then(function () { busy(btn, false); });
  };

  api.previewNarration = function () {
    if (!window.speechSynthesis) { toast('Trình duyệt không hỗ trợ đọc văn bản.', 'error'); return; }
    speechSynthesis.cancel();
    var lines = $('cc-vtt').value.split(/\n\n+/).map(function (b) {
      var parts = b.split('\n'); return parts.length >= 3 ? parts.slice(2).join(' ') : '';
    }).filter(Boolean).slice(0, 6);
    var u = new SpeechSynthesisUtterance(lines.join('. '));
    u.lang = $('cc-lang').value === 'english' ? 'en-US' : 'vi-VN';
    speechSynthesis.speak(u);
    toast('Đang đọc thử 6 câu phụ đề đầu tiên 🗣️');
  };

  /* ============================================================ Biểu tượng cảm xúc */
  var EMOJIS = ['😀', '😂', '😊', '😍', '🥳', '😎', '🤔', '😢', '😭', '😡', '👍', '👏', '🙏', '💪', '🎉', '🔥', '❤️', '💯', '✨', '📚', '💻', '☕', '🎵', '📷'];
  api.emoji = function (btn) {
    var old = document.querySelector('.composer-emoji');
    if (old) { old.remove(); return; }
    var box = document.createElement('div');
    box.className = 'composer-emoji';
    EMOJIS.forEach(function (em) {
      var b = document.createElement('button');
      b.type = 'button'; b.textContent = em;
      b.addEventListener('click', function () {
        var t = input(), s = t.selectionStart || t.value.length;
        t.value = t.value.slice(0, s) + em + t.value.slice(t.selectionEnd || s);
        t.focus(); t.selectionStart = t.selectionEnd = s + em.length;
      });
      box.appendChild(b);
    });
    btn.parentNode.appendChild(box);
  };

  /* ============================================================ Trước khi đăng */
  api.checkTone = function (text) {
    return post('/ai/sentiment', { text: text }).then(function (d) {
      if (d.label !== 'NEGATIVE' || d.score > -0.5 || !window.UTConfirm) return true;
      return UTConfirm({
        title: 'Bài viết có vẻ khá tiêu cực',
        message: 'Hệ thống nhận thấy bài có nhiều từ ngữ tiêu cực' + (d.cues && d.cues.length ? ' (' + d.cues.slice(0, 4).join(', ') + ')' : '') +
                 '. Bạn vẫn muốn đăng chứ? Nếu đang gặp chuyện buồn, hãy nhắn cho bạn bè hoặc thầy cô cố vấn — luôn có người sẵn sàng lắng nghe 💙',
        ok: 'Vẫn đăng', cancel: 'Xem lại'
      });
    }).catch(function () { return true; });
  };

  api.appendExtras = function (fd, hasImage, hasVideo) {
    var mode = document.querySelector('input[name="media-mode"]:checked');
    if (modelFile) {
      fd.append('model', modelFile);
      fd.append('mediaMode', 'MODEL3D');
    } else if (hasImage && mode && mode.value) {
      fd.append('mediaMode', mode.value);
    }
    var vtt = $('cc-vtt');
    if (hasVideo && vtt && vtt.value.trim().indexOf('WEBVTT') === 0) fd.append('captionsVtt', vtt.value);
  };

  api.reset = function () {
    api.removeModel();
    api.onVideo(null);
    undoStack = [];
    $('ai-undo').hidden = true;
    $('art-panel').hidden = true;
  };

  window.ComposerAI = api;
})();
