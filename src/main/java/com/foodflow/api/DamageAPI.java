package com.foodflow.api;

import com.foodflow.config.SecurityConfig;
import com.foodflow.dao.DamageDAO;
import com.foodflow.dao.ItemDAO;
import com.foodflow.model.Damage;
import com.foodflow.model.Item;
import com.foodflow.model.User;
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

@WebServlet("/api/damage")
public class DamageAPI extends HttpServlet {
    private final DamageDAO damageDAO = new DamageDAO();
    private final ItemDAO itemDAO = new ItemDAO();
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
                List<Damage> damages = damageDAO.getAllDamage();
                response.getWriter().write(gson.toJson(damages));
            } else if ("getByItemId".equals(action)) {
                List<Damage> damages = damageDAO.getAllDamage();
                int itemId = Integer.parseInt(request.getParameter("itemId"));
                java.util.stream.Stream<Damage> filtered = damages.stream()
                    .filter(d -> d.getItemId() == itemId);
                response.getWriter().write(gson.toJson(filtered.toList()));
            } else if ("getTypes".equals(action)) {
                JsonArray types = new JsonArray();
                types.add("Broken");
                types.add("Expired");
                types.add("Water Damaged");
                types.add("Other");
                response.getWriter().write(gson.toJson(types));
            } else if ("getDispositions".equals(action)) {
                JsonArray dispositions = new JsonArray();
                dispositions.add("DISPOSED");
                dispositions.add("REPLACED");
                dispositions.add("UNDER_REPAIR");
                dispositions.add("REPAIRED");
                response.getWriter().write(gson.toJson(dispositions));
            } else {
                List<Damage> damages = damageDAO.getAllDamage();
                response.getWriter().write(gson.toJson(damages));
            }
        } catch (Exception e) {
            sendError(response, "Error retrieving damage records: " + e.getMessage(), 500);
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
            sendError(response, "Access denied: only Store Keeper can record damages", 403);
            return;
        }

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String action = request.getParameter("action");
            
            if ("add".equals(action)) {
                int itemId = Integer.parseInt(request.getParameter("itemId"));
                int quantity = Integer.parseInt(request.getParameter("quantity"));
                String damageType = request.getParameter("damageType");
                String reportedByName = request.getParameter("reportedBy");
                String disposition = request.getParameter("disposition");
                
                Item item = itemDAO.getItemById(itemId);
                if (item == null) {
                    sendError(response, "Item not found", 404);
                    return;
                }
                
                boolean success = damageDAO.recordDamage(itemId, quantity, 
                    damageType != null ? damageType : "Other",
                    currentUser.getUserId(),
                    reportedByName,
                    disposition);
                
                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", success);
                jsonResponse.addProperty("message", success ? 
                    "Damage recorded successfully" : "Failed to record damage");
                response.getWriter().write(gson.toJson(jsonResponse));
                
            } else if ("updateStatus".equals(action)) {
                int damageId = Integer.parseInt(request.getParameter("damageId"));
                String disposition = request.getParameter("status");
                boolean success = damageDAO.updateDisposition(damageId, disposition);
                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", success);
                jsonResponse.addProperty("message", success
                        ? "Disposition updated"
                        : "Failed to update disposition");
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
