<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%--
  did-verify.jsp — Trang CÔNG KHAI (không cần đăng nhập) để bất kỳ ai kiểm tra:
    1. Tệp Verifiable Credential do người dùng UTErSpace xuất (chữ ký Ed25519, eddsa-jcs-2022) — kiểm tra ngay trên trình duyệt;
    2. Một DID (did:key) có liên kết với tài khoản UTErSpace nào không (GET /did/resolve).
  ?did=... → tự tra cứu DID đó (huy hiệu "Danh tính số đã xác minh" ở trang cá nhân trỏ về đây).
  Không ghi gì lên máy chủ; nội dung tệp chỉ được dựng bằng textContent.
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}" />
<c:set var="assetV" value="${not empty applicationScope.assetVersion ? applicationScope.assetVersion : 'dev'}" />
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kiểm tra danh tính số — UTErSpace</title>
  <meta name="description" content="Kiểm tra chữ ký Verifiable Credential và tra cứu danh tính số (DID) của người dùng UTErSpace.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap">
  <link rel="stylesheet" href="${ctx}/assets/css/global.css?v=${assetV}">
  <link rel="stylesheet" href="${ctx}/assets/css/pages/did-verify.css?v=${assetV}">
</head>
<body class="dv-page">
<%@ include file="../common/icons.jsp" %>

<header class="dv-top">
  <a class="dv-brand" href="${ctx}/">
    <span class="dv-brand-mark"><svg class="icon" aria-hidden="true"><use href="#i-sparkles"></use></svg></span>
    UTEr<span>Space</span>
  </a>
  <c:choose>
    <c:when test="${not empty sessionScope.currentUser}"><a class="dv-back" href="${ctx}/settings?tab=identity">Danh tính số của tôi</a></c:when>
    <c:otherwise><a class="dv-back" href="${ctx}/login">Đăng nhập</a></c:otherwise>
  </c:choose>
</header>

<main class="dv-main" id="main-content">
  <section class="dv-hero">
    <span class="dv-hero-icon" aria-hidden="true"><svg class="icon"><use href="#i-check-badge"></use></svg></span>
    <h1>Kiểm tra danh tính số</h1>
    <p>Xác minh một hồ sơ có chữ ký số do người dùng UTErSpace phát hành, hoặc tra cứu một DID thuộc về tài khoản nào.
      Chữ ký được kiểm tra <b>ngay trên trình duyệt của bạn</b> bằng khóa công khai nằm trong chính DID — tệp không được gửi lên máy chủ.</p>
  </section>

  <div class="dv-grid">
    <section class="dv-card" aria-labelledby="vc-title">
      <h2 id="vc-title"><svg class="icon" aria-hidden="true"><use href="#i-document"></use></svg> Kiểm tra tệp chứng nhận (VC)</h2>
      <label class="dv-drop" id="vc-drop">
        <svg class="icon" aria-hidden="true"><use href="#i-upload"></use></svg>
        <b>Kéo thả tệp <code>.vc.json</code> vào đây</b>
        <span>hoặc bấm để chọn tệp</span>
        <input type="file" id="vc-file" accept=".json,application/json" hidden>
      </label>
      <details class="dv-paste">
        <summary>Hoặc dán nội dung JSON</summary>
        <textarea id="vc-text" rows="6" spellcheck="false" placeholder='{"@context": [...], "type": ["VerifiableCredential", ...], "proof": {...}}'></textarea>
        <button type="button" class="dv-btn" id="vc-check">Kiểm tra</button>
      </details>
      <div class="dv-result" id="vc-result" aria-live="polite" hidden></div>
    </section>

    <section class="dv-card" aria-labelledby="did-title">
      <h2 id="did-title"><svg class="icon" aria-hidden="true"><use href="#i-id-card"></use></svg> Tra cứu DID</h2>
      <form class="dv-lookup" id="did-form">
        <label class="u-visually-hidden" for="did-input">DID cần tra cứu</label>
        <input id="did-input" name="did" autocomplete="off" spellcheck="false" placeholder="did:key:z6Mk…" value="<c:out value='${param.did}'/>">
        <button type="submit" class="dv-btn">Tra cứu</button>
      </form>
      <div class="dv-result" id="did-result" aria-live="polite" hidden></div>
    </section>
  </div>

  <ol class="dv-steps" aria-label="Cách xác minh hoạt động">
    <li><b>DID tự chứa khóa công khai</b><span><code>did:key</code> mã hóa khóa Ed25519 ngay trong chuỗi DID — không cần máy chủ trung tâm hay blockchain.</span></li>
    <li><b>Chữ ký chuẩn W3C</b><span>Tệp VC ký theo <code>DataIntegrityProof</code> / <code>eddsa-jcs-2022</code>: chỉ cần sửa một ký tự là chữ ký không còn khớp.</span></li>
    <li><b>Liên kết tài khoản</b><span>UTErSpace chỉ xác nhận DID đã được chủ tài khoản chứng minh sở hữu bằng chữ ký khi liên kết.</span></li>
  </ol>
</main>

<footer class="dv-foot">
  <span>© 2026 UTErSpace — Đồ án môn Lập trình Web, HCMUTE</span>
  <span><a href="${ctx}/privacy">Chính sách bảo mật</a> · <a href="${ctx}/terms">Điều khoản</a></span>
</footer>

<script>window.SEC_CTX = '${ctx}';</script>
<script src="${ctx}/assets/js/security.js?v=${assetV}"></script>
<script>
(function () {
  'use strict';
  var CTX = window.SEC_CTX;

  /** Khung kết quả: tiêu đề + bảng thông tin; mọi giá trị từ tệp / máy chủ đặt bằng textContent */
  function show(box, ok, title, rows, foot) {
    box.hidden = false;
    box.className = 'dv-result ' + (ok === true ? 'is-ok' : ok === false ? 'is-bad' : 'is-info');
    box.textContent = '';
    var h = document.createElement('p');
    h.className = 'dv-result-title';
    h.innerHTML = '<svg class="icon" aria-hidden="true"><use href="#' + (ok === true ? 'i-check-circle' : ok === false ? 'i-x-circle' : 'i-id-card') + '"></use></svg>';
    h.appendChild(document.createTextNode(title));
    box.appendChild(h);
    if (rows && rows.length) {
      var dl = document.createElement('dl');
      rows.forEach(function (r) {
        if (r[1] == null || r[1] === '') return;
        var d = document.createElement('div'), dt = document.createElement('dt'), dd = document.createElement('dd');
        dt.textContent = r[0];
        if (r[1] instanceof Node) dd.appendChild(r[1]); else dd.textContent = String(r[1]);
        d.appendChild(dt); d.appendChild(dd); dl.appendChild(d);
      });
      box.appendChild(dl);
    }
    if (foot) box.appendChild(foot);
    return box;
  }
  function link(text, href) { var a = document.createElement('a'); a.textContent = text; a.href = href; return a; }
  function fmtDate(s) { var d = s ? new Date(s) : null; return d && !isNaN(d) ? d.toLocaleString('vi-VN') : s; }
  function accountNode(acc) {
    if (!acc) return 'Không liên kết với tài khoản UTErSpace nào';
    return link(acc.name + ' — xem trang cá nhân', acc.profile);
  }
  function rawJson(obj, label) {
    var det = document.createElement('details');
    det.className = 'dv-raw';
    var sum = document.createElement('summary'); sum.textContent = label;
    var pre = document.createElement('pre'); pre.textContent = JSON.stringify(obj, null, 2);
    det.appendChild(sum); det.appendChild(pre);
    return det;
  }

  /* ---------- Kiểm tra VC ---------- */
  var vcBox = document.getElementById('vc-result');
  function checkVc(text) {
    var vc;
    try { vc = JSON.parse(text); } catch (e) { show(vcBox, false, 'Nội dung không phải JSON hợp lệ.'); return; }
    show(vcBox, null, 'Đang kiểm tra chữ ký…');
    UTDid.supported().then(function (ok) {
      if (!ok) throw new Error('Trình duyệt chưa hỗ trợ Ed25519 — hãy dùng Chrome / Edge 137+, Firefox 129+ hoặc Safari 17+.');
      return UTDid.verifyCredential(vc);
    }).then(function (r) {
      var sub = vc.credentialSubject || {};
      if (!r.valid) { show(vcBox, false, r.reason || 'Chữ ký không hợp lệ.', [['Bên phát hành', r.issuer]]); return; }
      var rows = [
        ['Chủ hồ sơ', sub.name],
        ['Nền tảng', sub.platform],
        ['Thành viên từ', sub.memberSince ? fmtDate(sub.memberSince.replace(' ', 'T')) : null],
        ['Bài viết', Array.isArray(sub.posts) ? sub.posts.length + ' bài' : null],
        ['Bạn bè', sub.friendCount],
        ['Phát hành bởi', r.issuer],
        ['Ký lúc', fmtDate((vc.proof && vc.proof.created) || vc.validFrom)],
        ['Định dạng', r.legacy ? 'Bản xuất cũ của UTErSpace' : 'W3C VC 2.0 · eddsa-jcs-2022']
      ];
      show(vcBox, true, 'Chữ ký hợp lệ — nội dung chưa bị chỉnh sửa', rows, rawJson(vc, 'Xem toàn bộ nội dung tệp'));
      return UTDid.resolve(r.issuer).then(function (res) {
        var p = document.createElement('p');
        p.className = 'dv-result-foot';
        if (res.linkedAccount) {
          p.appendChild(document.createTextNode('DID này đang liên kết với tài khoản UTErSpace: '));
          p.appendChild(link(res.linkedAccount.name, res.linkedAccount.profile));
          if (sub.name && sub.name !== res.linkedAccount.name) p.appendChild(document.createTextNode(' (tên trong tệp khác tên tài khoản hiện tại)'));
        } else {
          p.textContent = 'DID này hiện không liên kết với tài khoản UTErSpace nào — chữ ký vẫn đúng, nhưng không xác nhận được danh tính trên UTErSpace.';
        }
        vcBox.insertBefore(p, vcBox.querySelector('.dv-raw'));
      }).catch(function () { /* phân giải chỉ là thông tin thêm */ });
    }).catch(function (e) { show(vcBox, false, e.message || 'Tệp không hợp lệ.'); });
  }

  var drop = document.getElementById('vc-drop'), file = document.getElementById('vc-file');
  file.addEventListener('change', function () {
    var f = file.files[0]; file.value = '';
    if (f) f.text().then(checkVc);
  });
  ['dragenter', 'dragover'].forEach(function (t) {
    drop.addEventListener(t, function (e) { e.preventDefault(); drop.classList.add('is-over'); });
  });
  ['dragleave', 'drop'].forEach(function (t) {
    drop.addEventListener(t, function () { drop.classList.remove('is-over'); });
  });
  drop.addEventListener('drop', function (e) {
    e.preventDefault();
    var f = e.dataTransfer.files[0];
    if (f) f.text().then(checkVc);
  });
  document.getElementById('vc-check').addEventListener('click', function () {
    checkVc(document.getElementById('vc-text').value);
  });

  /* ---------- Tra cứu DID ---------- */
  var didBox = document.getElementById('did-result'), input = document.getElementById('did-input');
  function lookup(did) {
    did = did.trim();
    if (!did) return;
    show(didBox, null, 'Đang tra cứu…');
    UTDid.resolve(did).then(function (res) {
      var doc = res.didDocument, vm = doc.verificationMethod[0];
      var acc = res.linkedAccount;
      show(didBox, acc ? true : null, acc ? 'DID hợp lệ và đã liên kết với tài khoản UTErSpace' : 'DID hợp lệ — chưa liên kết tài khoản UTErSpace', [
        ['Tài khoản', accountNode(acc)],
        ['Liên kết lúc', acc && acc.linkedAt],
        ['Phương thức', 'did:key · khóa Ed25519 (Multikey)'],
        ['Khóa công khai', vm.publicKeyMultibase]
      ], rawJson(doc, 'Xem DID Document'));
    }).catch(function (e) { show(didBox, false, e.message); });
  }
  document.getElementById('did-form').addEventListener('submit', function (e) {
    e.preventDefault();
    lookup(input.value);
    history.replaceState(null, '', '?did=' + encodeURIComponent(input.value.trim()));
  });
  if (input.value) lookup(input.value);
})();
</script>
</body>
</html>
