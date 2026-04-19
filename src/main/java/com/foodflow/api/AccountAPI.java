package com.foodflow.api;

import com.foodflow.dao.UserDAO;
import com.foodflow.model.User;
import com.foodflow.model.UserSessionBean;
import com.foodflow.util.GsonUtil;
import com.foodflow.util.PasswordUtil;
import com.google.gson.Gson;
import com.google.gson.JsonObject;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

@WebServlet("/api/account")
public class AccountAPI extends HttpServlet {
    private final UserDAO userDAO = new UserDAO();
    private final Gson gson = GsonUtil.get();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = requireAuthenticatedUser(request, response);
        if (currentUser == null) {
            return;
        }

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        JsonObject payload = new JsonObject();
        payload.addProperty("userId", currentUser.getUserId());
        payload.addProperty("userName", safe(currentUser.getUsername()));
        payload.addProperty("email", safe(currentUser.getEmail()));
        payload.addProperty("role", currentUser.getRole() == null ? "" : currentUser.getRole().name());
        response.getWriter().write(gson.toJson(payload));
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        User currentUser = requireAuthenticatedUser(request, response);
        if (currentUser == null) {
            return;
        }

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        String action = safe(request.getParameter("action")).trim();
        if (action.isBlank() || "updateCredentials".equalsIgnoreCase(action)) {
            updateCredentials(request, response, currentUser);
            return;
        }

        sendError(response, "Unsupported action", 400);
    }

    private void updateCredentials(HttpServletRequest request, HttpServletResponse response, User currentUser)
            throws IOException {
        String requestedUsername = safe(request.getParameter("username")).trim();
        String currentPassword = safe(request.getParameter("currentPassword"));
        String newPassword = safe(request.getParameter("newPassword")).trim();

        if (currentPassword.isBlank()) {
            sendError(response, "Current password is required", 400);
            return;
        }

        User persistedUser = userDAO.getUserById(currentUser.getUserId());
        if (persistedUser == null) {
            sendError(response, "User account no longer exists", 404);
            return;
        }

        if (!PasswordUtil.verifyPassword(currentPassword, persistedUser.getPassword())) {
            sendError(response, "Current password is incorrect", 403);
            return;
        }

        String existingUsername = safe(persistedUser.getUsername()).trim();
        String nextUsername = requestedUsername.isBlank() ? existingUsername : requestedUsername;
        boolean usernameChanged = !nextUsername.equalsIgnoreCase(existingUsername);
        boolean passwordChangeRequested = !newPassword.isBlank();

        if (usernameChanged && userDAO.usernameExists(nextUsername, currentUser.getUserId())) {
            sendError(response, "Username already exists", 409);
            return;
        }

        if (passwordChangeRequested && newPassword.length() < 6) {
            sendError(response, "New password must be at least 6 characters", 400);
            return;
        }

        if (!usernameChanged && !passwordChangeRequested) {
            sendError(response, "No account changes were submitted", 400);
            return;
        }

        String nextPasswordHash = passwordChangeRequested ? PasswordUtil.hashPassword(newPassword) : "";
        boolean updated = userDAO.updateOwnCredentials(currentUser.getUserId(), nextUsername, nextPasswordHash);
        if (!updated) {
            sendError(response, "Could not update account settings", 500);
            return;
        }

        User refreshedUser = userDAO.getUserById(currentUser.getUserId());
        if (refreshedUser != null) {
            HttpSession session = request.getSession(false);
            if (session != null) {
                session.setAttribute("user", refreshedUser);
                Object sessionBeanAttr = session.getAttribute("userSession");
                if (sessionBeanAttr instanceof UserSessionBean) {
                    ((UserSessionBean) sessionBeanAttr).setFullName(refreshedUser.getFullName());
                }
            }
        }

        userDAO.logUserActivity(
                currentUser.getUserId(),
                "ACCOUNT_UPDATE",
                "account",
                "Updated account credentials",
                request.getRemoteAddr()
        );

        JsonObject payload = new JsonObject();
        payload.addProperty("success", true);
        payload.addProperty("message", "Account settings updated successfully");
        payload.addProperty("userName", refreshedUser == null ? nextUsername : safe(refreshedUser.getUsername()));
        response.getWriter().write(gson.toJson(payload));
    }

    private User requireAuthenticatedUser(HttpServletRequest request, HttpServletResponse response) throws IOException {
        HttpSession session = request.getSession(false);
        if (session == null) {
            sendError(response, "Authentication required", 401);
            return null;
        }
        Object userAttr = session.getAttribute("user");
        if (!(userAttr instanceof User)) {
            sendError(response, "Authentication required", 401);
            return null;
        }
        return (User) userAttr;
    }

    private void sendError(HttpServletResponse response, String message, int statusCode) throws IOException {
        response.setStatus(statusCode);
        JsonObject error = new JsonObject();
        error.addProperty("error", message);
        response.getWriter().write(gson.toJson(error));
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }
}
