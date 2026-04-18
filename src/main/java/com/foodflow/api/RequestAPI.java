package com.foodflow.api;

import com.foodflow.config.SecurityConfig;
import com.foodflow.dao.StoreRequestDAO;
import com.foodflow.model.StoreRequest;
import com.foodflow.model.User;
import com.foodflow.util.GsonUtil;
import com.google.gson.Gson;
import com.google.gson.JsonObject;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.List;

@WebServlet("/api/requests")
public class RequestAPI extends HttpServlet {
    private final StoreRequestDAO storeRequestDAO = new StoreRequestDAO();
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

        String action = request.getParameter("action");
        try {
            if ("pending".equals(action)) {
                if (!SecurityConfig.canApproveRequests(currentUser)) {
                    sendError(response, "Access denied: only Department Head can review requests", 403);
                    return;
                }
                List<StoreRequest> pending = storeRequestDAO.getPendingRequests();
                response.getWriter().write(gson.toJson(pending));
                return;
            }

            if ("mine".equals(action)) {
                if (!SecurityConfig.canCreateRequests(currentUser)) {
                    sendError(response, "Access denied: only Store Keeper can create requests", 403);
                    return;
                }
                List<StoreRequest> mine = storeRequestDAO.getRequestsForRequester(currentUser.getUserId());
                response.getWriter().write(gson.toJson(mine));
                return;
            }

            if (SecurityConfig.canApproveRequests(currentUser)) {
                response.getWriter().write(gson.toJson(storeRequestDAO.getAllRequests()));
            } else if (SecurityConfig.canCreateRequests(currentUser)) {
                response.getWriter().write(gson.toJson(storeRequestDAO.getRequestsForRequester(currentUser.getUserId())));
            } else {
                sendError(response, "Access denied", 403);
            }
        } catch (Exception e) {
            sendError(response, "Error retrieving requests: " + e.getMessage(), 500);
        }
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

        String action = request.getParameter("action");
        try {
            if ("create".equals(action)) {
                if (!SecurityConfig.canCreateRequests(currentUser)) {
                    sendError(response, "Access denied: only Store Keeper can create requests", 403);
                    return;
                }

                int itemId = Integer.parseInt(request.getParameter("itemId"));
                double quantity = Double.parseDouble(request.getParameter("quantity"));
                String notes = request.getParameter("notes");

                StoreRequest req = new StoreRequest();
                req.setRequesterId(currentUser.getUserId());
                req.setItemId(itemId);
                req.setQuantityRequested(quantity);
                req.setNotes(notes);

                boolean success = storeRequestDAO.createRequest(req);
                JsonObject payload = new JsonObject();
                payload.addProperty("success", success);
                payload.addProperty("message", success ? "Store request submitted" : "Failed to submit store request");
                response.getWriter().write(gson.toJson(payload));
                return;
            }

            if ("approve".equals(action) || "reject".equals(action)) {
                if (!SecurityConfig.canApproveRequests(currentUser)) {
                    sendError(response, "Access denied: only Department Head can approve/reject requests", 403);
                    return;
                }

                int requestId = Integer.parseInt(request.getParameter("requestId"));
                String status = "approve".equals(action) ? "APPROVED" : "REJECTED";
                String rejectionNote = request.getParameter("rejectionNote");
                boolean success = storeRequestDAO.updateRequestStatus(requestId, currentUser.getUserId(), status, rejectionNote);

                JsonObject payload = new JsonObject();
                payload.addProperty("success", success);
                payload.addProperty("message",
                        success
                                ? "Request " + status.toLowerCase()
                                : "Request could not be updated. It may already be processed or invalid.");
                response.getWriter().write(gson.toJson(payload));
                return;
            }

            sendError(response, "Invalid action", 400);
        } catch (NumberFormatException e) {
            sendError(response, "Invalid numeric input: " + e.getMessage(), 400);
        } catch (Exception e) {
            sendError(response, "Error processing request: " + e.getMessage(), 500);
        }
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
}
