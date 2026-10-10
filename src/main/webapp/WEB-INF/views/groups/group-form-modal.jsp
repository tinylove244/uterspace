<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  group-form-modal.jsp — Hộp thoại tạo nhóm / sửa nhóm.
  Đặt editGroup = nhóm cần sửa TRƯỚC khi include để mở ở chế độ sửa; không đặt = tạo mới.
--%>
<c:set var="isEdit" value="${not empty editGroup}" />
<c:set var="curIcon" value="${isEdit ? editGroup.iconDisplay : '📚'}" />

<div class="modal-overlay" id="group-form-modal" role="dialog" aria-modal="true" aria-labelledby="group-form-title">
  <article class="modal modal-compose">
    <header class="modal-header">
      <h2 id="group-form-title">${isEdit ? 'Chỉnh sửa nhóm' : 'Tạo nhóm mới'}</h2>
      <button type="button" class="modal-close" onclick="closeModal('group-form-modal')" aria-label="Đóng hộp thoại">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>

    <form id="group-form" onsubmit="return submitGroupForm(event)" data-mode="${isEdit ? 'edit' : 'create'}">
      <c:if test="${isEdit}"><input type="hidden" name="groupId" value="${editGroup.groupId}"></c:if>
      <div class="modal-body">
        <div class="field">
          <label for="group-name">Tên nhóm</label>
          <input type="text" id="group-name" name="name" required minlength="3" maxlength="100"
                 value="<c:out value='${editGroup.name}'/>" placeholder="VD: CLB Lập trình Web HCMUTE">
        </div>
        <div class="field">
          <label for="group-desc">Mô tả <small>(không bắt buộc)</small></label>
          <textarea id="group-desc" name="description" rows="3" maxlength="500"
                    placeholder="Nhóm dành cho ai, sinh hoạt về chủ đề gì..."><c:out value="${editGroup.description}"/></textarea>
        </div>

        <div class="group-form-row">
          <div class="field">
            <label for="group-category">Loại nhóm</label>
            <select id="group-category" name="category">
              <option value="STUDY" ${editGroup.category == 'CLUB' ? '' : 'selected'}>Học tập</option>
              <option value="CLUB"  ${editGroup.category == 'CLUB' ? 'selected' : ''}>Câu lạc bộ</option>
            </select>
          </div>
          <fieldset class="field icon-choices">
            <legend>Biểu tượng</legend>
            <c:set var="iconInPresets" value="false" />
            <c:forTokens var="ic" items="📚,💻,🤖,🎨,⚽,🎵,🧪,🌏,🏷️" delims=",">
              <label class="icon-choice">
                <input type="radio" name="coverIcon" value="${ic}" ${ic == curIcon ? 'checked' : ''}>
                <span aria-hidden="true">${ic}</span>
              </label>
              <c:if test="${ic == curIcon}"><c:set var="iconInPresets" value="true" /></c:if>
            </c:forTokens>
            <c:if test="${not iconInPresets}">
              <label class="icon-choice">
                <input type="radio" name="coverIcon" value="<c:out value='${curIcon}'/>" checked>
                <span aria-hidden="true"><c:out value="${curIcon}"/></span>
              </label>
            </c:if>
          </fieldset>
        </div>

        <fieldset class="field privacy-choices">
          <legend>Quyền riêng tư</legend>
          <label class="privacy-choice">
            <input type="radio" name="privacy" value="PUBLIC" ${editGroup.privacy == 'PRIVATE' ? '' : 'checked'}>
            <span>
              <b><svg class="icon" aria-hidden="true"><use href="#i-globe"></use></svg> Công khai</b>
              Ai cũng xem được bài viết và tham gia ngay.
            </span>
          </label>
          <label class="privacy-choice">
            <input type="radio" name="privacy" value="PRIVATE" ${editGroup.privacy == 'PRIVATE' ? 'checked' : ''}>
            <span>
              <b><svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg> Nhóm kín</b>
              Chỉ thành viên xem được bài viết; chủ nhóm duyệt từng người xin vào.
            </span>
          </label>
        </fieldset>
      </div>
      <footer class="modal-footer">
        <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('group-form-modal')">Hủy</button>
        <button type="submit" class="btn-pill" id="group-form-submit">
          <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> ${isEdit ? 'Lưu thay đổi' : 'Tạo nhóm'}
        </button>
      </footer>
    </form>
  </article>
</div>
