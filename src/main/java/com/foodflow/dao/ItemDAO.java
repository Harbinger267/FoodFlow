package com.foodflow.dao;

import com.foodflow.config.DatabaseConfig;
import com.foodflow.model.Item;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

public class ItemDAO {

    public boolean addItem(Item item) {
        String sql = "INSERT INTO items (name, category, item_type, stock, unit_of_measure, description, status) VALUES (?, ?, ?, ?, ?, ?, ?)";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, item.getName());
            stmt.setString(2, item.getCategory());
            stmt.setString(3, item.getItemType() == null ? "FOOD" : item.getItemType().toUpperCase());
            stmt.setDouble(4, item.getCurrentStock());
            stmt.setString(5, item.getUnitOfMeasure());
            stmt.setString(6, item.getDescription());
            stmt.setString(7, normalizeStatus(item.getStatus(), item.getCurrentStock()));
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    public Item getItemById(int id) {
        String sql = "SELECT * FROM items WHERE item_id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? mapResultSetToItem(rs) : null;
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return null;
    }

    public List<Item> getAllItems() {
        String sql = "SELECT * FROM items ORDER BY name ASC";
        List<Item> items = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                items.add(mapResultSetToItem(rs));
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return items;
    }

    public List<Item> getLowStockItems() {
        return getLowStockItems(10.0); // Default threshold
    }

    public List<Item> getLowStockItems(double threshold) {
        String sql = "SELECT * FROM items WHERE stock <= ? OR status = 'OUT_OF_STOCK' ORDER BY stock ASC";
        List<Item> items = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, threshold);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    items.add(mapResultSetToItem(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return items;
    }

    public List<Item> searchItems(String query) {
        if (query == null || query.isBlank()) {
            return getAllItems();
        }

        String sql = "SELECT * FROM items WHERE LOWER(name) LIKE ? OR LOWER(category) LIKE ? ORDER BY name ASC";
        List<Item> items = new ArrayList<>();
        String term = "%" + query.trim().toLowerCase() + "%";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, term);
            stmt.setString(2, term);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    items.add(mapResultSetToItem(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return items;
    }

    public boolean updateItemStatus(int itemId, double currentStock, String status) {
        String sql = "UPDATE items SET stock = ?, status = ? WHERE item_id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, currentStock);
            stmt.setString(2, normalizeStatus(status, currentStock));
            stmt.setInt(3, itemId);
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    public boolean replenishStock(int itemId, double quantityToAdd) {
        String sql = "UPDATE items " +
                "SET stock = stock + ?, " +
                "status = CASE WHEN stock + ? <= 0 THEN 'OUT_OF_STOCK' ELSE 'AVAILABLE' END " +
                "WHERE item_id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setDouble(1, quantityToAdd);
            stmt.setDouble(2, quantityToAdd);
            stmt.setInt(3, itemId);
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    private String normalizeStatus(String requestedStatus, double stock) {
        if (stock <= 0) {
            return "OUT_OF_STOCK";
        }
        if (requestedStatus == null || requestedStatus.isBlank()) {
            return "AVAILABLE";
        }
        String normalized = requestedStatus.toUpperCase();
        if ("DAMAGED".equals(normalized) || "INACTIVE".equals(normalized) || "AVAILABLE".equals(normalized) || "OUT_OF_STOCK".equals(normalized)) {
            return normalized;
        }
        return "AVAILABLE";
    }

    private Item mapResultSetToItem(ResultSet rs) throws SQLException {
        Item item = new Item();
        item.setItemId(rs.getInt("item_id"));
        item.setName(rs.getString("name"));
        item.setCategory(rs.getString("category"));
        item.setItemType(rs.getString("item_type"));
        item.setCurrentStock(rs.getDouble("stock"));
        item.setUnitOfMeasure(rs.getString("unit_of_measure"));
        item.setDescription(rs.getString("description"));
        item.setStatus(rs.getString("status"));
        return item;
    }
}
