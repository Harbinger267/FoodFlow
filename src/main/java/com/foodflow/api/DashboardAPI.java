package com.foodflow.api;

import com.foodflow.dao.DamageDAO;
import com.foodflow.dao.ItemDAO;
import com.foodflow.dao.StoreRequestDAO;
import com.foodflow.model.Item;
import com.foodflow.util.GsonUtil;
import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@WebServlet("/api/dashboard")
public class DashboardAPI extends HttpServlet {
    private final ItemDAO itemDAO = new ItemDAO();
    private final DamageDAO damageDAO = new DamageDAO();
    private final StoreRequestDAO storeRequestDAO = new StoreRequestDAO();
    private final Gson gson = GsonUtil.get();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        System.out.println("DashboardAPI.doGet called - Action: " + request.getParameter("action"));
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String action = request.getParameter("action");
            System.out.println("Processing dashboard action: " + action);
            
            if ("stats".equals(action)) {
                System.out.println("Getting dashboard stats...");
                // Get dashboard statistics
                JsonObject stats = getDashboardStats();
                System.out.println("Stats retrieved: " + stats.toString());
                response.getWriter().write(gson.toJson(stats));
                
            } else if ("lowStock".equals(action)) {
                // Get low stock items
                List<Item> allItems = itemDAO.getAllItems();
                JsonArray lowStockItems = new JsonArray();
                
                for (Item item : allItems) {
                    if (item.isLowStock()) {
                        JsonObject itemJson = new JsonObject();
                        itemJson.addProperty("id", item.getItemId());
                        itemJson.addProperty("name", item.getName());
                        itemJson.addProperty("currentStock", item.getCurrentStock());
                        itemJson.addProperty("status", item.getStatus());
                        lowStockItems.add(itemJson);
                    }
                }
                
                JsonObject responseObj = new JsonObject();
                responseObj.add("items", lowStockItems);
                responseObj.addProperty("count", lowStockItems.size());
                response.getWriter().write(gson.toJson(responseObj));
                
            } else if ("recentActivity".equals(action)) {
                // Get recent activity (damages and requests)
                JsonObject activity = getRecentActivity();
                response.getWriter().write(gson.toJson(activity));
                
            } else if ("charts".equals(action)) {
                // Get chart data
                JsonObject chartData = getChartData();
                response.getWriter().write(gson.toJson(chartData));
                
            } else {
                // Default: return all dashboard data
                JsonObject dashboardData = new JsonObject();
                dashboardData.add("stats", getDashboardStats());
                dashboardData.add("lowStock", getLowStockData());
                dashboardData.add("recentActivity", getRecentActivity());
                dashboardData.add("charts", getChartData());
                response.getWriter().write(gson.toJson(dashboardData));
            }
            
        } catch (Exception e) {
            sendError(response, "Error retrieving dashboard data: " + e.getMessage(), 500);
        }
    }

    private JsonObject getDashboardStats() throws IOException {
        JsonObject stats = new JsonObject();
        
        List<Item> allItems = itemDAO.getAllItems();
        int totalItems = allItems.size();
        int inStock = 0;
        int lowStock = 0;
        int outOfStock = 0;
        
        for (Item item : allItems) {
            if (item.getCurrentStock() > 0) {
                inStock++;
            } else {
                outOfStock++;
            }
            
            if (item.isLowStock()) {
                lowStock++;
            }
        }
        
        List<com.foodflow.model.Damage> damages = damageDAO.getAllDamage();
        int damagedCount = damages.size();
        
        int pendingRequests = storeRequestDAO.countPendingRequests();
        
        stats.addProperty("totalItems", totalItems);
        stats.addProperty("inStock", inStock);
        stats.addProperty("lowStock", lowStock);
        stats.addProperty("outOfStock", outOfStock);
        stats.addProperty("damagedCount", damagedCount);
        stats.addProperty("pendingRequests", pendingRequests);
        
        return stats;
    }

    private JsonArray getLowStockData() {
        JsonArray lowStockItems = new JsonArray();
        try {
            List<Item> allItems = itemDAO.getAllItems();
            for (Item item : allItems) {
                if (item.isLowStock()) {
                    JsonObject itemJson = new JsonObject();
                    itemJson.addProperty("id", item.getItemId());
                    itemJson.addProperty("name", item.getName());
                    itemJson.addProperty("currentStock", item.getCurrentStock());
                    itemJson.addProperty("status", item.getStatus());
                    lowStockItems.add(itemJson);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return lowStockItems;
    }

    private JsonObject getRecentActivity() {
        JsonObject activity = new JsonObject();
        JsonArray activities = new JsonArray();
        
        try {
            // Get recent damages
            List<com.foodflow.model.Damage> damages = damageDAO.getAllDamage();
            int count = 0;
            for (com.foodflow.model.Damage damage : damages) {
                if (count >= 5) break; // Limit to 5 recent activities
                
                JsonObject act = new JsonObject();
                act.addProperty("type", "damage");
                act.addProperty("description", "Damage reported: " + damage.getDamageType());
                act.addProperty("quantity", damage.getQuantity());
                act.addProperty("date", damage.getReportDate() != null ? damage.getReportDate().toString() : "Unknown");
                activities.add(act);
                count++;
            }
            
            // TODO: Add recent store requests when available
            
            activity.add("items", activities);
            activity.addProperty("count", activities.size());
            
        } catch (Exception e) {
            e.printStackTrace();
            activity.add("items", new JsonArray());
            activity.addProperty("count", 0);
        }
        
        return activity;
    }

    private JsonObject getChartData() {
        JsonObject chartData = new JsonObject();
        
        try {
            // Stock trend data (last 7 days - mock data for now)
            JsonArray stockTrend = new JsonArray();
            stockTrend.add(120);
            stockTrend.add(132);
            stockTrend.add(101);
            stockTrend.add(134);
            stockTrend.add(90);
            stockTrend.add(130);
            stockTrend.add(145);
            chartData.add("stockTrend", stockTrend);
            
            // Category distribution
            JsonObject categoryDist = new JsonObject();
            List<Item> allItems = itemDAO.getAllItems();
            Map<String, Integer> categories = new HashMap<>();
            
            for (Item item : allItems) {
                String cat = item.getCategory() != null ? item.getCategory() : "Other";
                categories.put(cat, categories.getOrDefault(cat, 0) + 1);
            }
            
            for (Map.Entry<String, Integer> entry : categories.entrySet()) {
                categoryDist.addProperty(entry.getKey(), entry.getValue());
            }
            chartData.add("categoryDistribution", categoryDist);
            
            // Damage by type
            JsonObject damageByType = new JsonObject();
            List<com.foodflow.model.Damage> damages = damageDAO.getAllDamage();
            Map<String, Integer> damageTypes = new HashMap<>();
            
            for (com.foodflow.model.Damage damage : damages) {
                String type = damage.getDamageType() != null ? damage.getDamageType() : "Other";
                int qty = (int) Math.round(damage.getQuantity()); // Convert double to int
                damageTypes.put(type, damageTypes.getOrDefault(type, 0) + qty);
            }
            
            for (Map.Entry<String, Integer> entry : damageTypes.entrySet()) {
                damageByType.addProperty(entry.getKey(), entry.getValue());
            }
            chartData.add("damageByType", damageByType);
            
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        return chartData;
    }

    private void sendError(HttpServletResponse response, String message, int statusCode) throws IOException {
        response.setStatus(statusCode);
        JsonObject error = new JsonObject();
        error.addProperty("error", message);
        response.getWriter().write(gson.toJson(error));
    }
}
