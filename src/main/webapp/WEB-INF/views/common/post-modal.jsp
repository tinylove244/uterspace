<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  post-modal.jsp — Hộp thoại soạn bài viết, dùng chung cho mọi trang.
  Gửi về POST /feed/create (XMLHttpRequest để có thanh tiến trình khi upload video) rồi tải lại trang.
  Mỗi bài một media: ảnh HOẶC video (plan mục 5.1).
  Migration 090 (assets/js/composer-ai.js):
    - Trợ lý AI: viết chú thích theo giọng văn (nhìn cả ảnh), tóm tắt bài dài, dịch, tạo ảnh nghệ thuật từ văn bản.
    - Ảnh: chọn hiển thị thường / 360° / 3D chiều sâu; vật thể 3D .glb (xem 3D + AR).
    - Video: phụ đề tự động (nhận dạng giọng nói ngay trên trình duyệt) + nghe thử thuyết minh.
    - Trước khi đăng: cảnh báo nhẹ nếu bài có vẻ rất tiêu cực.
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="me"  value="${sessionScope.currentUser}" />

<div class="modal-overlay" id="post-modal" role="dialog" aria-modal="true" aria-labelledby="post-modal-title">
  <article class="modal modal-compose">
    <header class="modal-header">
      <h2 id="post-modal-title">Tạo bài viết</h2>
      <button type="button" class="modal-close" onclick="closeModal('post-modal')" aria-label="Đóng hộp thoại">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>

    <div class="modal-body">
      <p class="compose-author">
        <c:choose>
          <c:when test="${not empty me.avatar}">
            <img src="${ctx}${me.avatarUrl}" alt="" width="42" height="42">
          </c:when>
          <c:otherwise>
            <span class="compose-initials" aria-hidden="true">${me.initials}</span>
          </c:otherwise>
        </c:choose>
        <span>
          <span class="compose-author-name">${me.fullName}</span><br>
          <c:choose>
            <%-- Trang nhóm (người xem là thành viên) đặt postGroup trước khi include: bài đăng vào nhóm --%>
            <c:when test="${not empty postGroup}">
              <input type="hidden" id="post-group-id" value="${postGroup.groupId}">
              <span class="compose-group-note">
                <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg>
                Đăng trong nhóm <b><c:out value="${postGroup.name}"/></b>
              </span>
            </c:when>
            <c:otherwise>
              <label class="u-visually-hidden" for="post-visibility">Chế độ hiển thị</label>
              <select class="visibility-select" id="post-visibility" onchange="syncPrivacyHint(this, 'post-privacy-hint')">
                <option value="public">🌐 Công khai</option>
                <option value="friends">👥 Bạn bè</option>
                <option value="private">🔒 Chỉ mình tôi</option>
              </select>
            </c:otherwise>
          </c:choose>
        </span>
      </p>

      <p class="privacy-hint" id="post-privacy-hint" hidden>
        <svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>
        Bài sẽ được đăng ở chế độ ẩn: chỉ bạn thấy trong trang cá nhân. Bạn có thể bấm "Hiện lại" bất cứ lúc nào.
      </p>

      <label class="u-visually-hidden" for="post-content-input">Nội dung bài viết</label>
      <textarea class="compose-textarea" id="post-content-input" rows="5"
                placeholder="Bạn đang nghĩ gì thế, ${me.firstName}?"></textarea>

      <%-- Trợ lý AI tạo sinh --%>
      <div class="ai-bar" id="ai-bar">
        <span class="ai-bar-label">✨ Trợ lý AI <small id="ai-mode-note"></small></span>
        <span class="ai-bar-tools">
          <label class="u-visually-hidden" for="ai-tone">Giọng văn</label>
          <select id="ai-tone" class="ai-select" title="Giọng văn của chú thích">
            <option value="friendly">😊 Thân thiện</option>
            <option value="inspiring">💪 Truyền cảm hứng</option>
            <option value="funny">😂 Hài hước</option>
            <option value="professional">💼 Chuyên nghiệp</option>
            <option value="short">✂️ Ngắn gọn</option>
          </select>
          <button type="button" class="ai-chip" onclick="ComposerAI.caption()" title="AI viết chú thích từ ý tưởng của bạn (và ảnh đính kèm)">✍️ Viết chú thích</button>
          <button type="button" class="ai-chip" onclick="ComposerAI.summarize()" title="Thêm dòng tóm tắt cho bài dài">📝 Tóm tắt</button>
          <button type="button" class="ai-chip" onclick="ComposerAI.translate()" title="Dịch nội dung Việt ⇄ Anh">🌐 Dịch</button>
          <button type="button" class="ai-chip" onclick="ComposerAI.openArt()" title="Tạo ảnh nghệ thuật từ nội dung bài">🎨 Tạo ảnh</button>
          <button type="button" class="ai-chip ai-chip--ghost" id="ai-undo" hidden onclick="ComposerAI.undo()">↶ Hoàn tác</button>
        </span>
      </div>

      <%-- Tạo ảnh nghệ thuật từ văn bản (vẽ trên máy, không gửi đi đâu) --%>
      <div class="art-panel" id="art-panel" hidden>
        <canvas id="art-canvas" width="1080" height="1080" aria-label="Ảnh nghệ thuật tạo từ văn bản"></canvas>
        <div class="art-controls">
          <label>Phong cách
            <select id="art-style" class="ai-select">
              <option value="nebula">🌌 Tinh vân</option>
              <option value="waves">🌊 Sóng</option>
              <option value="geo">🔷 Hình học</option>
              <option value="bloom">🌸 Nở hoa</option>
            </select></label>
          <label><input type="checkbox" id="art-text" checked> Chèn chữ lên ảnh</label>
          <button type="button" class="ai-chip" onclick="ComposerAI.drawArt(true)">🎲 Vẽ lại</button>
          <button type="button" class="btn-pill btn-pill--sm" onclick="ComposerAI.useArt()">Dùng ảnh này</button>
          <button type="button" class="ai-chip ai-chip--ghost" onclick="document.getElementById('art-panel').hidden = true">Đóng</button>
        </div>
      </div>

      <figure class="compose-preview" id="image-preview-wrap" hidden>
        <img id="image-preview" src="" alt="Xem trước ảnh sắp đăng">
        <button type="button" class="compose-preview-remove" onclick="removeImagePreview()" aria-label="Xóa ảnh">
          <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
        </button>
      </figure>
      <%-- Kiểu hiển thị ảnh (ảnh tỉ lệ 2:1 được gợi ý sẵn là 360°) --%>
      <fieldset class="media-mode-pick" id="media-mode-pick" hidden>
        <legend>Hiển thị ảnh dạng</legend>
        <label><input type="radio" name="media-mode" value="" checked> 🖼️ Ảnh thường</label>
        <label><input type="radio" name="media-mode" value="PANORAMA"> 🌐 Ảnh 360°</label>
        <label><input type="radio" name="media-mode" value="DEPTH"> 🧊 Ảnh 3D chiều sâu</label>
        <small id="media-mode-hint"></small>
      </fieldset>

      <%-- Vật thể 3D / AR (.glb) --%>
      <div class="model-pick" id="model-pick" hidden>
        <span class="model-pick-name" id="model-pick-name"></span>
        <small>Ảnh đính kèm (nếu có) sẽ là ảnh bìa của mô hình. Người xem xoay 3D trên bảng tin, điện thoại xem được bằng AR.</small>
        <button type="button" class="compose-preview-remove" onclick="ComposerAI.removeModel()" aria-label="Bỏ mô hình 3D">
          <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
        </button>
      </div>

      <figure class="compose-preview compose-preview--video" id="video-preview-wrap" hidden>
        <video id="video-preview" controls muted playsinline preload="metadata"></video>
        <figcaption class="compose-video-meta" id="video-preview-meta"></figcaption>
        <button type="button" class="compose-preview-remove" onclick="removeVideoPreview()" aria-label="Bỏ video">
          <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
        </button>
      </figure>
      <%-- Phụ đề tự động (Whisper chạy trong trình duyệt) + thuyết minh --%>
      <div class="caption-tool" id="caption-tool" hidden>
        <p class="caption-tool-row">
          <button type="button" class="ai-chip" id="cc-run" onclick="ComposerAI.autoCaption()">🎙️ Tạo phụ đề tự động</button>
          <select id="cc-model" class="ai-select" title="Mô hình nhận dạng giọng nói">
            <option value="base">Chính xác hơn (~80 MB)</option>
            <option value="tiny">Nhanh (~40 MB)</option>
          </select>
          <select id="cc-lang" class="ai-select" title="Ngôn ngữ nói trong video">
            <option value="vietnamese">Tiếng Việt</option>
            <option value="english">English</option>
          </select>
          <button type="button" class="ai-chip ai-chip--ghost" id="cc-narrate" hidden onclick="ComposerAI.previewNarration()">🗣️ Nghe thử thuyết minh</button>
        </p>
        <p class="caption-tool-status" id="cc-status" aria-live="polite">Mô hình nhận dạng giọng nói được tải về máy bạn một lần; âm thanh không gửi đi đâu.</p>
        <label class="u-visually-hidden" for="cc-vtt">Phụ đề WebVTT</label>
        <textarea id="cc-vtt" class="caption-vtt" rows="5" hidden spellcheck="false"></textarea>
      </div>

      <div class="upload-progress" id="upload-progress" hidden>
        <div class="upload-progress-bar"><span id="upload-progress-fill"></span></div>
        <p class="upload-progress-text" id="upload-progress-text" aria-live="polite">Đang tải lên…</p>
      </div>

      <label class="u-visually-hidden" for="post-image-input">Chọn ảnh đính kèm</label>
      <input type="file" id="post-image-input" accept="image/jpeg,image/png,image/gif,image/webp" hidden onchange="previewImage(this)">
      <label class="u-visually-hidden" for="post-video-input">Chọn video đính kèm</label>
      <input type="file" id="post-video-input" accept="video/mp4,video/webm" hidden onchange="previewVideo(this)">
      <label class="u-visually-hidden" for="post-model-input">Chọn mô hình 3D (.glb)</label>
      <input type="file" id="post-model-input" accept=".glb,model/gltf-binary" hidden onchange="ComposerAI.pickModel(this)">
    </div>

    <footer class="modal-footer" style="justify-content:space-between;align-items:center;">
      <p class="compose-tools">
        <button type="button" class="compose-tool" aria-label="Thêm ảnh"
                onclick="document.getElementById('post-image-input').click()">
          <svg class="icon" aria-hidden="true"><use href="#i-photo"></use></svg>
        </button>
        <button type="button" class="compose-tool" aria-label="Thêm video (MP4 hoặc WEBM, tối đa 100 MB)"
                title="Video MP4 (H.264) hoặc WEBM, tối đa 100 MB"
                onclick="document.getElementById('post-video-input').click()">
          <svg class="icon" aria-hidden="true"><use href="#i-video"></use></svg>
        </button>
        <button type="button" class="compose-tool compose-tool--text" aria-label="Thêm vật thể 3D / AR (.glb, tối đa 20 MB)"
                title="Vật thể 3D / AR (.glb, tối đa 20 MB)"
                onclick="document.getElementById('post-model-input').click()">🧊</button>
        <button type="button" class="compose-tool" aria-label="Thêm cảm xúc" onclick="ComposerAI.emoji(this)">
          <svg class="icon" aria-hidden="true"><use href="#i-smile"></use></svg>
        </button>
      </p>
      <button type="button" class="btn-create" id="submit-post-btn" onclick="submitNewPost()">
        <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg>
        <span>Đăng bài</span>
      </button>
    </footer>
  </article>
</div>

<script>
/** Hiện dòng giải thích khi chọn "🔒 Chỉ mình tôi" (dùng cho hộp đăng bài và hộp sửa bài) */
function syncPrivacyHint(sel, hintId) {
  var hint = document.getElementById(hintId);
  if (hint) hint.hidden = sel.value !== 'private';
}
var POST_MAX_IMAGE = 10 * 1024 * 1024;
var POST_MAX_VIDEO = 100 * 1024 * 1024;
var postVideoDuration = 0;      // giây, đọc ở trình duyệt khi loadedmetadata
var postVideoPlayable = false;  // trình duyệt giải mã được (mp4 phải H.264 + AAC)

function previewImage(input) {
  var file = input.files && input.files[0];
  if (!file) return;
  if (file.size > POST_MAX_IMAGE) {
    showToast('Ảnh tối đa 10 MB.', 'error');
    input.value = '';
    return;
  }
  removeVideoPreview();   // mỗi bài chỉ một media
  var reader = new FileReader();
  reader.onload = function (e) {
    document.getElementById('image-preview').src = e.target.result;
    document.getElementById('image-preview-wrap').removeAttribute('hidden');
    if (window.ComposerAI) ComposerAI.onImage(e.target.result);
  };
  reader.readAsDataURL(file);
}

function removeImagePreview() {
  document.getElementById('image-preview-wrap').setAttribute('hidden', '');
  document.getElementById('image-preview').src = '';
  document.getElementById('post-image-input').value = '';
  if (window.ComposerAI) ComposerAI.onImage(null);
}

function formatBytes(n) { return (n / 1024 / 1024).toFixed(1) + ' MB'; }
function formatDuration(sec) {
  sec = Math.round(sec);
  return Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
}

function previewVideo(input) {
  var file = input.files && input.files[0];
  if (!file) return;
  if (!/^video\/(mp4|webm)$/.test(file.type) && !/\.(mp4|webm)$/i.test(file.name)) {
    showToast('Chỉ nhận video MP4 hoặc WEBM.', 'error');
    input.value = '';
    return;
  }
  if (file.size > POST_MAX_VIDEO) {
    showToast('Video ' + formatBytes(file.size) + ' vượt giới hạn 100 MB.', 'error');
    input.value = '';
    return;
  }
  removeImagePreview();   // mỗi bài chỉ một media

  var video = document.getElementById('video-preview');
  var meta  = document.getElementById('video-preview-meta');
  postVideoDuration = 0;
  postVideoPlayable = false;
  video.ondurationchange = null;   // bỏ trình đọc thời lượng của file chọn trước đó
  if (video.src) URL.revokeObjectURL(video.src);
  meta.textContent = 'Đang đọc video…';

  function showVideoMeta() {
    postVideoDuration = isFinite(video.duration) ? video.duration : 0;
    meta.textContent = postVideoPlayable
      ? file.name + ' · ' + formatBytes(file.size) + (postVideoDuration > 0 ? ' · ' + formatDuration(postVideoDuration) : '')
      : 'Không đọc được hình ảnh của video này. Hãy xuất lại thành MP4 (H.264 + AAC).';
    meta.classList.toggle('is-error', !postVideoPlayable);
  }
  // Không upload file mà trình duyệt không phát được (vd: MP4 H.265/HEVC) — báo lỗi rõ trước khi gửi
  video.onloadedmetadata = function () {
    postVideoPlayable = video.videoWidth > 0;
    showVideoMeta();
    if (!postVideoPlayable || isFinite(video.duration)) return;
    // WEBM quay từ trình duyệt / ghi màn hình không ghi thời lượng vào header (duration = Infinity):
    // tua tới cuối để trình duyệt tự tính thời lượng, rồi quay lại đầu
    video.ondurationchange = function () {
      if (!isFinite(video.duration)) return;
      video.ondurationchange = null;
      video.currentTime = 0;
      showVideoMeta();
    };
    video.currentTime = 1e101;
  };
  video.onerror = function () {
    postVideoPlayable = false;
    meta.textContent = 'Trình duyệt không phát được video này (codec không hỗ trợ, vd: H.265/HEVC). Hãy xuất lại thành MP4 (H.264 + AAC).';
    meta.classList.add('is-error');
  };
  video.src = URL.createObjectURL(file);
  document.getElementById('video-preview-wrap').removeAttribute('hidden');
  if (window.ComposerAI) ComposerAI.onVideo(file);
}

function removeVideoPreview() {
  var video = document.getElementById('video-preview');
  if (video.src) URL.revokeObjectURL(video.src);
  video.removeAttribute('src');
  video.load();
  document.getElementById('video-preview-wrap').setAttribute('hidden', '');
  document.getElementById('video-preview-meta').classList.remove('is-error');
  document.getElementById('post-video-input').value = '';
  postVideoDuration = 0;
  postVideoPlayable = false;
  if (window.ComposerAI) ComposerAI.onVideo(null);
}

function setUploadProgress(percent, text) {
  var box = document.getElementById('upload-progress');
  box.hidden = percent === null;
  if (percent === null) return;
  document.getElementById('upload-progress-fill').style.width = percent + '%';
  document.getElementById('upload-progress-text').textContent = text;
}

function submitNewPost() {
  var contentInput = document.getElementById('post-content-input');
  var imageInput   = document.getElementById('post-image-input');
  var videoInput   = document.getElementById('post-video-input');
  var btn          = document.getElementById('submit-post-btn');
  var content      = contentInput.value.trim();
  var videoFile    = videoInput.files && videoInput.files[0];

  if (!content) {
    contentInput.focus();
    showToast('Vui lòng nhập nội dung bài viết!', 'error');
    return;
  }
  if (videoFile && !postVideoPlayable) {
    showToast('Video chưa sẵn sàng hoặc trình duyệt không phát được — hãy chọn file MP4 (H.264) hoặc WEBM khác.', 'error');
    return;
  }
  // Nhắc nhẹ trước khi đăng bài có vẻ rất tiêu cực (phân tích cảm xúc tức thì bằng từ điển, /ai/sentiment)
  if (window.ComposerAI && !submitNewPost._toneOk) {
    btn.disabled = true;
    ComposerAI.checkTone(content).then(function (go) {
      btn.disabled = false;
      if (!go) return;
      submitNewPost._toneOk = true;
      try { submitNewPost(); } finally { submitNewPost._toneOk = false; }
    });
    return;
  }

  var formData = new FormData();
  formData.append('content', content);
  var groupInput = document.getElementById('post-group-id');
  if (groupInput) {
    formData.append('groupId', groupInput.value);
  } else {
    // "Chỉ mình tôi" = đăng ở trạng thái tự ẩn; phạm vi khi hiện lại mặc định là Bạn bè (an toàn hơn Công khai)
    var vis = document.getElementById('post-visibility').value;
    formData.append('visibility', vis === 'private' ? 'friends' : vis);
    if (vis === 'private') formData.append('hidden', 'true');
  }
  if (imageInput.files && imageInput.files.length > 0) formData.append('image', imageInput.files[0]);
  // Media nâng cao: kiểu ảnh (360° / 3D chiều sâu), vật thể 3D .glb, phụ đề video
  if (window.ComposerAI) ComposerAI.appendExtras(formData, !!(imageInput.files && imageInput.files.length), !!videoFile);
  if (videoFile) {
    formData.append('video', videoFile);
    formData.append('videoDuration', String(postVideoDuration));
  }

  // XMLHttpRequest thay fetch: fetch không báo tiến trình upload (plan mục 5.1)
  var xhr = new XMLHttpRequest();
  xhr.open('POST', '${ctx}/feed/create');
  if (videoFile) {
    xhr.upload.onprogress = function (e) {
      if (!e.lengthComputable) return;
      var pct = Math.round(e.loaded / e.total * 100);
      setUploadProgress(pct, pct < 100 ? 'Đang tải video lên… ' + pct + '% (' + formatBytes(e.loaded) + ' / ' + formatBytes(e.total) + ')'
                                       : 'Đang xử lý trên máy chủ…');
    };
    setUploadProgress(0, 'Bắt đầu tải lên…');
  }
  xhr.onload = function () {
    var data = {};
    try { data = JSON.parse(xhr.responseText); } catch (e) { }
    if (xhr.status === 200 && data.success) {
      setUploadProgress(null);
      showToast(data.hidden ? 'Đã đăng bài ở chế độ Chỉ mình tôi 🔒 — xem trong trang cá nhân.'
                            : 'Đã đăng bài thành công! 🎉', 'success');
      contentInput.value = '';
      var visSel = document.getElementById('post-visibility');
      if (visSel) { visSel.value = 'public'; syncPrivacyHint(visSel, 'post-privacy-hint'); }
      removeImagePreview();
      removeVideoPreview();
      if (window.ComposerAI) ComposerAI.reset();
      closeModal('post-modal');
      setTimeout(function () { window.location.reload(); }, 800);
    } else {
      fail(data.error || (xhr.status === 413 ? 'File quá lớn.' : 'Lỗi khi đăng bài (' + xhr.status + ')'));
    }
  };
  xhr.onerror = function () { fail('Mất kết nối khi tải lên — file có thể quá lớn, thử lại nhé.'); };
  function fail(msg) {
    setUploadProgress(null);
    showToast(msg, 'error');
    btn.disabled = false;
  }
  btn.disabled = true;
  xhr.send(formData);
}
</script>
<script src="${ctx}/assets/js/composer-ai.js?v=${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}"></script>
