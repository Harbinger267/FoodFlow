package com.foodflow.api;

import com.foodflow.config.SecurityConfig;
import com.foodflow.dao.ItemDAO;
import com.foodflow.dao.UsageDAO;
import com.foodflow.model.Item;
import com.foodflow.model.User;
import com.foodflow.model.Usage;
import com.foodflow.service.UsageService;
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

@WebServlet("/api/usage")
public class UsageAPI extends HttpServlet {
    private final UsageDAO usageDAO = new UsageDAO();
    private final ItemDAO itemDAO = new ItemDAO();
    private final UsageService usageService = new UsageService();
    private final Gson gson = GsonUtil.get();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        User currentUser = requireAuthenticatedUser(request, response);
        if (currentUser == null) {
            return;
        }

        String action = request.getParameter("action");
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            if ("getAll".equals(action)) {
                List<Usage> usages = usageDAO.getAllUsage();
                response.getWriter().write(gson.toJson(usages));
            } else if ("getByItemId".equals(action)) {
                List<Usage> usages = usageDAO.getAllUsage();
                int itemId = Integer.parseInt(request.getParameter("itemId"));
                java.util.stream.Stream<Usage> filtered = usages.stream()
                    .filter(u -> u.getItemId() == itemId);
                response.getWriter().write(gson.toJson(filtered.toList()));
            } else if ("getItems".equals(action)) {
                List<Item> items = itemDAO.getAllItems();
                response.getWriter().write(gson.toJson(items));
            } else {
                List<Usage> usages = usageDAO.getAllUsage();
                response.getWriter().write(gson.toJson(usages));
            }
        } catch (Exception e) {
            sendError(response, "Error retrieving usage records: " + e.getMessage(), 500);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        User currentUser = requireAuthenticatedUser(request, response);
        if (currentUser == null) {
            return;
        }

        if (!SecurityConfig.canRecordOperationalData(currentUser)) {
            sendError(response, "Access denied: only Store Keeper can record issued items", 403);
            return;
        }

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String action = request.getParameter("action");
            
            if ("add".equals(action)) {
                int itemId = Integer.parseInt(request.getParameter("itemId"));
                int quantity = Integer.parseInt(request.getParameter("quantity"));
                String staffName = request.getParameter("staffName");
                String department = request.getParameter("department");
                
                Item item = itemDAO.getItemById(itemId);
                if (item == null) {
                    sendError(response, "Item not found", 404);
                    return;
                }
                
                if (item.getCurrentStock() < quantity) {
                    sendError(response, "Insufficient stock available", 400);
                    return;
                }
                
                boolean success = usageService.recordUsage(
                        itemId,
                        quantity,
                        currentUser.getUserId(),
                        staffName,
                        department != null ? department : "Internal Department"
                );
                
                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", success);
                jsonResponse.addProperty("message", success ? 
                    "Usage recorded successfully" : "Failed to record usage");
                response.getWriter().write(gson.toJson(jsonResponse));
                
            } else if ("recordReturn".equals(action)) {
                int usageId = Integer.parseInt(request.getParameter("usageId"));
                double quantity = Double.parseDouble(request.getParameter("quantity"));

                boolean success = usageDAO.recordReturn(usageId, quantity);
                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", success);
                jsonResponse.addProperty("message", success
                        ? "Return recorded successfully"
                        : "Failed to record return (check outstanding quantity)");
                response.getWriter().write(gson.toJson(jsonResponse));

            } else if ("updateStatus".equals(action)) {
                int usageId = Integer.parseInt(request.getParameter("usageId"));
                String status = request.getParameter("status");
                String normalized = status == null ? "" : status.trim().toUpperCase();

                boolean success;
                String message;
                if ("LOST".equals(normalized)) {
                    success = usageDAO.markBorrowAsLost(usageId);
                    message = success ? "Borrow record marked as lost" : "Unable to mark record as lost";
                } else if ("RETURNED".equals(normalized)) {
                    String quantityParam = request.getParameter("quantity");
                    if (quantityParam != null && !quantityParam.isBlank()) {
                        success = usageDAO.recordReturn(usageId, Double.parseDouble(quantityParam));
                    } else {
                        success = usageDAO.completeReturn(usageId);
                    }
                    message = success ? "Return recorded successfully" : "Unable to complete return";
                } else {
                    success = false;
                    message = "Unsupported status update";
                }

                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", success);
                jsonResponse.addProperty("message", message);
                response.getWriter().write(gson.toJson(jsonResponse));
            }
            
        } catch (NumberFormatException e) {
            sendError(response, "Invalid number format: " + e.getMessage(), 400);
        } catch (Exception e) {
            sendError(response, "Error processing request: " + e.getMessage(), 500);
        }
    }

    private void sendError(HttpServletResponse response, String message, int statusCode) throws IOException {
        response.setStatus(statusCode);
        JsonObject error = new JsonObject();
        error.addProperty("error", message);
        response.getWriter().write(gson.toJson(error));
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
}
