package com.foodflow.util;

import com.google.gson.Gson;
import com.google.gson.JsonObject;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Utility class for JSON response handling in servlets
 */
public class ResponseUtil {
    
    private static final Gson gson = new Gson();
    private static final DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    
    /**
     * Send successful JSON response
     */
    public static void sendSuccess(HttpServletResponse response, String message) throws IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        
        JsonObject jsonResponse = new JsonObject();
        jsonResponse.addProperty("success", true);
        jsonResponse.addProperty("message", message);
        jsonResponse.addProperty("timestamp", LocalDateTime.now().format(formatter));
        
        PrintWriter out = response.getWriter();
        out.print(gson.toJson(jsonResponse));
        out.flush();
    }
    
    /**
     * Send successful JSON response with data
     */
    public static void sendSuccess(HttpServletResponse response, String message, Object data) throws IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        
        JsonObject jsonResponse = new JsonObject();
        jsonResponse.addProperty("success", true);
        jsonResponse.addProperty("message", message);
        jsonResponse.add("data", gson.toJsonTree(data));
        jsonResponse.addProperty("timestamp", LocalDateTime.now().format(formatter));
        
        PrintWriter out = response.getWriter();
        out.print(gson.toJson(jsonResponse));
        out.flush();
    }
    
    /**
     * Send error JSON response
     */
    public static void sendError(HttpServletResponse response, String message, int statusCode) throws IOException {
        response.setStatus(statusCode);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        
        JsonObject errorResponse = new JsonObject();
        errorResponse.addProperty("success", false);
        errorResponse.addProperty("error", message);
        errorResponse.addProperty("statusCode", statusCode);
        errorResponse.addProperty("timestamp", LocalDateTime.now().format(formatter));
        
        PrintWriter out = response.getWriter();
        out.print(gson.toJson(errorResponse));
        out.flush();
    }
    
    /**
     * Send JSON object directly
     */
    public static void sendJson(HttpServletResponse response, Object data) throws IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        
        PrintWriter out = response.getWriter();
        out.print(gson.toJson(data));
        out.flush();
    }
    
    /**
     * Create a standard API response
     */
    public static JsonObject createResponse(boolean success, String message) {
        JsonObject response = new JsonObject();
        response.addProperty("success", success);
        response.addProperty("message", message);
        return response;
    }
    
    /**
     * Create a data wrapper
     */
    public static JsonObject createDataWrapper(Object data, long count) {
        JsonObject wrapper = new JsonObject();
        wrapper.add("data", gson.toJsonTree(data));
        wrapper.addProperty("count", count);
        wrapper.addProperty("timestamp", LocalDateTime.now().format(formatter));
        return wrapper;
    }
}
