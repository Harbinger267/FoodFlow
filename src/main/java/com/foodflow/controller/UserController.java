package com.foodflow.controller;

import com.foodflow.dao.UserDAO;
import com.foodflow.model.User;
import com.foodflow.service.UserService;
import com.foodflow.util.PasswordUtil;
import com.foodflow.util.GsonUtil;
import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.List;

@WebServlet("/admin/users")
public class UserController extends HttpServlet {

    private final UserDAO userDAO = new UserDAO();
    private final UserService userService = new UserService();
    private final Gson gson = GsonUtil.get();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        User currentUser = requireAdminUser(request, response);
        if (currentUser == null) {
            return;
        }

        String action = request.getParameter("action");
        if (action == null || action.isBlank() || "list".equalsIgnoreCase(action)) {
            List<User> users = userDAO.getAllUsers();
            JsonArray usersJson = new JsonArray();
            for (User user : users) {
                JsonObject entry = new JsonObject();
                entry.addProperty("userId", user.getUserId());
                entry.addProperty("username", safe(user.getUsername()));
                entry.addProperty("fullName", safe(user.getFullName()));
                entry.addProperty("email", safe(user.getEmail()));
                entry.addProperty("role", user.getRole().name());
                entry.addProperty("status", user.getStatus());
                entry.addProperty("active", user.isActive());
                entry.addProperty("createdAt", user.getCreatedAt() == null ? "" : user.getCreatedAt().toString());
                usersJson.add(entry);
            }

            JsonObject payload = new JsonObject();
            payload.add("users", usersJson);
            payload.addProperty("count", usersJson.size());
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write(gson.toJson(payload));
            return;
        }

        sendError(response, "Unsupported action", 400);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        User currentUser = requireAdminUser(request, response);
        if (currentUser == null) {
            return;
        }

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        String action = request.getParameter("action");
        if (action == null || action.isBlank()) {
            sendError(response, "Action is required", 400);
            return;
        }

        if ("add".equalsIgnoreCase(action)) {
            String username = safe(request.getParameter("username")).trim();
            String email = safe(request.getParameter("email")).trim();
            String roleValue = safe(request.getParameter("role")).trim();
            String tempPassword = safe(request.getParameter("tempPassword"));

            if (username.isBlank() || email.isBlank() || roleValue.isBlank() || tempPassword.isBlank()) {
                sendError(response, "Username, email, role, and temporary password are required", 400);
                return;
            }
            if (userDAO.usernameExists(username, null)) {
                sendError(response, "Username already exists", 409);
                return;
            }
            if (userDAO.emailExists(email, null)) {
                sendError(response, "Email already exists", 409);
                return;
            }

            User.Role parsedRole = parseRole(roleValue);
            if (parsedRole == null) {
                sendError(response, "Invalid role", 400);
                return;
            }

            User newUser = new User();
            newUser.setFullName(username);
            newUser.setUsername(username);
            newUser.setEmail(email);
            newUser.setPassword(tempPassword);
            newUser.setRole(parsedRole);
            newUser.setStatus("ACTIVE");

            boolean success = userService.addUser(newUser);
            if (!success) {
                sendError(response, "Failed to create user", 500);
                return;
            }

            userDAO.logUserActivity(
                    currentUser.getUserId(),
                    "ADMIN_ADD_USER",
                    "users",
                    "Created user " + username + " with role " + parsedRole.name(),
                    request.getRemoteAddr()
            );
            sendSuccess(response, "User created with temporary credentials");
            return;
        }

        if ("update".equalsIgnoreCase(action)) {
            int id = parseInt(request.getParameter("userId"));
            if (id <= 0) {
                sendError(response, "Valid userId is required", 400);
                return;
            }

            User userToUpdate = userDAO.getUserById(id);
            if (userToUpdate == null) {
                sendError(response, "User not found", 404);
                return;
            }

            String username = safe(request.getParameter("username")).trim();
            String email = safe(request.getParameter("email")).trim();
            String roleValue = safe(request.getParameter("role")).trim();
            String status = safe(request.getParameter("status")).trim().toUpperCase();

            if (username.isBlank() || email.isBlank() || roleValue.isBlank()) {
                sendError(response, "Username, email, and role are required", 400);
                return;
            }

            if (userDAO.usernameExists(username, id)) {
                sendError(response, "Username already exists", 409);
                return;
            }
            if (userDAO.emailExists(email, id)) {
                sendError(response, "Email already exists", 409);
                return;
            }

            User.Role parsedRole = parseRole(roleValue);
            if (parsedRole == null) {
                sendError(response, "Invalid role", 400);
                return;
            }

            if ("INACTIVE".equals(status) && userToUpdate.getUserId() == currentUser.getUserId()) {
                sendError(response, "You cannot deactivate your own account", 400);
                return;
            }

            userToUpdate.setFullName(username);
            userToUpdate.setUsername(username);
            userToUpdate.setEmail(email);
            userToUpdate.setRole(parsedRole);
            userToUpdate.setStatus("INACTIVE".equals(status) ? "INACTIVE" : "ACTIVE");
            userToUpdate.setPassword("");

            boolean success = userDAO.updateUser(userToUpdate);
            if (!success) {
                sendError(response, "Failed to update user", 500);
                return;
            }

            userDAO.logUserActivity(
                    currentUser.getUserId(),
                    "ADMIN_UPDATE_USER",
                    "users",
                    "Updated user " + username + " to role " + parsedRole.name(),
                    request.getRemoteAddr()
            );
            sendSuccess(response, "User updated successfully");
            return;
        }

        if ("resetPassword".equalsIgnoreCase(action)) {
            int id = parseInt(request.getParameter("userId"));
            String tempPassword = safe(request.getParameter("tempPassword"));

            if (id <= 0 || tempPassword.isBlank()) {
                sendError(response, "Valid userId and temporary password are required", 400);
                return;
            }

            User targetUser = userDAO.getUserById(id);
            if (targetUser == null) {
                sendError(response, "User not found", 404);
                return;
            }

            targetUser.setPassword(PasswordUtil.hashPassword(tempPassword));
            boolean success = userDAO.updateUser(targetUser);
            if (!success) {
                sendError(response, "Failed to reset password", 500);
                return;
            }

            userDAO.logUserActivity(
                    currentUser.getUserId(),
                    "ADMIN_RESET_PASSWORD",
                    "users",
                    "Reset credentials for user " + targetUser.getUsername(),
                    request.getRemoteAddr()
            );
            sendSuccess(response, "Temporary password reset successfully");
            return;
        }

        if ("delete".equalsIgnoreCase(action)) {
            int id = parseInt(request.getParameter("userId"));
            if (id <= 0) {
                sendError(response, "Valid userId is required", 400);
                return;
            }
            if (id == currentUser.getUserId()) {
                sendError(response, "You cannot delete your own account", 400);
                return;
            }

            User targetUser = userDAO.getUserById(id);
            if (targetUser == null) {
                sendError(response, "User not found", 404);
                return;
            }

            boolean success = userDAO.deleteUser(id);
            if (!success) {
                sendError(response, "Failed to delete user", 500);
                return;
            }

            userDAO.logUserActivity(
                    currentUser.getUserId(),
                    "ADMIN_DELETE_USER",
                    "users",
                    "Deleted user " + targetUser.getUsername(),
                    request.getRemoteAddr()
            );
            sendSuccess(response, "User deleted successfully");
            return;
        }

        sendError(response, "Unsupported action", 400);
    }

    private User requireAdminUser(HttpServletRequest request, HttpServletResponse response) throws IOException {
        HttpSession session = request.getSession(false);
        if (session == null || !(session.getAttribute("user") instanceof User)) {
            sendError(response, "Authentication required", 401);
            return null;
        }

        User currentUser = (User) session.getAttribute("user");
        if (currentUser.getRole() != User.Role.ADMIN) {
            sendError(response, "Access denied", 403);
            return null;
        }
        return currentUser;
    }

    private void sendSuccess(HttpServletResponse response, String message) throws IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        JsonObject payload = new JsonObject();
        payload.addProperty("success", true);
        payload.addProperty("message", message);
        response.getWriter().write(gson.toJson(payload));
    }

    private void sendError(HttpServletResponse response, String message, int statusCode) throws IOException {
        response.setStatus(statusCode);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        JsonObject payload = new JsonObject();
        payload.addProperty("success", false);
        payload.addProperty("error", message);
        response.getWriter().write(gson.toJson(payload));
    }

    private int parseInt(String value) {
        if (value == null || value.isBlank()) {
            return 0;
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException ex) {
            return 0;
        }
    }

    private User.Role parseRole(String roleValue) {
        if (roleValue == null || roleValue.isBlank()) {
            return null;
        }
        String normalized = roleValue.trim().toUpperCase();
        if ("STORE_KEEPER".equals(normalized)) {
            normalized = "STOREKEEPER";
        }
        try {
            return User.Role.valueOf(normalized);
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }
}
