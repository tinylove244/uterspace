<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>

<c:set var="pageTitle"       value="${profileUser.fullName}" />
<c:set var="pageDescription" value="Trang cá nhân của ${profileUser.fullName} trên UTErSpace — bài viết, ảnh và bạn bè." />
<c:set var="extraCss"        value="profile.css" />
<c:set var="currentPage"     value="profile" />
<c:set var="hideTopbar"      value="true" />
<c:set var="isOwner"         value="${profileUser.userId == sessionScope.currentUser.userId}" />

<%@ include file="../common/header.jsp" %>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css">
<script src="https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js"></script>

<c:set var="ctx" value="${pageContext.request.contextPath}" />

<div class="app-shell">

  <%@ include file="../common/app-sidebar.jsp" %>

  <main class="app-main" id="main-content">

    <%@ include file="../common/app-topbar.jsp" %>

    <section class="app-section">

      <!-- ============ Ảnh bìa + hồ sơ ============ -->
      <header class="pf-header">
        <c:set var="coverBg" value="" />
        <c:if test="${not empty profileUser.coverImage}">
          <c:set var="coverBg" value="${ctx}${profileUser.coverUrl}" />
        </c:if>
        
        <div class="pf-cover"
           <c:if test="${not empty coverBg}">style="background-image:url('${coverBg}'); cursor:pointer;" onclick="viewImage('${coverBg}')"</c:if>>
          <c:if test="${isOwner}">
            <form id="cover-form" action="${ctx}/profile/cover" method="POST" enctype="multipart/form-data" style="position:absolute; width:0; height:0; overflow:hidden;">
               <input type="file" id="cover-input" name="cover" accept="image/*" onclick="event.stopPropagation()" onchange="handleImageSelect(event, 'cover')">
            </form>
            <label for="cover-input" class="pf-cover-btn" onclick="event.stopPropagation()">
              <svg class="icon" aria-hidden="true"><use href="#i-photo"></use></svg> Đổi ảnh bìa
            </label>
          </c:if>
        </div>

        <div class="pf-identity">
          <span class="pf-avatar" style="position: relative;">
            <c:choose>
              <c:when test="${not empty profileUser.avatar}">
                <c:set var="avatarImg" value="${ctx}${profileUser.avatarUrl}" />
                <img src="${avatarImg}"
                     alt="Ảnh đại diện của ${profileUser.fullName}" width="128" height="128"
                     style="cursor:pointer;" onclick="viewImage('${avatarImg}')">
              </c:when>
              <c:otherwise>
                <span class="pf-avatar-initials" aria-hidden="true">${profileUser.initials}</span>
              </c:otherwise>
            </c:choose>
            <c:if test="${isOwner}">
              <form id="avatar-form" action="${ctx}/profile/avatar" method="POST" enctype="multipart/form-data" style="position:absolute; width:0; height:0; overflow:hidden;">
                 <input type="file" id="avatar-input" name="avatar" accept="image/*" onclick="event.stopPropagation()" onchange="handleImageSelect(event, 'avatar')">
              </form>
              <label for="avatar-input" class="pf-avatar-btn" onclick="event.stopPropagation()"
                      style="position:absolute; bottom:5px; right:5px; border-radius:50%; width:32px; height:32px; background:var(--surface); border:1px solid var(--line); display:flex; align-items:center; justify-content:center; cursor:pointer;" 
                      aria-label="Đổi ảnh đại diện">
                 <svg class="icon" aria-hidden="true" style="width:16px;height:16px;color:var(--ink-muted);"><use href="#i-photo"></use></svg>
              </label>
            </c:if>
          </span>

          <hgroup class="pf-namebox">
            <h1 class="pf-name">${profileUser.fullName}<c:if test="${not empty profileDid}"><a class="pf-did-badge" href="${ctx}/did/verify?did=${fn:escapeXml(profileDid.did)}"
                  title="Danh tính số đã xác minh (DID) — bấm để xem" aria-label="Danh tính số đã xác minh"><svg class="icon" aria-hidden="true"><use href="#i-check-badge"></use></svg></a></c:if></h1>
            <p class="pf-handle">
              @${fn:toLowerCase(profileUser.firstName)}${fn:toLowerCase(profileUser.lastName)}
              <c:if test="${not empty profileUser.location}">
                · <svg class="icon" aria-hidden="true"><use href="#i-pin"></use></svg> ${profileUser.location}
              </c:if>
            </p>
          </hgroup>

          <c:if test="${not isOwner and (not empty presenceLabel or mutualCount > 0)}">
            <p class="pf-presence">
              <c:if test="${not empty presenceLabel}">
                <span class="pf-presence-dot ${profileOnline ? 'is-online' : ''}" data-presence-user="${profileUser.userId}"></span>
                <span class="${profileOnline ? 'presence-label' : ''}" data-presence-label="${profileUser.userId}"><c:out value="${presenceLabel}"/></span>
              </c:if>
              <c:if test="${mutualCount > 0}"><span class="pf-mutual">· ${mutualCount} bạn chung</span></c:if>
            </p>
          </c:if>

          <dl class="pf-stats">
            <div class="profile-stat">
              <dt>Bài viết</dt>
              <dd>${fn:length(userPosts)}</dd>
            </div>
            <div class="profile-stat">
              <dt>Bạn bè</dt>
              <dd>${fn:length(friends)}</dd>
            </div>
            <div class="profile-stat">
              <dt>Tham gia</dt>
              <dd>${fn:substring(profileUser.formattedJoinDate, fn:length(profileUser.formattedJoinDate) - 4, -1)}</dd>
            </div>
          </dl>

          <p class="pf-actions">
            <c:choose>
              <c:when test="${isOwner}">
                <button type="button" class="btn-pill" onclick="openModal('edit-profile-modal')">
                  <svg class="icon" aria-hidden="true"><use href="#i-pencil"></use></svg> Chỉnh sửa hồ sơ
                </button>
                <button type="button" class="btn-pill btn-pill--ghost" onclick="openModal('post-modal')">
                  <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng bài
                </button>
              </c:when>
              <c:otherwise>
                <%-- Nút quan hệ dùng chung (relation.js): Kết bạn / Đã gửi lời mời · Thu hồi / Chấp nhận · Từ chối /
                     Bạn bè ▾ (Hủy kết bạn, Chặn) / Bỏ chặn — cập nhật tức thì khi người kia thay đổi (rt:friend) --%>
                <span class="rel-actions" data-relation-user="${profileUser.userId}" data-status="${relationStatus}"
                      data-can-request="${canRequest}" data-name="<c:out value='${profileUser.firstName}'/>" data-variant="profile"></span>
                <c:if test="${relationStatus != 'BLOCKED' and relationStatus != 'BLOCKED_BY'}">
                  <a class="btn-pill btn-pill--ghost" href="${ctx}/chat?with=${profileUser.userId}">
                    <svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg> Nhắn tin
                  </a>
                </c:if>
                <button type="button" class="btn-pill btn-pill--ghost btn-pill--icon" onclick="reportUser(${profileUser.userId})"
                        aria-label="Báo cáo tài khoản này" title="Báo cáo tài khoản">
                  <svg class="icon" aria-hidden="true"><use href="#i-flag"></use></svg>
                </button>
              </c:otherwise>
            </c:choose>
          </p>
        </div>

        <c:if test="${not empty profileUser.bio}">
          <p class="pf-bio"><c:out value="${profileUser.bio}"/></p>
        </c:if>
      </header>

      <c:if test="${profileHidden}">
        <p class="state-empty pf-blocked-note">
          <svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>
          <c:choose>
            <c:when test="${relationStatus == 'BLOCKED'}">
              <strong>Bạn đã chặn <c:out value="${profileUser.firstName}"/></strong>
              Bỏ chặn để xem bài viết và nhắn tin với người này.
            </c:when>
            <c:otherwise>
              <strong>Trang cá nhân này hiện không khả dụng</strong>
              Người dùng có thể đã giới hạn người xem hoặc tài khoản đang tạm khóa.
            </c:otherwise>
          </c:choose>
        </p>
      </c:if>

      <!-- ============ Tabs ============ -->
      <ul class="pill-tabs" role="tablist" aria-label="Nội dung trang cá nhân">
        <li>
          <button type="button" class="pill-tab" id="tab-posts" role="tab"
                  aria-selected="true" aria-controls="panel-posts" onclick="switchTab('posts')">
            <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg>
            Bài viết <span class="pill-count">${fn:length(userPosts)}</span>
          </button>
        </li>
        <li>
          <button type="button" class="pill-tab" id="tab-about" role="tab"
                  aria-selected="false" aria-controls="panel-about" onclick="switchTab('about')">
            <svg class="icon" aria-hidden="true"><use href="#i-user-circle"></use></svg>
            Giới thiệu
          </button>
        </li>
        <li>
          <button type="button" class="pill-tab" id="tab-friends" role="tab"
                  aria-selected="false" aria-controls="panel-friends" onclick="switchTab('friends')">
            <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg>
            Bạn bè <span class="pill-count">${fn:length(friends)}</span>
          </button>
        </li>
        <li>
          <button type="button" class="pill-tab" id="tab-photos" role="tab"
                  aria-selected="false" aria-controls="panel-photos" onclick="switchTab('photos')">
            <svg class="icon" aria-hidden="true"><use href="#i-photo"></use></svg>
            Ảnh
          </button>
        </li>
      </ul>

      <!-- ============ Tab: Bài viết ============ -->
      <section id="panel-posts" role="tabpanel" aria-labelledby="tab-posts">
        <div class="pf-columns">

          <!-- Cột thông tin -->
          <aside class="pf-side" aria-label="Thông tin tóm tắt">
            <section class="pf-widget">
              <h2 class="pf-widget-title">Giới thiệu</h2>
              <ul class="pf-info-list">
                <c:if test="${not empty profileUser.location}">
                  <li><svg class="icon" aria-hidden="true"><use href="#i-pin"></use></svg>
                    Sống tại <b>${profileUser.location}</b></li>
                </c:if>
                <c:if test="${not empty profileUser.website}">
                  <li><svg class="icon" aria-hidden="true"><use href="#i-link"></use></svg>
                    <a href="${fn:escapeXml(profileUser.website)}" target="_blank" rel="noopener nofollow">${profileUser.website}</a></li>
                </c:if>
                <li><svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg>
                  Tham gia <b>${profileUser.formattedJoinDate}</b></li>
                <c:if test="${not empty profileDid}">
                  <li><svg class="icon" aria-hidden="true"><use href="#i-id-card"></use></svg>
                    <span>Danh tính số <a href="${ctx}/did/verify?did=${fn:escapeXml(profileDid.did)}" title="<c:out value='${profileDid.did}'/>"><c:out value="${profileDid.shortDid}"/></a></span></li>
                </c:if>
              </ul>
            </section>

            <c:set var="photoCount" value="0"/>
            <c:forEach var="post" items="${userPosts}">
              <c:if test="${not empty post.imagePath}"><c:set var="photoCount" value="${photoCount + 1}"/></c:if>
            </c:forEach>

            <c:if test="${photoCount > 0}">
              <section class="pf-widget">
                <h2 class="pf-widget-title">
                  Ảnh
                  <button type="button" class="pf-widget-link" onclick="switchTab('photos')">Xem tất cả</button>
                </h2>
                <ul class="pf-photo-mini">
                  <c:set var="shown" value="0"/>
                  <c:forEach var="post" items="${userPosts}">
                    <c:if test="${not empty post.imagePath and shown < 6}">
                      <c:set var="miniImg"
                             value="${ctx}${post.imageUrl}" />
                      <li>
                        <button type="button" onclick="switchTab('photos')" aria-label="Xem tất cả ảnh">
                          <img src="${miniImg}" alt="" loading="lazy"
                               onerror="this.onerror=null;this.style.display='none';">
                        </button>
                      </li>
                      <c:set var="shown" value="${shown + 1}"/>
                    </c:if>
                  </c:forEach>
                </ul>
              </section>
            </c:if>

            <c:if test="${not empty friends}">
              <section class="pf-widget">
                <h2 class="pf-widget-title">
                  Bạn bè
                  <button type="button" class="pf-widget-link" onclick="switchTab('friends')">Xem tất cả</button>
                </h2>
                <ul class="pf-friend-mini">
                  <c:forEach var="friend" items="${friends}" varStatus="fs">
                    <c:if test="${fs.index < 6}">
                      <li>
                        <a href="${ctx}/profile?userId=${friend.userId}">
                          <c:choose>
                            <c:when test="${not empty friend.avatar}">
                              <img src="${ctx}${friend.avatarUrl}" alt="" loading="lazy">
                            </c:when>
                            <c:otherwise>
                              <span class="pf-friend-initials" aria-hidden="true">${friend.initials}</span>
                            </c:otherwise>
                          </c:choose>
                          <span class="pf-friend-name">${friend.firstName}</span>
                        </a>
                      </li>
                    </c:if>
                  </c:forEach>
                </ul>
              </section>
            </c:if>
          </aside>

          <!-- Cột bài viết -->
          <div class="pf-posts">
            <c:choose>
              <c:when test="${empty userPosts}">
                <p class="state-empty">
                  <svg class="icon" aria-hidden="true"><use href="#i-stack"></use></svg>
                  <strong>Chưa có bài viết nào</strong>
                  <c:choose>
                    <c:when test="${isOwner}">Hãy chia sẻ điều gì đó với cộng đồng!</c:when>
                    <c:otherwise>${profileUser.firstName} chưa đăng bài viết nào.</c:otherwise>
                  </c:choose>
                  <c:if test="${isOwner}">
                    <button type="button" class="btn-pill" onclick="openModal('post-modal')">
                      <svg class="icon" aria-hidden="true"><use href="#i-plus"></use></svg> Đăng bài đầu tiên
                    </button>
                  </c:if>
                </p>
              </c:when>

              <c:otherwise>
                <c:forEach var="post" items="${userPosts}" varStatus="ps">
                  <c:set var="postImg"
                         value="${ctx}${post.imageUrl}" />

                  <article class="post-card ${isOwner and (post.hiddenByOwner or post.hiddenByAdmin) ? 'post-card--hidden' : ''}"
                           id="profile-post-${post.postId}"
                           data-hidden="${post.hiddenByOwner}" data-visibility="${post.visibility}" data-group="${post.groupId}"
                           aria-labelledby="pf-post-author-${post.postId}">
                    <%-- Chỉ chủ trang mới nhận được bài đang ẩn (PostDAO.getProfilePosts) — plan 6.2 --%>
                    <c:choose>
                      <c:when test="${isOwner and post.hiddenByAdmin}">
                        <p class="post-hidden-note post-hidden-note--admin">
                          <svg class="icon" aria-hidden="true"><use href="#i-flag"></use></svg>
                          Bài bị ẩn do vi phạm tiêu chuẩn cộng đồng — chỉ bạn nhìn thấy bài này.
                        </p>
                      </c:when>
                      <c:when test="${isOwner and post.hiddenByOwner}">
                        <p class="post-hidden-note">
                          <svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>
                          Bạn đã ẩn bài này — chỉ mình bạn nhìn thấy.
                          <button type="button" class="post-hidden-undo" onclick="togglePostHidden(${post.postId}, false)">Hiện lại</button>
                        </p>
                      </c:when>
                    </c:choose>
                    <c:if test="${not empty post.groupId}">
                      <a class="post-group-tag" href="${ctx}/groups/view?id=${post.groupId}">
                        <svg class="icon" aria-hidden="true"><use href="#i-user-group"></use></svg>
                        <c:out value="${not empty post.groupName ? post.groupName : 'Nhóm'}"/>
                      </a>
                    </c:if>
                    <header class="post-head">
                      <a class="post-author" href="${ctx}/profile?userId=${profileUser.userId}">
                        <c:choose>
                          <c:when test="${not empty profileUser.avatar}">
                            <img class="post-avatar" src="${ctx}${profileUser.avatarUrl}"
                                 alt="" width="38" height="38" loading="lazy">
                          </c:when>
                          <c:otherwise>
                            <span class="post-avatar-initials" aria-hidden="true">${profileUser.initials}</span>
                          </c:otherwise>
                        </c:choose>
                        <h3 class="post-author-name" id="pf-post-author-${post.postId}">${profileUser.fullName}</h3>
                        <p class="post-author-meta">
                          <c:choose>
                            <c:when test="${post.share}">
                              <svg class="icon" aria-hidden="true"><use href="#i-share"></use></svg>
                              đã chia sẻ một bài viết
                            </c:when>
                            <c:when test="${post.hiddenByOwner}">
                              <svg class="icon" aria-hidden="true"><use href="#i-lock"></use></svg>
                              Chỉ mình tôi
                            </c:when>
                            <c:otherwise>
                              <svg class="icon" aria-hidden="true"><use href="#i-globe"></use></svg>
                              ${post.visibilityLabel}
                            </c:otherwise>
                          </c:choose>
                        </p>
                      </a>

                      <!-- Menu tuỳ chọn bài viết -->
                      <button type="button" class="post-more"
                              id="pf-post-more-${post.postId}"
                              aria-haspopup="true" aria-expanded="false"
                              aria-label="Tùy chọn cho bài viết"
                              onclick="togglePostMenu(${post.postId}, this)">
                        <svg class="icon" aria-hidden="true"><use href="#i-dots"></use></svg>
                      </button>

                      <ul class="dropdown-menu post-menu" id="pf-post-menu-${post.postId}">
                        <c:choose>
                          <c:when test="${isOwner and post.hiddenByAdmin}">
                            <%-- Bài bị admin ẩn: giữ nguyên làm bằng chứng, chủ bài không sửa/xóa/hiện lại được --%>
                          </c:when>
                          <c:when test="${isOwner}">
                            <li>
                              <button type="button" class="dropdown-item" onclick="openEditModal(${post.postId})">
                                <svg class="icon" aria-hidden="true"><use href="#i-pencil"></use></svg> Chỉnh sửa
                              </button>
                            </li>
                            <li>
                              <button type="button" class="dropdown-item" onclick="togglePostHidden(${post.postId}, ${not post.hiddenByOwner})">
                                <svg class="icon" aria-hidden="true"><use href="#i-${post.hiddenByOwner ? 'eye' : 'eye-slash'}"></use></svg>
                                ${post.hiddenByOwner ? 'Hiện lại bài viết' : 'Ẩn bài viết'}
                              </button>
                            </li>
                            <li>
                              <button type="button" class="dropdown-item danger" onclick="deletePost(${post.postId})">
                                <svg class="icon" aria-hidden="true"><use href="#i-trash"></use></svg> Xóa bài viết
                              </button>
                            </li>
                          </c:when>
                          <c:otherwise>
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
                        <%@ include file="../common/shared-post-embed.jsp" %>
                      </c:when>
                      <c:when test="${post.video}">
                        <c:set var="vpost" value="${post}" />
                        <%@ include file="/WEB-INF/views/common/post-video.jsp" %>
                      </c:when>
                      <c:when test="${not empty post.imagePath}">
                        <figure class="post-media">
                          <img src="${postImg}" alt="Ảnh trong bài viết của ${profileUser.fullName}"
                               loading="lazy" decoding="async"
                               onerror="this.onerror=null;this.src='${ctx}/assets/images/study_setup.jpg';">
                        </figure>
                      </c:when>
                    </c:choose>

                    <%-- Chia sẻ bài chia sẻ = chia sẻ bài gốc của nó (chỉ lồng 1 cấp) --%>
                    <c:set var="shareRoot" value="${post.share ? post.sharedPost : post}" />

                    <footer>
                      <div class="post-actions">
                        <button type="button"
                                class="post-action ${post.likedByCurrentUser ? 'is-active' : ''}"
                                id="like-btn-${post.postId}"
                                aria-pressed="${post.likedByCurrentUser}" aria-label="Thích bài viết"
                                onclick="toggleLike(${post.postId}, this)">
                          <svg class="icon" aria-hidden="true"><use href="#i-heart"></use></svg>
                        </button>
                        <button type="button" class="post-action"
                                aria-expanded="false" aria-controls="comments-${post.postId}"
                                aria-label="Bình luận"
                                onclick="toggleComments(${post.postId}, this)">
                          <svg class="icon" aria-hidden="true"><use href="#i-comment"></use></svg>
                        </button>
                        <button type="button" class="post-action" aria-label="Chia sẻ bài viết kèm bình luận"
                                data-share-id="${shareRoot.postId}"
                                data-share-state="${empty shareRoot ? 'deleted' : (shareRoot.visibility == 'friends' and shareRoot.author.userId != sessionScope.currentUser.userId ? 'friends' : 'ok')}"
                                onclick="openShareModal(this)">
                          <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg>
                        </button>
                      </div>

                      <p class="post-likes">
                        <b id="like-count-${post.postId}">${post.likeCount}</b> lượt thích
                        · <span id="comment-count-${post.postId}">${post.commentCount}</span> bình luận
                        <c:if test="${not post.share}">
                          · <span id="share-count-${post.postId}">${post.shareCount}</span> chia sẻ
                        </c:if>
                      </p>

                      <c:if test="${not post.share}">
                        <p class="post-caption" id="caption-${post.postId}">
                          <span class="post-caption-text"><c:out value="${post.content}"/></span>
                        </p>
                      </c:if>

                      <time class="post-time" datetime="${post.createdAt}" data-time="${post.createdAt}">
                        ${post.formattedCreatedAt}
                      </time>
                    </footer>

                    <section class="post-comments" id="comments-${post.postId}" hidden
                             aria-label="Bình luận về bài viết">
                      <form class="comment-form" onsubmit="return submitComment(event, ${post.postId})">
                        <c:choose>
                          <c:when test="${not empty sessionScope.currentUser.avatar}">
                            <c:set var="myAvatar" value="${ctx}${sessionScope.currentUser.avatarUrl}" />
                            <img src="${myAvatar}" alt="" width="30" height="30" style="border-radius:50%; object-fit:cover;">
                          </c:when>
                          <c:otherwise>
                            <span class="comment-initials" aria-hidden="true">${sessionScope.currentUser.initials}</span>
                          </c:otherwise>
                        </c:choose>
                        <label class="u-visually-hidden" for="comment-input-${post.postId}">Viết bình luận</label>
                        <input type="text" class="comment-input" id="comment-input-${post.postId}"
                               placeholder="Viết bình luận..." autocomplete="off" required>
                        <button type="submit" class="comment-send" aria-label="Gửi bình luận">
                          <svg class="icon" aria-hidden="true"><use href="#i-send"></use></svg>
                        </button>
                      </form>
                      <ul class="comment-list" id="comment-list-${post.postId}"></ul>
                    </section>
                  </article>
                </c:forEach>
              </c:otherwise>
            </c:choose>
          </div>
        </div>
      </section>

      <!-- ============ Tab: Giới thiệu ============ -->
      <section id="panel-about" role="tabpanel" aria-labelledby="tab-about" hidden>
        <div class="pf-widget">
          <h2 class="pf-widget-title">Thông tin cá nhân</h2>
          <ul class="pf-info-list">
            <li><svg class="icon" aria-hidden="true"><use href="#i-user-circle"></use></svg>
              Họ và tên <b>${profileUser.fullName}</b></li>
            <c:if test="${not empty profileUser.location}">
              <li><svg class="icon" aria-hidden="true"><use href="#i-pin"></use></svg>
                Sống tại <b>${profileUser.location}</b></li>
            </c:if>
            <c:if test="${not empty profileUser.website}">
              <li><svg class="icon" aria-hidden="true"><use href="#i-link"></use></svg>
                Website <a href="${fn:escapeXml(profileUser.website)}" target="_blank" rel="noopener nofollow">${profileUser.website}</a></li>
            </c:if>
            <li><svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg>
              Tham gia UTErSpace <b>${profileUser.formattedJoinDate}</b></li>
            <c:if test="${isOwner}">
              <li><svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg>
                Email <b>${profileUser.email}</b></li>
            </c:if>
          </ul>
        </div>

        <c:if test="${not empty profileUser.bio}">
          <div class="pf-widget">
            <h2 class="pf-widget-title">Giới thiệu bản thân</h2>
            <p class="pf-about-bio"><c:out value="${profileUser.bio}"/></p>
          </div>
        </c:if>
      </section>

      <!-- ============ Tab: Bạn bè ============ -->
      <section id="panel-friends" role="tabpanel" aria-labelledby="tab-friends" hidden>
        <c:choose>
          <c:when test="${empty friends}">
            <p class="state-empty">
              <svg class="icon" aria-hidden="true"><use href="#i-users"></use></svg>
              <strong>Chưa có bạn bè nào</strong>
              Danh sách bạn bè sẽ hiện ở đây.
            </p>
          </c:when>
          <c:otherwise>
            <ul class="card-grid">
              <c:forEach var="friend" items="${friends}">
                <li class="user-card">
                  <a href="${ctx}/profile?userId=${friend.userId}" aria-label="Trang cá nhân của ${friend.fullName}">
                    <c:choose>
                      <c:when test="${not empty friend.avatar}">
                        <img class="user-card-avatar" src="${ctx}${friend.avatarUrl}"
                             alt="Ảnh đại diện của ${friend.fullName}" width="74" height="74" loading="lazy">
                      </c:when>
                      <c:otherwise>
                        <span class="user-card-initials" aria-hidden="true">${friend.initials}</span>
                      </c:otherwise>
                    </c:choose>
                  </a>
                  <h3 class="user-card-name">
                    <a class="user-card-name" href="${ctx}/profile?userId=${friend.userId}">${friend.fullName}</a>
                  </h3>
                  <p class="user-card-meta">
                    <svg class="icon" aria-hidden="true"><use href="#i-pin"></use></svg>
                    ${not empty friend.location ? friend.location : 'UTErSpace'}
                  </p>
                  <p class="user-card-actions">
                    <a class="btn-pill btn-pill--ghost" href="${ctx}/profile?userId=${friend.userId}">Hồ sơ</a>
                    <a class="btn-pill" href="${ctx}/chat?with=${friend.userId}">
                      <svg class="icon" aria-hidden="true"><use href="#i-chat"></use></svg> Nhắn tin
                    </a>
                  </p>
                </li>
              </c:forEach>
            </ul>
          </c:otherwise>
        </c:choose>
      </section>

      <!-- ============ Tab: Ảnh ============ -->
      <section id="panel-photos" role="tabpanel" aria-labelledby="tab-photos" hidden>
        <c:choose>
          <c:when test="${photoCount == 0}">
            <p class="state-empty">
              <svg class="icon" aria-hidden="true"><use href="#i-photo"></use></svg>
              <strong>Chưa có ảnh nào</strong>
              Ảnh đính kèm trong bài viết sẽ xuất hiện tại đây.
            </p>
          </c:when>
          <c:otherwise>
            <ul class="pf-photo-grid">
              <c:forEach var="post" items="${userPosts}">
                <c:if test="${not empty post.imagePath}">
                  <c:set var="gridImg"
                         value="${ctx}${post.imageUrl}" />
                  <li>
                    <a href="${ctx}/feed#post-${post.postId}"
                       aria-label="Xem bài viết chứa ảnh này trên Bảng tin">
                      <img src="${gridImg}"
                           alt="Ảnh trong bài viết của ${profileUser.fullName}" loading="lazy">
                    </a>
                  </li>
                </c:if>
              </c:forEach>
            </ul>
          </c:otherwise>
        </c:choose>
      </section>
    </section>
  </main>
</div>

<%@ include file="../common/post-modal.jsp" %>
<%@ include file="../common/share-modal.jsp" %>
<%@ include file="../common/report-modal.jsp" %>
<%@ include file="../common/post-privacy.jsp" %>

<!-- ============ Hộp thoại chỉnh sửa hồ sơ ============ -->
<c:if test="${isOwner}">
<div class="modal-overlay" id="edit-profile-modal" role="dialog" aria-modal="true" aria-labelledby="edit-profile-title">
  <article class="modal modal-compose">
    <header class="modal-header">
      <h2 id="edit-profile-title">Chỉnh sửa trang cá nhân</h2>
      <button type="button" class="modal-close" onclick="closeModal('edit-profile-modal')" aria-label="Đóng">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>
    <form method="POST" action="${ctx}/profile">
      <div class="modal-body">
        <div class="field">
          <label for="edit-bio">Tiểu sử</label>
          <textarea name="bio" id="edit-bio" rows="3" placeholder="Giới thiệu về bản thân..."><c:out value="${profileUser.bio}"/></textarea>
        </div>
        <div class="field">
          <label for="edit-website">Website / Mạng xã hội</label>
          <input type="url" name="website" id="edit-website" value="<c:out value='${profileUser.website}'/>"
                 placeholder="https://linkedin.com/in/ban">
        </div>
        <div class="field">
          <label for="edit-location">Nơi ở</label>
          <input type="text" name="location" id="edit-location" value="<c:out value='${profileUser.location}'/>"
                 placeholder="VD: TP. Thủ Đức">
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('edit-profile-modal')">Hủy</button>
        <button type="submit" class="btn-pill">Lưu thay đổi</button>
      </div>
    </form>
  </article>
</div>
</c:if>

<!-- Dữ liệu bình luận (ẩn) -->
<div id="comments-data-store" hidden>
  <c:forEach var="post" items="${userPosts}">
    <div class="post-comments-data" data-post-id="${post.postId}">
      <c:forEach var="comment" items="${post.comments}">
        <div class="comment-data"
             data-id="${comment.commentId}"
             data-author-id="${comment.author.userId}"
             data-author="<c:out value="${comment.author.firstName} ${comment.author.lastName}"/>"
             data-initials="<c:out value="${comment.author.initials}"/>"
             data-avatar="<c:out value="${comment.author.avatarUrl}"/>"
             data-time="${comment.createdAt}"><c:out value="${comment.content}"/></div>
      </c:forEach>
    </div>
  </c:forEach>
</div>

<script>
var CTX = '${ctx}';

function switchTab(tab) {
  ['posts', 'about', 'friends', 'photos'].forEach(function (t) {
    var on = (t === tab);
    document.getElementById('tab-' + t).setAttribute('aria-selected', String(on));
    var panel = document.getElementById('panel-' + t);
    if (on) { panel.removeAttribute('hidden'); } else { panel.setAttribute('hidden', ''); }
  });
}

/* ---------- Thời gian tương đối ---------- */
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

/* ---------- Xem thêm (hashtag được biến thành link trong footer.jsp) ---------- */
document.querySelectorAll('.post-caption, .shared-embed-body').forEach(function (box) {
  var textEl = box.querySelector('.post-caption-text, .shared-embed-text');
  if (!textEl) return;

  if (textEl.scrollHeight - textEl.clientHeight > 4) {
    var more = document.createElement('button');
    more.type = 'button';
    more.className = 'post-more-text';
    more.textContent = '… Xem thêm';
    more.addEventListener('click', function () {
      box.classList.add('is-expanded');
      more.remove();
    });
    box.appendChild(more);
  }
});

/* ---------- Thích ---------- */
function toggleLike(postId, btn) {
  btn.disabled = true;
  fetch(CTX + '/feed/like', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      btn.classList.toggle('is-active', data.liked);
      btn.setAttribute('aria-pressed', String(data.liked));
      document.getElementById('like-count-' + postId).textContent = data.likeCount;
    })
    .catch(function () { showToast('Lỗi hệ thống khi thả tim', 'error'); })
    .finally(function () { btn.disabled = false; });
}

/* ---------- Bình luận ---------- */
function buildComment(data) {
  var li = document.createElement('li');
  li.className = 'comment';

  if (data.avatar) {
    var img = document.createElement('img');
    img.src = CTX + data.avatar;
    img.alt = ''; img.width = 30; img.height = 30;
    li.appendChild(img);
  } else {
    var ini = document.createElement('span');
    ini.className = 'comment-initials';
    ini.setAttribute('aria-hidden', 'true');
    ini.textContent = data.initials || '?';
    li.appendChild(ini);
  }

  var bubble = document.createElement('p');
  bubble.className = 'comment-bubble';

  var author = document.createElement('span');
  author.className = 'comment-author';
  author.textContent = data.author;

  var text = document.createElement('span');
  text.className = 'comment-text';
  text.textContent = data.content;

  var time = document.createElement('time');
  time.className = 'comment-time';
  if (data.time) time.dateTime = data.time;
  time.textContent = data.time ? relativeTime(data.time) : '';

  bubble.appendChild(author);
  bubble.appendChild(document.createElement('br'));
  bubble.appendChild(text);
  bubble.appendChild(document.createElement('br'));
  bubble.appendChild(time);

  // Bình luận của người khác: nút "Báo cáo" nhỏ (report-modal.jsp)
  if (data.id && data.authorId && Number(data.authorId) !== ME_ID) {
    var flag = document.createElement('button');
    flag.type = 'button';
    flag.className = 'comment-report';
    flag.textContent = 'Báo cáo';
    flag.setAttribute('aria-label', 'Báo cáo bình luận của ' + data.author);
    flag.addEventListener('click', function () { reportComment(data.id); });
    bubble.appendChild(flag);
  }
  li.appendChild(bubble);
  return li;
}

function renderComments(postId) {
  var list = document.getElementById('comment-list-' + postId);
  if (list.dataset.rendered) return;
  list.dataset.rendered = 'true';

  var store = document.querySelector('.post-comments-data[data-post-id="' + postId + '"]');
  var rows = store ? store.querySelectorAll('.comment-data') : [];

  if (!rows.length) {
    var empty = document.createElement('li');
    empty.className = 'comment-empty';
    empty.textContent = 'Chưa có bình luận nào. Hãy là người đầu tiên!';
    list.appendChild(empty);
    return;
  }
  rows.forEach(function (row) {
    list.appendChild(buildComment({
      id:       row.getAttribute('data-id'),
      authorId: row.getAttribute('data-author-id'),
      author:   row.getAttribute('data-author'),
      initials: row.getAttribute('data-initials'),
      avatar:   row.getAttribute('data-avatar'),
      time:     row.getAttribute('data-time'),
      content:  row.textContent.trim()
    }));
  });
}

function toggleComments(postId, btn) {
  var section = document.getElementById('comments-' + postId);
  var isOpen = !section.hasAttribute('hidden');
  if (isOpen) {
    section.setAttribute('hidden', '');
    btn.setAttribute('aria-expanded', 'false');
  } else {
    section.removeAttribute('hidden');
    btn.setAttribute('aria-expanded', 'true');
    renderComments(postId);
    var input = document.getElementById('comment-input-' + postId);
    if (input) input.focus();
  }
}

function submitComment(event, postId) {
  event.preventDefault();
  var input = document.getElementById('comment-input-' + postId);
  var text = input.value.trim();
  if (!text) return false;

  input.disabled = true;
  fetch(CTX + '/feed/comment', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId + '&content=' + encodeURIComponent(text)
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      var list = document.getElementById('comment-list-' + postId);
      list.dataset.rendered = 'true';
      var placeholder = list.querySelector('.comment-empty');
      if (placeholder) placeholder.remove();

      list.appendChild(buildComment({
        author: data.authorName,
        initials: '${sessionScope.currentUser.initials}',
        avatar: '${sessionScope.currentUser.avatarUrl}',
        time: '',
        content: data.content
      }));

      var countEl = document.getElementById('comment-count-' + postId);
      countEl.textContent = String(parseInt(countEl.textContent, 10) + 1);
      input.value = '';
      showToast('Đã bình luận! 💬', 'success');
    })
    .catch(function () { showToast('Không thể gửi bình luận', 'error'); })
    .finally(function () { input.disabled = false; input.focus(); });

  return false;
}

/* ---------- Kết bạn ---------- */
function sendFriendRequest(userId, btn) {
  btn.disabled = true;
  fetch(CTX + '/friends/add', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'userId=' + userId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      if (!data.success) throw new Error('failed');
      btn.classList.add('btn-pill--done');
      btn.textContent = '✓ Đã gửi lời mời';
      showToast('Đã gửi lời mời kết bạn! 👥', 'success');
    })
    .catch(function () {
      btn.disabled = false;
      showToast('Không thể gửi lời mời', 'error');
    });
}
/* ---------- Menu Bài Viết & Actions ---------- */
function togglePostMenu(postId, btn) {
  var menu = document.getElementById('pf-post-menu-' + postId);
  var isExpanded = btn.getAttribute('aria-expanded') === 'true';

  document.querySelectorAll('.post-menu.open').forEach(function (m) {
    if (m !== menu) {
      m.classList.remove('open');
      var b = document.querySelector('[aria-controls="' + m.id + '"]');
      if (b) b.setAttribute('aria-expanded', 'false');
    }
  });

  if (isExpanded) {
    menu.classList.remove('open');
    btn.setAttribute('aria-expanded', 'false');
  } else {
    menu.classList.add('open');
    btn.setAttribute('aria-expanded', 'true');
  }
}

function deletePost(postId) {
  if (!confirm('Bạn có chắc muốn xóa bài viết này?')) return;
  fetch(CTX + '/feed/delete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      if (!data.success) throw new Error('failed');
      var card = document.getElementById('profile-post-' + postId);
      if (card) {
        card.style.transition = 'opacity .3s, transform .3s';
        card.style.opacity = '0';
        card.style.transform = 'translateY(-10px)';
        setTimeout(function () { card.remove(); }, 300);
      }
      showToast('Đã xóa bài viết.', 'success');
    })
    .catch(function () { showToast('Không thể xóa bài viết', 'error'); });
}

function openEditModal(postId) {
  var captionEl = document.querySelector('#caption-' + postId + ' .post-caption-text');
  var currentContent = captionEl ? captionEl.textContent.trim() : '';
  document.getElementById('edit-post-id').value = postId;
  document.getElementById('edit-post-content').value = currentContent;
  fillEditPrivacy(postId);   // chọn sẵn chế độ hiện tại của bài (post-privacy.jsp)
  document.querySelectorAll('.post-menu.open').forEach(function (m) { m.classList.remove('open'); });
  openModal('edit-post-modal');
  document.getElementById('edit-post-content').focus();
}

function handleEditPost() {
  var postId  = document.getElementById('edit-post-id').value;
  var content = document.getElementById('edit-post-content').value.trim();
  var privacy = readEditPrivacy(postId);   // { visibility, hidden }
  var btn     = document.getElementById('edit-post-submit-btn');
  // Bài chia sẻ được phép để trống bình luận
  var isShare = !!document.querySelector('#profile-post-' + postId + ' .shared-embed');

  if (!content && !isShare) {
    document.getElementById('edit-post-content').focus();
    showToast('Nội dung không được để trống!', 'error');
    return;
  }

  btn.disabled = true;
  fetch(CTX + '/feed/edit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'postId=' + postId + '&content=' + encodeURIComponent(content) +
          '&visibility=' + privacy.visibility + (privacy.hidden === null ? '' : '&hidden=' + privacy.hidden)
  })
    .then(function (res) { if (!res.ok) throw new Error('network'); return res.json(); })
    .then(function (data) {
      if (!data.success) throw new Error('failed');
      var caption   = document.getElementById('caption-' + postId);
      var captionEl = caption ? caption.querySelector('.post-caption-text') : null;
      if (captionEl) {
        captionEl.textContent = data.content;
        linkifyHashtags(captionEl);
        caption.hidden = !data.content;
      }
      closeModal('edit-post-modal');
      if (applyEditPrivacy(postId, data)) return;   // đổi trạng thái ẩn → cập nhật/tải lại danh sách
      showToast('Đã cập nhật bài viết! ✏️', 'success');
    })
    .catch(function () { showToast('Không thể cập nhật bài viết', 'error'); })
    .finally(function () { btn.disabled = false; });
}

function copyPostLink(postId) {
  var url = window.location.origin + CTX + '/feed#post-' + postId;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(url).finally(function () {
      showToast('Đã sao chép liên kết! 🔗', 'success');
    });
  } else {
    showToast('Đã sao chép liên kết! 🔗', 'success');
  }
}

// ----------------------------------------------------------------------------
// Cropper & Image Viewer
// ----------------------------------------------------------------------------
function viewImage(url) {
  if (!url) return;
  document.getElementById('image-viewer-img').src = url;
  openModal('image-viewer-modal');
}

let cropper;
let currentCropType = '';

function handleImageSelect(event, type) {
  var file = event.target.files[0];
  if (!file) return;
  
  currentCropType = type;
  var url = URL.createObjectURL(file);
  var image = document.getElementById('crop-image');
  image.src = url;
  
  openModal('crop-modal');
  
  if (cropper) cropper.destroy();
  
  var aspectRatio = type === 'avatar' ? 1 : 3/1;
  
  setTimeout(function() {
    cropper = new Cropper(image, {
      aspectRatio: aspectRatio,
      viewMode: 1,
      autoCropArea: 1,
      dragMode: 'move',
      cropBoxResizable: false,
    });
  }, 150);
}

function saveCroppedImage() {
  if (!cropper) return;
  
  var btn = document.getElementById('crop-save-btn');
  btn.disabled = true;
  btn.textContent = 'Đang lưu...';
  
  cropper.getCroppedCanvas({
    width: currentCropType === 'avatar' ? 512 : 1200,
  }).toBlob(function(blob) {
    var formData = new FormData();
    formData.append(currentCropType, blob, currentCropType + '.jpg');
    
    fetch(CTX + '/profile/' + currentCropType, {
      method: 'POST',
      body: formData
    })
    .then(function(res) {
      if (res.ok) window.location.reload();
      else throw new Error();
    })
    .catch(function() {
      showToast('Có lỗi xảy ra khi lưu ảnh', 'error');
      btn.disabled = false;
      btn.textContent = 'Lưu ảnh';
    });
  }, 'image/jpeg', 0.85);
}
</script>

<%-- Modal Chỉnh sửa bài viết --%>
<div class="modal-overlay" id="edit-post-modal" role="dialog" aria-modal="true" aria-labelledby="edit-post-title">
  <article class="modal modal-compose">
    <header class="modal-header">
      <h2 id="edit-post-title">Chỉnh sửa bài viết</h2>
      <button type="button" class="modal-close" onclick="closeModal('edit-post-modal')" aria-label="Đóng">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>
    <div class="modal-body">
      <input type="hidden" id="edit-post-id" value="">
      <div class="field">
        <label class="u-visually-hidden" for="edit-post-content">Nội dung bài viết</label>
        <textarea class="compose-textarea" id="edit-post-content" rows="5" placeholder="Chỉnh sửa nội dung..."></textarea>
      </div>
      <div class="field" style="margin-top:10px;">
        <label for="edit-post-visibility" style="font-size:0.85rem;color:var(--ink-muted);margin-bottom:4px;display:block;">Chế độ hiển thị</label>
        <select class="visibility-select" id="edit-post-visibility" onchange="syncPrivacyHint(this, 'edit-privacy-hint')">
          <option value="public">🌐 Công khai</option>
          <option value="friends">👥 Bạn bè</option>
          <option value="private">🔒 Chỉ mình tôi (ẩn bài)</option>
        </select>
        <p class="privacy-hint" id="edit-privacy-hint" hidden>
          <svg class="icon" aria-hidden="true"><use href="#i-eye-slash"></use></svg>
          Bài sẽ bị ẩn với mọi người, chỉ bạn còn thấy trong trang cá nhân.
        </p>
      </div>
    </div>
    <div class="modal-footer">
      <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('edit-post-modal')">Hủy</button>
      <button type="button" class="btn-pill" id="edit-post-submit-btn" onclick="handleEditPost()">
        <svg class="icon" aria-hidden="true"><use href="#i-check"></use></svg> Lưu thay đổi
      </button>
    </div>
  </article>
</div>

<%-- Modal Xem ảnh lớn --%>
<div class="modal-overlay" id="image-viewer-modal" role="dialog" aria-modal="true" onclick="closeModal('image-viewer-modal')">
  <div style="display:flex; justify-content:center; align-items:center; width:100%; height:100%; padding:20px;">
    <img id="image-viewer-img" src="" style="max-width:100%; max-height:100%; border-radius:8px; box-shadow:0 10px 30px rgba(0,0,0,0.5); object-fit:contain;" onclick="event.stopPropagation()">
  </div>
  <button type="button" class="modal-close" style="position:absolute; top:20px; right:20px; background:var(--surface); border-radius:50%; width:40px; height:40px; display:flex; justify-content:center; align-items:center; border:none; cursor:pointer; box-shadow:0 2px 10px rgba(0,0,0,0.2);" aria-label="Đóng" onclick="closeModal('image-viewer-modal')">
    <svg class="icon" aria-hidden="true" style="color:var(--ink);"><use href="#i-close"></use></svg>
  </button>
</div>

<%-- Modal Cắt ảnh --%>
<div class="modal-overlay" id="crop-modal" role="dialog" aria-modal="true">
  <article class="modal modal-compose" style="max-width:600px; width:100%;">
    <header class="modal-header">
      <h2>Điều chỉnh hình ảnh</h2>
      <button type="button" class="modal-close" onclick="closeModal('crop-modal')" aria-label="Đóng">
        <svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>
      </button>
    </header>
    <div class="modal-body" style="background:#000; padding:0; height:400px; display:flex; justify-content:center; align-items:center;">
      <img id="crop-image" src="" style="max-width: 100%; max-height:100%; display:block;">
    </div>
    <div class="modal-footer">
      <button type="button" class="btn-pill btn-pill--ghost" onclick="closeModal('crop-modal')">Hủy</button>
      <button type="button" class="btn-pill" id="crop-save-btn" onclick="saveCroppedImage()">Lưu ảnh</button>
    </div>
  </article>
</div>

<%@ include file="../common/footer.jsp" %>
