package com.uterspace.controller;

import com.uterspace.dao.UserDAO;
import com.uterspace.dao.UserDAOImpl;
import com.uterspace.model.User;
import com.uterspace.security.DidDAO;
import com.uterspace.security.DidKey;
import com.uterspace.security.WebAuthnService;
import com.uterspace.util.JsonUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * DidLoginController — đăng nhập KHÔNG mật khẩu bằng danh tính số did:key (trang đăng nhập → "Đăng nhập bằng DID").
 * Công khai (không qua AuthFilter). Luồng challenge–response:
 *
 *   POST /did/challenge          → thông điệp ngẫu nhiên (lưu trong phiên, hết hạn sau 3 phút)
 *   POST /did/login {did, signature} → trình duyệt đã ký thông điệp bằng khóa riêng Ed25519 → máy chủ kiểm tra chữ ký
 *                                      bằng khóa công khai NẰM TRONG chính DID, tìm tài khoản đã liên kết DID đó → đăng nhập.
 * Máy chủ không giữ bí mật nào của người dùng (không mật khẩu, không khóa riêng) → không có gì để rò rỉ.
 *
 * Công cụ công khai cho bên thứ ba kiểm tra danh tính số / hồ sơ do người dùng UTErSpace phát hành:
 *   GET /did/resolve?did=did:key:z… | ?userId=N → DID Resolution Result (W3C): DID Document của did:key
 *                                                (tự suy ra từ khóa công khai trong DID) + tài khoản UTErSpace đã liên kết (nếu có)
 *   GET /did/verify                             → trang kiểm tra chữ ký Verifiable Credential (chạy trên trình duyệt)
 */
@WebServlet(urlPatterns = {"/did/challenge", "/did/login", "/did/resolve", "/did/verify"})
public class DidLoginController extends HttpServlet {

    private static final long TTL_MS = 3 * 60 * 1000L;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final DidDAO  didDAO  = new DidDAO();
    private final UserDAO userDAO = new UserDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        if ("/did/verify".equals(req.getServletPath())) {
            req.getRequestDispatcher("/WEB-INF/views/auth/did-verify.jsp").forward(req, resp);
        } else if ("/did/resolve".equals(req.getServletPath())) {
            resolve(req, resp);
        } else {
            resp.sendError(405);
        }
    }

    /** DID Resolution: did:key tự chứa khóa công khai nên DID Document được suy ra trực tiếp, không cần tra cứu */
    private void resolve(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setHeader("Access-Control-Allow-Origin", "*");   // dữ liệu công khai — cho phép trình kiểm tra ở trang khác gọi
        String did = req.getParameter("did");
        DidDAO.DidInfo info = null;
        if (did == null && req.getParameter("userId") != null) {
            try { info = didDAO.findByUser(Integer.parseInt(req.getParameter("userId"))); }
            catch (NumberFormatException e) { JsonUtil.error(resp, 400, "userId không hợp lệ."); return; }
            if (info == null) { JsonUtil.error(resp, 404, "Tài khoản này chưa liên kết danh tính số."); return; }
            did = info.getDid();
        }
        did = did == null ? "" : did.trim();
        if (DidKey.publicKeyOf(did) == null) {
            resp.setStatus(400);
            JsonUtil.write(resp, "{\"didResolutionMetadata\":{\"error\":\"invalidDid\"},\"error\":" +
                    JsonUtil.str("DID không hợp lệ — chỉ hỗ trợ did:key với khóa Ed25519.") + "}");
            return;
        }
        if (info == null) info = didDAO.findByDid(did);

        String key = did.substring("did:key:".length());   // z6Mk… (multibase base58btc của khóa)
        String vm = JsonUtil.str(did + "#" + key);
        String doc = "{\"@context\":[\"https://www.w3.org/ns/did/v1\",\"https://w3id.org/security/multikey/v1\"]" +
                ",\"id\":" + JsonUtil.str(did) +
                ",\"verificationMethod\":[{\"id\":" + vm + ",\"type\":\"Multikey\",\"controller\":" + JsonUtil.str(did) +
                ",\"publicKeyMultibase\":" + JsonUtil.str(key) + "}]" +
                ",\"authentication\":[" + vm + "],\"assertionMethod\":[" + vm + "]" +
                ",\"capabilityInvocation\":[" + vm + "],\"capabilityDelegation\":[" + vm + "]}";
        String account = "null";
        if (info != null) {
            User u = userDAO.getUserById(info.getUserId());
            if (u != null && !u.isLocked()) {
                account = "{\"platform\":\"UTErSpace\",\"userId\":" + u.getUserId() +
                        ",\"name\":" + JsonUtil.str(u.getFullName()) +
                        ",\"profile\":" + JsonUtil.str(req.getContextPath() + "/profile?userId=" + u.getUserId()) +
                        ",\"linkedAt\":" + JsonUtil.str(info.getFormattedCreatedAt()) + "}";
            }
        }
        resp.setContentType("application/json;charset=UTF-8");
        resp.getWriter().write("{\"@context\":\"https://w3id.org/did-resolution/v1\"" +
                ",\"didDocument\":" + doc +
                ",\"didResolutionMetadata\":{\"contentType\":\"application/did+ld+json\",\"method\":\"key\"}" +
                ",\"didDocumentMetadata\":{}" +
                ",\"linkedAccount\":" + account + "}");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        req.setCharacterEncoding("UTF-8");
        HttpSession session = req.getSession(true);
        if ("/did/challenge".equals(req.getServletPath())) {
            byte[] b = new byte[24];
            RANDOM.nextBytes(b);
            String msg = DidKey.challengeMessage("login", req.getServerName(), WebAuthnService.b64(b));
            session.setAttribute("didLoginChallenge", new Object[]{ msg, System.currentTimeMillis() });
            JsonUtil.write(resp, "{\"message\":" + JsonUtil.str(msg) + "}");
            return;
        }

        Object[] saved = (Object[]) session.getAttribute("didLoginChallenge");
        session.removeAttribute("didLoginChallenge");
        if (saved == null || System.currentTimeMillis() - (Long) saved[1] > TTL_MS) {
            JsonUtil.error(resp, 400, "Phiên đăng nhập DID đã hết hạn — thử lại nhé."); return;
        }
        String did = req.getParameter("did");
        byte[] sig;
        try { sig = Base64.getUrlDecoder().decode(req.getParameter("signature")); }
        catch (RuntimeException e) { JsonUtil.error(resp, 400, "Chữ ký không hợp lệ."); return; }
        if (!DidKey.verify(did, (String) saved[0], sig)) { JsonUtil.error(resp, 401, "Chữ ký không khớp với danh tính số."); return; }

        DidDAO.DidInfo info = didDAO.findByDid(did);
        if (info == null) { JsonUtil.error(resp, 404, "Danh tính số này chưa liên kết với tài khoản UTErSpace nào. Hãy đăng nhập bằng mật khẩu rồi liên kết trong Cài đặt → Danh tính số."); return; }
        User u = userDAO.getUserById(info.getUserId());
        if (u == null) { JsonUtil.error(resp, 404, "Tài khoản không còn tồn tại."); return; }
        if (u.isLocked()) { JsonUtil.error(resp, 403, AuthController.lockedMessage(u)); return; }

        String target = AuthController.startSession(req, u, " bằng danh tính số (DID)");
        JsonUtil.write(resp, "{\"success\":true,\"redirect\":" + JsonUtil.str(req.getContextPath() + target) + "}");
    }
}
