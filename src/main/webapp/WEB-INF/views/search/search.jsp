<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  search.jsp — Trang kết quả tìm kiếm /search?q=&tab=  (SearchController)
  Tab: Tất cả · Mọi người · Bài viết · Nhóm · Hashtag. Từ khóa được tô sáng (không phân biệt dấu) bằng JS cuối trang.
--%>
<c:set var="pageDescription" value="Tìm người, bài viết, nhóm và hashtag trên UTErSpace." />
<c:set var="extraCss"        value="search.css" />
<c:set var="currentPage"     value="search" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>

<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="me"  value="${sessionScope.currentUser}" />

<%-- Số kết quả mỗi loại (đạt giới hạn thì hiện "30+") --%>
<c:set var="nPeople" value="${fn:length(people)}" />
<c:set var="nPosts"  value="${fn:length(posts)}" />
<c:set var="nGroups" value="${fn:length(groups)}" />
<c:set var="nTags"   value="${fn:length(tags)}" />
<c:set var="nTotal"  value="${nPeople + nPosts + nGroups + nTags}" />
<c:url var="baseUrl" value="/search"><c:param name="q" value="${q}"/></c:url>

<div class="app-shell">
  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">
    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section search-page" data-query="<c:out value='${q}'/>">
      <header class="page-head">
        <hgroup>
          <h1><svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
            <c:choose>
              <c:when test="${empty q}">Tìm kiếm</c:when>
              <c:otherwise><span>Kết quả cho “<span class="search-term"><c:out value="${q}"/></span>”</span></c:otherwise>
            </c:choose>
          </h1>
          <p>
            <c:choose>
              <c:when test="${empty q}">Tìm bạn bè, bài viết, nhóm hoặc #hashtag — không cần gõ dấu.</c:when>
              <c:otherwise>Tìm thấy ${nTotal} kết quả · tìm không phân biệt dấu (gõ “duc” cũng ra “Đức”)</c:otherwise>
            </c:choose>
          </p>
        </hgroup>
      </header>

      <c:choose>
        <%-- ===================== CHƯA NHẬP TỪ KHÓA ===================== --%>
        <c:when test="${empty q}">
          <form class="search-big" action="${ctx}/search" method="get" role="search" onsubmit="return searchHashtag(this)">
            <label class="u-visually-hidden" for="search-big-input">Từ khóa tìm kiếm</label>
            <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
            <input type="search" id="search-big-input" name="q" placeholder="Nhập tên bạn bè, nội dung bài viết, tên nhóm..." autofocus autocomplete="off">
            <button type="submit" class="btn-pill">Tìm kiếm</button>
          </form>
          <c:if test="${not empty trending}">
            <h2 class="search-section-title">Hashtag thịnh hành</h2>
            <ul class="search-tags">
              <c:forEach var="t" items="${trending}">
                <li><a class="search-tag" href="${ctx}/hashtag?tag=${fn:escapeXml(t.key)}">#<c:out value="${t.key}"/> <small>${t.value} bài</small></a></li>
              </c:forEach>
            </ul>
          </c:if>
          <ul class="search-tips">
            <li><b>Mẹo:</b> gõ <code>#</code> ở đầu để xem ngay mọi bài có hashtag đó, ví dụ <code>#HCMUTE</code>.</li>
            <li>Có thể tìm theo email, ví dụ <code>student.hcmute</code>.</li>
            <li>Dùng phím <kbd>↑</kbd> <kbd>↓</kbd> và <kbd>Enter</kbd> trong ô tìm kiếm phía trên để chọn gợi ý nhanh.</li>
          </ul>
        </c:when>

        <%-- ===================== CÓ TỪ KHÓA ===================== --%>
        <c:otherwise>
          <nav aria-label="Lọc kết quả">
            <ul class="pill-tabs">
              <li><a class="pill-tab" href="${baseUrl}" ${tab == 'all' ? 'aria-current="page"' : ''}>
                <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg> Tất cả <span class="pill-count">${nTotal}</span></a></li>
              <li><a class="pill-tab" href="${baseUrl}&amp;tab=people" ${tab == 'people' ? 'aria-current="page"' : ''}>
                <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg> Mọi người
                <span class="pill-count">${nPeople}${nPeople >= limitPeople ? '+' : ''}</span></a></li>
              <li><a class="pill-tab" href="${baseUrl}&amp;tab=posts" ${tab == 'posts' ? 'aria-current="page"' : ''}>
                <svg class="icon" aria-hidden="true"><use href="#i-document"></use></svg> Bài viết
                <span class="pill-count">${nPosts}${nPosts >= limitPosts ? '+' : ''}</span></a></li>
              <li><a class="pill-tab" href="${baseUrl}&amp;tab=groups" ${tab == 'groups' ? 'aria-current="page"' : ''}>
                <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg> Nhóm
                <span class="pill-count">${nGroups}${nGroups >= limitGroups ? '+' : ''}</span></a></li>
              <li><a class="pill-tab" href="${baseUrl}&amp;tab=tags" ${tab == 'tags' ? 'aria-current="page"' : ''}>
                <svg class="icon" aria-hidden="true"><use href="#i-hashtag"></use></svg> Hashtag <span class="pill-count">${nTags}</span></a></li>
            </ul>
          </nav>

          <c:if test="${nTotal == 0}">
            <p class="state-empty">
              <svg class="icon" aria-hidden="true"><use href="#i-search"></use></svg>
              <strong>Không tìm thấy kết quả cho “<c:out value="${q}"/>”</strong>
              Hãy kiểm tra chính tả, thử từ khóa ngắn hơn hoặc tìm theo #hashtag.
            </p>
          </c:if>

          <%-- ---------- MỌI NGƯỜI ---------- --%>
          <c:if test="${(tab == 'all' or tab == 'people') and nPeople > 0}">
            <section class="search-block" aria-labelledby="sr-people-title">
              <header class="search-block-head">
                <h2 class="search-section-title" id="sr-people-title">Mọi người</h2>
                <c:if test="${tab == 'all' and nPeople > 4}"><a href="${baseUrl}&amp;tab=people">Xem tất cả (${nPeople})</a></c:if>
              </header>
              <ul class="card-grid">
                <c:forEach var="u" items="${people}" end="${tab == 'all' ? 3 : 99}">
                  <c:set var="fsKey">${u.userId}</c:set>
                  <c:set var="fs" value="${friendStatus[fsKey]}" />
                  <li class="user-card" id="sr-user-${u.userId}">
                    <a href="${ctx}/profile?userId=${u.userId}" aria-label="Trang cá nhân của <c:out value='${u.fullName}'/>">
                      <c:choose>
                        <c:when test="${not empty u.avatar}">
                          <img class="user-card-avatar" src="${ctx}${u.avatarUrl}" alt="" width="74" height="74" loading="lazy">
                        </c:when>
                        <c:otherwise><span class="user-card-initials" aria-hidden="true"><c:out value="${u.initials}"/></span></c:otherwise>
                      </c:choose>
                    </a>
                    <h3 class="user-card-name"><a class="user-card-name sr-hl" href="${ctx}/profile?userId=${u.userId}"><c:out value="${u.fullName}"/></a></h3>
                    <p class="user-card-meta sr-hl">
                      <svg class="icon" aria-hidden="true"><use href="#i-pin"></use></svg>
                      <c:out value="${not empty u.location ? u.location : u.email}"/>
                    </p>
                    <p class="user-card-actions">
                      <%-- Nút quan hệ dùng chung (relation.js) — đúng trạng thái kể cả sau khi người kia đổi --%>
                      <span class="rel-actions" data-relation-user="${u.userId}" data-status="${empty fs ? 'NONE' : fs}"
                            data-name="<c:out value='${u.firstName}'/>" data-variant="card"></span>
                    </p>
                  </li>
                </c:forEach>
              </ul>
            </section>
          </c:if>

          <%-- ---------- HASHTAG ---------- --%>
          <c:if test="${(tab == 'all' or tab == 'tags') and nTags > 0}">
            <section class="search-block" aria-labelledby="sr-tags-title">
              <header class="search-block-head">
                <h2 class="search-section-title" id="sr-tags-title">Hashtag</h2>
                <c:if test="${tab == 'all' and nTags > 8}"><a href="${baseUrl}&amp;tab=tags">Xem tất cả (${nTags})</a></c:if>
              </header>
              <ul class="search-tags">
                <c:forEach var="t" items="${tags}" end="${tab == 'all' ? 7 : 99}">
                  <li><a class="search-tag" href="${ctx}/hashtag?tag=${fn:escapeXml(t.key)}">
                    <span class="sr-hl">#<c:out value="${t.key}"/></span> <small>${t.value} bài viết</small></a></li>
                </c:forEach>
              </ul>
            </section>
          </c:if>

          <%-- ---------- NHÓM ---------- --%>
          <c:if test="${(tab == 'all' or tab == 'groups') and nGroups > 0}">
            <section class="search-block" aria-labelledby="sr-groups-title">
              <header class="search-block-head">
                <h2 class="search-section-title" id="sr-groups-title">Nhóm</h2>
                <c:if test="${tab == 'all' and nGroups > 3}"><a href="${baseUrl}&amp;tab=groups">Xem tất cả (${nGroups})</a></c:if>
              </header>
              <ul class="search-groups">
                <c:forEach var="g" items="${groups}" end="${tab == 'all' ? 2 : 99}">
                  <c:set var="gm" value="${g.myMembership}" />
                  <li class="search-group">
                    <a class="search-group-icon" href="${ctx}/groups/view?id=${g.groupId}" aria-hidden="true" tabindex="-1"
                       <c:if test="${not empty g.coverImage}">style="background-image:url('${ctx}${g.coverUrl}')"</c:if>>
                      <c:if test="${empty g.coverImage}"><c:out value="${g.iconDisplay}"/></c:if>
                    </a>
                    <div class="search-group-body">
                      <h3><a class="sr-hl" href="${ctx}/groups/view?id=${g.groupId}"><c:out value="${g.name}"/></a></h3>
                      <p class="search-group-meta">
                        <svg class="icon" aria-hidden="true"><use href="${g.privateGroup ? '#i-lock' : '#i-globe'}"></use></svg>
                        ${g.privacyLabel} · ${g.categoryLabel} · ${g.memberCount} thành viên
                        <c:choose>
                          <c:when test="${gm.owner}"><span class="search-badge">Chủ nhóm</span></c:when>
                          <c:when test="${gm.active}"><span class="search-badge">Đã tham gia</span></c:when>
                          <c:when test="${gm.pending}"><span class="search-badge search-badge--wait">Chờ duyệt</span></c:when>
                        </c:choose>
                      </p>
                      <c:if test="${not empty g.description}"><p class="search-group-desc sr-hl"><c:out value="${g.description}"/></p></c:if>
                    </div>
                    <a class="btn-pill btn-pill--ghost" href="${ctx}/groups/view?id=${g.groupId}">Xem nhóm</a>
                  </li>
                </c:forEach>
              </ul>
            </section>
          </c:if>

          <%-- ---------- BÀI VIẾT (dùng lại thẻ bài của bảng tin: thích, bình luận, lưu... hoạt động như thường) ---------- --%>
          <c:if test="${(tab == 'all' or tab == 'posts') and nPosts > 0}">
            <section class="search-block" aria-labelledby="sr-posts-title">
              <header class="search-block-head">
                <h2 class="search-section-title" id="sr-posts-title">Bài viết</h2>
                <c:if test="${tab == 'all' and nPosts > 6}"><a href="${baseUrl}&amp;tab=posts">Xem tất cả (${nPosts})</a></c:if>
              </header>
              <div class="search-posts" role="feed" aria-labelledby="sr-posts-title">
                <c:forEach var="post" items="${posts}" varStatus="ps" end="${tab == 'all' ? 5 : 99}">
                  <%@ include file="../common/post-card.jsp" %>
                </c:forEach>
              </div>
            </section>
          </c:if>
        </c:otherwise>
      </c:choose>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>
<c:if test="${not empty posts}">
  <%@ include file="../common/post-support.jsp" %>
</c:if>

<script>
var SEARCH_CTX = '${ctx}';

/* ---------- Tô sáng từ khóa, KHÔNG phân biệt dấu ----------
   So khớp trên chuỗi đã bỏ dấu (fold), nhưng bọc <mark> đúng đoạn chữ gốc có dấu.
   Chỉ thao tác trên text node (textContent), không dùng innerHTML → an toàn XSS. */
(function () {
  var page = document.querySelector('.search-page');
  var q = page ? page.getAttribute('data-query') : '';
  if (!q) return;
  function fold(ch) {
    return ch.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase();
  }
  var needle = q.replace(/^#+/, '').split('').map(fold).join('');
  if (!needle.trim()) return;

  function highlight(root) {
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
    var nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach(function (node) {
      var text = node.nodeValue, folded = '', map = [];
      for (var i = 0; i < text.length; i++) {
        var f = fold(text[i]);
        for (var k = 0; k < f.length; k++) { folded += f[k]; map.push(i); }
      }
      var at = folded.indexOf(needle);
      if (at < 0) return;
      var start = map[at], end = map[at + needle.length - 1] + 1;
      var mark = document.createElement('mark');
      mark.className = 'search-mark';
      mark.textContent = text.slice(start, end);
      var after = node.splitText(start);
      after.nodeValue = after.nodeValue.slice(end - start);
      node.parentNode.insertBefore(mark, after);
    });
  }
  // Chạy sau khi footer.jsp đã biến #hashtag thành link (sự kiện load)
  window.addEventListener('load', function () {
    document.querySelectorAll('.sr-hl, .search-posts .post-caption-text, .search-posts .post-author-name')
            .forEach(highlight);
  });
})();
</script>

<%@ include file="../common/footer.jsp" %>
