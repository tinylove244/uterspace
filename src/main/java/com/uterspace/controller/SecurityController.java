package com.uterspace.controller;

import com.uterspace.dao.FriendshipDAO;
import com.uterspace.dao.FriendshipDAOImpl;
import com.uterspace.dao.PostDAO;
import com.uterspace.dao.PostDAOImpl;
import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.model.Post;
import com.uterspace.model.User;
import com.uterspace.security.*;
import com.uterspace.service.NotificationService;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.PasswordUtil;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.List;

/**
 * SecurityController — Bảo mật nâng cao (Cài đặt → Bảo mật nâng cao / Danh tính số). Cần đăng nhập + CSRF (web.xml).
 *
 * Sinh trắc học (WebAuthn / passkey):
 *   POST /security/passkey/register-options → challenge + thông tin để navigator.credentials.create()
 *   POST /security/passkey/register         {credentialId, clientDataJSON, publicKey, alg, label}
 *   POST /security/passkey/auth-options     → challenge + danh sách passkey cho navigator.credentials.get()
 *   POST /security/passkey/verify           {credentialId, clientDataJSON, authenticatorData, signature} → mở khóa 5 phút
 *   POST /security/passkey/delete           {id}  (cần vừa xác thực lại)
 *   POST /security/unlock                   {password}  — chỉ cho tài khoản CHƯA có passkey
 *   GET  /security/status                   → {hasPasskey, unlocked}
 *   GET  /security/hidden-album             → ảnh / video trong các bài "Chỉ mình tôi" (cần vừa xác thực lại)
 *
 * Danh tính số (did:key) — liên kết / hủy liên kết là thao tác nhạy cảm (DID = khóa đăng nhập không mật khẩu)
 * nên cần vừa xác thực lại (StepUp), tránh kẻ chiếm được phiên gắn DID của mình vào tài khoản nạn nhân:
 *   POST /security/did/challenge → thông điệp cần ký (cần StepUp)
 *   POST /security/did/link      {did, signature}  — chữ ký Ed25519 của thông điệp trên chứng minh sở hữu khóa riêng
 *   POST /security/did/unlink    (cần StepUp)
 *   GET  /security/did/export    → dữ liệu cá nhân (JSON) để trình duyệt ký thành Verifiable Credential
 */
@WebServlet(urlPatterns = {"/security/*"})
public class SecurityController extends HttpServlet {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final WebAuthnDAO passkeyDAO = new WebAuthnDAO();
    private final DidDAO      didDAO     = new DidDAO();
    private final UserDAO     userDAO    = new UserDAOImpl();
    private final PostDAO     postDAO    = new PostDAOImpl();
    private final FriendshipDAO friendshipDAO = new FriendshipDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        switch (path(req)) {
            case "/status": {
                boolean has = passkeyDAO.countFor(me.getUserId()) > 0;
                JsonUtil.write(resp, "{\"hasPasskey\":" + has + ",\"unlocked\":" + StepUp.satisfied(req.getSession(), me.getUserId()) +
                                     ",\"secondsLeft\":" + secondsLeft(req.getSession()) + "}");
                break;
            }
            case "/hidden-album":  hiddenAlbum(req, resp, me); break;
            case "/did/export":    exportData(req, resp, me); break;
            default:               resp.sendError(404);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        req.setCharacterEncoding("UTF-8");
        User me = (User) req.getSession().getAttribute("currentUser");
        HttpSession session = req.getSession();
        try {
            switch (path(req)) {
                case "/passkey/register-options": registerOptions(req, resp, me); break;
                case "/passkey/register":         register(req, resp, me); break;
                case "/passkey/auth-options":     authOptions(req, resp, me); break;
                case "/passkey/verify":           verify(req, resp, me); break;
                case "/passkey/delete": {
                    if (!StepUp.satisfied(session, me.getUserId())) { needStepUp(resp, me); return; }
                    int id = Integer.parseInt(req.getParameter("id"));
                    if (!passkeyDAO.delete(id, me.getUserId())) { JsonUtil.error(resp, 404, "Không tìm thấy passkey."); return; }
                    NotificationService.account(me.getUserId(), "Một passkey sinh trắc học vừa bị gỡ khỏi tài khoản của bạn.", "/settings?tab=security");
                    JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Đã gỡ passkey.") + "}");
                    break;
                }
                case "/unlock": {
                    if (passkeyDAO.countFor(me.getUserId()) > 0) {
                        JsonUtil.error(resp, 403, "Tài khoản đã bật sinh trắc học — hãy xác thực bằng vân tay / khuôn mặt."); return;
                    }
                    User fresh = userDAO.getUserById(me.getUserId());
                    if (!PasswordUtil.verifyPassword(req.getParameter("password") == null ? "" : req.getParameter("password"), fresh.getPasswordHash())) {
                        JsonUtil.error(resp, 400, "Mật khẩu không đúng."); return;
                    }
                    StepUp.mark(session, "password");
                    JsonUtil.write(resp, "{\"success\":true}");
                    break;
                }
                case "/did/challenge": {
                    if (!StepUp.satisfied(session, me.getUserId())) { needStepUp(resp, me); return; }
                    String msg = DidKey.challengeMessage("link", req.getServerName(), nonce());
                    session.setAttribute("didLinkMessage", msg);
                    JsonUtil.write(resp, "{\"message\":" + JsonUtil.str(msg) + "}");
                    break;
                }
                case "/did/link":   linkDid(req, resp, me); break;
                case "/did/unlink": {
                    if (!StepUp.satisfied(session, me.getUserId())) { needStepUp(resp, me); return; }
                    if (didDAO.findByUser(me.getUserId()) == null) { JsonUtil.error(resp, 404, "Tài khoản chưa liên kết danh tính số."); return; }
                    didDAO.unlink(me.getUserId());
                    NotificationService.account(me.getUserId(), "Danh tính số (DID) vừa bị hủy liên kết khỏi tài khoản — không thể đăng nhập bằng DID nữa.", "/settings?tab=identity");
                    JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Đã hủy liên kết danh tính số.") + "}");
                    break;
                }
                default: resp.sendError(404);
            }
        } catch (WebAuthnService.WebAuthnException e) {
            JsonUtil.error(resp, 400, e.getMessage());
        } catch (NumberFormatException e) {
            JsonUtil.error(resp, 400, "Tham số không hợp lệ.");
        }
    }

    // ============================================================ Passkey

    private void registerOptions(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        String challenge = WebAuthnService.newChallenge(req.getSession(), "register");
        StringBuilder exclude = new StringBuilder("[");
        List<Passkey> keys = passkeyDAO.listFor(me.getUserId());
        for (int i = 0; i < keys.size(); i++) exclude.append(i > 0 ? "," : "").append(JsonUtil.str(keys.get(i).getCredentialId()));
        JsonUtil.write(resp, "{\"challenge\":" + JsonUtil.str(challenge) +
                ",\"rpId\":" + JsonUtil.str(WebAuthnService.rpId(req)) +
                ",\"rpName\":\"UTErSpace\"" +
                ",\"userId\":" + JsonUtil.str(WebAuthnService.b64(("uterspace-user-" + me.getUserId()).getBytes(StandardCharsets.UTF_8))) +
                ",\"userName\":" + JsonUtil.str(me.getEmail()) +
                ",\"displayName\":" + JsonUtil.str(me.getFullName()) +
                ",\"exclude\":" + exclude.append(']') + "}");
    }

    private void register(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, WebAuthnService.WebAuthnException {
        String credentialId = req.getParameter("credentialId");
        if (credentialId == null || credentialId.isEmpty() || credentialId.length() > 700) throw new WebAuthnService.WebAuthnException("Mã passkey không hợp lệ.");
        int alg = Integer.parseInt(req.getParameter("alg"));
        byte[] spki = WebAuthnService.verifyRegistration(req, req.getParameter("clientDataJSON"), req.getParameter("publicKey"), alg);
        if (passkeyDAO.findByCredentialId(credentialId) != null) { JsonUtil.error(resp, 409, "Passkey này đã được đăng ký."); return; }
        String label = req.getParameter("label");
        label = label == null || label.trim().isEmpty() ? "Passkey" : label.trim();
        if (label.length() > 100) label = label.substring(0, 100);
        passkeyDAO.add(me.getUserId(), credentialId, spki, alg, 0, label);
        StepUp.mark(req.getSession(), "biometric");   // vừa quét vân tay / khuôn mặt khi tạo passkey
        NotificationService.account(me.getUserId(), "Đã bật xác thực sinh trắc học (" + label + ") cho tài khoản của bạn.", "/settings?tab=security");
        JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Đã đăng ký passkey \"" + label + "\".") + "}");
    }

    private void authOptions(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        List<Passkey> keys = passkeyDAO.listFor(me.getUserId());
        if (keys.isEmpty()) { JsonUtil.error(resp, 404, "Bạn chưa đăng ký passkey sinh trắc học nào."); return; }
        String challenge = WebAuthnService.newChallenge(req.getSession(), "authenticate");
        StringBuilder allow = new StringBuilder("[");
        for (int i = 0; i < keys.size(); i++) allow.append(i > 0 ? "," : "").append(JsonUtil.str(keys.get(i).getCredentialId()));
        JsonUtil.write(resp, "{\"challenge\":" + JsonUtil.str(challenge) + ",\"rpId\":" + JsonUtil.str(WebAuthnService.rpId(req)) +
                             ",\"allow\":" + allow.append(']') + "}");
    }

    private void verify(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, WebAuthnService.WebAuthnException {
        Passkey key = passkeyDAO.findByCredentialId(req.getParameter("credentialId"));
        if (key == null || key.getUserId() != me.getUserId()) throw new WebAuthnService.WebAuthnException("Passkey không thuộc tài khoản này.");
        long counter = WebAuthnService.verifyAssertion(req, key, req.getParameter("clientDataJSON"),
                                                       req.getParameter("authenticatorData"), req.getParameter("signature"));
        passkeyDAO.touch(key.getId(), counter);
        StepUp.mark(req.getSession(), "biometric");
        JsonUtil.write(resp, "{\"success\":true,\"secondsLeft\":" + secondsLeft(req.getSession()) + "}");
    }

    private static void needStepUp(HttpServletResponse resp, User me) throws IOException {
        boolean has = new WebAuthnDAO().countFor(me.getUserId()) > 0;
        resp.setStatus(403);
        JsonUtil.write(resp, "{\"error\":" + JsonUtil.str(has ? "Cần xác thực vân tay / khuôn mặt trước khi thực hiện." : "Cần nhập lại mật khẩu trước khi thực hiện.") +
                             ",\"needStepUp\":true,\"method\":" + JsonUtil.str(has ? "biometric" : "password") + "}");
    }

    private static long secondsLeft(HttpSession s) {
        Object at = s.getAttribute("stepUpAt");
        if (!(at instanceof Long)) return 0;
        return Math.max(0, (StepUp.WINDOW_MS - (System.currentTimeMillis() - (Long) at)) / 1000);
    }

    // ============================================================ Album ẩn

    private void hiddenAlbum(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        if (!StepUp.satisfied(req.getSession(), me.getUserId())) { needStepUp(resp, me); return; }
        String ctx = req.getContextPath();
        StringBuilder sb = new StringBuilder("{\"items\":[");
        String sep = "";
        for (Post p : postDAO.getProfilePosts(me.getUserId(), me.getUserId())) {
            if (!p.isHiddenByOwner() || (p.getImagePath() == null && p.getVideoPath() == null)) continue;
            sb.append(sep).append("{\"postId\":").append(p.getPostId())
              .append(",\"type\":").append(JsonUtil.str(p.isVideo() ? "VIDEO" : "IMAGE"))
              .append(",\"url\":").append(JsonUtil.str(ctx + (p.isVideo() ? p.getVideoUrl() : p.getImageUrl())))
              .append(",\"caption\":").append(JsonUtil.str(p.getContent()))
              .append(",\"date\":").append(JsonUtil.str(p.getFormattedCreatedAt())).append('}');
            sep = ",";
        }
        JsonUtil.write(resp, sb.append("],\"secondsLeft\":").append(secondsLeft(req.getSession())).append('}').toString());
    }

    // ============================================================ DID

    private void linkDid(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, WebAuthnService.WebAuthnException {
        String msg = (String) req.getSession().getAttribute("didLinkMessage");
        req.getSession().removeAttribute("didLinkMessage");
        String did = req.getParameter("did");
        byte[] pub = DidKey.publicKeyOf(did);
        if (msg == null) throw new WebAuthnService.WebAuthnException("Phiên liên kết đã hết hạn, thử lại nhé.");
        if (!StepUp.satisfied(req.getSession(), me.getUserId())) { needStepUp(resp, me); return; }
        if (pub == null) throw new WebAuthnService.WebAuthnException("DID không hợp lệ (chỉ hỗ trợ did:key Ed25519).");
        byte[] sig;
        try { sig = java.util.Base64.getUrlDecoder().decode(req.getParameter("signature")); }
        catch (RuntimeException e) { throw new WebAuthnService.WebAuthnException("Chữ ký không hợp lệ."); }
        if (!DidKey.verify(did, msg, sig)) throw new WebAuthnService.WebAuthnException("Chữ ký không khớp với DID — không chứng minh được quyền sở hữu khóa.");
        DidDAO.DidInfo old = didDAO.findByUser(me.getUserId());
        if (old != null && old.getDid().equals(did)) { JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str("Khóa này đã được liên kết sẵn.") + "}"); return; }
        if (!didDAO.link(me.getUserId(), did, pub)) { JsonUtil.error(resp, 409, "DID này đã liên kết với tài khoản khác."); return; }
        NotificationService.account(me.getUserId(), old == null
                ? "Danh tính số (DID) vừa được liên kết với tài khoản — bạn có thể đăng nhập bằng DID."
                : "Danh tính số (DID) của tài khoản vừa được THAY bằng khóa mới — khóa cũ không còn đăng nhập được.", "/settings?tab=identity");
        JsonUtil.write(resp, "{\"success\":true,\"message\":" + JsonUtil.str(old == null ? "Đã liên kết danh tính số." : "Đã thay danh tính số bằng khóa mới.") + "}");
    }

    /** Dữ liệu cá nhân để đóng gói thành Verifiable Credential (trình duyệt ký bằng khóa riêng DID) */
    private void exportData(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException {
        DidDAO.DidInfo did = didDAO.findByUser(me.getUserId());
        if (did == null) { JsonUtil.error(resp, 400, "Hãy tạo / liên kết danh tính số trước khi xuất dữ liệu."); return; }
        User u = userDAO.getUserById(me.getUserId());
        StringBuilder posts = new StringBuilder("[");
        String sep = "";
        for (Post p : postDAO.getProfilePosts(me.getUserId(), me.getUserId())) {
            posts.append(sep).append("{\"id\":").append(p.getPostId())
                 .append(",\"content\":").append(JsonUtil.str(p.getContent()))
                 .append(",\"visibility\":").append(JsonUtil.str(p.isHiddenByOwner() ? "private" : p.getVisibility()))
                 .append(",\"createdAt\":").append(JsonUtil.str(String.valueOf(p.getCreatedAt())))
                 .append(",\"likes\":").append(p.getLikeCount()).append('}');
            sep = ",";
        }
        String json = "{\"id\":" + JsonUtil.str(did.getDid()) +
                ",\"platform\":\"UTErSpace\"" +
                ",\"name\":" + JsonUtil.str(u.getFullName()) +
                ",\"givenName\":" + JsonUtil.str(u.getFirstName()) +
                ",\"familyName\":" + JsonUtil.str(u.getLastName()) +
                ",\"email\":" + JsonUtil.str(u.getEmail()) +
                ",\"bio\":" + JsonUtil.str(u.getBio()) +
                ",\"location\":" + JsonUtil.str(u.getLocation()) +
                ",\"website\":" + JsonUtil.str(u.getWebsite()) +
                ",\"memberSince\":" + JsonUtil.str(String.valueOf(u.getCreatedAt())) +
                ",\"friendCount\":" + friendshipDAO.getFriendIds(me.getUserId()).size() +
                ",\"posts\":" + posts.append(']') + "}";
        JsonUtil.write(resp, "{\"subject\":" + json + "}");
    }

    private static String nonce() {
        byte[] b = new byte[18];
        RANDOM.nextBytes(b);
        return WebAuthnService.b64(b);
    }

    private static String path(HttpServletRequest req) { return req.getPathInfo() == null ? "" : req.getPathInfo(); }
}
