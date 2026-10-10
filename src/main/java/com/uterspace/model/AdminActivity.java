package com.uterspace.model;

import java.time.Duration;
import java.time.LocalDateTime;

/**
 * AdminActivity — một dòng "Hoạt động gần đây" trên dashboard quản trị. Không phải entity.
 * Gộp ba nguồn: nhật ký admin, báo cáo mới, tài khoản mới đăng ký — sắp theo thời gian.
 * Câu hiển thị tách thành actor (in đậm) + text, JSP tự escape từng phần.
 */
public class AdminActivity {

    private final String icon;       // tên icon SVG trong sprite (#i-…)
    private final String actor;
    private final String text;
    private final String url;        // trang admin liên quan (tương đối với context path), có thể null
    private final String tone;       // danger | ok | "" — màu chấm bên trái
    private final LocalDateTime at;

    public AdminActivity(String icon, String actor, String text, String url, String tone, LocalDateTime at) {
        this.icon = icon;
        this.actor = actor;
        this.text = text;
        this.url = url;
        this.tone = tone;
        this.at = at;
    }

    /** "5 phút trước", "Hôm qua", "3 ngày trước" */
    public static String timeAgo(LocalDateTime t) {
        if (t == null) return "";
        long min = Duration.between(t, LocalDateTime.now()).toMinutes();
        if (min < 1) return "Vừa xong";
        if (min < 60) return min + " phút trước";
        if (min < 24 * 60) return (min / 60) + " giờ trước";
        long days = min / (24 * 60);
        return days == 1 ? "Hôm qua" : days + " ngày trước";
    }

    public String getIcon() { return icon; }
    public String getActor() { return actor; }
    public String getText() { return text; }
    public String getUrl() { return url; }
    public String getTone() { return tone; }
    public LocalDateTime getAt() { return at; }
    public String getTimeAgo() { return timeAgo(at); }
}
