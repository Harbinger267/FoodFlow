package com.foodflow.api;

import com.foodflow.dao.ItemDAO;
import com.foodflow.model.Item;
import com.foodflow.util.GsonUtil;
import com.google.gson.Gson;
import com.google.gson.JsonObject;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

@WebServlet("/api/items")
public class ItemAPI extends HttpServlet {
    private final ItemDAO itemDAO = new ItemDAO();
    private final Gson gson = GsonUtil.get();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        String action = request.getParameter("action");
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            if ("getAll".equals(action)) {
                List<Item> items = itemDAO.getAllItems();
                response.getWriter().write(gson.toJson(items));
            } else if ("getById".equals(action)) {
                int itemId = Integer.parseInt(request.getParameter("itemId"));
                Item item = itemDAO.getItemById(itemId);
                if (item != null) {
                    response.getWriter().write(gson.toJson(item));
                } else {
                    sendError(response, "Item not found", 404);
                }
            } else if ("search".equals(action)) {
                String query = request.getParameter("q");
                List<Item> items = itemDAO.searchItems(query);
                response.getWriter().write(gson.toJson(items));
            } else {
                List<Item> items = itemDAO.getAllItems();
                response.getWriter().write(gson.toJson(items));
            }
        } catch (Exception e) {
            sendError(response, "Database error: " + e.getMessage(), 500);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String action = request.getParameter("action");
            
            if ("add".equals(action)) {
                String itemName = request.getParameter("itemName");
                String category = request.getParameter("category");
                String itemType = request.getParameter("itemType");
                String unit = request.getParameter("unit");
                String description = request.getParameter("description");
                String quantityStr = request.getParameter("quantity");
                String minLevelStr = request.getParameter("minStockLevel");
                
                if (itemName == null || itemName.trim().isEmpty()) {
                    sendError(response, "Item name is required", 400);
                    return;
                }
                if (category == null || category.trim().isEmpty()) {
                    sendError(response, "Category is required", 400);
                    return;
                }
                if (quantityStr == null) {
                    sendError(response, "Quantity is required", 400);
                    return;
                }
                
                Item item = new Item();
                item.setName(itemName.trim());
                item.setCategory(category.trim());
                item.setItemType(itemType != null && !itemType.isEmpty() ? itemType : "FOOD");
                item.setUnitOfMeasure(unit != null && !unit.isEmpty() ? unit : "Pieces");
                item.setDescription(description != null ? description : "");
                
                double qty = parseDouble(quantityStr);
                item.setCurrentStock(qty);
                
                double minLevel = parseDouble(minLevelStr != null ? minLevelStr : "10");
                item.setStatus(qty <= minLevel ? "LOW_STOCK" : "AVAILABLE");
                
                boolean success = itemDAO.addItem(item);
                
                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", success);
                jsonResponse.addProperty("message", success ? 
                    "Item added successfully" : "Failed to add item. Check database.");
                response.getWriter().write(gson.toJson(jsonResponse));
                
            } else if ("update".equals(action)) {
                int itemId = Integer.parseInt(request.getParameter("itemId"));
                double stock = parseDouble(request.getParameter("stock"));
                String status = request.getParameter("status");
                
                boolean success = itemDAO.updateItemStatus(itemId, stock, status);
                
                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", success);
                jsonResponse.addProperty("message", success ? "Item updated" : "Update failed");
                response.getWriter().write(gson.toJson(jsonResponse));
                
            } else if ("delete".equals(action)) {
                JsonObject jsonResponse = new JsonObject();
                jsonResponse.addProperty("success", false);
                jsonResponse.addProperty("message", "Delete not implemented");
                response.getWriter().write(gson.toJson(jsonResponse));
            }
            
        } catch (Exception e) {
            sendError(response, "Error processing request: " + e.getMessage(), 500);
        }
    }

    private double parseDouble(String value) {
        if (value == null || value.isBlank()) return 0;
        try {
            return Double.parseDouble(value);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private void sendError(HttpServletResponse response, String message, int statusCode) throws IOException {
        response.setStatus(statusCode);
        JsonObject error = new JsonObject();
        error.addProperty("error", message);
        response.getWriter().write(gson.toJson(error));
    }
}