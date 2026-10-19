<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>

<%-- Cấu hình trang: đặt trước khi include header.
     Trang này phục vụ cả /feed lẫn /hashtag?tag=X (khi có thuộc tính "hashtag"). --%>
<c:choose>
  <c:when test="${not empty hashtag}">
    <c:set var="pageTitle"       value="#${hashtag}" />
    <c:set var="pageDescription" value="Tổng hợp các bài viết gắn thẻ #${hashtag} trên UTErSpace." />
  </c:when>
  <c:otherwise>
    <c:set var="pageTitle"       value="Bảng tin" />
    <c:set var="pageDescription" value="Bảng tin UTErSpace — theo dõi bài viết, tin và hoạt động mới nhất từ bạn bè, nhóm và cộng đồng sinh viên HCMUTE." />
  </c:otherwise>
</c:choose>
<c:set var="extraCss"        value="feed.css" />
<c:set var="currentPage"     value="feed" />
<%-- Trang này có thanh công cụ riêng nằm trong khung ứng dụng --%>
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>

<c:set var="ctx"  value="${pageContext.request.contextPath}" />
<c:set var="me"   value="${sessionScope.currentUser}" />

<div class="app-shell">

  <c:if test="${empty hashtag}">
    <h1 class="u-visually-hidden">Bảng tin UTErSpace</h1>
  </c:if>

  <%@ include file="../common/app-sidebar.jsp" %>


  <!-- ============================================================
       CỘT PHẢI — Thanh công cụ + nội dung
       ============================================================ -->
  <main class="app-main" id="main-content">

    <%@ include file="../common/app-topbar.jsp" %>

    <c:choose>
    <%-- ---------- TRANG HASHTAG: tiêu đề thay cho Tin + Gợi ý kết bạn ---------- --%>
    <c:when test="${not empty hashtag}">
    <section class="app-section">
      <header class="page-head hashtag-head">
        <hgroup>
          <h1><span class="hashtag-mark">#</span>${hashtag}</h1>
          <p><b>${fn:length(posts)}</b> bài viết gắn thẻ này từ cộng đồng và bạn bè của bạn</p>
        </hgroup>
        <p class="page-head-actions">
          <a class="btn-pill btn-pill--ghost" href="${ctx}/feed">
            <svg class="icon" aria-hidden="true"><use href="#i-arrow-left"></use></svg> Bảng tin
          </a>
          <button type="button" class="btn-pill" onclick="composeWithHashtag('${hashtag}')">
            <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng bài với #${hashtag}
          </button>
        </p>
      </header>
    </section>
    </c:when>

    <c:otherwise>
    <!-- ---------- TIN (Stories) ---------- -->
    <section class="app-section" aria-labelledby="stories-title">
      <header class="section-head">
        <h2 class="section-title" id="stories-title">
          <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg> Tin
        </h2>
      </header>

      <%-- Thanh Tin: vòng của mình đứng đầu, sau đó bạn bè có tin trong 24 giờ (StoryDAO.getRings).
           Vòng màu = còn tin chưa xem, vòng xám (.is-seen) = đã xem hết. Thứ tự [data-story-user]
           cũng là thứ tự trình xem tự chuyển sang người kế (story-viewer.jsp). --%>
      <ul class="story-list" id="story-list">
        <li class="story story--self">
          <c:choose>
            <c:when test="${not empty myStoryRing}">
              <button type="button" class="story-link" data-story-user="${me.userId}"
                      onclick="openStories(${me.userId})" aria-label="Xem tin của bạn (${myStoryRing.count} tin)">
                <span class="story-ring story-ring--mine">
                  <c:choose>
                    <c:when test="${not empty me.avatar}"><img src="${ctx}${me.avatarUrl}" alt="" width="70" height="70"></c:when>
                    <c:otherwise><span class="story-initials" aria-hidden="true">${me.initials}</span></c:otherwise>
                  </c:choose>
                  <span class="story-count" aria-hidden="true">${myStoryRing.count}</span>
                </span>
                <span class="story-name">Tin của bạn</span>
              </button>
              <button type="button" class="story-add" onclick="openStoryCreate()" aria-label="Thêm tin mới" title="Thêm tin mới">
                <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg>
              </button>
            </c:when>
            <c:otherwise>
              <button type="button" class="story-link" onclick="openStoryCreate()" aria-label="Tạo tin mới bằng ảnh hoặc video">
                <span class="story-ring">
                  <c:choose>
                    <c:when test="${not empty me.avatar}"><img src="${ctx}${me.avatarUrl}" alt="" width="70" height="70"></c:when>
                    <c:otherwise><span class="story-initials" aria-hidden="true">${me.initials}</span></c:otherwise>
                  </c:choose>
                  <span class="story-badge"><svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg></span>
                </span>
                <span class="story-name">Tạo tin</span>
              </button>
            </c:otherwise>
          </c:choose>
        </li>

        <c:forEach var="ring" items="${storyRings}">
          <li class="story">
            <button type="button" class="story-link" data-story-user="${ring.user.userId}"
                    onclick="openStories(${ring.user.userId})"
                    aria-label="Xem tin của <c:out value='${ring.user.fullName}'/> (${ring.count} tin${ring.hasUnseen ? ', có tin mới' : ''})">
              <span class="story-ring ${ring.hasUnseen ? '' : 'is-seen'}">
                <c:choose>
                  <c:when test="${not empty ring.user.avatar}">
                    <img src="${ctx}${ring.user.avatarUrl}" alt="" width="70" height="70" loading="lazy">
                  </c:when>
                  <c:otherwise>
                    <span class="story-initials" aria-hidden="true"><c:out value="${ring.user.initials}"/></span>
                  </c:otherwise>
                </c:choose>
              </span>
              <span class="story-name"><c:out value="${ring.user.firstName}"/></span>
            </button>
          </li>
        </c:forEach>

        <c:if test="${empty storyRings}">
          <li class="story-empty">
            <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg>
            Bạn bè chưa đăng tin nào trong 24 giờ qua.<br>Hãy chia sẻ khoảnh khắc đầu tiên bằng ảnh hoặc video!
          </li>
        </c:if>
      </ul>
    </section>

    <!-- ---------- GỢI Ý KẾT BẠN ---------- -->
    <c:if test="${not empty suggestedFriends}">
      <section class="app-section" aria-labelledby="suggest-title">
        <header class="section-head">
          <h2 class="section-title" id="suggest-title">
            <svg class="icon" aria-hidden="true"><use href="#i-user-plus"></use></svg> Gợi ý kết bạn
          </h2>
          <a class="section-link" href="${ctx}/friends">Xem tất cả</a>
        </header>

        <ul class="suggest-list">
          <c:forEach var="sug" items="${suggestedFriends}">
            <c:set var="sugUser" value="${sug.user}" />
            <li class="suggest-card" id="suggest-${sugUser.userId}">
              <a href="${ctx}/profile?userId=${sugUser.userId}">
                <c:choose>
                  <c:when test="${not empty sugUser.avatar}">
                    <img src="${ctx}${sugUser.avatarUrl}"
                         alt="Ảnh đại diện của ${sugUser.fullName}" width="58" height="58" loading="lazy">
                  </c:when>
                  <c:otherwise>
                    <span class="suggest-initials" aria-hidden="true">${sugUser.initials}</span>
                  </c:otherwise>
                </c:choose>
                <h3 class="suggest-name">${sugUser.fullName}</h3>
              </a>
              <p class="suggest-meta" title="Vì sao gợi ý người này"><c:out value="${sug.reason}"/></p>
              <span class="rel-actions" data-relation-user="${sugUser.userId}" data-status="NONE"
                        data-name="<c:out value='${sugUser.firstName}'/>" data-variant="card"></span>
            </li>
          </c:forEach>
        </ul>
      </section>
    </c:if>

    <!-- ---------- GỢI Ý CHO BẠN: nhóm · hashtag · video (RecommendationService) ---------- -->
    <c:if test="${not empty suggestedGroups or not empty suggestedTags or not empty suggestedVideos}">
      <section class="app-section discover" aria-labelledby="discover-title">
        <header class="section-head">
          <h2 class="section-title" id="discover-title">
            <svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg> Gợi ý cho bạn
          </h2>
          <div class="discover-tabs" role="tablist" aria-label="Loại gợi ý">
            <c:if test="${not empty suggestedGroups}"><button type="button" role="tab" class="discover-tab is-active" data-discover="groups">Nhóm</button></c:if>
            <c:if test="${not empty suggestedTags}"><button type="button" role="tab" class="discover-tab ${empty suggestedGroups ? 'is-active' : ''}" data-discover="tags">Hashtag</button></c:if>
            <c:if test="${not empty suggestedVideos}"><button type="button" role="tab" class="discover-tab ${empty suggestedGroups and empty suggestedTags ? 'is-active' : ''}" data-discover="videos">Video</button></c:if>
          </div>
        </header>
        <c:if test="${not empty interestTags}">
          <p class="discover-interest">Dựa trên sở thích của bạn:
            <c:forEach var="t" items="${interestTags}"><c:url var="itUrl" value="/hashtag"><c:param name="tag" value="${t}"/></c:url><a href="${itUrl}">#<c:out value="${t}"/></a> </c:forEach>
            và lịch sử tương tác, tìm kiếm gần đây.</p>
        </c:if>

        <ul class="discover-list" data-discover-panel="groups" ${empty suggestedGroups ? 'hidden' : ''}>
          <c:forEach var="sg" items="${suggestedGroups}">
            <li class="discover-card">
              <a class="discover-link" href="${ctx}/groups/view?id=${sg.item.groupId}">
                <span class="discover-icon" aria-hidden="true">${sg.item.iconDisplay}</span>
                <span class="discover-text"><b><c:out value="${sg.item.name}"/></b>
                  <small><c:out value="${sg.reason}"/> · ${sg.item.privacyLabel}</small></span>
              </a>
            </li>
          </c:forEach>
        </ul>

        <ul class="discover-list discover-list--tags" data-discover-panel="tags" ${not empty suggestedGroups or empty suggestedTags ? 'hidden' : ''}>
          <c:forEach var="st" items="${suggestedTags}">
            <c:url var="stUrl" value="/hashtag"><c:param name="tag" value="${st.item}"/></c:url>
            <li><a class="topic-chip" href="${stUrl}" title="<c:out value='${st.reason}'/>">#<c:out value="${st.item}"/> <small><c:out value="${st.reason}"/></small></a></li>
          </c:forEach>
        </ul>

        <ul class="discover-list" data-discover-panel="videos" ${not empty suggestedGroups or not empty suggestedTags or empty suggestedVideos ? 'hidden' : ''}>
          <c:forEach var="sv" items="${suggestedVideos}">
            <li class="discover-card discover-card--video">
              <a class="discover-link" href="${ctx}/video#reel-${sv.item.postId}">
                <span class="discover-thumb">
                  <video src="${ctx}${sv.item.videoUrl}#t=1" muted preload="metadata" playsinline></video>
                  <span class="discover-duration">${sv.item.formattedDuration}</span>
                </span>
                <span class="discover-text"><b><c:out value="${sv.item.author.fullName}"/></b>
                  <small><c:out value="${sv.reason}"/></small></span>
              </a>
            </li>
          </c:forEach>
        </ul>
      </section>
    </c:if>
    </c:otherwise>
    </c:choose>

    <!-- ---------- BÀI VIẾT ---------- -->
    <section class="app-section" aria-labelledby="feed-title">
      <header class="section-head">
        <h2 class="section-title" id="feed-title">
          <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg>
          ${empty hashtag and smartFeed ? 'Dành cho bạn' : 'Bài viết mới nhất'}
        </h2>
        <c:if test="${empty hashtag}">
          <div class="feed-mode" role="group" aria-label="Cách sắp xếp bảng tin">
            <a class="feed-mode-btn ${smartFeed ? 'is-active' : ''}" href="${ctx}/feed?mode=smart" ${smartFeed ? 'aria-current="true"' : ''}
               title="Sắp xếp theo mức độ quan tâm: người bạn hay tương tác, chủ đề bạn thích, xu hướng">✨ Dành cho bạn</a>
            <a class="feed-mode-btn ${smartFeed ? '' : 'is-active'}" href="${ctx}/feed?mode=latest" ${smartFeed ? '' : 'aria-current="true"'}
               title="Chỉ theo thời gian đăng">🕒 Mới nhất</a>
          </div>
        </c:if>

        <%-- Kiểu hiển thị: lưới 3 cột (mặc định) · lưới 2 cột · từng bài một như Facebook.
             Lựa chọn nhớ trong localStorage của trình duyệt; script đặt sẵn html[data-feed-view]
             trước khi vẽ lưới để không bị nháy bố cục khi tải trang. --%>
        <script>
          try {
            var savedFeedView = localStorage.getItem('uterspace.feedView');
            if (savedFeedView === 'grid2' || savedFeedView === 'list') {
              document.documentElement.setAttribute('data-feed-view', savedFeedView);
            }
          } catch (e) { /* chế độ riêng tư / chặn lưu trữ: dùng mặc định */ }
        </script>
        <div class="feed-view" role="group" aria-label="Kiểu hiển thị bảng tin">
          <button type="button" class="feed-view-btn is-active" data-view="grid3" aria-pressed="true"
                  title="Lưới 3 cột" aria-label="Lưới 3 cột">
            <svg class="icon" aria-hidden="true"><use href="#i-cols-3"></use></svg>
          </button>
          <button type="button" class="feed-view-btn" data-view="grid2" aria-pressed="false"
                  title="Lưới 2 cột" aria-label="Lưới 2 cột">
            <svg class="icon" aria-hidden="true"><use href="#i-cols-2"></use></svg>
          </button>
          <button type="button" class="feed-view-btn" data-view="list" aria-pressed="false"
                  title="Từng bài một (lướt như Facebook)" aria-label="Từng bài một">
            <svg class="icon" aria-hidden="true"><use href="#i-rows"></use></svg>
          </button>
        </div>

        <c:if test="${not empty trendingTopics}">
          <ul class="topic-list" aria-label="Chủ đề đang thịnh hành">
            <li>
              <span class="topic-chip" style="cursor:default;">
                <svg class="icon" aria-hidden="true" style="width:14px;height:14px;"><use href="#i-trending"></use></svg>
                Thịnh hành
              </span>
            </li>
            <c:forEach var="trend" items="${trendingTopics}">
              <c:url var="trendUrl" value="/hashtag"><c:param name="tag" value="${trend.name}" /></c:url>
              <c:set var="isCurrentTag" value="${not empty hashtag and fn:toLowerCase(trend.name) == fn:toLowerCase(hashtag)}" />
              <li>
                <a class="topic-chip ${isCurrentTag ? 'is-active' : ''}" href="${trendUrl}"
                   ${isCurrentTag ? 'aria-current="page"' : ''}>
                  ${trend.tag} <small>${trend.count}</small>
                </a>
              </li>
            </c:forEach>
          </ul>
        </c:if>
      </header>

      <c:choose>
        <c:when test="${empty posts and not empty hashtag}">
          <p class="feed-empty" id="feed-empty">
            <svg class="icon" aria-hidden="true"><use href="#i-hashtag"></use></svg>
            <strong>Chưa có bài viết nào gắn thẻ #${hashtag}</strong><br>
            Hãy là người đầu tiên chia sẻ về chủ đề này!
          </p>
        </c:when>
        <c:when test="${empty posts}">
          <p class="feed-empty" id="feed-empty">
            <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg>
            <strong>Bảng tin đang trống</strong><br>
            Hãy kết bạn thêm hoặc đăng bài viết đầu tiên của bạn nhé!
          </p>
        </c:when>

        <c:otherwise>
          <div class="feed-grid" role="feed" aria-labelledby="feed-title">

            <c:forEach var="post" items="${posts}" varStatus="ps">
              <%@ include file="../common/post-card.jsp" %>
            </c:forEach>

          </div>
        </c:otherwise>
      </c:choose>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>
<%@ include file="../common/post-support.jsp" %>
<%-- Tin (Stories): hộp đăng tin + trình xem toàn màn hình --%>
<%@ include file="story-create-modal.jsp" %>
<%@ include file="story-viewer.jsp" %>


<!-- ============================================================
     DỮ LIỆU CÓ CẤU TRÚC (schema.org) — hỗ trợ SEO / AI Search
     ============================================================ -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "CollectionPage",
  "name": "Bảng tin — UTErSpace",
  "description": "<c:out value="${pageDescription}"/>",
  "inLanguage": "vi-VN",
  "isPartOf": {
    "@type": "WebSite",
    "name": "UTErSpace",
    "url": "${ctx}/"
  },
  "mainEntity": {
    "@type": "ItemList",
    "numberOfItems": ${fn:length(posts)},
    "itemListElement": [<c:forEach var="post" items="${posts}" varStatus="ps">
      {
        "@type": "ListItem",
        "position": ${ps.index + 1},
        "item": {
          "@type": "SocialMediaPosting",
          "url": "${ctx}/feed#post-${post.postId}",
          "datePublished": "${post.createdAt}",
          "author": { "@type": "Person", "name": "<c:out value="${post.author.fullName}"/>" },
          "interactionStatistic": [
            { "@type": "InteractionCounter", "interactionType": "https://schema.org/LikeAction", "userInteractionCount": ${post.likeCount} },
            { "@type": "InteractionCounter", "interactionType": "https://schema.org/CommentAction", "userInteractionCount": ${post.commentCount} },
            { "@type": "InteractionCounter", "interactionType": "https://schema.org/ShareAction", "userInteractionCount": ${post.shareCount} }
          ]
        }
      }<c:if test="${not ps.last}">,</c:if></c:forEach>
    ]
  }
}
</script>

<!-- ============================================================
     FEED JS — Thích, bình luận, lưu, đăng bài
     ============================================================ -->
<script>
/* ---------- Gợi ý cho bạn: chuyển tab Nhóm / Hashtag / Video ---------- */
document.querySelectorAll('.discover-tab').forEach(function (tab) {
  tab.addEventListener('click', function () {
    var key = tab.getAttribute('data-discover');
    document.querySelectorAll('.discover-tab').forEach(function (t) { t.classList.toggle('is-active', t === tab); });
    document.querySelectorAll('[data-discover-panel]').forEach(function (p) { p.hidden = p.getAttribute('data-discover-panel') !== key; });
  });
});

/* ---------- Kiểu hiển thị bảng tin: lưới 3 cột · lưới 2 cột · từng bài một ----------
   Đổi html[data-feed-view] (CSS trong feed.css / app-shell.css), nhớ lựa chọn cho lần sau. */
(function () {
  var KEY = 'uterspace.feedView';
  var btns = document.querySelectorAll('.feed-view-btn');
  if (!btns.length) return;

  function apply(view) {
    if (view === 'grid2' || view === 'list') document.documentElement.setAttribute('data-feed-view', view);
    else { view = 'grid3'; document.documentElement.removeAttribute('data-feed-view'); }
    btns.forEach(function (b) {
      var on = b.getAttribute('data-view') === view;
      b.classList.toggle('is-active', on);
      b.setAttribute('aria-pressed', String(on));
    });
    return view;
  }

  apply(document.documentElement.getAttribute('data-feed-view'));
  btns.forEach(function (b) {
    b.addEventListener('click', function () {
      var view = apply(b.getAttribute('data-view'));
      try { localStorage.setItem(KEY, view); } catch (e) { }
      refreshMoreText();                              // số dòng thu gọn đổi theo kiểu hiển thị
      window.dispatchEvent(new Event('resize'));      // trình xem 360° / 3D tự co giãn theo khung mới
    });
  });
})();

/* ---------- Trang hashtag: soạn bài có sẵn thẻ ---------- */
function composeWithHashtag(tag) {
  openModal('post-modal');
  var input = document.getElementById('post-content-input');
  if (!input.value.trim()) input.value = '\n\n#' + tag;
  input.focus();
  input.setSelectionRange(0, 0);
}

/* ---------- Kết bạn ---------- */
function sendFriendRequest(userId, btn) {
  btn.disabled = true;
  btn.textContent = 'Đang gửi...';
  fetch(CTX + '/friends/add', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'userId=' + userId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      if (!data.success) throw new Error('failed');
      btn.textContent = '✓ Đã gửi';
      btn.setAttribute('aria-pressed', 'true');
      showToast('Đã gửi lời mời kết bạn! 👥', 'success');
    })
    .catch(function () {
      btn.disabled = false;
      btn.textContent = 'Kết bạn';
      showToast('Không thể gửi lời mời', 'error');
    });
}
</script>

<%@ include file="../common/footer.jsp" %>
