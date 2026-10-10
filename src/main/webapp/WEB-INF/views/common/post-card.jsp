<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  post-card.jsp — Thẻ một bài viết (bảng tin, trang hashtag, trang nhóm).
  Include TĨNH bên trong <c:forEach var="post" items="${posts}" varStatus="ps">.
  Yêu cầu: ctx, me (người đang xem), savedPostIds (Set id bài đã lưu, có thể rỗng).
  Tùy chọn: groupOwner = true khi đang ở trang nhóm và người xem là chủ nhóm (được xóa bài người khác),
            inGroupPage = true để ẩn nhãn tên nhóm (đang ở chính nhóm đó),
            readOnlyPosts = true khi người xem chưa vào nhóm (ẩn các nút tương tác).
  JS đi kèm (thích, bình luận, menu, sửa, xóa...) nằm trong post-support.jsp.
  Migration 090: thu gọn theo bộ lọc của người xem (post.filteredBy), lý do xếp hạng bảng tin (post.feedReason),
  nhãn cảm xúc, công cụ AI (dịch / tóm tắt / nghe) và media nâng cao (ảnh 360°, ảnh 3D chiều sâu, mô hình 3D-AR) — post-media.jsp.
--%>
<c:set var="isSaved" value="${not empty savedPostIds and savedPostIds.contains(post.postId)}" />
<c:set var="postImg"
       value="${ctx}${post.imageUrl}" />

<article class="post-card fade-in-up ${not empty post.filteredBy ? 'is-filtered' : ''}"
         id="post-${post.postId}" data-sentiment="${post.sentiment}"
         data-visibility="${post.visibility}" data-hidden="${post.hiddenByOwner}" data-group="${post.groupId}"
         aria-posinset="${ps.index + 1}"
         aria-setsize="${fn:length(posts)}"
         aria-labelledby="post-author-${post.postId}">

  <%-- Bộ lọc nội dung cá nhân / ẩn bài tiêu cực: thu gọn, bấm để xem (ContentFilter) --%>
  <c:if test="${not empty post.filteredBy}">
    <div class="post-filtered">
      <span>🙈 Bài viết của <b><c:out value="${post.author.fullName}"/></b> được thu gọn theo bộ lọc của bạn (<c:out value="${post.filteredBy}"/>).</span>
      <button type="button" class="post-filtered-show" onclick="this.closest('.post-card').classList.remove('is-filtered')">Vẫn xem</button>
    </div>
  </c:if>

  <%-- Bảng tin "Dành cho bạn": vì sao bài này được xếp lên --%>
  <c:if test="${not empty post.feedReason}">
    <p class="post-reason">✨ <c:out value="${post.feedReason}"/></p>
  </c:if>

  <%-- Bài trong nhóm: nhãn tên nhóm (ẩn khi đang ở chính trang nhóm đó) --%>
  <c:if test="${not empty post.groupId and not inGroupPage}">
    <a class="post-group-tag" href="${ctx}/groups/view?id=${post.groupId}">
      <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg>
      <c:out value="${not empty post.groupName ? post.groupName : 'Nhóm'}"/>
    </a>
  </c:if>

  <header class="post-head dropdown">
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
      <h3 class="post-author-name" id="post-author-${post.postId}">${post.author.fullName}</h3>
      <p class="post-author-meta">
        <c:choose>
          <c:when test="${post.share}">
            <svg class="icon" aria-hidden="true"><use href="#i-share"></use></svg>
            đã chia sẻ một bài viết
          </c:when>
          <c:when test="${not empty post.author.location}">
            <svg class="icon" aria-hidden="true"><use href="#i-pin"></use></svg>
            ${post.author.location}
          </c:when>
          <c:otherwise>
            <svg class="icon" aria-hidden="true"><use href="#i-globe"></use></svg>
            ${post.visibilityLabel}
          </c:otherwise>
        </c:choose>
      </p>
    </a>

    <button type="button" class="post-more"
            id="post-more-${post.postId}"
            aria-haspopup="true" aria-expanded="false"
            aria-label="Tùy chọn cho bài viết của ${post.author.fullName}"
            onclick="togglePostMenu(${post.postId}, this)">
      <svg class="icon" aria-hidden="true"><use href="#i-dots"></use></svg>
    </button>

    <ul class="dropdown-menu post-menu" id="post-menu-${post.postId}">
      <c:choose>
        <c:when test="${post.author.userId == me.userId}">
          <li>
            <button type="button" class="dropdown-item" onclick="openEditModal(${post.postId})">
              <svg class="icon" aria-hidden="true"><use href="#i-pencil"></use></svg> Chỉnh sửa
            </button>
          </li>
          <li>
            <%-- Bài hiện trên bảng tin luôn đang hiện → chỉ có "Ẩn"; "Hiện lại" nằm ở trang cá nhân --%>
            <button type="button" class="dropdown-item" onclick="togglePostHidden(${post.postId}, true)">
              <svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg> Ẩn bài viết
            </button>
          </li>
          <li>
            <button type="button" class="dropdown-item danger" onclick="deletePost(${post.postId})">
              <svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg> Xóa bài viết
            </button>
          </li>
        </c:when>
        <c:otherwise>
          <c:if test="${groupOwner}">
            <%-- Chủ nhóm xóa được bài của người khác trong nhóm (server kiểm lại quyền) --%>
            <li>
              <button type="button" class="dropdown-item danger" onclick="deletePost(${post.postId})">
                <svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg> Xóa khỏi nhóm
              </button>
            </li>
          </c:if>
          <li>
            <button type="button" class="dropdown-item" onclick="reportPost(${post.postId})">
              <svg class="icon" aria-hidden="true"><use href="#i-flag"></use></svg> Báo cáo vi phạm
            </button>
          </li>
        </c:otherwise>
      </c:choose>
      <li>
        <button type="button" class="dropdown-item" onclick="copyPostLink(${post.postId})">
          <svg class="icon" aria-hidden="true"><use href="#i-link"></use></svg> Sao chép liên kết
        </button>
      </li>
    </ul>
  </header>

  <c:choose>
    <%-- Bài chia sẻ: bình luận của người chia sẻ ở trên, bài gốc lồng bên dưới --%>
    <c:when test="${post.share}">
      <p class="post-caption post-caption--quote" id="caption-${post.postId}" ${empty post.content ? 'hidden' : ''}>
        <span class="post-caption-text"><c:out value="${post.content}"/></span>
      </p>
      <%@ include file="/WEB-INF/views/common/shared-post-embed.jsp" %>
    </c:when>
    <c:when test="${post.video}">
      <c:set var="vpost" value="${post}" />
      <%@ include file="/WEB-INF/views/common/post-video.jsp" %>
    </c:when>
    <c:when test="${post.model3d or post.panorama or post.depth}">
      <c:set var="mpost" value="${post}" />
      <%@ include file="/WEB-INF/views/common/post-media.jsp" %>
    </c:when>
    <c:when test="${not empty post.imagePath}">
      <figure class="post-media">
        <img src="${postImg}"
             alt="Ảnh trong bài viết của ${post.author.fullName}"
             id="post-img-${post.postId}"
             loading="lazy" decoding="async"
             onerror="this.onerror=null;this.src='${ctx}/assets/images/study_setup.jpg';">
      </figure>
    </c:when>
  </c:choose>

  <%-- Chia sẻ bài chia sẻ = chia sẻ bài gốc của nó (chỉ lồng 1 cấp) --%>
  <c:set var="shareRoot" value="${post.share ? post.sharedPost : post}" />

  <footer>
    <%-- readOnlyPosts: người ngoài xem nhóm công khai — không có nút thích/bình luận/lưu/chia sẻ --%>
    <div class="post-actions" ${readOnlyPosts ? 'hidden' : ''}>
      <button type="button"
              class="post-action ${post.likedByCurrentUser ? 'is-active' : ''}"
              id="like-btn-${post.postId}"
              aria-pressed="${post.likedByCurrentUser}"
              aria-label="Thích bài viết"
              onclick="toggleLike(${post.postId}, this)">
        <svg class="icon" aria-hidden="true"><use href="#i-heart"></use></svg>
      </button>
      <button type="button" class="post-action"
              id="comment-btn-${post.postId}"
              aria-expanded="false"
              aria-controls="comments-${post.postId}"
              aria-label="Bình luận"
              onclick="toggleComments(${post.postId}, this)">
        <svg class="icon" aria-hidden="true"><use href="#i-comment"></use></svg>
      </button>
      <button type="button" class="post-action"
              aria-label="Chia sẻ bài viết kèm bình luận"
              data-share-id="${shareRoot.postId}"
              data-share-state="${empty shareRoot ? 'deleted' : (not empty shareRoot.groupId ? 'group' : (shareRoot.visibility == 'friends' and shareRoot.author.userId != me.userId ? 'friends' : 'ok'))}"
              onclick="openShareModal(this)">
        <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg>
      </button>
      <button type="button"
              class="post-action post-action--save ${isSaved ? 'is-active' : ''}"
              id="save-btn-${post.postId}"
              aria-pressed="${isSaved}"
              aria-label="Lưu bài viết"
              onclick="toggleSave(${post.postId}, this)">
        <svg class="icon" aria-hidden="true"><use href="#i-bookmark"></use></svg>
      </button>
    </div>

    <p class="post-likes">
      <b id="like-count-${post.postId}">${post.likeCount}</b> lượt thích
      · <span id="comment-count-${post.postId}">${post.commentCount}</span> bình luận
      <%-- Lượt chia sẻ luôn dồn về bài gốc nên bài chia sẻ không có số riêng --%>
      <c:if test="${not post.share}">
        · <span id="share-count-${post.postId}">${post.shareCount}</span> chia sẻ
      </c:if>
    </p>

    <c:if test="${not post.share}">
      <p class="post-caption" id="caption-${post.postId}">
        <a class="post-caption-name" href="${ctx}/profile?userId=${post.author.userId}">${post.author.firstName}</a>
        <span class="post-caption-text"><c:out value="${post.content}"/></span>
      </p>
    </c:if>

    <%-- Công cụ AI cho người đọc: dịch, tóm tắt (bài dài), nghe đọc (Text-to-Speech) — post-ai.js --%>
    <c:if test="${not empty post.content}">
      <p class="post-ai-tools" data-post-ai="${post.postId}">
        <button type="button" class="post-ai-btn" data-ai="translate" title="Dịch bài viết">🌐 Dịch</button>
        <c:if test="${fn:length(post.content) > 220}">
          <button type="button" class="post-ai-btn" data-ai="summarize" title="Tóm tắt bài viết dài bằng AI">📝 Tóm tắt</button>
        </c:if>
        <button type="button" class="post-ai-btn" data-ai="speak" title="Nghe đọc bài viết">🔊 Nghe</button>
      </p>
      <div class="post-ai-result" id="post-ai-result-${post.postId}" hidden></div>
    </c:if>

    <p class="post-time-row">
      <time class="post-time" datetime="${post.createdAt}" data-time="${post.createdAt}">
        ${post.formattedCreatedAt}
      </time>
      <c:if test="${post.positive or post.negative}">
        <span class="sentiment-badge sentiment-badge--${post.positive ? 'pos' : 'neg'}"
              title="Cảm xúc bài viết do ${post.sentimentSource == 'AI' ? 'AI' : 'bộ từ điển cảm xúc'} nhận diện">
          ${post.positive ? '😊' : '😟'} ${post.sentimentLabel}
        </span>
      </c:if>
    </p>
  </footer>

  <!-- Bình luận -->
  <section class="post-comments" id="comments-${post.postId}" hidden
           aria-label="Bình luận về bài viết của ${post.author.fullName}">
    <form class="comment-form" onsubmit="return submitComment(event, ${post.postId})">
      <c:choose>
        <c:when test="${not empty me.avatar}">
          <c:set var="myAvatar" value="${ctx}${me.avatarUrl}" />
          <img src="${myAvatar}" alt="" width="30" height="30" style="border-radius:50%; object-fit:cover;">
        </c:when>
        <c:otherwise>
          <span class="comment-initials" aria-hidden="true">${me.initials}</span>
        </c:otherwise>
      </c:choose>
      <label class="u-visually-hidden" for="comment-input-${post.postId}">Viết bình luận</label>
      <input type="text" class="comment-input" id="comment-input-${post.postId}"
             name="content" placeholder="Viết bình luận..." autocomplete="off" required>
      <button type="submit" class="comment-send" aria-label="Gửi bình luận">
        <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg>
      </button>
    </form>
    <ul class="comment-list" id="comment-list-${post.postId}"></ul>
  </section>

</article>
