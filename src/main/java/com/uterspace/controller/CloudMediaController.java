package com.uterspace.controller;

import com.uterspace.util.MediaUrl;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.regex.Pattern;

/**
 * CloudMediaController — GET /cdn/{cloud}/{video|image|raw}/upload/... → 301 sang https://res.cloudinary.com/...
 * MediaUrl đổi URL Cloudinary thành /cdn/... để mọi chỗ nối ${ctx}${post.videoUrl} vẫn ra URL đúng.
 * Chỉ chuyển hướng về res.cloudinary.com (không phải open redirect). URL Cloudinary có số phiên bản (v123...)
 * nên nội dung không đổi → trình duyệt cache luôn lần chuyển hướng, lần sau tải thẳng từ CDN.
 * Công khai (không nằm trong AuthFilter), giống /assets và /uploads.
 */
@WebServlet("/cdn/*")
public class CloudMediaController extends HttpServlet {

    /** Ký tự hợp lệ trong đường dẫn Cloudinary (thư mục, public_id, tham số biến đổi c_fill,w_200...) */
    private static final Pattern SAFE_PATH = Pattern.compile("/[A-Za-z0-9_\\-.,/]+");

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String path = req.getPathInfo();
        if (path == null || !SAFE_PATH.matcher(path).matches() || path.contains("..")) {
            resp.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        resp.setStatus(HttpServletResponse.SC_MOVED_PERMANENTLY);
        resp.setHeader("Location", "https://" + MediaUrl.CLOUDINARY_HOST + path);
        resp.setHeader("Cache-Control", "public, max-age=31536000, immutable");
    }
}
