package com.uterspace.dao;

import com.uterspace.model.*;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceException;
import javax.persistence.TypedQuery;
import java.time.LocalDateTime;
import java.util.*;

/** MessageDAOImpl — Implementation của MessageDAO dùng JPA */
public class MessageDAOImpl implements MessageDAO {

    /**
     * Điều kiện "tin m của hội thoại :cid mà người xem :u còn thấy":
     * sau mốc xóa lịch sử của :u và không nằm trong danh sách "Xóa ở phía tôi" của :u.
     */
    private static final String VISIBLE =
        " m.conversation.conversationId = :cid " +
        " AND m.messageId > (SELECT cmv.clearedMessageId FROM ConversationMember cmv WHERE cmv.conversationId = :cid AND cmv.userId = :u) " +
        " AND NOT EXISTS (SELECT h.messageId FROM MessageHidden h WHERE h.messageId = m.messageId AND h.userId = :u) ";

    private static TypedQuery<ChatMessage> visible(EntityManager em, String extra, String order, int cid, int viewer) {
        return em.createQuery("SELECT m FROM ChatMessage m JOIN FETCH m.sender JOIN FETCH m.conversation WHERE" + VISIBLE + extra +
                              " ORDER BY m.messageId " + order, ChatMessage.class)
                 .setParameter("cid", cid).setParameter("u", viewer);
    }

    // ============================================================ Đọc

    @Override
    public List<ChatMessage> getRecent(int conversationId, int viewerId, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<ChatMessage> list = visible(em, "", "DESC", conversationId, viewerId).setMaxResults(limit).getResultList();
            Collections.reverse(list);
            return list;
        } finally {
            em.close();
        }
    }

    @Override
    public List<ChatMessage> getAfter(int conversationId, int viewerId, int afterId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return visible(em, " AND m.messageId > :after", "ASC", conversationId, viewerId)
                     .setParameter("after", afterId).setMaxResults(200).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<ChatMessage> getBefore(int conversationId, int viewerId, int beforeId, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<ChatMessage> list = visible(em, " AND m.messageId < :before", "DESC", conversationId, viewerId)
                                       .setParameter("before", beforeId).setMaxResults(limit).getResultList();
            Collections.reverse(list);
            return list;
        } finally {
            em.close();
        }
    }

    @Override
    public List<ChatMessage> getAround(int conversationId, int viewerId, int messageId, int half) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<ChatMessage> before = visible(em, " AND m.messageId <= :mid", "DESC", conversationId, viewerId)
                                         .setParameter("mid", messageId).setMaxResults(half + 1).getResultList();
            Collections.reverse(before);
            List<ChatMessage> after = visible(em, " AND m.messageId > :mid", "ASC", conversationId, viewerId)
                                        .setParameter("mid", messageId).setMaxResults(half).getResultList();
            before.addAll(after);
            return before;
        } finally {
            em.close();
        }
    }

    @Override
    public ChatMessage getById(int messageId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<ChatMessage> r = em.createQuery("SELECT m FROM ChatMessage m JOIN FETCH m.sender JOIN FETCH m.conversation " +
                                                 "WHERE m.messageId = :id", ChatMessage.class)
                                    .setParameter("id", messageId).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    private static ChatMessage findByClientId(EntityManager em, int senderId, String clientId) {
        List<ChatMessage> r = em.createQuery("SELECT m FROM ChatMessage m JOIN FETCH m.sender JOIN FETCH m.conversation " +
                                             "WHERE m.sender.userId = :s AND m.clientId = :cl", ChatMessage.class)
                                .setParameter("s", senderId).setParameter("cl", clientId).getResultList();
        return r.isEmpty() ? null : r.get(0);
    }

    // ============================================================ Ghi

    @Override
    public ChatMessage send(int conversationId, int senderId, ChatMessage draft) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            if (draft.getClientId() != null) {
                ChatMessage dup = findByClientId(em, senderId, draft.getClientId());
                if (dup != null) return dup;                         // gửi lại sau lỗi mạng: trả tin đã lưu
            }
            em.getTransaction().begin();
            LocalDateTime now = LocalDateTime.now();
            draft.setConversation(em.getReference(Conversation.class, conversationId));
            draft.setSender(em.find(User.class, senderId));
            draft.setTimestamp(now);
            if (draft.getContent() == null) draft.setContent("");
            em.persist(draft);
            em.flush();                                              // lấy id; trùng clientId (gửi đồng thời) nổ ở đây
            em.createQuery("UPDATE Conversation c SET c.lastMessageTime = :now WHERE c.conversationId = :c")
              .setParameter("now", now).setParameter("c", conversationId).executeUpdate();
            em.createQuery("UPDATE ConversationMember cm SET cm.lastReadMessageId = :v, cm.lastDeliveredMessageId = :v " +
                           "WHERE cm.conversationId = :c AND cm.userId = :u")
              .setParameter("v", draft.getMessageId()).setParameter("c", conversationId).setParameter("u", senderId).executeUpdate();
            em.getTransaction().commit();
            return getById(draft.getMessageId());
        } catch (PersistenceException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            if (draft.getClientId() != null) {
                EntityManager em2 = JPAUtil.getEntityManager();
                try {
                    ChatMessage dup = findByClientId(em2, senderId, draft.getClientId());
                    if (dup != null) return dup;
                } finally {
                    em2.close();
                }
            }
            throw e;
        } finally {
            if (em.isOpen()) em.close();
        }
    }

    @Override
    public ChatMessage system(int conversationId, int actorId, String text) {
        ChatMessage m = new ChatMessage();
        m.setMessageType(ChatMessage.TYPE_SYSTEM);
        m.setContent(text);
        return send(conversationId, actorId, m);
    }

    @Override
    public boolean edit(int messageId, String content) {
        return update("UPDATE ChatMessage m SET m.content = :v, m.editedAt = :now WHERE m.messageId = :id AND m.recalledAt IS NULL",
                      messageId, content) == 1;
    }

    @Override
    public String recall(int messageId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            ChatMessage m = em.find(ChatMessage.class, messageId);
            if (m == null || m.getRecalledAt() != null) { em.getTransaction().rollback(); return null; }
            String path = m.getAttachmentPath();
            m.setRecalledAt(LocalDateTime.now());
            m.setContent("");
            m.setAttachmentPath(null);
            m.setAttachmentName(null);
            m.setAttachmentSize(null);
            m.setAttachmentType(null);
            m.setPinnedAt(null);
            m.setPinnedBy(null);
            em.createQuery("DELETE FROM MessageReaction r WHERE r.messageId = :id").setParameter("id", messageId).executeUpdate();
            em.getTransaction().commit();
            return path != null ? path : "";
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public void hide(int messageId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            if (em.find(MessageHidden.class, new MessageHidden.Key(messageId, userId)) == null) {
                em.persist(new MessageHidden(messageId, userId));
            }
            em.getTransaction().commit();
        } catch (PersistenceException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();   // bấm 2 lần: đã ẩn rồi
        } finally {
            em.close();
        }
    }

    @Override
    public String react(int messageId, int userId, String emoji) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            MessageReaction r = em.find(MessageReaction.class, new MessageReaction.Key(messageId, userId));
            String result;
            if (r == null) { em.persist(new MessageReaction(messageId, userId, emoji)); result = emoji; }
            else if (r.getEmoji().equals(emoji)) { em.remove(r); result = null; }
            else { r.setEmoji(emoji); result = emoji; }
            em.getTransaction().commit();
            return result;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean setPinned(int messageId, Integer pinnedBy) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("UPDATE ChatMessage m SET m.pinnedAt = :at, m.pinnedBy = :by WHERE m.messageId = :id AND m.recalledAt IS NULL")
                      .setParameter("at", pinnedBy != null ? LocalDateTime.now() : null)
                      .setParameter("by", pinnedBy).setParameter("id", messageId).executeUpdate();
            em.getTransaction().commit();
            return n == 1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public List<ChatMessage> getPinned(int conversationId, int viewerId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<ChatMessage> list = visible(em, " AND m.pinnedAt IS NOT NULL", "DESC", conversationId, viewerId).getResultList();
            list.sort((a, b) -> b.getPinnedAt().compareTo(a.getPinnedAt()));
            return list;
        } finally {
            em.close();
        }
    }

    @Override
    public List<ChatMessage> search(int conversationId, int viewerId, String query, int limit) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            // Lọc chữ không dấu bằng SQL gốc (COLLATE utf8mb4_0900_ai_ci coi "đ" = "d", giống SearchDAO)
            @SuppressWarnings("unchecked")
            List<Number> ids = em.createNativeQuery(
                    "SELECT m.message_id FROM chat_messages m " +
                    "JOIN conversation_members cm ON cm.conversation_id = m.conversation_id AND cm.user_id = ?2 " +
                    "WHERE m.conversation_id = ?1 AND m.message_id > cm.cleared_message_id AND m.recalled_at IS NULL " +
                    "AND m.message_type = 'TEXT' " +
                    "AND (m.content COLLATE utf8mb4_0900_ai_ci LIKE ?3 ESCAPE '!' " +
                    "     OR m.attachment_name COLLATE utf8mb4_0900_ai_ci LIKE ?3 ESCAPE '!') " +
                    "AND NOT EXISTS (SELECT 1 FROM message_hidden h WHERE h.message_id = m.message_id AND h.user_id = ?2) " +
                    "ORDER BY m.message_id DESC")
                .setParameter(1, conversationId).setParameter(2, viewerId).setParameter(3, SearchDAO.likePattern(query))
                .setMaxResults(limit).getResultList();
            if (ids.isEmpty()) return new ArrayList<>();
            List<Integer> idList = new ArrayList<>();
            for (Number n : ids) idList.add(n.intValue());
            return em.createQuery("SELECT m FROM ChatMessage m JOIN FETCH m.sender JOIN FETCH m.conversation " +
                                  "WHERE m.messageId IN :ids ORDER BY m.messageId DESC", ChatMessage.class)
                     .setParameter("ids", idList).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public void attachExtras(List<ChatMessage> messages) {
        if (messages == null || messages.isEmpty()) return;
        Map<Integer, ChatMessage> byId = new HashMap<>();
        Set<Integer> replyIds = new HashSet<>();
        for (ChatMessage m : messages) {
            byId.put(m.getMessageId(), m);
            if (m.getReplyToId() != null) replyIds.add(m.getReplyToId());
        }
        EntityManager em = JPAUtil.getEntityManager();
        try {
            for (MessageReaction r : em.createQuery("SELECT r FROM MessageReaction r JOIN FETCH r.user WHERE r.messageId IN :ids " +
                                                    "ORDER BY r.createdAt", MessageReaction.class)
                                       .setParameter("ids", byId.keySet()).getResultList()) {
                byId.get(r.getMessageId()).getReactions().add(r);
            }
            if (!replyIds.isEmpty()) {
                Map<Integer, ChatMessage> replies = new HashMap<>();
                for (ChatMessage r : em.createQuery("SELECT m FROM ChatMessage m JOIN FETCH m.sender WHERE m.messageId IN :ids",
                                                    ChatMessage.class).setParameter("ids", replyIds).getResultList()) {
                    replies.put(r.getMessageId(), r);
                }
                for (ChatMessage m : messages) if (m.getReplyToId() != null) m.setReplyTo(replies.get(m.getReplyToId()));
            }
        } finally {
            em.close();
        }
    }

    @Override
    public int getUnreadMessageCount(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(m) FROM ChatMessage m, ConversationMember cm " +
                                  "WHERE cm.userId = :u AND m.conversation.conversationId = cm.conversationId " +
                                  "AND m.messageId > cm.lastReadMessageId AND m.messageId > cm.clearedMessageId " +
                                  "AND m.sender.userId <> :u AND m.messageType = 'TEXT'", Long.class)
                     .setParameter("u", userId).getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public int unreadIn(int conversationId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT COUNT(m) FROM ChatMessage m, ConversationMember cm " +
                                  "WHERE cm.userId = :u AND cm.conversationId = :c AND m.conversation.conversationId = :c " +
                                  "AND m.messageId > cm.lastReadMessageId AND m.messageId > cm.clearedMessageId " +
                                  "AND m.sender.userId <> :u AND m.messageType = 'TEXT'", Long.class)
                     .setParameter("u", userId).setParameter("c", conversationId).getSingleResult().intValue();
        } finally {
            em.close();
        }
    }

    @Override
    public int maxMessageId(int conversationId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            Integer max = em.createQuery("SELECT MAX(m.messageId) FROM ChatMessage m WHERE m.conversation.conversationId = :c", Integer.class)
                            .setParameter("c", conversationId).getSingleResult();
            return max != null ? max : 0;
        } finally {
            em.close();
        }
    }

    private int update(String jpql, int messageId, Object value) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery(jpql).setParameter("v", value).setParameter("now", LocalDateTime.now())
                      .setParameter("id", messageId).executeUpdate();
            em.getTransaction().commit();
            return n;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }
}
