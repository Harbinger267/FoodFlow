
package com.catering.servlet;
import java.io.IOException;
import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.WebServlet;


public class LoginServlet extends HttpServlet {
 
   protected void doPost(HttpServletRequest request, HttpServletResponse response)
        throws ServletException, IOException {

    String role = request.getParameter("role");

    if (role == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    role = role.toLowerCase();

    switch(role) {

        case "admin":
            response.sendRedirect("admin.jsp");
            break;

        case "manager":
            response.sendRedirect("manager.jsp");
            break;

        case "store":
            response.sendRedirect("store.jsp");
            break;

        default:
            response.sendRedirect("login.jsp");
    }
   }
}