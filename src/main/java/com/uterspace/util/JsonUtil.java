package com.uterspace.util;

import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * JsonUtil — dựng chuỗi JSON nhỏ cho các endpoint AJAX (project không dùng thư viện JSON).
 * Escape đủ dấu nháy, backslash và MỌI ký tự điều khiển (tin nhắn có thể chứa tab, xuống dòng...).
 */
public final class JsonUtil {

    private JsonUtil() { }

    /** Chuỗi JSON có dấu nháy, hoặc null */
    public static String str(String s) {
        if (s == null) return "null";
        StringBuilder sb = new StringBuilder(s.length() + 16).append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"':  sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n");  break;
                case '\r': sb.append("\\r");  break;
                case '\t': sb.append("\\t");  break;
                // < > & thành \\u003c... : JSON nhúng trong <script type="application/json"> (chat.jsp) không thể
                // bị chuỗi "</script>" trong tin nhắn phá ra ngoài thẻ — vẫn là JSON hợp lệ cho JSON.parse
                case '<':  sb.append("\\u003c"); break;
                case '>':  sb.append("\\u003e"); break;
                case '&':  sb.append("\\u0026"); break;
                default:
                    if (c < 0x20 || c == ' ' || c == ' ') sb.append(String.format("\\u%04x", (int) c));
                    else sb.append(c);
            }
        }
        return sb.append('"').toString();
    }

    /** Ghi JSON với Content-Type chuẩn */
    public static void write(HttpServletResponse resp, String json) throws IOException {
        resp.setContentType("application/json;charset=UTF-8");
        resp.getWriter().write(json);
    }

    /** {"error": "..."} kèm mã HTTP */
    public static void error(HttpServletResponse resp, int status, String message) throws IOException {
        resp.setStatus(status);
        write(resp, "{\"error\":" + str(message) + "}");
    }
}
