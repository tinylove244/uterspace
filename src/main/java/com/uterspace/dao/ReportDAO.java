package com.uterspace.dao;

import com.uterspace.model.Report;
import com.uterspace.model.ReportGroup;

import java.util.List;
import java.util.Map;

/** ReportDAO — báo cáo vi phạm (bảng reports), plan mục 6. */
public interface ReportDAO {

    /**
     * Tạo báo cáo mới.
     * @return true nếu tạo được; false nếu người này đã báo cáo đối tượng này rồi (UNIQUE)
     */
    boolean create(int reporterId, String targetType, int targetId, String reason, String detail);

    /** Báo cáo đang chờ, gom theo đối tượng — nhiều người báo cáo nhất trước; kèm danh sách báo cáo */
    List<ReportGroup> getPendingGroups(int page, int pageSize);

    int countPendingGroups();

    /** Tổng số báo cáo đang chờ (huy hiệu ở sidebar admin) */
    int countPending();

    /** Đóng mọi báo cáo đang chờ của một đối tượng: RESOLVED (đã xử lý) hoặc DISMISSED (bỏ qua) */
    int closeReports(String targetType, int targetId, String status, int adminId);

    /** Số báo cáo đang chờ theo từng bài (trang quản lý bài viết) */
    Map<Integer, Integer> countPendingByPost(List<Integer> postIds);

    /** Các mã lý do (khác nhau) của báo cáo đang chờ về một đối tượng */
    List<String> pendingReasons(String targetType, int targetId);

    /** Báo cáo mới nhất (mọi trạng thái), kèm người báo cáo — dashboard */
    List<Report> getRecent(int limit);
}
