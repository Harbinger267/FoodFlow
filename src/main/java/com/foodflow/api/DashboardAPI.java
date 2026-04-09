package com.foodflow.api;

import com.foodflow.config.SecurityConfig;
import com.foodflow.dao.DamageDAO;
import com.foodflow.dao.ItemDAO;
import com.foodflow.dao.StoreRequestDAO;
import com.foodflow.dao.SystemDAO;
import com.foodflow.dao.UsageDAO;
import com.foodflow.model.Damage;
import com.foodflow.model.Item;
import com.foodflow.model.StoreRequest;
import com.foodflow.model.SystemLog;
import com.foodflow.model.Usage;
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
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@WebServlet("/api/dashboard")
public class DashboardAPI extends HttpServlet {
    private final ItemDAO itemDAO = new ItemDAO();
    private final DamageDAO damageDAO = new DamageDAO();
    private final UsageDAO usageDAO = new UsageDAO();
    private final SystemDAO systemDAO = new SystemDAO();
    private final StoreRequestDAO storeRequestDAO = new StoreRequestDAO();
    private final Gson gson = GsonUtil.get();
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        User currentUser = requireAuthenticatedUser(request, response);
        if (currentUser == null) {
            return;
        }

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        try {
            String action = request.getParameter("action");
            
            if ("stats".equals(action)) {
                JsonObject stats = getDashboardStats(currentUser);
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
                JsonObject activity = getRecentActivity(currentUser);
                response.getWriter().write(gson.toJson(activity));
                
            } else if ("charts".equals(action)) {
                JsonObject chartData = getChartData();
                response.getWriter().write(gson.toJson(chartData));
                
            } else {
                JsonObject dashboardData = new JsonObject();
                dashboardData.add("stats", getDashboardStats(currentUser));
                dashboardData.add("lowStock", getLowStockData());
                dashboardData.add("recentActivity", getRecentActivity(currentUser));
                dashboardData.add("charts", getChartData());
                response.getWriter().write(gson.toJson(dashboardData));
            }
            
        } catch (Exception e) {
            sendError(response, "Error retrieving dashboard data: " + e.getMessage(), 500);
        }
    }

    private JsonObject getDashboardStats(User user) throws IOException {
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
        
        int pendingRequests = SecurityConfig.canCreateRequests(user)
                ? storeRequestDAO.countPendingRequestsForRequester(user.getUserId())
                : storeRequestDAO.countPendingRequests();
        int systemLogCount = systemDAO.getRecentLogs().size();
        
        stats.addProperty("totalItems", totalItems);
        stats.addProperty("inStock", inStock);
        stats.addProperty("lowStock", lowStock);
        stats.addProperty("outOfStock", outOfStock);
        stats.addProperty("damagedCount", damagedCount);
        stats.addProperty("pendingRequests", pendingRequests);
        stats.addProperty("systemLogCount", systemLogCount);
        stats.addProperty("role", user.getRole().name());
        
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

    private JsonObject getRecentActivity(User user) {
        JsonObject activity = new JsonObject();
        JsonArray activities = new JsonArray();
        
        try {
            appendRoleBlueprintActivities(activities, user);

            if (SecurityConfig.isAdmin(user)) {
                List<SystemLog> logs = systemDAO.getRecentLogs();
                int count = 0;
                for (SystemLog log : logs) {
                    if (count >= 5) break;
                    addActivity(
                            activities,
                            "system",
                            log.getAction(),
                            0,
                            log.getTimestamp() == null ? nowIso() : log.getTimestamp().format(DATE_FORMATTER)
                    );
                    count++;
                }
            } else if (SecurityConfig.isDepartmentHead(user)) {
                List<StoreRequest> pending = storeRequestDAO.getPendingRequests();
                int count = 0;
                for (StoreRequest req : pending) {
                    if (count >= 5) break;
                    addActivity(
                            activities,
                            "request",
                            "Pending request from " + safe(req.getRequesterName()) + " for " + safe(req.getItemName()),
                            req.getQuantityRequested(),
                            req.getRequestDate() == null ? nowIso() : req.getRequestDate().format(DATE_FORMATTER)
                    );
                    count++;
                }
            } else {
                int count = 0;
                List<Damage> damages = damageDAO.getAllDamage();
                for (Damage damage : damages) {
                    if (count >= 3) break;
                    if (damage.getReportedByUserId() != null && damage.getReportedByUserId() == user.getUserId()) {
                        addActivity(
                                activities,
                                "damage",
                                "Damage logged for " + safe(damage.getItemName()),
                                damage.getQuantity(),
                                damage.getDateString() == null ? nowIso() : damage.getDateString()
                        );
                        count++;
                    }
                }

                count = 0;
                List<Usage> usages = usageDAO.getAllUsage();
                for (Usage usage : usages) {
                    if (count >= 3) break;
                    if (usage.getRecordedBy() != null && usage.getRecordedBy() == user.getUserId()) {
                        addActivity(
                                activities,
                                "usage",
                                "Issued/Borrowed " + safe(usage.getItemName()) + " to " + safe(usage.getIssuedTo()),
                                usage.getQuantity(),
                                usage.getDate() == null ? nowIso() : usage.getDate().atStartOfDay().format(DATE_FORMATTER)
                        );
                        count++;
                    }
                }
            }

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

    private void appendRoleBlueprintActivities(JsonArray activities, User user) {
        if (user == null) {
            return;
        }

        String[] blueprint;
        if (SecurityConfig.isAdmin(user)) {
            blueprint = new String[]{
                    "Manage users (add, update, delete)",
                    "Perform system maintenance tasks",
                    "Run database backup/restore operations",
                    "Review system logs and audit activity",
                    "Access reporting overview"
            };
        } else if (SecurityConfig.isDepartmentHead(user)) {
            blueprint = new String[]{
                    "Review pending store requests",
                    "Approve or reject requests",
                    "Generate report outputs",
                    "Review charts and summary reports"
            };
        } else {
            blueprint = new String[]{
                    "Update supplied inventory records",
                    "Record issued items/usage",
                    "Submit store requests",
                    "Record damaged items",
                    "Search and view item list"
            };
        }

        for (String step : blueprint) {
            addActivity(activities, "role", "[Role Task] " + step, 0, nowIso());
        }
    }

    private void addActivity(JsonArray activities, String type, String description, double quantity, String isoDate) {
        JsonObject act = new JsonObject();
        act.addProperty("type", type);
        act.addProperty("description", description);
        act.addProperty("quantity", quantity);
        act.addProperty("date", isoDate);
        activities.add(act);
    }

    private String nowIso() {
        return LocalDateTime.now().format(DATE_FORMATTER);
    }

    private String safe(String value) {
        return value == null || value.isBlank() ? "N/A" : value;
    }
}
