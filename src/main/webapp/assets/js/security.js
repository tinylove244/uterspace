/* ============================================================
   security.js — Bảo mật nâng cao phía trình duyệt.

   UTPasskey  — xác thực sinh trắc học chuẩn WebAuthn (vân tay / khuôn mặt / PIN của thiết bị):
                register(label), verify(), stepUp(method) — dữ liệu sinh trắc học KHÔNG rời khỏi thiết bị,
                máy chủ chỉ nhận khóa công khai và chữ ký (xem SecurityController / WebAuthnService).
   UTDid      — danh tính số did:key (Ed25519): tạo khóa ngay trên trình duyệt (WebCrypto), lưu trong IndexedDB,
                ký thông điệp đăng nhập / liên kết, sao lưu + khôi phục khóa (tệp JWK), đóng gói dữ liệu cá nhân thành
                Verifiable Credential (DataIntegrityProof, eddsa-jcs-2022) và kiểm tra VC bất kỳ (không cần máy chủ).
   Dùng được cả ở trang đăng nhập (chưa có realtime.js) — không phụ thuộc thư viện ngoài.
   ============================================================ */
(function () {
  'use strict';
  // Đọc lười: trang Cài đặt nạp file này TRƯỚC footer.jsp (nơi khai báo window.UT)
  function ctx() { return (window.UT && window.UT.ctx) || window.SEC_CTX || ''; }

  /* ---------- tiện ích ---------- */
  function b64u(buf) {
    var bytes = new Uint8Array(buf), s = '';
    for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function unb64u(str) {
    str = str.replace(/-/g, '+').replace(/_/g, '/');
    while (str.length % 4) str += '=';
    var bin = atob(str), out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }
  function post(path, data) {
    return fetch(ctx() + path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
      body: new URLSearchParams(data || {}).toString()
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) { var e = new Error(d.error || ('Lỗi ' + r.status)); e.status = r.status; e.data = d; throw e; }
        return d;
      });
    });
  }
  function toast(msg, type) { if (window.showToast) window.showToast(msg, type); else alert(msg); }

  /* ============================================================ PASSKEY (WebAuthn) */
  function supported() { return !!(window.PublicKeyCredential && navigator.credentials && window.isSecureContext); }

  function platformAvailable() {
    if (!supported() || !PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) return Promise.resolve(false);
    return PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().catch(function () { return false; });
  }

  function friendlyError(e) {
    if (!e) return 'Không xác thực được.';
    if (e.name === 'NotAllowedError') return 'Bạn đã hủy hoặc hết thời gian quét vân tay / khuôn mặt.';
    if (e.name === 'InvalidStateError') return 'Thiết bị này đã đăng ký passkey cho tài khoản rồi.';
    if (e.name === 'SecurityError') return 'Trình duyệt chặn WebAuthn — cần mở trang qua https hoặc localhost.';
    if (e.name === 'NotSupportedError') return 'Thiết bị không hỗ trợ loại khóa này.';
    return e.message || String(e);
  }

  function register(label) {
    if (!supported()) return Promise.reject(new Error('Trình duyệt / kết nối này không hỗ trợ WebAuthn (cần https hoặc localhost).'));
    return post('/security/passkey/register-options').then(function (o) {
      return navigator.credentials.create({
        publicKey: {
          challenge: unb64u(o.challenge),
          rp: { id: o.rpId, name: o.rpName },
          user: { id: unb64u(o.userId), name: o.userName, displayName: o.displayName },
          pubKeyCredParams: [{ type: 'public-key', alg: -7 }, { type: 'public-key', alg: -257 }],
          authenticatorSelection: { authenticatorAttachment: 'platform', userVerification: 'required', residentKey: 'preferred' },
          excludeCredentials: o.exclude.map(function (id) { return { type: 'public-key', id: unb64u(id) }; }),
          attestation: 'none',
          timeout: 60000
        }
      });
    }).then(function (cred) {
      var r = cred.response;
      if (!r.getPublicKey) throw new Error('Trình duyệt quá cũ, chưa hỗ trợ đọc khóa công khai passkey.');
      return post('/security/passkey/register', {
        credentialId: b64u(cred.rawId),
        clientDataJSON: b64u(r.clientDataJSON),
        publicKey: b64u(r.getPublicKey()),
        alg: String(r.getPublicKeyAlgorithm()),
        label: label || guessDevice()
      });
    }).catch(function (e) { if (e.status) throw e; throw new Error(friendlyError(e)); });
  }

  function verify() {
    if (!supported()) return Promise.reject(new Error('Trình duyệt / kết nối này không hỗ trợ WebAuthn (cần https hoặc localhost).'));
    return post('/security/passkey/auth-options').then(function (o) {
      return navigator.credentials.get({
        publicKey: {
          challenge: unb64u(o.challenge),
          rpId: o.rpId,
          allowCredentials: o.allow.map(function (id) { return { type: 'public-key', id: unb64u(id) }; }),
          userVerification: 'required',
          timeout: 60000
        }
      });
    }).then(function (cred) {
      var r = cred.response;
      return post('/security/passkey/verify', {
        credentialId: b64u(cred.rawId),
        clientDataJSON: b64u(r.clientDataJSON),
        authenticatorData: b64u(r.authenticatorData),
        signature: b64u(r.signature)
      });
    }).catch(function (e) { if (e.status) throw e; throw new Error(friendlyError(e)); });
  }

  /** Hộp nhập lại mật khẩu (tài khoản chưa có passkey) */
  function askPassword() {
    return new Promise(function (resolve, reject) {
      var ov = document.createElement('div');
      ov.className = 'modal-overlay open';
      ov.setAttribute('role', 'dialog');
      ov.setAttribute('aria-modal', 'true');
      ov.innerHTML = '<form class="modal modal-compose sec-pw-modal"><header class="modal-header"><h2>Xác nhận lại mật khẩu</h2></header>' +
        '<div class="modal-body"><p>Vì lý do bảo mật, hãy nhập lại mật khẩu để tiếp tục. ' +
        'Bật <b>xác thực sinh trắc học</b> trong Cài đặt để dùng vân tay / khuôn mặt thay cho bước này.</p>' +
        '<input type="password" class="sec-pw-input" autocomplete="current-password" required placeholder="Mật khẩu hiện tại"></div>' +
        '<footer class="modal-footer"><button type="button" class="btn-pill btn-pill--ghost" data-x>Hủy</button>' +
        '<button type="submit" class="btn-pill">Xác nhận</button></footer></form>';
      document.body.appendChild(ov);
      var form = ov.querySelector('form'), input = ov.querySelector('input');
      input.focus();
      function close(err) { ov.remove(); if (err) reject(err); }
      ov.querySelector('[data-x]').addEventListener('click', function () { close(new Error('Đã hủy.')); });
      form.addEventListener('submit', function (e) {
        e.preventDefault();
        post('/security/unlock', { password: input.value })
          .then(function (d) { close(); resolve(d); })
          .catch(function (err) { toast(err.message, 'error'); input.select(); });
      });
    });
  }

  /** Xác thực lại theo cách máy chủ yêu cầu (biometric | password) */
  function stepUp(method) {
    return method === 'password' ? askPassword() : verify();
  }

  /**
   * Gọi một hành động nhạy cảm; nếu máy chủ trả {needStepUp} thì xác thực lại rồi gọi lại đúng 1 lần.
   * action: () => Promise (ném lỗi có .data.needStepUp khi cần)
   */
  function guarded(action) {
    return action().catch(function (e) {
      if (!e.data || !e.data.needStepUp) throw e;
      return stepUp(e.data.method).then(function () { return action(); });
    });
  }

  function guessDevice() {
    var ua = navigator.userAgent;
    var os = /Windows/.test(ua) ? 'Windows Hello' : /Android/.test(ua) ? 'Android' : /iPhone|iPad/.test(ua) ? 'iPhone / iPad'
           : /Mac/.test(ua) ? 'Touch ID (Mac)' : 'Thiết bị';
    var br = /Edg\//.test(ua) ? 'Edge' : /Chrome\//.test(ua) ? 'Chrome' : /Firefox\//.test(ua) ? 'Firefox' : /Safari\//.test(ua) ? 'Safari' : '';
    return os + (br ? ' · ' + br : '');
  }

  window.UTPasskey = {
    supported: supported, platformAvailable: platformAvailable,
    register: register, verify: verify, stepUp: stepUp, guarded: guarded, post: post
  };

  /* ============================================================ DID (did:key, Ed25519) */
  var ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  function base58(bytes) {
    var digits = [0];
    for (var i = 0; i < bytes.length; i++) {
      var carry = bytes[i];
      for (var j = 0; j < digits.length; j++) { carry += digits[j] << 8; digits[j] = carry % 58; carry = (carry / 58) | 0; }
      while (carry) { digits.push(carry % 58); carry = (carry / 58) | 0; }
    }
    var s = '';
    for (var k = 0; k < bytes.length && bytes[k] === 0; k++) s += '1';
    for (var q = digits.length - 1; q >= 0; q--) s += ALPHABET[digits[q]];
    return s;
  }
  function unbase58(str) {
    var bytes = [0];
    for (var i = 0; i < str.length; i++) {
      var v = ALPHABET.indexOf(str[i]);
      if (v < 0) throw new Error('Ký tự base58 không hợp lệ');
      var carry = v;
      for (var j = 0; j < bytes.length; j++) { carry += bytes[j] * 58; bytes[j] = carry & 0xff; carry >>= 8; }
      while (carry) { bytes.push(carry & 0xff); carry >>= 8; }
    }
    for (var k = 0; k < str.length && str[k] === '1'; k++) bytes.push(0);
    return new Uint8Array(bytes.reverse());
  }
  function didFromRaw(raw) {
    var b = new Uint8Array(34);
    b[0] = 0xed; b[1] = 0x01; b.set(new Uint8Array(raw), 2);
    return 'did:key:z' + base58(b);
  }
  function rawFromDid(did) {
    if (!/^did:key:z/.test(did)) throw new Error('Chỉ hỗ trợ did:key');
    var b = unbase58(did.slice(9));
    if (b.length !== 34 || b[0] !== 0xed || b[1] !== 0x01) throw new Error('DID không phải khóa Ed25519');
    return b.slice(2);
  }

  /* IndexedDB: lưu CryptoKey (khóa riêng không xuất ra ngoài trừ khi người dùng bấm Sao lưu) */
  function db() {
    return new Promise(function (resolve, reject) {
      var req = indexedDB.open('uterspace-did', 1);
      req.onupgradeneeded = function () { req.result.createObjectStore('keys'); };
      req.onsuccess = function () { resolve(req.result); };
      req.onerror = function () { reject(req.error); };
    });
  }
  function idb(mode, fn) {
    return db().then(function (d) {
      return new Promise(function (resolve, reject) {
        var tx = d.transaction('keys', mode), store = tx.objectStore('keys');
        var r = fn(store);
        tx.oncomplete = function () { resolve(r && r.result); };
        tx.onerror = function () { reject(tx.error); };
      });
    });
  }
  function ed25519Supported() {
    if (!window.crypto || !crypto.subtle) return Promise.resolve(false);
    return crypto.subtle.generateKey({ name: 'Ed25519' }, false, ['sign', 'verify'])
      .then(function () { return true; }, function () { return false; });
  }

  function loadKey() { return idb('readonly', function (s) { return s.get('main'); }); }
  function saveKey(rec) { return idb('readwrite', function (s) { return s.put(rec, 'main'); }); }
  function clearKey() { return idb('readwrite', function (s) { return s.delete('main'); }); }

  function createKey() {
    return crypto.subtle.generateKey({ name: 'Ed25519' }, true, ['sign', 'verify']).then(function (kp) {
      return crypto.subtle.exportKey('raw', kp.publicKey).then(function (raw) {
        var rec = { did: didFromRaw(raw), privateKey: kp.privateKey, publicKey: kp.publicKey, createdAt: new Date().toISOString() };
        return saveKey(rec).then(function () { return rec; });
      });
    });
  }

  function sign(rec, message) {
    return crypto.subtle.sign({ name: 'Ed25519' }, rec.privateKey, new TextEncoder().encode(message))
      .then(function (sig) { return new Uint8Array(sig); });
  }

  /** Sao lưu khóa: tệp JWK (chứa KHÓA RIÊNG — người dùng tự cất giữ) */
  function backup(rec) {
    return crypto.subtle.exportKey('jwk', rec.privateKey).then(function (jwk) {
      var blob = new Blob([JSON.stringify({ type: 'UTErSpace-DID-Key', did: rec.did, jwk: jwk, createdAt: rec.createdAt }, null, 2)],
                          { type: 'application/json' });
      var a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = 'uterspace-did-key.json';
      a.click();
      setTimeout(function () { URL.revokeObjectURL(a.href); }, 2000);
    });
  }

  /** Khôi phục khóa từ tệp sao lưu (dùng trên thiết bị / trình duyệt khác) */
  function restore(file, persist) {
    return file.text().then(function (txt) {
      var data = JSON.parse(txt);
      if (!data.jwk || data.jwk.crv !== 'Ed25519' || !data.jwk.d) throw new Error('Tệp không phải khóa DID của UTErSpace.');
      var pubJwk = { kty: 'OKP', crv: 'Ed25519', x: data.jwk.x };
      return Promise.all([
        crypto.subtle.importKey('jwk', data.jwk, { name: 'Ed25519' }, true, ['sign']),
        crypto.subtle.importKey('jwk', pubJwk, { name: 'Ed25519' }, true, ['verify'])
      ]).then(function (keys) {
        var rec = { did: didFromRaw(unb64u(data.jwk.x)), privateKey: keys[0], publicKey: keys[1], createdAt: data.createdAt || new Date().toISOString() };
        return persist === false ? rec : saveKey(rec).then(function () { return rec; });
      });
    });
  }

  /**
   * Liên kết DID với tài khoản đang đăng nhập (ký thông điệp challenge của máy chủ).
   * Máy chủ yêu cầu vừa xác thực lại → guarded() tự hỏi vân tay / mật khẩu rồi thử lại.
   */
  function link(rec) {
    return guarded(function () {
      return post('/security/did/challenge').then(function (c) {
        return sign(rec, c.message);
      }).then(function (sig) {
        return post('/security/did/link', { did: rec.did, signature: b64u(sig) });
      });
    });
  }

  function unlink() {
    return guarded(function () { return post('/security/did/unlink'); });
  }

  /** Đăng nhập không mật khẩu bằng DID (trang đăng nhập) */
  function login(rec) {
    return post('/did/challenge').then(function (c) {
      return sign(rec, c.message);
    }).then(function (sig) {
      return post('/did/login', { did: rec.did, signature: b64u(sig) });
    });
  }

  /* ---------- Verifiable Credential ---------- */
  /** JSON chuẩn hóa (khóa sắp xếp, không khoảng trắng — kiểu JCS) để chữ ký không phụ thuộc thứ tự khóa */
  function canonical(v) {
    if (v === null || typeof v !== 'object') return JSON.stringify(v);
    if (Array.isArray(v)) return '[' + v.map(canonical).join(',') + ']';
    return '{' + Object.keys(v).sort().filter(function (k) { return v[k] !== undefined; })
      .map(function (k) { return JSON.stringify(k) + ':' + canonical(v[k]); }).join(',') + '}';
  }

  function sha256(str) {
    return crypto.subtle.digest('SHA-256', new TextEncoder().encode(str)).then(function (h) { return new Uint8Array(h); });
  }

  /**
   * Dữ liệu được ký theo cryptosuite eddsa-jcs-2022 (W3C VC Data Integrity EdDSA):
   *   SHA-256(JCS(proofConfig có @context của tài liệu)) || SHA-256(JCS(tài liệu không có proof))
   */
  function jcsHashData(doc, proofConfig) {
    var cfg = JSON.parse(JSON.stringify(proofConfig));
    delete cfg.proofValue;
    if (doc['@context']) cfg['@context'] = doc['@context'];
    return Promise.all([sha256(canonical(cfg)), sha256(canonical(doc))]).then(function (h) {
      var out = new Uint8Array(64);
      out.set(h[0], 0); out.set(h[1], 32);
      return out;
    });
  }

  function isoNow() { return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'); }

  /** Ký một tài liệu JSON-LD bất kỳ (VC) bằng khóa DID → thêm proof DataIntegrityProof / eddsa-jcs-2022 */
  function signDocument(rec, doc) {
    var proof = {
      type: 'DataIntegrityProof',
      cryptosuite: 'eddsa-jcs-2022',
      created: isoNow(),
      verificationMethod: rec.did + '#' + rec.did.slice(8),
      proofPurpose: 'assertionMethod'
    };
    return jcsHashData(doc, proof).then(function (data) {
      return crypto.subtle.sign({ name: 'Ed25519' }, rec.privateKey, data);
    }).then(function (sig) {
      var out = JSON.parse(JSON.stringify(doc));
      proof.proofValue = 'z' + base58(new Uint8Array(sig));
      out.proof = proof;
      return out;
    });
  }

  function download(obj, name) {
    var blob = new Blob([JSON.stringify(obj, null, 2)], { type: 'application/json' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name;
    a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 2000);
  }

  function exportCredential(rec) {
    return fetch(ctx() + '/security/did/export', { headers: { Accept: 'application/json' } })
      .then(function (r) { return r.json().then(function (d) { if (!r.ok) throw new Error(d.error || 'Không xuất được dữ liệu'); return d; }); })
      .then(function (d) {
        if (d.subject.id !== rec.did) throw new Error('Khóa trên trình duyệt này không khớp DID đã liên kết với tài khoản.');
        return signDocument(rec, {
          '@context': ['https://www.w3.org/ns/credentials/v2'],
          id: 'urn:uuid:' + (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36)),
          type: ['VerifiableCredential', 'SocialProfileCredential'],
          name: 'Hồ sơ UTErSpace của ' + (d.subject.name || ''),
          issuer: rec.did,
          validFrom: isoNow(),
          credentialSubject: d.subject
        });
      })
      .then(function (vc) { download(vc, 'uterspace-profile.vc.json'); return vc; });
  }

  /**
   * Kiểm tra chữ ký của một VC bất kỳ do did:key (Ed25519) phát hành — chạy hoàn toàn trên trình duyệt.
   * Trả về { valid, issuer, legacy, reason }. Hỗ trợ eddsa-jcs-2022 chuẩn và định dạng cũ của UTErSpace
   * (ký thẳng JCS của tài liệu) để tệp xuất trước đây vẫn kiểm tra được.
   */
  function verifyCredential(vc) {
    if (!vc || typeof vc !== 'object' || !vc.proof) return Promise.reject(new Error('Tệp không phải Verifiable Credential có chữ ký (thiếu "proof").'));
    var proof = Array.isArray(vc.proof) ? vc.proof[0] : vc.proof;
    var issuer = typeof vc.issuer === 'string' ? vc.issuer : (vc.issuer && vc.issuer.id);
    if (!issuer) return Promise.reject(new Error('VC không có "issuer".'));
    if (proof.cryptosuite && proof.cryptosuite !== 'eddsa-jcs-2022') {
      return Promise.reject(new Error('Chỉ hỗ trợ cryptosuite eddsa-jcs-2022 (tệp đang dùng ' + proof.cryptosuite + ').'));
    }
    var vm = String(proof.verificationMethod || '');
    if (vm && vm.split('#')[0] !== issuer) {
      return Promise.resolve({ valid: false, issuer: issuer, reason: 'Khóa ký (verificationMethod) không thuộc bên phát hành.' });
    }
    var doc = JSON.parse(JSON.stringify(vc));
    delete doc.proof;
    var sig, raw;
    try { sig = unbase58(String(proof.proofValue || '').replace(/^z/, '')); }
    catch (e) { return Promise.resolve({ valid: false, issuer: issuer, reason: 'proofValue không phải base58btc.' }); }
    try { raw = rawFromDid(issuer); }
    catch (e) { return Promise.reject(new Error('Bên phát hành không phải did:key Ed25519: ' + e.message)); }
    return crypto.subtle.importKey('raw', raw, { name: 'Ed25519' }, false, ['verify']).then(function (key) {
      return jcsHashData(doc, proof).then(function (data) {
        return crypto.subtle.verify({ name: 'Ed25519' }, key, sig, data);
      }).then(function (ok) {
        if (ok) return { valid: true, issuer: issuer, legacy: false };
        return crypto.subtle.verify({ name: 'Ed25519' }, key, sig, new TextEncoder().encode(canonical(doc))).then(function (old) {
          return { valid: old, issuer: issuer, legacy: old,
                   reason: old ? '' : 'Chữ ký không khớp nội dung — tệp đã bị sửa hoặc không do khóa này ký.' };
        });
      });
    }).then(function (r) {
      if (r.valid && vc.validUntil && new Date(vc.validUntil) < new Date()) {
        r.valid = false;
        r.reason = 'Chữ ký đúng nhưng chứng nhận đã hết hạn (validUntil).';
      }
      return r;
    });
  }

  /** Tra DID Document + tài khoản UTErSpace đã liên kết (GET /did/resolve, công khai) */
  function resolve(did) {
    return fetch(ctx() + '/did/resolve?did=' + encodeURIComponent(did), { headers: { Accept: 'application/json' } })
      .then(function (r) { return r.json().then(function (d) { if (!r.ok) throw new Error(d.error || 'Không phân giải được DID'); return d; }); });
  }

  function shortDid(did) { return did && did.length > 34 ? did.slice(0, 22) + '…' + did.slice(-8) : did; }

  window.UTDid = {
    supported: ed25519Supported, load: loadKey, create: createKey, clear: clearKey, unlink: unlink, backup: backup, restore: restore,
    link: link, login: login, exportCredential: exportCredential, verifyCredential: verifyCredential,
    signDocument: signDocument, resolve: resolve, shortDid: shortDid, didFromRaw: didFromRaw, canonical: canonical
  };
})();
