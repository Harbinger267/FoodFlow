package com.foodflow.dao;

import com.foodflow.config.DatabaseConfig;
import com.foodflow.model.Damage;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

public class DamageDAO {
    private static volatile boolean schemaChecked = false;

    public boolean addDamage(Damage damage) {
        String insertSql = "INSERT INTO damage_log (item_id, quantity, damage_date, description, damage_type, disposition, reported_by, reported_by_name) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        String stockSql = "UPDATE items SET stock = stock - ?, status = CASE WHEN stock - ? <= 0 THEN 'OUT_OF_STOCK' ELSE 'AVAILABLE' END WHERE item_id = ? AND stock >= ?";
        try (Connection conn = DatabaseConfig.getConnection()) {
            ensureSchema(conn);
            try (PreparedStatement insertStmt = conn.prepareStatement(insertSql);
                 PreparedStatement stockStmt = conn.prepareStatement(stockSql)) {
            conn.setAutoCommit(false);
            insertStmt.setInt(1, damage.getItemId());
            insertStmt.setDouble(2, damage.getQuantity());
            insertStmt.setTimestamp(3, new Timestamp(System.currentTimeMillis())); // use current time
            insertStmt.setString(4, damage.getDescription());
            insertStmt.setString(5, damage.getDamageType());
            insertStmt.setString(6, normalizeDisposition(damage.getDisposition()));
            if (damage.getReportedByUserId() == null || damage.getReportedByUserId() <= 0) {
                insertStmt.setNull(7, java.sql.Types.INTEGER);
            } else {
                insertStmt.setInt(7, damage.getReportedByUserId());
            }
            String reportedByName = damage.getReportedBy() == null || damage.getReportedBy().isBlank()
                    ? null
                    : damage.getReportedBy().trim();
            insertStmt.setString(8, reportedByName);
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
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    public List<Damage> getAllDamage() {
        String sql = "SELECT d.damage_id, d.item_id, d.quantity, d.damage_date, d.description, " +
                "d.damage_type, d.disposition, d.reported_by, d.reported_by_name, " +
                "i.name AS item_name, u.name AS recorded_by_name " +
                "FROM damage_log d JOIN items i ON d.item_id = i.item_id " +
                "LEFT JOIN users u ON d.reported_by = u.user_id ORDER BY d.damage_date DESC";
        List<Damage> damages = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection()) {
            ensureSchema(conn);
            try (Statement stmt = conn.createStatement();
                 ResultSet rs = stmt.executeQuery(sql)) {
                while (rs.next()) {
                    damages.add(mapResultSetToDamage(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return damages;
    }

    public boolean updateDisposition(int damageId, String disposition) {
        if (damageId <= 0) {
            return false;
        }

        String sql = "UPDATE damage_log SET disposition = ? WHERE damage_id = ?";
        try (Connection conn = DatabaseConfig.getConnection()) {
            ensureSchema(conn);
            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setString(1, normalizeDisposition(disposition));
                stmt.setInt(2, damageId);
                return stmt.executeUpdate() > 0;
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    public boolean recordDamage(
            int itemId,
            double quantity,
            String damageType,
            int userId,
            String reportedByName,
            String disposition
    ) {
        Damage damage = new Damage();
        damage.setItemId(itemId);
        damage.setQuantity(quantity);
        String normalizedType = (damageType == null || damageType.isBlank()) ? "Other" : damageType.trim();
        damage.setDescription(normalizedType);
        damage.setDamageType(normalizedType);
        damage.setDisposition(normalizeDisposition(disposition));
        damage.setReportedBy(reportedByName);
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
        String damageType = rs.getString("damage_type");
        damage.setDamageType((damageType == null || damageType.isBlank())
                ? rs.getString("description")
                : damageType);
        damage.setDisposition(normalizeDisposition(rs.getString("disposition")));
        int reportedBy = rs.getInt("reported_by");
        damage.setReportedByUserId(rs.wasNull() ? null : reportedBy);
        String reportedByName = rs.getString("reported_by_name");
        damage.setReportedBy((reportedByName == null || reportedByName.isBlank())
                ? rs.getString("recorded_by_name")
                : reportedByName);
        damage.setRecordedByName(rs.getString("recorded_by_name"));
        return damage;
    }

    private void ensureSchema(Connection conn) throws SQLException {
        if (schemaChecked) {
            return;
        }

        synchronized (DamageDAO.class) {
            if (schemaChecked) {
                return;
            }
            try (Statement stmt = conn.createStatement()) {
                if (!columnExists(conn, "damage_log", "damage_type")) {
                    stmt.executeUpdate("ALTER TABLE damage_log ADD COLUMN damage_type VARCHAR(100) NULL");
                }
                if (!columnExists(conn, "damage_log", "reported_by_name")) {
                    stmt.executeUpdate("ALTER TABLE damage_log ADD COLUMN reported_by_name VARCHAR(100) NULL");
                }
                if (!columnExists(conn, "damage_log", "disposition")) {
                    stmt.executeUpdate(
                            "ALTER TABLE damage_log ADD COLUMN disposition " +
                                    "ENUM('DISPOSED','REPLACED','UNDER_REPAIR','REPAIRED') NOT NULL DEFAULT 'DISPOSED'"
                    );
                }
            }
            schemaChecked = true;
        }
    }

    private boolean columnExists(Connection conn, String tableName, String columnName) throws SQLException {
        DatabaseMetaData metaData = conn.getMetaData();
        try (ResultSet columns = metaData.getColumns(conn.getCatalog(), null, tableName, columnName)) {
            return columns.next();
        }
    }

    private String normalizeDisposition(String disposition) {
        String normalized = disposition == null ? "" : disposition.trim().toUpperCase();
        if ("REPLACED".equals(normalized)
                || "UNDER_REPAIR".equals(normalized)
                || "REPAIRED".equals(normalized)
                || "DISPOSED".equals(normalized)) {
            return normalized;
        }
        return "DISPOSED";
    }
}
