<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>

<c:set var="pageTitle"       value="Bài viết đã lưu" />
<c:set var="pageDescription" value="Bộ sưu tập bài viết, tài liệu và đồ án bạn đã lưu lại trên UTErSpace." />
<c:set var="extraCss"        value="saved.css" />
<c:set var="currentPage"     value="saved" />
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
          <h1><svg class="icon" aria-hidden="true"><use href="#i-bookmark"></use></svg> Đã lưu</h1>
          <p>Bài viết, tài liệu và đồ án bạn muốn xem lại sau</p>
        </hgroup>
      </header>

      <!-- Bộ sưu tập -->
      <nav aria-label="Bộ sưu tập đã lưu">
        <ul class="pill-tabs">
          <li>
            <a class="pill-tab" href="${ctx}/saved?collection=all"
               aria-selected="${selectedCollection == 'all'}">
              <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg>
              Tất cả <span class="pill-count">${totalCount}</span>
            </a>
          </li>
          <li>
            <a class="pill-tab" href="${ctx}/saved?collection=documents"
               aria-selected="${selectedCollection == 'documents'}">
              <svg class="icon" aria-hidden="true"><use href="#i-bookmark"></use></svg>
              Tài liệu học tập <span class="pill-count">${docsCount}</span>
            </a>
          </li>
          <li>
            <a class="pill-tab" href="${ctx}/saved?collection=projects"
               aria-selected="${selectedCollection == 'projects'}">
              <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg>
              Đồ án &amp; Nghiên cứu <span class="pill-count">${projectsCount}</span>
            </a>
          </li>
          <li>
            <a class="pill-tab" href="${ctx}/saved?collection=lifestyle"
               aria-selected="${selectedCollection == 'lifestyle'}">
              <svg class="icon" aria-hidden="true"><use href="#i-smile"></use></svg>
              Đời sống sinh viên <span class="pill-count">${lifestyleCount}</span>
            </a>
          </li>
        </ul>
      </nav>

      <form class="inline-search" role="search" onsubmit="return false;">
        <label class="u-visually-hidden" for="saved-search-input">Tìm trong mục đã lưu</label>
        <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
        <input type="search" id="saved-search-input" placeholder="Tìm trong mục đã lưu..."
               autocomplete="off" oninput="filterSavedCards(this.value)">
      </form>

      <c:choose>
        <c:when test="${empty savedPosts}">
          <p class="state-empty">
            <svg class="icon" aria-hidden="true"><use href="#i-bookmark"></use></svg>
            <strong>Chưa có bài viết nào trong mục này</strong>
            Khi lướt Bảng tin, bấm biểu tượng dấu trang trên bài viết để lưu lại xem sau.
            <a class="btn-pill" href="${ctx}/feed">
              <svg class="icon" aria-hidden="true"><use href="#i-home"></use></svg> Về Bảng tin
            </a>
          </p>
        </c:when>

        <c:otherwise>
          <div class="saved-grid" id="saved-list">
            <c:forEach var="post" items="${savedPosts}" varStatus="ps">
              <c:set var="postImg"
                     value="${ctx}${post.imageUrl}" />

              <article class="post-card" id="saved-card-${post.postId}"
                       data-search="${fn:toLowerCase(post.content)} ${fn:toLowerCase(post.author.fullName)} ${fn:toLowerCase(post.sharedPost.content)}"
                       aria-labelledby="saved-author-${post.postId}">

                <header class="post-head">
                  <a class="post-author" href="${ctx}/profile?userId=${post.author.userId}">
                    <c:choose>
                      <c:when test="${not empty post.author.avatar}">
                        <img class="post-avatar" src="${ctx}${post.author.avatarUrl}"
                             alt="" width="38" height="38" loading="lazy">
                      </c:when>
                      <c:otherwise>
                        <span class="post-avatar-initials" aria-hidden="true">${post.author.initials}</span>
                      </c:otherwise>
                    </c:choose>
                    <h2 class="post-author-name" id="saved-author-${post.postId}">${post.author.fullName}</h2>
                    <p class="post-author-meta">
                      <c:choose>
                        <c:when test="${post.share}">
                          <svg class="icon" aria-hidden="true"><use href="#i-share"></use></svg>
                          đã chia sẻ một bài viết
                        </c:when>
                        <c:otherwise>
                          <svg class="icon" aria-hidden="true"><use href="#i-pin"></use></svg>
                          ${not empty post.author.location ? post.author.location : 'UTErSpace'}
                        </c:otherwise>
                      </c:choose>
                    </p>
                  </a>
                  <button type="button" class="post-more" title="Bỏ lưu bài viết"
                          aria-label="Bỏ lưu bài viết của ${post.author.fullName}"
                          onclick="unsavePost(${post.postId})">
                    <svg class="icon icon-filled" aria-hidden="true"><use href="#i-bookmark"></use></svg>
                  </button>
                </header>

                <c:choose>
                  <c:when test="${post.share}">
                    <p class="post-caption post-caption--quote" ${empty post.content ? 'hidden' : ''}>
                      <span class="post-caption-text"><c:out value="${post.content}"/></span>
                    </p>
                    <%@ include file="../common/shared-post-embed.jsp" %>
                  </c:when>
                  <c:when test="${post.video}">
                    <c:set var="vpost" value="${post}" />
                    <%@ include file="/WEB-INF/views/common/post-video.jsp" %>
                  </c:when>
                  <c:when test="${not empty post.imagePath}">
                    <figure class="post-media">
                      <img src="${postImg}" alt="Ảnh trong bài viết của ${post.author.fullName}"
                           loading="lazy" decoding="async"
                           onerror="this.onerror=null;this.src='${ctx}/assets/images/study_setup.jpg';">
                    </figure>
                  </c:when>
                </c:choose>

                <footer>
                  <p class="post-likes">
                    <b>${post.likeCount}</b> lượt thích · <span>${post.commentCount}</span> bình luận
                    <c:if test="${not post.share}">· <span>${post.shareCount}</span> chia sẻ</c:if>
                  </p>
                  <c:if test="${not post.share}">
                    <p class="post-caption">
                      <span class="post-caption-text"><c:out value="${post.content}"/></span>
                    </p>
                  </c:if>
                  <p class="saved-foot">
                    <time class="post-time" datetime="${post.createdAt}" data-time="${post.createdAt}">
                      ${post.formattedCreatedAt}
                    </time>
                    <a class="saved-link" href="${ctx}/feed#post-${post.postId}">
                      Xem trên Bảng tin
                      <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg>
                    </a>
                  </p>
                </footer>
              </article>
            </c:forEach>
          </div>

          <p class="state-empty" id="saved-no-match" hidden>
            <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
            <strong>Không tìm thấy bài viết phù hợp</strong>
            Thử một từ khoá khác xem sao.
          </p>
        </c:otherwise>
      </c:choose>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>

<script>
var CTX = '${ctx}';

/* Bộ sưu tập dùng thẻ <a> nên phải tự gán aria-selected dạng chuỗi "true"/"false" */
document.querySelectorAll('.pill-tab[aria-selected]').forEach(function (el) {
  if (el.getAttribute('aria-selected') !== 'true') el.setAttribute('aria-selected', 'false');
});

function relativeTime(raw) {
  var d = new Date(raw);
  if (isNaN(d)) return raw;
  var diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60)      return 'vừa xong';
  if (diff < 3600)    return Math.floor(diff / 60) + ' phút trước';
  if (diff < 86400)   return Math.floor(diff / 3600) + ' giờ trước';
  if (diff < 2592000) return Math.floor(diff / 86400) + ' ngày trước';
  return d.toLocaleDateString('vi-VN');
}
document.querySelectorAll('.post-time, .shared-embed-time').forEach(function (el) {
  var raw = el.getAttribute('data-time');
  if (raw) el.textContent = relativeTime(raw);
});

function unsavePost(postId) {
  var card = document.getElementById('saved-card-' + postId);
  if (!card) return;
  card.style.pointerEvents = 'none';

  fetch(CTX + '/saved/remove', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      if (!data.success) throw new Error('failed');
      card.style.transition = 'opacity .3s, transform .3s';
      card.style.opacity = '0';
      card.style.transform = 'scale(.95)';
      setTimeout(function () {
        card.remove();
        showToast('Đã bỏ lưu bài viết 🔖', 'success');
      }, 300);
    })
    .catch(function () {
      showToast('Không thể bỏ lưu bài viết', 'error');
      card.style.pointerEvents = 'auto';
    });
}

function filterSavedCards(query) {
  var q = query.toLowerCase().trim();
  var shown = 0;
  document.querySelectorAll('#saved-list .post-card').forEach(function (card) {
    var hay = card.getAttribute('data-search') || '';
    var ok = (q === '' || hay.indexOf(q) !== -1);
    card.style.display = ok ? '' : 'none';
    if (ok) shown++;
  });
  var none = document.getElementById('saved-no-match');
  if (none) {
    if (shown === 0) { none.removeAttribute('hidden'); } else { none.setAttribute('hidden', ''); }
  }
}
</script>

<%@ include file="../common/footer.jsp" %>
