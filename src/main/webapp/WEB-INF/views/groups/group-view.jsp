<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"  uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>

<c:set var="pageTitle"       value="${group.name}" />
<c:set var="pageDescription" value="Nhóm ${group.name} trên UTErSpace." />
<c:set var="extraCss"        value="groups.css" />
<c:set var="currentPage"     value="groups" />
<c:set var="hideTopbar"      value="true" />

<%@ include file="../common/header.jsp" %>
<c:if test="${groupOwner}">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js"></script>
</c:if>

<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="gm"  value="${group.myMembership}" />

<div class="app-shell">

  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">

    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section">
      <!-- ============ Ảnh bìa + thông tin nhóm ============ -->
      <header class="gv-header ${group.categoryClass}">
        <div class="gv-cover"
             <c:if test="${not empty group.coverImage}">style="background-image:url('${ctx}${group.coverUrl}')"</c:if>>
          <c:if test="${groupOwner}">
            <input type="file" id="gv-cover-input" accept="image/*" hidden onchange="handleCoverSelect(event)">
            <label for="gv-cover-input" class="gv-cover-btn">
              <svg class="icon" aria-hidden="true"><use href="#i-photo"></use></svg> Đổi ảnh bìa
            </label>
          </c:if>
        </div>

        <div class="gv-identity">
          <span class="gv-icon" aria-hidden="true"><c:out value="${group.iconDisplay}"/></span>
          <hgroup class="gv-title">
            <h1><c:out value="${group.name}"/></h1>
            <p class="group-tags">
              <span class="group-privacy ${group.privateGroup ? 'is-private' : ''}">
                <svg class="icon" aria-hidden="true"><use href="${group.privateGroup ? '#i-lock' : '#i-globe'}"></use></svg>
                ${group.privacyLabel}
              </span>
              <span class="group-tag">${group.categoryLabel}</span>
              <span class="gv-count"><b>${group.memberCount}</b> thành viên</span>
              <c:if test="${groupOwner}"><span class="group-role">Bạn là chủ nhóm</span></c:if>
            </p>
          </hgroup>

          <p class="gv-actions">
            <c:choose>
              <c:when test="${groupOwner}">
                <button type="button" class="btn-pill" onclick="openModal('post-modal')">
                  <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng bài
                </button>
                <button type="button" class="btn-pill btn-pill--ghost" onclick="openModal('group-form-modal')">
                  <svg class="icon" aria-hidden="true"><use href="#i-pencil"></use></svg> Chỉnh sửa nhóm
                </button>
              </c:when>
              <c:when test="${isMember}">
                <button type="button" class="btn-pill" onclick="openModal('post-modal')">
                  <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng bài
                </button>
                <button type="button" class="btn-pill btn-pill--ghost" onclick="groupAction('leave', ${group.groupId}, null, this)">
                  <svg class="icon" aria-hidden="true"><use href="#i-logout"></use></svg> Rời nhóm
                </button>
              </c:when>
              <c:when test="${gm.pending}">
                <button type="button" class="btn-pill btn-pill--done" onclick="groupAction('leave', ${group.groupId}, null, this)">
                  <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> Đã gửi yêu cầu · Hủy
                </button>
              </c:when>
              <c:when test="${gm.banned}">
                <button type="button" class="btn-pill btn-pill--ghost" disabled>Bạn đã bị xóa khỏi nhóm</button>
              </c:when>
              <c:otherwise>
                <button type="button" class="btn-pill" onclick="groupAction('join', ${group.groupId}, null, this)">
                  <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg>
                  ${group.privateGroup ? 'Xin vào nhóm' : 'Tham gia nhóm'}
                </button>
              </c:otherwise>
            </c:choose>
          </p>
        </div>
      </header>

      <!-- ============ Tabs ============ -->
      <ul class="pill-tabs" role="tablist" aria-label="Nội dung nhóm">
        <li>
          <button type="button" class="pill-tab" id="tab-posts" role="tab" aria-controls="panel-posts"
                  aria-selected="false" onclick="switchGroupTab('posts')">
            <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg> Bài viết
            <c:if test="${canViewPosts}"><span class="pill-count">${fn:length(posts)}</span></c:if>
          </button>
        </li>
        <li>
          <button type="button" class="pill-tab" id="tab-members" role="tab" aria-controls="panel-members"
                  aria-selected="false" onclick="switchGroupTab('members')">
            <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg> Thành viên
            <span class="pill-count">${group.memberCount}</span>
            <c:if test="${not empty pendingMembers}"><span class="pill-alert">${fn:length(pendingMembers)} chờ duyệt</span></c:if>
          </button>
        </li>
        <li>
          <button type="button" class="pill-tab" id="tab-about" role="tab" aria-controls="panel-about"
                  aria-selected="false" onclick="switchGroupTab('about')">
            <svg class="icon" aria-hidden="true"><use href="#i-user-circle"></use></svg> Giới thiệu
          </button>
        </li>
      </ul>

      <!-- ============ Tab: Bài viết ============ -->
      <section id="panel-posts" role="tabpanel" aria-labelledby="tab-posts" hidden>
        <c:choose>
          <c:when test="${not canViewPosts}">
            <p class="state-empty">
              <svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>
              <strong>Đây là nhóm kín</strong>
              Chỉ thành viên mới xem được bài viết. Gửi yêu cầu tham gia để chủ nhóm duyệt.
            </p>
          </c:when>
          <c:when test="${empty posts}">
            <p class="state-empty">
              <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg>
              <strong>Nhóm chưa có bài viết nào</strong>
              <c:choose>
                <c:when test="${isMember}">
                  Hãy mở đầu cuộc trò chuyện của nhóm!
                  <button type="button" class="btn-pill" onclick="openModal('post-modal')">
                    <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng bài đầu tiên
                  </button>
                </c:when>
                <c:otherwise>Tham gia nhóm để đăng bài và thảo luận.</c:otherwise>
              </c:choose>
            </p>
          </c:when>
          <c:otherwise>
            <c:if test="${not isMember}">
              <p class="gv-readonly-note">
                <svg class="icon" aria-hidden="true"><use href="#i-globe"></use></svg>
                Bạn đang xem nhóm công khai. Tham gia nhóm để thích, bình luận và đăng bài.
              </p>
            </c:if>
            <%-- Biến cho post-card.jsp --%>
            <c:set var="inGroupPage"   value="true" />
            <c:set var="readOnlyPosts" value="${not isMember}" />
            <div class="gv-posts" role="feed" aria-label="Bài viết trong nhóm">
              <c:forEach var="post" items="${posts}" varStatus="ps">
                <%@ include file="../common/post-card.jsp" %>
              </c:forEach>
            </div>
          </c:otherwise>
        </c:choose>
      </section>

      <!-- ============ Tab: Thành viên ============ -->
      <section id="panel-members" role="tabpanel" aria-labelledby="tab-members" hidden>
        <c:if test="${groupOwner and not empty pendingMembers}">
          <section class="gv-block" aria-labelledby="pending-h">
            <h2 class="group-subtitle" id="pending-h">Yêu cầu tham gia <span class="pill-count">${fn:length(pendingMembers)}</span></h2>
            <ul class="member-list">
              <c:forEach var="m" items="${pendingMembers}">
                <li class="member-row">
                  <%@ include file="member-avatar.jsp" %>
                  <span class="member-meta">Gửi yêu cầu ${m.formattedJoinedAt}</span>
                  <span class="member-actions">
                    <button type="button" class="btn-pill" onclick="groupAction('approve', ${group.groupId}, ${m.userId}, this)">Duyệt</button>
                    <button type="button" class="btn-pill btn-pill--ghost" onclick="groupAction('reject', ${group.groupId}, ${m.userId}, this)">Từ chối</button>
                  </span>
                </li>
              </c:forEach>
            </ul>
          </section>
        </c:if>

        <c:choose>
          <c:when test="${not canViewPosts}">
            <p class="state-empty">
              <svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>
              <strong>${group.memberCount} thành viên</strong>
              Danh sách thành viên nhóm kín chỉ hiện với thành viên.
            </p>
          </c:when>
          <c:otherwise>
            <section class="gv-block" aria-labelledby="members-h">
              <h2 class="group-subtitle" id="members-h">Thành viên <span class="pill-count">${fn:length(members)}</span></h2>
              <ul class="member-list">
                <c:forEach var="m" items="${members}">
                  <li class="member-row">
                    <%@ include file="member-avatar.jsp" %>
                    <span class="member-meta">
                      <span class="member-role ${m.role == 'OWNER' ? 'is-owner' : ''}">${m.roleLabel}</span>
                      · tham gia ${m.formattedJoinedAt}
                    </span>
                    <c:if test="${groupOwner and m.userId != me.userId}">
                      <span class="member-actions">
                        <button type="button" class="btn-pill btn-pill--ghost" onclick="groupAction('transfer', ${group.groupId}, ${m.userId}, this)">
                          Chuyển quyền chủ nhóm
                        </button>
                        <button type="button" class="btn-pill btn-pill--ghost btn-pill--danger" onclick="groupAction('kick', ${group.groupId}, ${m.userId}, this)">
                          Xóa khỏi nhóm
                        </button>
                      </span>
                    </c:if>
                  </li>
                </c:forEach>
              </ul>
            </section>
          </c:otherwise>
        </c:choose>

        <c:if test="${groupOwner and not empty bannedMembers}">
          <section class="gv-block" aria-labelledby="banned-h">
            <h2 class="group-subtitle" id="banned-h">Đã chặn</h2>
            <ul class="member-list">
              <c:forEach var="m" items="${bannedMembers}">
                <li class="member-row">
                  <%@ include file="member-avatar.jsp" %>
                  <span class="member-meta">Không thể tự tham gia lại</span>
                  <span class="member-actions">
                    <button type="button" class="btn-pill btn-pill--ghost" onclick="groupAction('unban', ${group.groupId}, ${m.userId}, this)">Bỏ chặn</button>
                  </span>
                </li>
              </c:forEach>
            </ul>
          </section>
        </c:if>
      </section>

      <!-- ============ Tab: Giới thiệu ============ -->
      <section id="panel-about" role="tabpanel" aria-labelledby="tab-about" hidden>
        <div class="gv-widget">
          <h2 class="gv-widget-title">Giới thiệu nhóm</h2>
          <c:choose>
            <c:when test="${not empty group.description}"><p class="gv-about-desc"><c:out value="${group.description}"/></p></c:when>
            <c:otherwise><p class="gv-about-desc is-empty">Nhóm chưa có mô tả.</p></c:otherwise>
          </c:choose>
          <ul class="gv-info-list">
            <li><svg class="icon" aria-hidden="true"><use href="${group.privateGroup ? '#i-lock' : '#i-globe'}"></use></svg>
              <c:choose>
                <c:when test="${group.privateGroup}"><b>Nhóm kín</b> — chỉ thành viên xem được bài viết; chủ nhóm duyệt người xin vào.</c:when>
                <c:otherwise><b>Công khai</b> — ai cũng xem được bài viết và tham gia ngay.</c:otherwise>
              </c:choose>
            </li>
            <li><svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg> Loại nhóm <b>${group.categoryLabel}</b></li>
            <li><svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg> <b>${group.memberCount}</b> thành viên</li>
            <li><svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg> Thành lập ngày <b>${group.formattedCreatedAt}</b></li>
            <c:if test="${not empty groupOwnerUser}">
              <li><svg class="icon" aria-hidden="true"><use href="#i-user-circle"></use></svg> Chủ nhóm
                <a href="${ctx}/profile?userId=${groupOwnerUser.userId}"><b><c:out value="${groupOwnerUser.fullName}"/></b></a></li>
            </c:if>
          </ul>
        </div>

        <c:if test="${groupOwner}">
          <div class="gv-widget gv-danger">
            <h2 class="gv-widget-title">Vùng nguy hiểm</h2>
            <p>Xóa nhóm sẽ xóa vĩnh viễn toàn bộ bài viết, bình luận và thành viên của nhóm. Không thể hoàn tác.</p>
            <button type="button" class="btn-pill btn-pill--ghost btn-pill--danger" onclick="openModal('group-delete-modal')">
              <svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg> Xóa nhóm
            </button>
          </div>
        </c:if>
      </section>
    </section>
  </main>
</div>

<%-- Hộp thoại đăng bài: chỉ thành viên mới đăng vào nhóm --%>
<c:if test="${isMember}"><c:set var="postGroup" value="${group}" /></c:if>
<%@ include file="../common/post-modal.jsp" %>
<%@ include file="../common/post-support.jsp" %>
<%@ include file="group-actions.jsp" %>

<c:if test="${groupOwner}">
  <c:set var="editGroup" value="${group}" />
  <%@ include file="group-form-modal.jsp" %>

  <%-- Xóa nhóm: gõ lại tên nhóm để xác nhận --%>
  <div class="modal-overlay" id="group-delete-modal" role="dialog" aria-modal="true" aria-labelledby="group-delete-title">
    <article class="modal modal-compose">
      <header class="modal-header">
        <h2 id="group-delete-title">Xóa nhóm?</h2>
        <button type="button" class="modal-close" onclick="closeModal('group-delete-modal')" aria-label="Đóng">
          <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
        </button>
      </header>
      <form onsubmit="return deleteGroup(event)">
        <div class="modal-body">
          <p>Toàn bộ bài viết, bình luận và thành viên của nhóm sẽ bị xóa vĩnh viễn.
             Gõ lại tên nhóm <b><c:out value="${group.name}"/></b> để xác nhận:</p>
          <div class="field">
            <label class="u-visually-hidden" for="group-delete-name">Tên nhóm</label>
            <input type="text" id="group-delete-name" autocomplete="off" required>
          </div>
        </div>
        <footer class="modal-footer">
          <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('group-delete-modal')">Hủy</button>
          <button type="submit" class="btn-pill gv-btn-danger" id="group-delete-btn">Xóa vĩnh viễn</button>
        </footer>
      </form>
    </article>
  </div>

  <%-- Cắt ảnh bìa tỉ lệ 3:1 (giống ảnh bìa trang cá nhân) --%>
  <div class="modal-overlay" id="gv-crop-modal" role="dialog" aria-modal="true" aria-label="Điều chỉnh ảnh bìa">
    <article class="modal modal-compose" style="max-width:640px;">
      <header class="modal-header">
        <h2>Điều chỉnh ảnh bìa</h2>
        <button type="button" class="modal-close" onclick="closeModal('gv-crop-modal')" aria-label="Đóng">
          <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
        </button>
      </header>
      <div class="modal-body gv-crop-body"><img id="gv-crop-image" src="" alt=""></div>
      <footer class="modal-footer">
        <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('gv-crop-modal')">Hủy</button>
        <button type="button" class="btn-pill" id="gv-crop-save" onclick="saveGroupCover()">Lưu ảnh bìa</button>
      </footer>
    </article>
  </div>
</c:if>

<script>
var GROUP_ID = ${group.groupId};

function switchGroupTab(tab) {
  ['posts', 'members', 'about'].forEach(function (t) {
    var on = (t === tab);
    document.getElementById('tab-' + t).setAttribute('aria-selected', String(on));
    document.getElementById('panel-' + t).hidden = !on;
  });
}
// Mở đúng tab theo ?tab= (vd: thông báo "xin vào nhóm" dẫn thẳng tới tab Thành viên)
switchGroupTab(['posts', 'members', 'about'].indexOf('${fn:escapeXml(activeTab)}') >= 0 ? '${fn:escapeXml(activeTab)}' : 'posts');

function deleteGroup(e) {
  e.preventDefault();
  var btn = document.getElementById('group-delete-btn');
  btn.disabled = true;
  groupRequest('delete', { groupId: GROUP_ID, confirmName: document.getElementById('group-delete-name').value })
    .then(function () {
      showToast('Đã xóa nhóm.', 'success');
      setTimeout(function () { window.location.href = GROUP_CTX + '/groups'; }, 700);
    })
    .catch(function (err) { showToast(err.message, 'error'); btn.disabled = false; });
  return false;
}

var coverCropper = null;
function handleCoverSelect(e) {
  var file = e.target.files[0];
  if (!file) return;
  var img = document.getElementById('gv-crop-image');
  img.src = URL.createObjectURL(file);
  openModal('gv-crop-modal');
  if (coverCropper) coverCropper.destroy();
  setTimeout(function () {
    coverCropper = new Cropper(img, { aspectRatio: 3, viewMode: 1, autoCropArea: 1, dragMode: 'move' });
  }, 150);
  e.target.value = '';
}
function saveGroupCover() {
  if (!coverCropper) return;
  var btn = document.getElementById('gv-crop-save');
  btn.disabled = true;
  coverCropper.getCroppedCanvas({ width: 1500 }).toBlob(function (blob) {
    var fd = new FormData();
    fd.append('groupId', GROUP_ID);
    fd.append('cover', blob, 'cover.jpg');
    fetch(GROUP_CTX + '/groups/cover', { method: 'POST', body: fd })
      .then(function (res) { return res.json().then(function (d) { if (!res.ok) throw new Error(d.error || 'Lỗi'); }); })
      .then(function () { window.location.reload(); })
      .catch(function (err) { showToast(err.message, 'error'); btn.disabled = false; });
  }, 'image/jpeg', 0.88);
}

/* Bảng tin nhóm: tin nhắn thông báo "#post-123" → cuộn tới bài */
if (location.hash.indexOf('#post-') === 0) {
  var target = document.querySelector(location.hash);
  if (target) target.scrollIntoView({ block: 'center' });
}
</script>

<%@ include file="../common/footer.jsp" %>
