/* ============================================================
   post-ai.js — Công cụ AI cho NGƯỜI ĐỌC trên thẻ bài viết + bộ lọc bình luận.

   🌐 Dịch     POST /ai/translate {postId, to} (Gemini / Claude). Máy chủ chưa cấu hình AI → dùng Translator API có sẵn
               trong trình duyệt (Chrome 138+, dịch ngay trên máy) nếu có.
   📝 Tóm tắt  POST /ai/summarize {postId} (Gemini / Claude, hoặc thuật toán trích câu khi offline).
   🔊 Nghe     Text-to-Speech của trình duyệt (speechSynthesis): chọn giọng, tốc độ, cao độ ("ngữ điệu") — lưu trên máy.
   🗣️ Thuyết minh video: đọc to từng câu phụ đề (track WebVTT) đúng lúc video chạy, tự hạ âm lượng gốc.
   UTFilter    từ khóa bộ lọc cá nhân (post-support.jsp nhúng #ut-filter-terms) — thu gọn bình luận chứa từ khóa.
   ============================================================ */
(function () {
  'use strict';
  var CTX = window.CTX || (window.UT && window.UT.ctx) || '';
  var LANGS = { vi: 'Tiếng Việt', en: 'English', ja: '日本語', ko: '한국어', zh: '中文', fr: 'Français' };

  function fold(s) {
    return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase();
  }

  /* ============================================================ Bộ lọc nội dung (bình luận) */
  var terms = [];
  try { terms = JSON.parse(document.getElementById('ut-filter-terms').textContent || '[]'); } catch (e) { terms = []; }
  var matchers = terms.map(function (t) {
    var f = fold(t), wordy = /[\p{L}\p{N}]/u.test(f);
    var esc = f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return { term: t, re: wordy ? new RegExp('(^|[^\\p{L}\\p{N}])' + esc + '(?![\\p{L}\\p{N}])', 'u') : null, raw: t };
  });
  window.UTFilter = {
    terms: terms,
    match: function (text) {
      if (!text || !matchers.length) return null;
      var f = fold(text);
      for (var i = 0; i < matchers.length; i++) {
        var m = matchers[i];
        if (m.re ? m.re.test(f) : text.indexOf(m.raw) >= 0) return m.term;
      }
      return null;
    }
  };

  /* ============================================================ Tiện ích */
  function post(path, data) {
    return fetch(CTX + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
      body: new URLSearchParams(data).toString()
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) throw new Error(d.error || ('Lỗi ' + r.status));
        return d;
      });
    });
  }
  function postText(card) {
    var t = card.querySelector('.post-caption-text');
    return t ? t.textContent.trim() : '';
  }
  function resultBox(postId) { return document.getElementById('post-ai-result-' + postId); }
  function showResult(postId, title, text, source, extra) {
    var box = resultBox(postId);
    box.hidden = false;
    box.textContent = '';
    var head = document.createElement('p');
    head.className = 'post-ai-head';
    var b = document.createElement('b');
    b.textContent = title;
    head.appendChild(b);
    if (source) {
      var src = document.createElement('small');
      src.textContent = source === 'AI' ? ' · ' + (window.UT_AI_PROVIDER || 'AI') : source === 'BROWSER' ? ' · bộ dịch của trình duyệt' : ' · thuật toán offline';
      head.appendChild(src);
    }
    var x = document.createElement('button');
    x.type = 'button';
    x.className = 'post-ai-close';
    x.setAttribute('aria-label', 'Đóng');
    x.textContent = '×';
    x.addEventListener('click', function () { box.hidden = true; stopSpeak(); });
    head.appendChild(x);
    box.appendChild(head);
    if (text != null) {
      var p = document.createElement('p');
      p.className = 'post-ai-text';
      p.textContent = text;
      box.appendChild(p);
    }
    if (extra) box.appendChild(extra);
    return box;
  }
  function loading(postId, title) { showResult(postId, title, 'Đang xử lý…', null); }

  /* ============================================================ Dịch */
  function looksVietnamese(t) { return /[ăâđêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]/i.test(t); }

  function browserTranslate(text, to) {
    if (!('Translator' in self)) return Promise.reject(new Error('no-browser-translator'));
    var detect = ('LanguageDetector' in self)
      ? LanguageDetector.create().then(function (d) { return d.detect(text); }).then(function (r) { return (r && r[0] && r[0].detectedLanguage) || 'en'; })
      : Promise.resolve(looksVietnamese(text) ? 'vi' : 'en');
    return detect.then(function (from) {
      if (from === to) return text;
      return Translator.create({ sourceLanguage: from, targetLanguage: to }).then(function (tr) { return tr.translate(text); });
    });
  }

  function translateMenu(btn, postId) {
    var old = document.querySelector('.post-ai-menu');
    if (old) { old.remove(); if (old._for === btn) return; }
    var text = postText(btn.closest('.post-card'));
    var def = looksVietnamese(text) ? 'en' : 'vi';
    var menu = document.createElement('div');
    menu.className = 'post-ai-menu';
    menu._for = btn;
    Object.keys(LANGS).forEach(function (code) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = (code === def ? '★ ' : '') + LANGS[code];
      b.addEventListener('click', function () { menu.remove(); doTranslate(postId, code, text); });
      menu.appendChild(b);
    });
    btn.parentNode.appendChild(menu);
  }

  function doTranslate(postId, to, text) {
    loading(postId, '🌐 Bản dịch ' + LANGS[to]);
    post('/ai/translate', { postId: postId, to: to }).then(function (d) {
      if (d.provider) window.UT_AI_PROVIDER = d.provider;
      if (!d.offline) { showResult(postId, '🌐 Bản dịch ' + LANGS[to], d.text, d.source); return; }
      return browserTranslate(text, to).then(function (t) {
        showResult(postId, '🌐 Bản dịch ' + LANGS[to], t, 'BROWSER');
      }, function () {
        showResult(postId, '🌐 Dịch', 'Máy chủ chưa cấu hình AI (Gemini / Claude) và trình duyệt này chưa có bộ dịch tích hợp (Chrome 138+). ' +
                   'Quản trị viên có thể bật AI theo hướng dẫn trong db/uterspace-ai.properties.example.', null);
      });
    }).catch(function (e) { showResult(postId, '🌐 Dịch', e.message, null); });
  }

  /* ============================================================ Tóm tắt */
  function doSummarize(postId) {
    loading(postId, '📝 Tóm tắt');
    post('/ai/summarize', { postId: postId })
      .then(function (d) { if (d.provider) window.UT_AI_PROVIDER = d.provider; showResult(postId, '📝 Tóm tắt', d.text, d.source); })
      .catch(function (e) { showResult(postId, '📝 Tóm tắt', e.message, null); });
  }

  /* ============================================================ Text-to-Speech */
  var TTS_KEY = 'ut.tts';
  function ttsPrefs() {
    try { return JSON.parse(localStorage.getItem(TTS_KEY)) || {}; } catch (e) { return {}; }
  }
  function saveTts(p) { try { localStorage.setItem(TTS_KEY, JSON.stringify(p)); } catch (e) { } }
  function voices() { return window.speechSynthesis ? speechSynthesis.getVoices() : []; }
  function pickVoice(lang) {
    var pref = ttsPrefs(), list = voices();
    var chosen = list.find(function (v) { return v.voiceURI === pref.voice; });
    if (chosen && (!lang || chosen.lang.slice(0, 2) === lang)) return chosen;
    return list.find(function (v) { return v.lang && v.lang.slice(0, 2) === lang; }) || null;
  }
  /** "Ngữ điệu" có sẵn: tốc độ + cao độ */
  var STYLES = {
    news:   { label: '📰 Phát thanh viên', rate: 1.0,  pitch: 1.0 },
    warm:   { label: '☕ Ấm áp, chậm rãi',  rate: 0.85, pitch: 0.9 },
    bright: { label: '🎉 Vui tươi',         rate: 1.15, pitch: 1.25 },
    fast:   { label: '⚡ Đọc nhanh',         rate: 1.45, pitch: 1.0 }
  };
  function speak(text, lang, onEnd) {
    if (!window.speechSynthesis) { if (window.showToast) showToast('Trình duyệt không hỗ trợ đọc văn bản (Text-to-Speech).', 'error'); return null; }
    var pref = ttsPrefs(), st = STYLES[pref.style] || STYLES.news;
    var u = new SpeechSynthesisUtterance(text);
    u.lang = lang === 'en' ? 'en-US' : 'vi-VN';
    var v = pickVoice(lang);
    if (v) u.voice = v;
    u.rate = st.rate; u.pitch = st.pitch;
    if (onEnd) u.onend = onEnd;
    speechSynthesis.speak(u);
    return u;
  }
  function stopSpeak() { if (window.speechSynthesis) speechSynthesis.cancel(); }

  function ttsControls(text, lang) {
    var wrap = document.createElement('div');
    wrap.className = 'tts-controls';
    var styleSel = document.createElement('select');
    styleSel.setAttribute('aria-label', 'Ngữ điệu');
    Object.keys(STYLES).forEach(function (k) {
      var o = document.createElement('option'); o.value = k; o.textContent = STYLES[k].label; styleSel.appendChild(o);
    });
    styleSel.value = ttsPrefs().style || 'news';
    var voiceSel = document.createElement('select');
    voiceSel.setAttribute('aria-label', 'Giọng đọc');
    function fillVoices() {
      voiceSel.textContent = '';
      var list = voices().filter(function (v) { return /^(vi|en)/.test(v.lang); });
      if (!list.length) list = voices();
      var auto = document.createElement('option'); auto.value = ''; auto.textContent = '🎙️ Giọng tự động'; voiceSel.appendChild(auto);
      list.forEach(function (v) {
        var o = document.createElement('option'); o.value = v.voiceURI; o.textContent = v.name + ' (' + v.lang + ')'; voiceSel.appendChild(o);
      });
      voiceSel.value = ttsPrefs().voice || '';
    }
    fillVoices();
    if (window.speechSynthesis) speechSynthesis.addEventListener('voiceschanged', fillVoices);
    var play = document.createElement('button');
    play.type = 'button'; play.className = 'btn-pill btn-pill--sm'; play.textContent = '⏸ Dừng';
    var speaking = true;
    function restart() {
      stopSpeak();
      speak(text, lang, function () { speaking = false; play.textContent = '▶ Nghe lại'; });
      speaking = true; play.textContent = '⏸ Dừng';
    }
    play.addEventListener('click', function () {
      if (speaking) { stopSpeak(); speaking = false; play.textContent = '▶ Nghe lại'; } else restart();
    });
    function onChange() { saveTts({ style: styleSel.value, voice: voiceSel.value }); restart(); }
    styleSel.addEventListener('change', onChange);
    voiceSel.addEventListener('change', onChange);
    wrap.appendChild(play); wrap.appendChild(styleSel); wrap.appendChild(voiceSel);
    wrap._start = restart;
    return wrap;
  }

  function doSpeak(postId, card) {
    var text = postText(card);
    if (!text) return;
    var lang = looksVietnamese(text) || !/[a-z]{3,}/i.test(text) ? 'vi' : 'en';
    var controls = ttsControls(text, lang);
    showResult(postId, '🔊 Đang đọc bài viết', null, null, controls);
    controls._start();
  }

  /* ============================================================ Gắn sự kiện */
  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.post-ai-btn');
    if (btn) {
      var row = btn.closest('[data-post-ai]'), postId = row.getAttribute('data-post-ai'), card = btn.closest('.post-card');
      var kind = btn.getAttribute('data-ai');
      if (kind === 'translate') translateMenu(btn, postId);
      else if (kind === 'summarize') doSummarize(postId);
      else if (kind === 'speak') doSpeak(postId, card);
      return;
    }
    if (!e.target.closest('.post-ai-menu')) { var m = document.querySelector('.post-ai-menu'); if (m) m.remove(); }

    var nb = e.target.closest('[data-narrate]');
    if (nb) toggleNarration(nb);
  });

  /* ============================================================ Thuyết minh video (đọc phụ đề) */
  function toggleNarration(btn) {
    var video = btn.closest('figure').querySelector('video');
    var track = video && video.textTracks && video.textTracks[0];
    if (!track) return;
    if (btn._on) {
      btn._on = false; btn.classList.remove('is-on'); btn.textContent = '🗣️ Thuyết minh';
      track.oncuechange = null; stopSpeak(); video.volume = btn._vol || 1;
      return;
    }
    btn._on = true; btn.classList.add('is-on'); btn.textContent = '🗣️ Đang thuyết minh';
    track.mode = 'showing';
    btn._vol = video.volume;
    video.muted = false;
    video.volume = Math.min(video.volume, 0.25);    // hạ tiếng gốc để nghe rõ giọng thuyết minh
    function sayCurrent() {
      var cue = track.activeCues && track.activeCues[0];
      if (!cue) return;
      stopSpeak();
      speak(cue.text.replace(/<[^>]+>/g, ''), looksVietnamese(cue.text) ? 'vi' : 'en');
    }
    track.oncuechange = sayCurrent;
    if (video.paused) video.play().catch(function () { });
    // Câu phụ đề đang hiện lúc bấm sẽ không phát sinh cuechange → đọc ngay (đợi track nạp xong)
    setTimeout(sayCurrent, 300);
  }
})();
