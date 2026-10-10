package com.uterspace.controller;

import com.uterspace.dao.*;
import com.uterspace.model.*;
import com.uterspace.util.LayoutSupport;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.List;
import java.util.stream.Collectors;

/** SavedController — Trang Đã lưu (/saved) */
@WebServlet(urlPatterns = {"/saved", "/saved/add", "/saved/remove"})
public class SavedController extends HttpServlet {

    private final SavedPostDAO    savedDAO   = new SavedPostDAOImpl();
    private final PostDAO         postDAO    = new PostDAOImpl();
    private final NotificationDAO notifDAO   = new NotificationDAOImpl();
    private final MessageDAO      messageDAO = new MessageDAOImpl();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        HttpSession session  = req.getSession(false);
        User currentUser     = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (currentUser == null) { resp.sendRedirect(req.getContextPath() + "/login"); return; }

        int uid = currentUser.getUserId();
        List<Post> allSaved = savedDAO.getSavedPosts(uid);
        postDAO.attachSharedPosts(allSaved, uid);
        postDAO.attachGroupNames(allSaved);

        int totalCount     = allSaved.size();
        int docsCount      = (int) allSaved.stream()
                .filter(p -> p.getContent().contains("#TaiLieu") || p.getContent().contains("tài liệu")
                          || p.getContent().contains("Drive")    || p.getContent().contains("slide")).count();
        int projectsCount  = (int) allSaved.stream()
                .filter(p -> p.getContent().contains("#DoAn") || p.getContent().contains("đồ án")
                          || p.getContent().contains("project") || p.getContent().contains("robot")
                          || p.getContent().contains("IoT")).count();
        int lifestyleCount = (int) allSaved.stream()
                .filter(p -> p.getContent().contains("cà phê") || p.getContent().contains("góc học tập")
                          || p.getContent().contains("setup")   || p.getContent().contains("thực tập")
                          || p.getContent().contains("bảo vệ")).count();

        List<Post> filteredPosts = allSaved;
        String collection = req.getParameter("collection");
        if (collection != null && !collection.isEmpty() && !"all".equalsIgnoreCase(collection)) {
            if ("documents".equalsIgnoreCase(collection)) {
                filteredPosts = allSaved.stream()
                        .filter(p -> p.getContent().contains("#TaiLieu") || p.getContent().contains("tài liệu")
                                  || p.getContent().contains("Drive")    || p.getContent().contains("slide"))
                        .collect(Collectors.toList());
            } else if ("projects".equalsIgnoreCase(collection)) {
                filteredPosts = allSaved.stream()
                        .filter(p -> p.getContent().contains("#DoAn") || p.getContent().contains("đồ án")
                                  || p.getContent().contains("project") || p.getContent().contains("robot")
                                  || p.getContent().contains("IoT"))
                        .collect(Collectors.toList());
            } else if ("lifestyle".equalsIgnoreCase(collection)) {
                filteredPosts = allSaved.stream()
                        .filter(p -> p.getContent().contains("cà phê") || p.getContent().contains("góc học tập")
                                  || p.getContent().contains("setup")   || p.getContent().contains("thực tập")
                                  || p.getContent().contains("bảo vệ"))
                        .collect(Collectors.toList());
            }
        }

        req.setAttribute("savedPosts",         filteredPosts);
        req.setAttribute("selectedCollection", (collection != null ? collection : "all"));
        req.setAttribute("totalCount",         totalCount);
        req.setAttribute("docsCount",          docsCount);
        req.setAttribute("projectsCount",      projectsCount);
        req.setAttribute("lifestyleCount",     lifestyleCount);
        req.setAttribute("currentPage",        "saved");
        req.setAttribute("pageTitle",          "Đã lưu");
        LayoutSupport.populate(req, currentUser);

        req.getRequestDispatcher("/WEB-INF/views/saved/saved.jsp").forward(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        HttpSession session = req.getSession(false);
        User currentUser = (session != null) ? (User) session.getAttribute("currentUser") : null;
        if (currentUser == null) { resp.setStatus(401); return; }

        String path = req.getServletPath();
        try {
            if ("/saved/add".equals(path)) {
                int postId = Integer.parseInt(req.getParameter("postId"));
                if (!postDAO.canView(postId, currentUser.getUserId())) { resp.setStatus(403); return; }
                savedDAO.savePost(postId, currentUser.getUserId());
                resp.getWriter().write("{\"success\":true}");
            } else if ("/saved/remove".equals(path)) {
                int postId = Integer.parseInt(req.getParameter("postId"));
                savedDAO.unsavePost(postId, currentUser.getUserId());
                resp.getWriter().write("{\"success\":true}");
            } else {
                resp.setStatus(404);
            }
        } catch (Exception e) {
            e.printStackTrace();
            resp.setStatus(500);
        }
    }
}
