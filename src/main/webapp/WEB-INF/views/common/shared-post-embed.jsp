<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<%--
  shared-post-embed.jsp — Bài GỐC lồng bên trong bài chia sẻ (Quote Share).
  Include tĩnh bên trong <c:forEach var="post" ...>, chỉ khi ${post.share}.

  Không đệ quy: bài chia sẻ luôn trỏ thẳng tới bài gốc (FeedController.handleSharePost
  chuyển "chia sẻ lại bài chia sẻ" về bài gốc), nên bài gốc không bao giờ là bài chia sẻ
  và đoạn này không bao giờ phải include lại chính nó.

  Yêu cầu: ctx, post — post.sharedPost do PostDAO.attachSharedPosts() nạp;
           null khi bài gốc đã bị xoá hoặc người xem không có quyền xem.
--%>
<c:set var="orig" value="${post.sharedPost}" />
<c:choose>
  <c:when test="${not empty orig}">
    <div class="shared-embed" data-original-id="${orig.postId}">
      <a class="shared-embed-head" href="${ctx}/profile?userId=${orig.author.userId}#profile-post-${orig.postId}">
        <c:choose>
          <c:when test="${not empty orig.author.avatar}">
            <img class="shared-embed-avatar"
                 src="${ctx}${orig.author.avatarUrl}"
                 alt="" width="30" height="30" loading="lazy">
          </c:when>
          <c:otherwise>
            <span class="shared-embed-avatar shared-embed-initials" aria-hidden="true">${orig.author.initials}</span>
          </c:otherwise>
        </c:choose>
        <span class="shared-embed-name"><c:out value="${orig.author.fullName}"/></span>
        <time class="shared-embed-time" datetime="${orig.createdAt}" data-time="${orig.createdAt}">${orig.formattedCreatedAt}</time>
      </a>

      <c:if test="${not empty orig.content}">
        <p class="shared-embed-body"><span class="shared-embed-text"><c:out value="${orig.content}"/></span></p>
      </c:if>

      <c:if test="${orig.video}">
        <div class="shared-embed-video">
          <c:set var="vpost" value="${orig}" />
          <%@ include file="/WEB-INF/views/common/post-video.jsp" %>
        </div>
      </c:if>
      <c:if test="${not orig.video and not empty orig.imagePath}">
        <figure class="shared-embed-media">
          <img src="${ctx}${orig.imageUrl}"
               alt="Ảnh trong bài viết được chia sẻ" loading="lazy" decoding="async"
               onerror="this.onerror=null;this.parentNode.remove();">
        </figure>
      </c:if>
    </div>
  </c:when>
  <c:otherwise>
    <div class="shared-embed shared-embed--unavailable" role="note">
      <svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>
      <p>
        <strong>Nội dung này hiện không khả dụng</strong>
        Bài viết gốc đã bị xóa hoặc bạn không có quyền xem.
      </p>
    </div>
  </c:otherwise>
</c:choose>
