package com.uterspace.dao;

import com.uterspace.model.UserSettings;
import com.uterspace.util.JPAUtil;

import javax.persistence.EntityManager;
import java.time.LocalDateTime;
import java.util.*;

/**
 * UserSettingsDAO — quyền riêng tư + tùy chọn thông báo (bảng user_settings).
 * Người chưa từng lưu cài đặt thì không có dòng trong DB → trả object mặc định (không ghi DB khi chỉ đọc).
 * Lớp nhỏ, không tách interface (giống AdminLogDAO).
 */
public class UserSettingsDAO {

    public UserSettings get(int userId) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            UserSettings s = em.find(UserSettings.class, userId);
            return s != null ? s : new UserSettings(userId);
        } finally {
            em.close();
        }
    }

    /** Cài đặt của nhiều người (người chưa lưu → mặc định) — dùng khi hiển thị trạng thái online cả danh sách */
    public Map<Integer, UserSettings> getMany(Collection<Integer> userIds) {
        Map<Integer, UserSettings> map = new HashMap<>();
        if (userIds == null || userIds.isEmpty()) return map;
        EntityManager em = JPAUtil.getEntityManager();
        try {
            for (UserSettings s : em.createQuery("SELECT s FROM UserSettings s WHERE s.userId IN :ids", UserSettings.class)
                                    .setParameter("ids", new ArrayList<>(new HashSet<>(userIds))).getResultList()) {
                map.put(s.getUserId(), s);
            }
            for (Integer id : userIds) map.putIfAbsent(id, new UserSettings(id));
            return map;
        } finally {
            em.close();
        }
    }

    /** Tạo mới hoặc cập nhật (merge theo khóa chính user_id) */
    public void save(UserSettings s) {
        EntityManager em = JPAUtil.getEntityManager();
        try {
            em.getTransaction().begin();
            s.setUpdatedAt(LocalDateTime.now());
            em.merge(s);
            em.getTransaction().commit();
        } catch (RuntimeException e) {
            if (em.getTransaction().isActive()) em.getTransaction().rollback();
            throw e;
        } finally {
            em.close();
        }
    }
}
