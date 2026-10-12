package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.util.LayoutSupport;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.List;

/**
 * VideoController — Trang Video (/video?tab=all|friends&page=N), plan mục 5.
 * Bài media_type = 'VIDEO' qua quy tắc VISIBLE, phân trang; giao diện cuộn dọc kiểu Reels (video.jsp).
 */
@WebServlet("/video")
public class VideoController extends HttpServlet {

    private static final int PAGE_SIZE = 8;

    private final PostDAO postDAO = new PostDAOImpl();
    private final LikeDAO likeDAO = new LikeDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        HttpSession session  = req.getSession(false);
        User currentUser     = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (currentUser == null) { resp.sendRedirect(req.getContextPath() + "/login"); return; }

        int uid = currentUser.getUserId();
        boolean friendsOnly = "friends".equals(req.getParameter("tab"));
        int total = postDAO.countVideoPosts(uid, friendsOnly);
        int pages = Math.max(1, (total + PAGE_SIZE - 1) / PAGE_SIZE);
        int page = 1;
        try { page = Integer.parseInt(req.getParameter("page")); } catch (NumberFormatException ignored) { }
        page = Math.min(Math.max(page, 1), pages);

        List<Post> videoPosts = postDAO.getVideoPosts(uid, friendsOnly, page, PAGE_SIZE);
        likeDAO.markLikedBy(videoPosts, uid);
        postDAO.attachGroupNames(videoPosts);

        req.setAttribute("videoPosts",   videoPosts);
        req.setAttribute("videoTab",     friendsOnly ? "friends" : "all");
        req.setAttribute("videoTotal",   total);
        req.setAttribute("videoPage",    page);
        req.setAttribute("videoPages",   pages);
        req.setAttribute("currentPage",  "video");
        req.setAttribute("pageTitle",    "Video");
        LayoutSupport.populate(req, currentUser);

        req.getRequestDispatcher("/WEB-INF/views/video/video.jsp").forward(req, resp);
    }
}
