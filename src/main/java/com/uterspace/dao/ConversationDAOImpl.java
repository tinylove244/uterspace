package com.uterspace.dao;

import com.uterspace.model.ChatMessage;
import com.uterspace.model.Conversation;
import com.uterspace.model.ConversationMember;
import com.uterspace.model.User;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import javax.persistence.PersistenceException;
import java.time.LocalDateTime;
import java.util.*;

/** ConversationDAOImpl — Implementation của ConversationDAO dùng JPA */
public class ConversationDAOImpl implements ConversationDAO {

    // ============================================================ Danh sách hội thoại

    @Override
    public List<Conversation> getConversationsFor(int userId) {
        healDirectMembers(userId);
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Conversation> list = em.createQuery(
                    "SELECT c FROM Conversation c LEFT JOIN FETCH c.userA LEFT JOIN FETCH c.userB WHERE c.conversationId IN " +
                    "(SELECT cm.conversationId FROM ConversationMember cm WHERE cm.userId = :u)", Conversation.class)
                .setParameter("u", userId).getResultList();
            if (list.isEmpty()) return list;

            Map<Integer, Conversation> byId = new LinkedHashMap<>();
            for (Conversation c : list) byId.put(c.getConversationId(), c);
            List<Integer> ids = new ArrayList<>(byId.keySet());

            // Thành viên (kèm User) của mọi hội thoại — 1 truy vấn
            for (ConversationMember m : em.createQuery("SELECT cm FROM ConversationMember cm JOIN FETCH cm.user " +
                                                       "WHERE cm.conversationId IN :ids ORDER BY cm.joinedAt", ConversationMember.class)
                                          .setParameter("ids", ids).getResultList()) {
                byId.get(m.getConversationId()).getMembers().add(m);
            }

            // Tin cuối mà MÌNH còn thấy (sau mốc "xóa cuộc trò chuyện", bỏ tin đã "xóa ở phía tôi")
            List<Integer> lastIds = em.createQuery(
                    "SELECT MAX(m.messageId) FROM ChatMessage m, ConversationMember cm " +
                    "WHERE cm.userId = :u AND cm.conversationId = m.conversation.conversationId " +
                    "AND m.messageId > cm.clearedMessageId " +
                    "AND NOT EXISTS (SELECT h.messageId FROM MessageHidden h WHERE h.messageId = m.messageId AND h.userId = :u) " +
                    "GROUP BY m.conversation.conversationId", Integer.class)
                .setParameter("u", userId).getResultList();
            if (!lastIds.isEmpty()) {
                for (ChatMessage m : em.createQuery("SELECT m FROM ChatMessage m JOIN FETCH m.sender JOIN FETCH m.conversation " +
                                                    "WHERE m.messageId IN :ids", ChatMessage.class)
                                       .setParameter("ids", lastIds).getResultList()) {
                    Conversation c = byId.get(m.getConversationId());
                    if (c == null) continue;
                    c.setLastMessage(m.getPreview());
                    c.setLastMessageMine(m.getSenderId() == userId);
                    c.setLastSenderName(m.isSystem() ? null : m.getSender().getFirstName());
                }
            }

            // Số tin chưa đọc từng hội thoại — 1 truy vấn GROUP BY
            for (Object[] row : em.createQuery(
                    "SELECT cm.conversationId, COUNT(m) FROM ChatMessage m, ConversationMember cm " +
                    "WHERE cm.userId = :u AND cm.conversationId = m.conversation.conversationId " +
                    "AND m.messageId > cm.lastReadMessageId AND m.messageId > cm.clearedMessageId " +
                    "AND m.sender.userId <> :u AND m.messageType = 'TEXT' GROUP BY cm.conversationId", Object[].class)
                    .setParameter("u", userId).getResultList()) {
                Conversation c = byId.get((Integer) row[0]);
                if (c != null) c.setUnreadCount(((Long) row[1]).intValue());
            }

            for (Conversation c : list) if (!c.isGroup()) c.setPartner(c.partnerOf(userId));

            // Mới hoạt động nhất trước (nhóm chưa có tin: theo thời điểm tạo)
            list.sort((x, y) -> {
                LocalDateTime tx = x.getLastMessageTime() != null ? x.getLastMessageTime() : x.getCreatedAt();
                LocalDateTime ty = y.getLastMessageTime() != null ? y.getLastMessageTime() : y.getCreatedAt();
                if (tx == null && ty == null) return 0;
                if (tx == null) return 1;
                if (ty == null) return -1;
                return ty.compareTo(tx);
            });
            return list;
        } finally {
            em.close();
        }
    }

    /**
     * Tự vá: hội thoại 1-1 tạo bởi bản code cũ (trước migration 060) chưa có dòng conversation_members.
     * Thêm thành viên còn thiếu, mốc đã xem = tin trước tin chưa đọc đầu tiên (giống migration).
     */
    private void healDirectMembers(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            em.createNativeQuery(
                "INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, last_read_message_id, last_delivered_message_id, cleared_message_id) " +
                "SELECT c.conversation_id, u.uid, 'MEMBER', ?1, " +
                "  COALESCE((SELECT MIN(m.message_id) - 1 FROM chat_messages m WHERE m.conversation_id = c.conversation_id AND m.sender_id <> u.uid AND m.is_read = 0)," +
                "           (SELECT MAX(m.message_id) FROM chat_messages m WHERE m.conversation_id = c.conversation_id), 0), " +
                "  COALESCE((SELECT MAX(m.message_id) FROM chat_messages m WHERE m.conversation_id = c.conversation_id), 0), 0 " +
                "FROM conversations c " +
                "JOIN (SELECT conversation_id AS cid, user_a_id AS uid FROM conversations WHERE user_a_id IS NOT NULL UNION ALL " +
                "      SELECT conversation_id, user_b_id FROM conversations WHERE user_b_id IS NOT NULL) u ON u.cid = c.conversation_id " +
                "WHERE c.is_group = 0 AND (c.user_a_id = ?2 OR c.user_b_id = ?2) " +
                "AND NOT EXISTS (SELECT 1 FROM conversation_members cm WHERE cm.conversation_id = c.conversation_id AND cm.user_id = u.uid)")
              .setParameter(1, java.sql.Timestamp.valueOf(LocalDateTime.now()))
              .setParameter(2, userId)
              .executeUpdate();
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
        } finally {
            em.close();
        }
    }

    // ============================================================ 1-1

    @Override
    public Conversation getOrCreateConversation(int userAId, int userBId) {
        int minId = Math.min(userAId, userBId), maxId = Math.max(userAId, userBId);
        Conversation found = findPair(minId, maxId);
        if (found == null) {
            EntityManager em = JPAUtil.getEntityManager();
            try {
                em.getTransaction().begin();
                Conversation c = new Conversation();
                c.setUserA(em.getReference(User.class, minId));
                c.setUserB(em.getReference(User.class, maxId));
                c.setGroup(false);
                c.setCreatedBy(userAId);
                em.persist(c);
                em.flush();
                em.persist(new ConversationMember(c.getConversationId(), minId, ConversationMember.ROLE_MEMBER));
                em.persist(new ConversationMember(c.getConversationId(), maxId, ConversationMember.ROLE_MEMBER));
                em.getTransaction().commit();
            } catch (PersistenceException e) {
                // Hai người mở hội thoại cùng lúc → người sau vi phạm UX_conversations_pair: đọc lại bên dưới
                if (em.getTransaction().isActive()) em.getTransaction().rollback();
            } finally {
                em.close();
            }
            found = findPair(minId, maxId);
            if (found == null) throw new RuntimeException("Không tạo được hội thoại giữa " + minId + " và " + maxId);
        }
        healDirectMembers(userAId);
        found.setPartner(found.partnerOf(userAId));
        return found;
    }

    @Override
    public Conversation findDirect(int userAId, int userBId) {
        Conversation c = findPair(Math.min(userAId, userBId), Math.max(userAId, userBId));
        if (c != null) c.setPartner(c.partnerOf(userAId));
        return c;
    }

    private Conversation findPair(int minId, int maxId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Conversation> r = em.createQuery(
                    "SELECT c FROM Conversation c JOIN FETCH c.userA JOIN FETCH c.userB " +
                    "WHERE c.group = false AND c.userA.userId = :a AND c.userB.userId = :b", Conversation.class)
                .setParameter("a", minId).setParameter("b", maxId).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public Conversation getConversationById(int conversationId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Conversation> r = em.createQuery(
                    "SELECT c FROM Conversation c LEFT JOIN FETCH c.userA LEFT JOIN FETCH c.userB WHERE c.conversationId = :cid",
                    Conversation.class)
                .setParameter("cid", conversationId).getResultList();
            return r.isEmpty() ? null : r.get(0);
        } finally {
            em.close();
        }
    }

    @Override
    public Conversation getForMember(int conversationId, int userId) {
        if (!isMember(conversationId, userId)) return null;
        Conversation c = getConversationById(conversationId);
        if (c == null) return null;
        c.setMembers(getMembers(conversationId));
        if (!c.isGroup()) c.setPartner(c.partnerOf(userId));
        return c;
    }

    @Override
    public boolean isMember(int conversationId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.find(ConversationMember.class, new ConversationMember.Key(conversationId, userId)) != null;
        } finally {
            em.close();
        }
    }

    @Override
    public List<Integer> getMemberIds(int conversationId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.createQuery("SELECT cm.userId FROM ConversationMember cm WHERE cm.conversationId = :c", Integer.class)
                     .setParameter("c", conversationId).getResultList();
        } finally {
            em.close();
        }
    }

    @Override
    public List<ConversationMember> getMembers(int conversationId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<ConversationMember> list = em.createQuery(
                    "SELECT cm FROM ConversationMember cm JOIN FETCH cm.user WHERE cm.conversationId = :c ORDER BY cm.joinedAt",
                    ConversationMember.class).setParameter("c", conversationId).getResultList();
            list.sort((a, b) -> Boolean.compare(b.isOwner(), a.isOwner()));
            return list;
        } finally {
            em.close();
        }
    }

    @Override
    public ConversationMember getMember(int conversationId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            return em.find(ConversationMember.class, new ConversationMember.Key(conversationId, userId));
        } finally {
            em.close();
        }
    }

    // ============================================================ Nhóm chat

    @Override
    public Conversation createGroup(int creatorId, String title, List<Integer> memberIds) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Conversation c = new Conversation();
            c.setGroup(true);
            c.setTitle(title);
            c.setCreatedBy(creatorId);
            c.setLastMessageTime(LocalDateTime.now());
            em.persist(c);
            em.flush();
            em.persist(new ConversationMember(c.getConversationId(), creatorId, ConversationMember.ROLE_OWNER));
            for (Integer id : new LinkedHashSet<>(memberIds)) {
                if (id != creatorId) em.persist(new ConversationMember(c.getConversationId(), id, ConversationMember.ROLE_MEMBER));
            }
            em.getTransaction().commit();
            return c;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public List<Integer> addMembers(int conversationId, List<Integer> userIds) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            Integer maxId = em.createQuery("SELECT MAX(m.messageId) FROM ChatMessage m WHERE m.conversation.conversationId = :c", Integer.class)
                              .setParameter("c", conversationId).getSingleResult();
            List<Integer> added = new ArrayList<>();
            for (Integer id : new LinkedHashSet<>(userIds)) {
                if (em.find(ConversationMember.class, new ConversationMember.Key(conversationId, id)) != null) continue;
                ConversationMember m = new ConversationMember(conversationId, id, ConversationMember.ROLE_MEMBER);
                // Người mới vẫn xem được lịch sử nhóm nhưng không bị tính là "chưa đọc" các tin cũ
                m.setLastReadMessageId(maxId != null ? maxId : 0);
                m.setLastDeliveredMessageId(maxId != null ? maxId : 0);
                em.persist(m);
                added.add(id);
            }
            em.getTransaction().commit();
            return added;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean removeMember(int conversationId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            ConversationMember m = em.find(ConversationMember.class, new ConversationMember.Key(conversationId, userId));
            if (m == null) { em.getTransaction().rollback(); return false; }
            boolean wasOwner = m.isOwner();
            em.remove(m);
            em.flush();
            List<ConversationMember> rest = em.createQuery(
                    "SELECT cm FROM ConversationMember cm WHERE cm.conversationId = :c ORDER BY cm.joinedAt", ConversationMember.class)
                .setParameter("c", conversationId).getResultList();
            if (rest.isEmpty()) {
                // Không còn ai: xóa nhóm (tin nhắn, cảm xúc, thành viên xóa theo ON DELETE CASCADE)
                em.createQuery("DELETE FROM Conversation c WHERE c.conversationId = :c").setParameter("c", conversationId).executeUpdate();
            } else if (wasOwner) {
                rest.get(0).setRole(ConversationMember.ROLE_OWNER);
            }
            em.getTransaction().commit();
            return true;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean rename(int conversationId, String title) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("UPDATE Conversation c SET c.title = :t WHERE c.conversationId = :c AND c.group = true")
                      .setParameter("t", title).setParameter("c", conversationId).executeUpdate();
            em.getTransaction().commit();
            return n == 1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    // ============================================================ Mốc đọc / nhận

    @Override
    public int markRead(int conversationId, int userId, int upToId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("UPDATE ConversationMember cm SET cm.lastReadMessageId = :v " +
                                   "WHERE cm.conversationId = :c AND cm.userId = :u AND cm.lastReadMessageId < :v")
                      .setParameter("v", upToId).setParameter("c", conversationId).setParameter("u", userId).executeUpdate();
            em.createQuery("UPDATE ConversationMember cm SET cm.lastDeliveredMessageId = :v " +
                           "WHERE cm.conversationId = :c AND cm.userId = :u AND cm.lastDeliveredMessageId < :v")
              .setParameter("v", upToId).setParameter("c", conversationId).setParameter("u", userId).executeUpdate();
            em.getTransaction().commit();
            return n > 0 ? upToId : -1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public int markDelivered(int conversationId, int userId, int upToId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            int n = em.createQuery("UPDATE ConversationMember cm SET cm.lastDeliveredMessageId = :v " +
                                   "WHERE cm.conversationId = :c AND cm.userId = :u AND cm.lastDeliveredMessageId < :v")
                      .setParameter("v", upToId).setParameter("c", conversationId).setParameter("u", userId).executeUpdate();
            em.getTransaction().commit();
            return n > 0 ? upToId : -1;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public Map<Integer, Integer> deliverAll(int userId) {
        Map<Integer, Integer> changed = new HashMap<>();
        EntityManager em = JPAUtil.getEntityManager();
        try {
            List<Object[]> rows = em.createQuery(
                    "SELECT cm.conversationId, MAX(m.messageId) FROM ConversationMember cm, ChatMessage m " +
                    "WHERE cm.userId = :u AND m.conversation.conversationId = cm.conversationId " +
                    "AND m.messageId > cm.lastDeliveredMessageId GROUP BY cm.conversationId", Object[].class)
                .setParameter("u", userId).getResultList();
            if (rows.isEmpty()) return changed;
            em.getTransaction().begin();
            for (Object[] r : rows) {
                int cid = (Integer) r[0], max = (Integer) r[1];
                int n = em.createQuery("UPDATE ConversationMember cm SET cm.lastDeliveredMessageId = :v " +
                                       "WHERE cm.conversationId = :c AND cm.userId = :u AND cm.lastDeliveredMessageId < :v")
                          .setParameter("v", max).setParameter("c", cid).setParameter("u", userId).executeUpdate();
                if (n > 0) changed.put(cid, max);
            }
            em.getTransaction().commit();
            return changed;
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public boolean markUnread(int conversationId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            Integer last = em.createQuery("SELECT MAX(m.messageId) FROM ChatMessage m WHERE m.conversation.conversationId = :c " +
                                          "AND m.sender.userId <> :u AND m.messageType = 'TEXT'", Integer.class)
                             .setParameter("c", conversationId).setParameter("u", userId).getSingleResult();
            if (last == null) return false;
            em.getTransaction().begin();
            int n = em.createQuery("UPDATE ConversationMember cm SET cm.lastReadMessageId = :v " +
                                   "WHERE cm.conversationId = :c AND cm.userId = :u")
                      .setParameter("v", last - 1).setParameter("c", conversationId).setParameter("u", userId).executeUpdate();
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
    public void clearHistory(int conversationId, int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            Integer max = em.createQuery("SELECT MAX(m.messageId) FROM ChatMessage m WHERE m.conversation.conversationId = :c", Integer.class)
                            .setParameter("c", conversationId).getSingleResult();
            if (max == null) return;
            em.getTransaction().begin();
            em.createQuery("UPDATE ConversationMember cm SET cm.clearedMessageId = :v WHERE cm.conversationId = :c AND cm.userId = :u")
              .setParameter("v", max).setParameter("c", conversationId).setParameter("u", userId).executeUpdate();
            em.createQuery("UPDATE ConversationMember cm SET cm.lastReadMessageId = :v " +
                           "WHERE cm.conversationId = :c AND cm.userId = :u AND cm.lastReadMessageId < :v")
              .setParameter("v", max).setParameter("c", conversationId).setParameter("u", userId).executeUpdate();
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }

    @Override
    public void touch(int conversationId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            em.createQuery("UPDATE Conversation c SET c.lastMessageTime = :now WHERE c.conversationId = :c")
              .setParameter("now", LocalDateTime.now()).setParameter("c", conversationId).executeUpdate();
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }
}
