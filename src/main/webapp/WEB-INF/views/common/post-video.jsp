<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  post-video.jsp — Khung video của một bài (feed, trang cá nhân, đã lưu, nhóm, bài lồng trong bài chia sẻ).
  Include TĨNH; yêu cầu biến vpost (bài có mediaType = VIDEO) và ctx.
  data-autoplay: footer.jsp tự phát (tắt tiếng) video đang nằm giữa màn hình và dừng video khác —
  trình duyệt chỉ cho autoplay khi muted. #t=0.5 để trình duyệt lấy khung hình làm ảnh bìa.
--%>
<figure class="post-media post-video">
  <c:choose>
    <c:when test="${not empty vpost.videoPath}">
      <video src="${ctx}${vpost.videoUrl}#t=0.5" controls muted playsinline preload="metadata" data-autoplay
             <c:if test="${not empty vpost.imagePath}">poster="${ctx}${vpost.imageUrl}"</c:if>><c:if test="${vpost.hasCaptions}">
        <track kind="captions" srclang="vi" label="Phụ đề tự động" src="${ctx}/media/captions?postId=${vpost.postId}" default></c:if></video>
      <c:if test="${vpost.videoDurationSec > 0}"><span class="video-badge">${vpost.formattedDuration}</span></c:if>
      <c:if test="${vpost.hasCaptions}">
        <%-- Thuyết minh: đọc to phụ đề bằng giọng đọc của trình duyệt (Text-to-Speech) khi video chạy — post-ai.js --%>
        <button type="button" class="video-narrate" data-narrate title="Thuyết minh: đọc phụ đề bằng giọng nói">🗣️ Thuyết minh</button>
        <span class="video-cc-badge" title="Video có phụ đề tự động">CC</span>
      </c:if>
    </c:when>
    <c:otherwise>
      <%-- Bài video trong dữ liệu mẫu cũ chỉ có ảnh thumbnail, chưa có file video --%>
      <c:if test="${not empty vpost.imagePath}">
        <img src="${ctx}${vpost.imageUrl}" alt="" loading="lazy" decoding="async">
      </c:if>
      <span class="video-missing">
        <svg class="icon" aria-hidden="true"><use href="#i-video"></use></svg> Video mẫu — chưa có file video
      </span>
      <c:if test="${vpost.videoDurationSec > 0}"><span class="video-badge">${vpost.formattedDuration}</span></c:if>
    </c:otherwise>
  </c:choose>
</figure>
