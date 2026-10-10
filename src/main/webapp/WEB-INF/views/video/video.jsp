<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>

<c:set var="pageTitle"       value="Video" />
<c:set var="pageDescription" value="Xem video, demo đồ án và clip do cộng đồng sinh viên UTErSpace chia sẻ." />
<c:set var="extraCss"        value="video.css" />
<c:set var="currentPage"     value="video" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>

<c:set var="ctx" value="${pageContext.request.contextPath}" />

<div class="app-shell">

  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">

    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section">
      <header class="page-head">
        <hgroup>
          <h1><svg class="icon" aria-hidden="true"><use href="#i-video"></use></svg> Video</h1>
          <p>Demo đồ án, vlog và clip được chia sẻ trong cộng đồng UTErSpace — cuộn để xem tiếp</p>
        </hgroup>
        <p class="page-head-actions">
          <button type="button" class="btn-pill" onclick="openVideoUpload()">
            <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng video
          </button>
        </p>
      </header>

      <nav aria-label="Bộ lọc video">
        <ul class="pill-tabs">
          <li>
            <a class="pill-tab" href="${ctx}/video?tab=all" aria-selected="${videoTab == 'all'}">
              <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg> Tất cả
              <c:if test="${videoTab == 'all'}"><span class="pill-count">${videoTotal}</span></c:if>
            </a>
          </li>
          <li>
            <a class="pill-tab" href="${ctx}/video?tab=friends" aria-selected="${videoTab == 'friends'}">
              <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg> Bạn bè
              <c:if test="${videoTab == 'friends'}"><span class="pill-count">${videoTotal}</span></c:if>
            </a>
          </li>
        </ul>
      </nav>

      <c:choose>
        <c:when test="${empty videoPosts}">
          <p class="state-empty">
            <svg class="icon" aria-hidden="true"><use href="#i-video"></use></svg>
            <c:choose>
              <c:when test="${videoTab == 'friends'}">
                <strong>Bạn bè chưa đăng video nào</strong>
                Kết bạn thêm để xem video từ những người bạn quen.
              </c:when>
              <c:otherwise>
                <strong>Chưa có video nào</strong>
                Hãy là người đầu tiên chia sẻ một clip với cộng đồng!
              </c:otherwise>
            </c:choose>
            <button type="button" class="btn-pill" onclick="openVideoUpload()">
              <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng video
            </button>
          </p>
        </c:when>

        <c:otherwise>
          <%-- Cuộn dọc kiểu Reels: mỗi video chiếm trọn khung, scroll-snap dừng đúng từng video --%>
          <div class="reels" id="reels" tabindex="0" aria-label="Danh sách video, cuộn để xem tiếp">
            <c:forEach var="post" items="${videoPosts}">
              <article class="reel" id="reel-${post.postId}" aria-labelledby="reel-author-${post.postId}">
                <div class="reel-stage">
                  <c:choose>
                    <c:when test="${not empty post.videoPath}">
                      <video class="reel-video" src="${ctx}${post.videoUrl}#t=0.5" controls muted loop playsinline
                             preload="metadata" data-autoplay
                             <c:if test="${not empty post.imagePath}">poster="${ctx}${post.imageUrl}"</c:if>></video>
                    </c:when>
                    <c:otherwise>
                      <c:if test="${not empty post.imagePath}"><img class="reel-poster" src="${ctx}${post.imageUrl}" alt="" loading="lazy"></c:if>
                      <span class="video-missing">
                        <svg class="icon" aria-hidden="true"><use href="#i-video"></use></svg> Video mẫu — chưa có file video
                      </span>
                    </c:otherwise>
                  </c:choose>

                  <div class="reel-info">
                    <a class="reel-author" href="${ctx}/profile?userId=${post.author.userId}">
                      <c:choose>
                        <c:when test="${not empty post.author.avatar}">
                          <img src="${ctx}${post.author.avatarUrl}" alt="" width="36" height="36" loading="lazy">
                        </c:when>
                        <c:otherwise>
                          <span class="reel-initials" aria-hidden="true">${post.author.initials}</span>
                        </c:otherwise>
                      </c:choose>
                      <span class="reel-name" id="reel-author-${post.postId}"><c:out value="${post.author.fullName}"/></span>
                    </a>
                    <c:if test="${not empty post.groupId}">
                      <a class="reel-group" href="${ctx}/groups/view?id=${post.groupId}">
                        <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg>
                        <c:out value="${post.groupName}"/>
                      </a>
                    </c:if>
                    <p class="reel-caption post-caption-text"><c:out value="${post.content}"/></p>
                    <p class="reel-meta">
                      <c:if test="${post.videoDurationSec > 0}">${post.formattedDuration} · </c:if>
                      <time datetime="${post.createdAt}" data-time="${post.createdAt}">${post.formattedCreatedAt}</time>
                    </p>
                  </div>
                </div>

                <aside class="reel-actions" aria-label="Tương tác với video">
                  <button type="button" class="reel-action ${post.likedByCurrentUser ? 'is-active' : ''}"
                          aria-pressed="${post.likedByCurrentUser}" aria-label="Thích video"
                          onclick="toggleReelLike(${post.postId}, this)">
                    <svg class="icon" aria-hidden="true"><use href="#i-heart"></use></svg>
                    <span id="like-count-${post.postId}">${post.likeCount}</span>
                  </button>
                  <a class="reel-action" href="${ctx}/profile?userId=${post.author.userId}#profile-post-${post.postId}"
                     aria-label="Xem bình luận">
                    <svg class="icon" aria-hidden="true"><use href="#i-comment"></use></svg>
                    <span>${post.commentCount}</span>
                  </a>
                  <button type="button" class="reel-action" aria-label="Sao chép liên kết video"
                          onclick="copyReelLink(${post.postId}, ${post.author.userId})">
                    <svg class="icon" aria-hidden="true"><use href="#i-link"></use></svg>
                  </button>
                </aside>
              </article>
            </c:forEach>
          </div>

          <c:if test="${videoPages > 1}">
            <nav class="pager" aria-label="Phân trang video">
              <a class="btn-pill btn-pill--ghost" href="${ctx}/video?tab=${videoTab}&amp;page=${videoPage - 1}"
                 ${videoPage <= 1 ? 'aria-disabled="true" tabindex="-1"' : ''}>← Trước</a>
              <span class="pager-info">Trang <b>${videoPage}</b> / ${videoPages}</span>
              <a class="btn-pill btn-pill--ghost" href="${ctx}/video?tab=${videoTab}&amp;page=${videoPage + 1}"
                 ${videoPage >= videoPages ? 'aria-disabled="true" tabindex="-1"' : ''}>Sau →</a>
            </nav>
          </c:if>
        </c:otherwise>
      </c:choose>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>

<script>
var CTX = '${ctx}';

/* Bộ lọc dùng thẻ <a> nên chuẩn hoá aria-selected về "true"/"false" */
document.querySelectorAll('.pill-tab[aria-selected]').forEach(function (el) {
  if (el.getAttribute('aria-selected') !== 'true') el.setAttribute('aria-selected', 'false');
});

/* Mở hộp thoại đăng bài và chọn video luôn */
function openVideoUpload() {
  openModal('post-modal');
  document.getElementById('post-video-input').click();
}

function toggleReelLike(postId, btn) {
  btn.disabled = true;
  fetch(CTX + '/feed/like', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId
  })
    .then(function (res) { if (!res.ok) throw new Error(); return res.json(); })
    .then(function (data) {
      btn.classList.toggle('is-active', data.liked);
      btn.setAttribute('aria-pressed', String(data.liked));
      document.getElementById('like-count-' + postId).textContent = data.likeCount;
    })
    .catch(function () { showToast('Không thể thích video này', 'error'); })
    .then(function () { btn.disabled = false; });
}

function copyReelLink(postId, authorId) {
  var url = location.origin + CTX + '/profile?userId=' + authorId + '#profile-post-' + postId;
  (navigator.clipboard ? navigator.clipboard.writeText(url) : Promise.resolve())
    .finally(function () { showToast('Đã sao chép liên kết! 🔗', 'success'); });
}

/* Thời gian tương đối */
document.querySelectorAll('.reel-meta time[data-time]').forEach(function (el) {
  var d = new Date(el.getAttribute('data-time'));
  if (isNaN(d)) return;
  var s = Math.floor((Date.now() - d) / 1000);
  el.textContent = s < 60 ? 'vừa xong' : s < 3600 ? Math.floor(s / 60) + ' phút trước'
                 : s < 86400 ? Math.floor(s / 3600) + ' giờ trước' : Math.floor(s / 86400) + ' ngày trước';
});
</script>

<%@ include file="../common/footer.jsp" %>
