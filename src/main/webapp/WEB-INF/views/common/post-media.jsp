<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  post-media.jsp — Media nâng cao của một bài (migration 090, cột posts.media_mode). Include TĨNH; cần mpost + ctx.
    PANORAMA : ảnh 360° (equirectangular) — bấm để xem toàn cảnh, kéo / nghiêng điện thoại để xoay (Pannellum).
    DEPTH    : ảnh 3D có chiều sâu — các lớp ảnh dịch chuyển theo góc nghiêng thiết bị hoặc vị trí chuột (parallax).
    MODEL3D  : vật thể 3D (.glb) xoay / phóng to ngay trên bảng tin, nút "Xem trong không gian của bạn" (AR) trên điện thoại.
  Thư viện ngoài chỉ được tải khi bài loại đó xuất hiện (assets/js/post-media.js).
--%>
<c:choose>
  <c:when test="${mpost.model3d}">
    <figure class="post-media post-model" data-model3d>
      <model-viewer src="${ctx}${mpost.modelUrl}" <c:if test="${not empty mpost.imagePath}">poster="${ctx}${mpost.imageUrl}"</c:if>
                    alt="Mô hình 3D trong bài viết của <c:out value='${mpost.author.fullName}'/>"
                    camera-controls auto-rotate ar ar-modes="webxr scene-viewer quick-look"
                    shadow-intensity="1" touch-action="pan-y" loading="lazy" reveal="auto">
        <button slot="ar-button" class="model-ar-btn" type="button">📱 Xem trong không gian của bạn (AR)</button>
      </model-viewer>
      <span class="media-mode-badge">3D · AR</span>
      <figcaption class="media-mode-hint">Kéo để xoay · cuộn / chụm để phóng to</figcaption>
    </figure>
  </c:when>
  <c:when test="${mpost.panorama}">
    <figure class="post-media post-pano" data-pano="${ctx}${mpost.imageUrl}">
      <img src="${ctx}${mpost.imageUrl}" alt="Ảnh 360° trong bài viết của <c:out value='${mpost.author.fullName}'/>" loading="lazy" decoding="async">
      <button type="button" class="pano-start" data-pano-start>🌐 Xem ảnh 360°</button>
      <span class="media-mode-badge">360°</span>
    </figure>
  </c:when>
  <c:otherwise>
    <figure class="post-media post-depth" data-depth tabindex="0" aria-label="Ảnh 3D — nghiêng điện thoại hoặc rê chuột để thấy chiều sâu">
      <span class="depth-layer depth-bg" style="background-image:url('${ctx}${mpost.imageUrl}')" aria-hidden="true"></span>
      <img class="depth-layer depth-fg" src="${ctx}${mpost.imageUrl}" alt="Ảnh 3D trong bài viết của <c:out value='${mpost.author.fullName}'/>" loading="lazy" decoding="async">
      <span class="depth-shine" aria-hidden="true"></span>
      <span class="media-mode-badge">3D</span>
      <button type="button" class="depth-motion" data-depth-motion hidden>📱 Bật cảm biến nghiêng</button>
    </figure>
  </c:otherwise>
</c:choose>
