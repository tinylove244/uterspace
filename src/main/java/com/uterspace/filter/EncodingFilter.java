package com.uterspace.filter;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * EncodingFilter — Đảm bảo mọi request/response đều dùng UTF-8.
 * Cần thiết để hiển thị tiếng Việt đúng.
 */
public class EncodingFilter implements Filter {

    private String encoding = "UTF-8";

    @Override
    public void init(FilterConfig filterConfig) {
        String enc = filterConfig.getInitParameter("encoding");
        if (enc != null && !enc.isEmpty()) encoding = enc;
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response,
                         FilterChain chain) throws IOException, ServletException {
        
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse resp = (HttpServletResponse) response;

        String uri = req.getRequestURI();
        // Ảnh, font, video: file nhị phân — không gắn charset vào Content-Type (video/mp4;charset=UTF-8 là sai)
        boolean isBinaryMedia = uri.endsWith(".jpg") || uri.endsWith(".jpeg") || uri.endsWith(".png")
                             || uri.endsWith(".gif") || uri.endsWith(".webp") || uri.endsWith(".ico")
                             || uri.endsWith(".woff") || uri.endsWith(".woff2") || uri.endsWith(".ttf")
                             || uri.endsWith(".mp4") || uri.endsWith(".webm");
        boolean isStaticAsset = isBinaryMedia || uri.endsWith(".css") || uri.endsWith(".js") || uri.endsWith(".svg");

        // Set UTF-8
        req.setCharacterEncoding(encoding);
        if (!isBinaryMedia) resp.setCharacterEncoding(encoding);

        if (!isStaticAsset) {
            // Chống cache cho các trang động (giải quyết lỗi giao diện bấm Back/Forward bị sai state)
            resp.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
            resp.setHeader("Pragma", "no-cache");
            resp.setDateHeader("Expires", 0);
        } else {
            // Cho phép cache static assets trong 7 ngày để web mượt mà, không bị chớp trắng
            resp.setHeader("Cache-Control", "max-age=604800, public");
        }


        chain.doFilter(request, response);
    }

    @Override public void destroy() {}
}
