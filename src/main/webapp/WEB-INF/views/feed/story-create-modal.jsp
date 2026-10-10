<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%--
  story-create-modal.jsp — Hộp thoại "Tạo tin mới": chọn ảnh hoặc video → xem trước khung 9:16 → chú thích → đăng.
  Kiểm tra ngay ở trình duyệt (server kiểm tra lại): ảnh ≤ 10 MB; video MP4/WEBM ≤ 50 MB, ≤ 60 giây, phát được.
  Gửi bằng XMLHttpRequest để hiện % tải lên → POST /stories/create. Yêu cầu: ctx.
--%>
<div class="modal-overlay" id="story-modal" role="dialog" aria-modal="true" aria-labelledby="story-modal-title">
  <article class="modal modal-compose story-compose">
    <header class="modal-header">
      <h2 id="story-modal-title">Tạo tin mới</h2>
      <button type="button" class="modal-close" onclick="closeStoryCreate()" aria-label="Đóng hộp thoại">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>

    <div class="modal-body">
      <%-- Bước 1: chọn file (bấm hoặc kéo thả) --%>
      <label class="story-drop" id="story-drop" for="story-file">
        <span class="story-drop-icons" aria-hidden="true">
          <svg class="icon"><use href="#i-photo"></use></svg>
          <svg class="icon"><use href="#i-video"></use></svg>
        </span>
        <b>Chọn ảnh hoặc video</b>
        <span>hoặc kéo thả file vào đây</span>
        <small>Ảnh JPG/PNG/WEBP/GIF ≤ 10 MB · Video MP4/WEBM ≤ 50 MB, tối đa 60 giây</small>
      </label>
      <input type="file" id="story-file" class="u-visually-hidden"
             accept="image/jpeg,image/png,image/gif,image/webp,video/mp4,video/webm">

      <%-- Bước 2: xem trước đúng tỉ lệ khung tin 9:16, chú thích hiện đè như khi đăng --%>
      <div class="story-preview-wrap" id="story-preview-wrap" hidden>
        <div class="story-preview" id="story-preview">
          <p class="story-preview-caption" id="story-preview-caption" hidden></p>
          <button type="button" class="story-preview-remove" onclick="resetStoryCreate()" aria-label="Chọn file khác">
            <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
          </button>
        </div>
        <p class="story-file-meta" id="story-file-meta" aria-live="polite"></p>
      </div>

      <div class="story-caption-field">
        <label for="story-caption">Chú thích <span>(không bắt buộc)</span></label>
        <input type="text" id="story-caption" maxlength="200" autocomplete="off"
               placeholder="Viết gì đó cho tin của bạn..." oninput="syncStoryCaption()">
        <span class="story-caption-count" id="story-caption-count">0/200</span>
      </div>

      <div class="upload-progress" id="story-progress" hidden>
        <div class="upload-progress-bar"><span id="story-progress-fill"></span></div>
        <p class="upload-progress-text" id="story-progress-text" aria-live="polite">Đang tải lên…</p>
      </div>
      <p class="story-note">
        <svg class="icon" aria-hidden="true"><use href="#i-clock"></use></svg>
        Tin chỉ bạn bè nhìn thấy và tự biến mất sau 24 giờ.
      </p>
    </div>

    <footer class="modal-footer">
      <button type="button" class="btn-pill btn-pill--ghost" onclick="closeStoryCreate()">Hủy</button>
      <button type="button" class="btn-pill" id="story-submit-btn" onclick="submitStory()" disabled>
        <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg> Đăng tin
      </button>
    </footer>
  </article>
</div>

<script>
(function () {
  var MAX_IMAGE = 10 * 1024 * 1024, MAX_VIDEO = 50 * 1024 * 1024, MAX_SEC = 60;
  var IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
  var VIDEO_TYPES = ['video/mp4', 'video/webm'];
  var fileInput = document.getElementById('story-file');
  var drop      = document.getElementById('story-drop');
  var state = { file: null, isVideo: false, duration: null, ready: false, objectUrl: null };

  function fmtBytes(n) { return n >= 1048576 ? (n / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(n / 1024)) + ' KB'; }
  function setReady(ok, meta, isError) {
    state.ready = ok;
    document.getElementById('story-submit-btn').disabled = !ok;
    var m = document.getElementById('story-file-meta');
    m.textContent = meta || '';
    m.classList.toggle('is-error', !!isError);
  }
  function clearPreview() {
    var box = document.getElementById('story-preview');
    box.querySelectorAll('img, video').forEach(function (n) { n.remove(); });
    if (state.objectUrl) { URL.revokeObjectURL(state.objectUrl); state.objectUrl = null; }
  }

  window.resetStoryCreate = function () {
    clearPreview();
    state = { file: null, isVideo: false, duration: null, ready: false, objectUrl: null };
    fileInput.value = '';
    document.getElementById('story-preview-wrap').hidden = true;
    drop.hidden = false;
    setReady(false, '');
  };

  window.openStoryCreate = function () {
    resetStoryCreate();
    document.getElementById('story-caption').value = '';
    syncStoryCaption();
    openModal('story-modal');
  };
  window.closeStoryCreate = function () {
    clearPreview();
    closeModal('story-modal');
  };

  window.syncStoryCaption = function () {
    var v = document.getElementById('story-caption').value;
    document.getElementById('story-caption-count').textContent = v.length + '/200';
    var cap = document.getElementById('story-preview-caption');
    cap.textContent = v;
    cap.hidden = !v.trim();
  };

  function pick(file) {
    if (!file) return;
    var isImage = IMAGE_TYPES.indexOf(file.type) >= 0, isVideo = VIDEO_TYPES.indexOf(file.type) >= 0;
    if (!isImage && !isVideo) { showToast('Chỉ chấp nhận ảnh JPG/PNG/WEBP/GIF hoặc video MP4/WEBM.', 'error'); return; }
    if (isImage && file.size > MAX_IMAGE) { showToast('Ảnh tối đa 10 MB (file này ' + fmtBytes(file.size) + ').', 'error'); return; }
    if (isVideo && file.size > MAX_VIDEO) { showToast('Video tối đa 50 MB (file này ' + fmtBytes(file.size) + ').', 'error'); return; }

    clearPreview();
    state.file = file; state.isVideo = isVideo; state.duration = null;
    state.objectUrl = URL.createObjectURL(file);
    drop.hidden = true;
    document.getElementById('story-preview-wrap').hidden = false;
    var box = document.getElementById('story-preview');

    if (isImage) {
      var img = document.createElement('img');
      img.src = state.objectUrl; img.alt = 'Xem trước tin';
      box.insertBefore(img, box.firstChild);
      setReady(true, '🖼️ Ảnh · ' + fmtBytes(file.size) + ' · hiển thị 5 giây');
      return;
    }
    // Video: đọc thời lượng + kiểm tra trình duyệt phát được trước khi cho đăng
    var v = document.createElement('video');
    v.src = state.objectUrl; v.muted = true; v.loop = true; v.playsInline = true; v.autoplay = true;
    box.insertBefore(v, box.firstChild);
    setReady(false, 'Đang đọc video…');
    v.addEventListener('loadedmetadata', function () {
      state.duration = v.duration;
      if (!isFinite(v.duration) || v.duration <= 0) { setReady(false, 'Không đọc được thời lượng video.', true); return; }
      if (v.duration > MAX_SEC + 0.5) {
        setReady(false, 'Video dài ' + Math.round(v.duration) + ' giây — tin chỉ cho phép tối đa ' + MAX_SEC + ' giây.', true);
        return;
      }
      setReady(true, '🎬 Video · ' + Math.round(v.duration) + ' giây · ' + fmtBytes(file.size));
    });
    v.addEventListener('error', function () {
      setReady(false, 'Trình duyệt không phát được video này — hãy chọn MP4 (H.264) hoặc WEBM khác.', true);
    });
  }

  fileInput.addEventListener('change', function () { pick(fileInput.files[0]); });
  ['dragenter', 'dragover'].forEach(function (ev) {
    drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.add('is-drag'); });
  });
  ['dragleave', 'drop'].forEach(function (ev) {
    drop.addEventListener(ev, function (e) { e.preventDefault(); drop.classList.remove('is-drag'); });
  });
  drop.addEventListener('drop', function (e) { pick(e.dataTransfer.files[0]); });

  function progress(pct, text) {
    var box = document.getElementById('story-progress');
    box.hidden = pct === null;
    if (pct === null) return;
    document.getElementById('story-progress-fill').style.width = pct + '%';
    document.getElementById('story-progress-text').textContent = text;
  }

  window.submitStory = function () {
    if (!state.ready || !state.file) return;
    var btn = document.getElementById('story-submit-btn');
    btn.disabled = true;
    var fd = new FormData();
    fd.append('media', state.file);
    fd.append('caption', document.getElementById('story-caption').value.trim());
    if (state.isVideo && state.duration) fd.append('duration', String(Math.round(state.duration)));

    var xhr = new XMLHttpRequest();
    xhr.open('POST', '${ctx}/stories/create');
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.upload.onprogress = function (e) {
      if (!e.lengthComputable) return;
      var pct = Math.round(e.loaded / e.total * 100);
      progress(pct, pct < 100 ? 'Đang tải lên… ' + pct + '% (' + fmtBytes(e.loaded) + ' / ' + fmtBytes(e.total) + ')' : 'Đang xử lý…');
    };
    progress(0, 'Bắt đầu tải lên…');
    xhr.onload = function () {
      var d = {};
      try { d = JSON.parse(xhr.responseText); } catch (err) { }
      if (xhr.status === 200 && d.success) {
        progress(null);
        closeStoryCreate();
        showToast('Đã đăng tin! Tin sẽ hiển thị trong 24 giờ ✨', 'success');
        setTimeout(function () { location.reload(); }, 700);
      } else {
        progress(null);
        btn.disabled = false;
        showToast(d.error || (xhr.status === 413 ? 'File quá lớn.' : 'Không đăng được tin (' + xhr.status + ')'), 'error');
      }
    };
    xhr.onerror = function () { progress(null); btn.disabled = false; showToast('Mất kết nối khi tải lên, thử lại nhé.', 'error'); };
    xhr.send(fd);
  };
})();
</script>
