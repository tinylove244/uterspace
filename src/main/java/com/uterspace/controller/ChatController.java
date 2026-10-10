package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.realtime.Presence;
import com.uterspace.service.ChatService;
import com.uterspace.service.ChatService.ChatException;
import com.uterspace.util.ChatJson;
import com.uterspace.util.JsonUtil;
import com.uterspace.util.LayoutSupport;
import com.uterspace.util.UploadUtil;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.net.URLEncoder;
import java.nio.file.Files;
import java.util.*;

/**
 * ChatController — Tin nhắn (1-1 và nhóm).
 *
 * Trang:  GET /chat?c=<conversationId> | /chat?with=<userId> (mở / tạo chat 1-1)
 * Đọc (JSON):
 *   /chat/messages?conversationId=&afterId=     đồng bộ bù sau mất kết nối (và poll dự phòng khi không có WebSocket)
 *   /chat/history?conversationId=&beforeId=     cuộn lên xem tin cũ
 *   /chat/around?conversationId=&messageId=     nhảy tới một tin (kết quả tìm kiếm, tin được trả lời, tin ghim)
 *   /chat/conversations                         danh sách hội thoại
 *   /chat/search?conversationId=&q=             tìm trong hội thoại (không phân biệt dấu)
 *   /chat/pinned?conversationId=                tin đang ghim
 *   /chat/info?conversationId=                  thành viên, trạng thái online, mốc đã xem, quyền gửi
 *   /chat/friends                               bạn bè (chọn người khi tạo nhóm / thêm thành viên)
 *   /chat/file?id=<messageId>[&download=1]      tải ảnh / file đính kèm (chỉ thành viên)
 * Ghi (POST, JSON, cần CSRF token):
 *   /chat/send (multipart: content, clientId, replyToId, file)  /chat/read  /chat/unread  /chat/clear
 *   /chat/edit  /chat/recall  /chat/hide  /chat/react  /chat/pin
 *   /chat/group/create  /chat/group/add  /chat/group/remove  /chat/group/leave  /chat/group/rename
 *
 * Mọi endpoint nhận conversationId / messageId đều kiểm tra người dùng là THÀNH VIÊN (ChatService.require...).
 */
@WebServlet(urlPatterns = {"/chat", "/chat/*"})
@MultipartConfig(fileSizeThreshold = 1024 * 1024, maxFileSize = 1024L * 1024 * 20, maxRequestSize = 1024L * 1024 * 21)
public class ChatController extends HttpServlet {

    private static final int PAGE_SIZE = 30;

    private final ConversationDAO conversationDAO = new ConversationDAOImpl();
    private final MessageDAO      messageDAO      = new MessageDAOImpl();
    private final UserDAO         userDAO         = new UserDAOImpl();
    private final FriendshipDAO   friendshipDAO   = new FriendshipDAOImpl();
    private final UserSettingsDAO settingsDAO     = new UserSettingsDAO();

    // ============================================================ GET

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        User me = currentUser(req);
        String action = action(req);
        try {
            switch (action) {
                case "":              showPage(req, resp, me); break;
                case "messages":      pollMessages(req, resp, me); break;
                case "history":       history(req, resp, me); break;
                case "around":        around(req, resp, me); break;
                case "conversations": JsonUtil.write(resp, "{\"conversations\":" + conversationsJson(me.getUserId()) + "}"); break;
                case "search":        search(req, resp, me); break;
                case "pinned":        pinned(req, resp, me); break;
                case "info":          info(req, resp, me); break;
                case "friends":       friends(resp, me); break;
                case "file":          file(req, resp, me); break;
                default:              resp.sendError(404);
            }
        } catch (ChatException e) {
            JsonUtil.error(resp, e.status, e.getMessage());
        }
    }

    // ============================================================ POST

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        req.setCharacterEncoding("UTF-8");
        User me = currentUser(req);
        try {
            switch (action(req)) {
                case "send":          send(req, resp, me); break;
                case "read": {
                    Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
                    ChatService.read(me, c, intParam(req, "upToId"));
                    ok(resp);
                    break;
                }
                case "unread":        ChatService.markUnread(me, ChatService.require(intParam(req, "conversationId"), me.getUserId())); ok(resp); break;
                case "clear":         ChatService.clearHistory(me, ChatService.require(intParam(req, "conversationId"), me.getUserId())); ok(resp); break;
                case "edit": {
                    ChatMessage m = ChatService.edit(me, ChatService.requireMessage(intParam(req, "messageId"), me.getUserId()), req.getParameter("content"));
                    JsonUtil.write(resp, "{\"success\":true,\"message\":" + ChatJson.message(m) + "}");
                    break;
                }
                case "recall": {
                    String path = ChatService.recall(me, ChatService.requireMessage(intParam(req, "messageId"), me.getUserId()));
                    if (path != null && !path.isEmpty()) UploadUtil.deletePrivate(getServletContext(), path);
                    ok(resp);
                    break;
                }
                case "hide":          ChatService.hide(me, ChatService.requireMessage(intParam(req, "messageId"), me.getUserId())); ok(resp); break;
                case "react": {
                    ChatMessage m = ChatService.react(me, ChatService.requireMessage(intParam(req, "messageId"), me.getUserId()), req.getParameter("emoji"));
                    JsonUtil.write(resp, "{\"success\":true,\"message\":" + ChatJson.message(m) + "}");
                    break;
                }
                case "pin": {
                    ChatMessage m = ChatService.pin(me, ChatService.requireMessage(intParam(req, "messageId"), me.getUserId()),
                                                    "true".equals(req.getParameter("pinned")));
                    JsonUtil.write(resp, "{\"success\":true,\"message\":" + ChatJson.message(m) + "}");
                    break;
                }
                case "group/create": {
                    Conversation c = ChatService.createGroup(me, req.getParameter("title"), intList(req, "memberIds"));
                    JsonUtil.write(resp, "{\"success\":true,\"conversationId\":" + c.getConversationId() + "}");
                    break;
                }
                case "group/add":
                    ChatService.addMembers(me, ChatService.require(intParam(req, "conversationId"), me.getUserId()), intList(req, "memberIds"));
                    ok(resp);
                    break;
                case "group/remove":
                    ChatService.removeMember(me, ChatService.require(intParam(req, "conversationId"), me.getUserId()), intParam(req, "userId"));
                    ok(resp);
                    break;
                case "group/leave":
                    ChatService.leave(me, ChatService.require(intParam(req, "conversationId"), me.getUserId()));
                    ok(resp);
                    break;
                case "group/rename":
                    ChatService.rename(me, ChatService.require(intParam(req, "conversationId"), me.getUserId()), req.getParameter("title"));
                    ok(resp);
                    break;
                default:
                    resp.sendError(404);
            }
        } catch (ChatException e) {
            JsonUtil.error(resp, e.status, e.getMessage());
        } catch (IllegalStateException e) {
            // Vượt maxFileSize / maxRequestSize khi đọc multipart
            JsonUtil.error(resp, 413, "File quá lớn — ảnh tối đa 10 MB, tệp tối đa 20 MB.");
        }
    }

    // ============================================================ Trang chat

    private void showPage(HttpServletRequest req, HttpServletResponse resp, User me) throws ServletException, IOException {
        int uid = me.getUserId();
        Conversation active = null;
        String notice = null;

        Integer cid = parse(req.getParameter("c"));
        Integer withId = parse(req.getParameter("with"));
        if (withId == null) withId = parse(req.getParameter("userId"));   // link cũ

        if (cid != null) {
            active = conversationDAO.getForMember(cid, uid);
            if (active == null) notice = "Cuộc trò chuyện không tồn tại hoặc bạn không còn là thành viên.";
        } else if (withId != null && withId != uid) {
            User other = userDAO.getUserById(withId);
            if (other == null || other.isLocked()) {
                notice = "Không tìm thấy người dùng này.";
            } else {
                Conversation existing = conversationDAO.findDirect(uid, withId);
                String denied = com.uterspace.service.RelationService.messageDeniedReason(uid, withId);
                if (existing != null) active = conversationDAO.getForMember(existing.getConversationId(), uid);
                else if (denied == null) {
                    Conversation created = conversationDAO.getOrCreateConversation(uid, withId);
                    active = conversationDAO.getForMember(created.getConversationId(), uid);
                } else notice = denied;
            }
        }

        List<Conversation> conversations = conversationDAO.getConversationsFor(uid);
        if (active == null && notice == null) {
            for (Conversation c : conversations) {
                if (c.getLastMessage() != null) { active = conversationDAO.getForMember(c.getConversationId(), uid); break; }
            }
        }
        final int activeId = active != null ? active.getConversationId() : -1;
        // 1-1 chưa có tin nào (hoặc đã xóa lịch sử) thì không hiện ở danh sách, trừ hội thoại đang mở
        conversations.removeIf(c -> c.getLastMessage() == null && c.getConversationId() != activeId);
        fillPresence(conversations, uid);

        String bootstrap = "null";
        if (active != null) {
            List<ChatMessage> messages = messageDAO.getRecent(activeId, uid, PAGE_SIZE + 1);
            boolean hasMore = messages.size() > PAGE_SIZE;
            if (hasMore) messages.remove(0);
            messageDAO.attachExtras(messages);
            if (!messages.isEmpty()) {
                ChatService.read(me, active, messages.get(messages.size() - 1).getMessageId());
                active = conversationDAO.getForMember(activeId, uid);   // mốc đã xem mới
            }
            List<ChatMessage> pinned = messageDAO.getPinned(activeId, uid);
            messageDAO.attachExtras(pinned);
            bootstrap = "{\"conversation\":" + conversationInfoJson(active, uid) +
                        ",\"messages\":" + ChatJson.messages(messages) +
                        ",\"hasMore\":" + hasMore +
                        ",\"pinned\":" + ChatJson.messages(pinned.size() > 20 ? pinned.subList(0, 20) : pinned) + "}";
            for (Conversation c : conversations) if (c.getConversationId() == activeId) c.setUnreadCount(0);
        }

        StringBuilder convJson = new StringBuilder("[");
        for (int i = 0; i < conversations.size(); i++) {
            if (i > 0) convJson.append(',');
            convJson.append(ChatJson.conversation(conversations.get(i), null));
        }
        req.setAttribute("convJson",        convJson.append(']').toString());
        req.setAttribute("conversations",   conversations);
        req.setAttribute("activeConvId",    activeId);
        req.setAttribute("chatBootstrap",   bootstrap);
        req.setAttribute("chatNotice",      notice);
        req.setAttribute("currentPage",     "chat");
        req.setAttribute("pageTitle",       "Tin nhắn");
        LayoutSupport.populate(req, me);
        req.getRequestDispatcher("/WEB-INF/views/chat/chat.jsp").forward(req, resp);
    }

    /** Trạng thái online của người kia (chat 1-1), tôn trọng cài đặt "hiển thị trạng thái hoạt động" */
    private void fillPresence(List<Conversation> list, int uid) {
        List<Integer> partnerIds = new ArrayList<>();
        for (Conversation c : list) if (!c.isGroup() && c.getPartner() != null) partnerIds.add(c.getPartner().getUserId());
        Map<Integer, UserSettings> settings = settingsDAO.getMany(partnerIds);
        for (Conversation c : list) {
            if (c.isGroup() || c.getPartner() == null) continue;
            UserSettings s = settings.get(c.getPartner().getUserId());
            c.setOnline(Presence.isOnline(c.getPartner(), s == null || s.isShowOnline()));
        }
    }

    private String conversationsJson(int uid) {
        List<Conversation> list = conversationDAO.getConversationsFor(uid);
        list.removeIf(c -> c.getLastMessage() == null && !c.isGroup());
        fillPresence(list, uid);
        StringBuilder sb = new StringBuilder("[");
        String sep = "";
        for (Conversation c : list) {
            sb.append(sep).append(ChatJson.conversation(c, null));
            sep = ",";
        }
        return sb.append(']').toString();
    }

    /** Thông tin một hội thoại cho khung chat: tên, thành viên (+ online), mốc đã xem, quyền gửi */
    private String conversationInfoJson(Conversation c, int uid) {
        List<ConversationMember> members = c.getMembers();
        List<Integer> ids = new ArrayList<>();
        for (ConversationMember m : members) ids.add(m.getUserId());
        Map<Integer, UserSettings> settings = settingsDAO.getMany(ids);
        String presence = "";
        for (ConversationMember m : members) {
            boolean show = settings.get(m.getUserId()).isShowOnline();
            m.setOnline(m.getUserId() != uid && Presence.isOnline(m.getUser(), show));
            if (!c.isGroup() && m.getUserId() != uid) presence = Presence.label(m.getUser(), show);
        }
        ConversationMember mine = null;
        for (ConversationMember m : members) if (m.getUserId() == uid) mine = m;
        String denied = ChatService.sendDeniedReason(c, uid);
        User p = c.isGroup() ? null : c.getPartner();
        return "{\"id\":" + c.getConversationId() +
               ",\"group\":" + c.isGroup() +
               ",\"title\":" + JsonUtil.str(c.getDisplayName()) +
               ",\"initials\":" + JsonUtil.str(c.isGroup() ? c.getGroupInitials() : (p != null ? p.getInitials() : "")) +
               ",\"avatar\":" + JsonUtil.str(p != null && p.getAvatar() != null ? p.getAvatarUrl() : null) +
               ",\"partnerId\":" + (p != null ? p.getUserId() : 0) +
               ",\"partnerLocation\":" + JsonUtil.str(p != null ? p.getLocation() : null) +
               ",\"presence\":" + JsonUtil.str(presence) +
               ",\"owner\":" + (mine != null && mine.isOwner()) +
               ",\"canSend\":" + (denied == null) +
               ",\"denyReason\":" + JsonUtil.str(denied) +
               ",\"members\":" + ChatJson.members(members) +
               ",\"receipts\":" + ChatJson.receipts(members) + "}";
    }

    // ============================================================ JSON đọc

    private void pollMessages(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ChatException {
        Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
        List<ChatMessage> fresh = messageDAO.getAfter(c.getConversationId(), me.getUserId(), intParamOr(req, "afterId", 0));
        messageDAO.attachExtras(fresh);
        if (!fresh.isEmpty()) ChatService.delivered(me, c, fresh.get(fresh.size() - 1).getMessageId());
        Conversation fresher = conversationDAO.getForMember(c.getConversationId(), me.getUserId());
        JsonUtil.write(resp, "{\"messages\":" + ChatJson.messages(fresh) + ",\"receipts\":" + ChatJson.receipts(fresher.getMembers()) + "}");
    }

    private void history(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ChatException {
        Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
        List<ChatMessage> older = messageDAO.getBefore(c.getConversationId(), me.getUserId(), intParam(req, "beforeId"), PAGE_SIZE + 1);
        boolean hasMore = older.size() > PAGE_SIZE;
        if (hasMore) older.remove(0);
        messageDAO.attachExtras(older);
        JsonUtil.write(resp, "{\"hasMore\":" + hasMore + ",\"messages\":" + ChatJson.messages(older) + "}");
    }

    private void around(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ChatException {
        Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
        int mid = intParam(req, "messageId");
        List<ChatMessage> list = messageDAO.getAround(c.getConversationId(), me.getUserId(), mid, 15);
        messageDAO.attachExtras(list);
        boolean hasMore = !list.isEmpty() && !messageDAO.getBefore(c.getConversationId(), me.getUserId(), list.get(0).getMessageId(), 1).isEmpty();
        JsonUtil.write(resp, "{\"hasMore\":" + hasMore + ",\"messages\":" + ChatJson.messages(list) + "}");
    }

    private void search(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ChatException {
        Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
        String q = req.getParameter("q") == null ? "" : req.getParameter("q").trim();
        if (q.length() > 100) q = q.substring(0, 100);
        List<ChatMessage> hits = q.isEmpty() ? new ArrayList<>() : messageDAO.search(c.getConversationId(), me.getUserId(), q, 50);
        JsonUtil.write(resp, "{\"q\":" + JsonUtil.str(q) + ",\"results\":" + ChatJson.messages(hits) + "}");
    }

    private void pinned(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ChatException {
        Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
        List<ChatMessage> list = messageDAO.getPinned(c.getConversationId(), me.getUserId());
        messageDAO.attachExtras(list);
        JsonUtil.write(resp, "{\"pinned\":" + ChatJson.messages(list) + "}");
    }

    private void info(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ChatException {
        Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
        JsonUtil.write(resp, "{\"conversation\":" + conversationInfoJson(c, me.getUserId()) + "}");
    }

    private void friends(HttpServletResponse resp, User me) throws IOException {
        Set<Integer> blocked = new BlockDAO().blockedEitherWay(me.getUserId());
        StringBuilder sb = new StringBuilder("{\"friends\":[");
        String sep = "";
        for (User u : friendshipDAO.getFriendsOf(me.getUserId())) {
            if (blocked.contains(u.getUserId()) || u.isLocked()) continue;
            sb.append(sep).append("{\"id\":").append(u.getUserId())
              .append(",\"name\":").append(JsonUtil.str(u.getFullName()))
              .append(",\"initials\":").append(JsonUtil.str(u.getInitials()))
              .append(",\"avatar\":").append(JsonUtil.str(u.getAvatar() != null ? u.getAvatarUrl() : null)).append('}');
            sep = ",";
        }
        JsonUtil.write(resp, sb.append("]}").toString());
    }

    /** Tải ảnh / file đính kèm — chỉ thành viên hội thoại; ảnh hiện trực tiếp, tài liệu tải về với tên gốc */
    private void file(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ChatException {
        ChatMessage m = ChatService.requireMessage(intParam(req, "id"), me.getUserId());
        File f = m.hasAttachment() ? UploadUtil.resolvePrivate(getServletContext(), m.getAttachmentPath()) : null;
        if (f == null) { resp.sendError(404); return; }
        String name = m.getAttachmentName() != null ? m.getAttachmentName() : f.getName();
        String mime = getServletContext().getMimeType(f.getName());
        boolean image = ChatMessage.ATT_IMAGE.equals(m.getAttachmentType());
        resp.setContentType(image && mime != null ? mime : "application/octet-stream");
        resp.setContentLengthLong(f.length());
        resp.setHeader("X-Content-Type-Options", "nosniff");
        resp.setHeader("Cache-Control", "private, max-age=86400");
        String disposition = image && !"1".equals(req.getParameter("download")) ? "inline" : "attachment";
        resp.setHeader("Content-Disposition", disposition + "; filename*=UTF-8''" + URLEncoder.encode(name, "UTF-8").replace("+", "%20"));
        try (OutputStream out = resp.getOutputStream()) {
            Files.copy(f.toPath(), out);
        }
    }

    // ============================================================ Gửi tin

    private void send(HttpServletRequest req, HttpServletResponse resp, User me) throws IOException, ServletException, ChatException {
        Conversation c = ChatService.require(intParam(req, "conversationId"), me.getUserId());
        String denied = ChatService.sendDeniedReason(c, me.getUserId());
        if (denied != null) throw new ChatException(403, denied);

        ChatMessage draft = new ChatMessage();
        draft.setContent(req.getParameter("content"));
        String clientId = req.getParameter("clientId");
        if (clientId != null && clientId.matches("[A-Za-z0-9_-]{8,40}")) draft.setClientId(clientId);
        draft.setReplyToId(parse(req.getParameter("replyToId")));

        Part file = isMultipart(req) ? req.getPart("file") : null;
        UploadUtil.StoredFile stored = null;
        if (file != null && file.getSize() > 0) {
            try {
                stored = UploadUtil.saveChatFile(getServletContext(), file);
            } catch (UploadUtil.UploadException e) {
                throw new ChatException(400, e.getMessage());
            }
            draft.setAttachmentPath(stored.path);
            draft.setAttachmentType(stored.type);
            draft.setAttachmentName(stored.name);
            draft.setAttachmentSize(stored.size);
        }
        try {
            ChatMessage m = ChatService.send(me, c, draft);
            // Trùng clientId (gửi lại) → file vừa lưu là bản thừa
            if (stored != null && !stored.path.equals(m.getAttachmentPath())) UploadUtil.deletePrivate(getServletContext(), stored.path);
            JsonUtil.write(resp, "{\"success\":true,\"message\":" + ChatJson.message(m) + "}");
        } catch (ChatException | RuntimeException e) {
            if (stored != null) UploadUtil.deletePrivate(getServletContext(), stored.path);   // không để file mồ côi
            throw e;
        }
    }

    // ============================================================ Tiện ích

    private static String action(HttpServletRequest req) {
        String info = req.getPathInfo();
        return info == null || info.equals("/") ? "" : info.substring(1);
    }

    private static boolean isMultipart(HttpServletRequest req) {
        String ct = req.getContentType();
        return ct != null && ct.toLowerCase(Locale.ROOT).startsWith("multipart/");
    }

    private static void ok(HttpServletResponse resp) throws IOException {
        JsonUtil.write(resp, "{\"success\":true}");
    }

    private static User currentUser(HttpServletRequest req) {
        return (User) req.getSession().getAttribute("currentUser");
    }

    private static Integer parse(String s) {
        if (s == null) return null;
        try { return Integer.parseInt(s.trim()); } catch (NumberFormatException e) { return null; }
    }

    private static int intParam(HttpServletRequest req, String name) throws ChatException {
        Integer v = parse(req.getParameter(name));
        if (v == null) throw new ChatException(400, "Thiếu hoặc sai tham số " + name + ".");
        return v;
    }

    private static int intParamOr(HttpServletRequest req, String name, int def) {
        Integer v = parse(req.getParameter(name));
        return v != null ? v : def;
    }

    /** memberIds=1,2,3 hoặc memberIds=1&memberIds=2 */
    private static List<Integer> intList(HttpServletRequest req, String name) {
        List<Integer> ids = new ArrayList<>();
        String[] values = req.getParameterValues(name);
        if (values == null) return ids;
        for (String v : values) for (String part : v.split(",")) { Integer i = parse(part); if (i != null) ids.add(i); }
        return ids;
    }
}
