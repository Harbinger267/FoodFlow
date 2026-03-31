package com.foodflow.dao;

import com.foodflow.config.DatabaseConfig;
import com.foodflow.model.Damage;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

public class DamageDAO {

    public boolean addDamage(Damage damage) {
        String insertSql = "INSERT INTO damage_log (item_id, quantity, damage_date, description, reported_by) VALUES (?, ?, ?, ?, ?)";
        String stockSql = "UPDATE items SET stock = stock - ?, status = CASE WHEN stock - ? <= 0 THEN 'OUT_OF_STOCK' ELSE 'AVAILABLE' END WHERE item_id = ? AND stock >= ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement insertStmt = conn.prepareStatement(insertSql);
             PreparedStatement stockStmt = conn.prepareStatement(stockSql)) {
            conn.setAutoCommit(false);
            insertStmt.setInt(1, damage.getItemId());
            insertStmt.setDouble(2, damage.getQuantity());
            insertStmt.setTimestamp(3, new Timestamp(System.currentTimeMillis())); // use current time
            insertStmt.setString(4, damage.getDescription());
            if (damage.getReportedByUserId() == null || damage.getReportedByUserId() <= 0) {
                insertStmt.setNull(5, java.sql.Types.INTEGER);
            } else {
                insertStmt.setInt(5, damage.getReportedByUserId());
            }
            insertStmt.executeUpdate();

            stockStmt.setDouble(1, damage.getQuantity());
            stockStmt.setDouble(2, damage.getQuantity());
            stockStmt.setInt(3, damage.getItemId());
            stockStmt.setDouble(4, damage.getQuantity());
            if (stockStmt.executeUpdate() == 0) {
                conn.rollback();
                return false;
            }
            conn.commit();
            return true;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    public List<Damage> getAllDamage() {
        String sql = "SELECT d.*, i.name AS item_name, u.name AS reported_by_name " +
                "FROM damage_log d JOIN items i ON d.item_id = i.item_id " +
                "LEFT JOIN users u ON d.reported_by = u.user_id ORDER BY d.damage_date DESC";
        List<Damage> damages = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                damages.add(mapResultSetToDamage(rs));
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return damages;
    }

    public boolean recordDamage(int itemId, double quantity, String reason, int userId) {
        Damage damage = new Damage();
        damage.setItemId(itemId);
        damage.setQuantity(quantity);
        damage.setDescription(reason);
        damage.setReportedByUserId(userId);
        return addDamage(damage);
    }

    private Damage mapResultSetToDamage(ResultSet rs) throws SQLException {
        Damage damage = new Damage();
        damage.setDamageId(rs.getInt("damage_id"));
        damage.setItemId(rs.getInt("item_id"));
        damage.setItemName(rs.getString("item_name"));
        damage.setQuantity(rs.getDouble("quantity"));

        // Store date as String to avoid Gson LocalDate serialization issues
        Timestamp timestamp = rs.getTimestamp("damage_date");
        if (timestamp != null) {
            damage.setDateString(timestamp.toLocalDateTime().toLocalDate().toString());
        }

        damage.setDescription(rs.getString("description"));
        int reportedBy = rs.getInt("reported_by");
        damage.setReportedByUserId(rs.wasNull() ? null : reportedBy);
        damage.setReportedBy(rs.getString("reported_by_name"));
        return damage;
    }
}