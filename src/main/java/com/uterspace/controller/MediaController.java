package com.uterspace.controller;

import com.uterspace.dao.PostDAO;
import com.uterspace.dao.PostDAOImpl;
import com.uterspace.model.Post;
import com.uterspace.model.User;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * MediaController — phụ đề WebVTT của video (cột posts.captions_vtt, migration 090).
 * GET /media/captions?postId= → text/vtt, chỉ khi người xem được xem bài (hoặc là tác giả). Thẻ <track> trong post-video.jsp.
 */
@WebServlet(urlPatterns = {"/media/captions"})
public class MediaController extends HttpServlet {

    private final PostDAO postDAO = new PostDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User me = (User) req.getSession().getAttribute("currentUser");
        int postId;
        try { postId = Integer.parseInt(req.getParameter("postId")); }
        catch (NumberFormatException e) { resp.sendError(400); return; }
        Post p = postDAO.getPostById(postId);
        boolean own = p != null && p.getAuthor() != null && p.getAuthor().getUserId() == me.getUserId();
        if (p == null || !p.isHasCaptions() || (!own && !postDAO.canView(postId, me.getUserId()))) { resp.sendError(404); return; }
        resp.setContentType("text/vtt;charset=UTF-8");
        resp.setHeader("Cache-Control", "private, max-age=300");
        resp.getWriter().write(p.getCaptionsVtt());
    }
}
