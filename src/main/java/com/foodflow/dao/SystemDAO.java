package com.foodflow.dao;

import com.foodflow.config.DatabaseConfig;
import com.foodflow.model.SystemLog;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

public class SystemDAO {
    private static volatile boolean schemaChecked = false;

    public List<SystemLog> getRecentLogs() {
        return getLogs(null, null, null, 50, 0, false);
    }

    public List<SystemLog> getLogs(
            LocalDateTime fromInclusive,
            LocalDateTime toExclusive,
            String search,
            int limit,
            int offset,
            boolean includeArchived
    ) {
        int safeLimit = Math.max(1, Math.min(limit <= 0 ? 50 : limit, 200));
        int safeOffset = Math.max(0, offset);

        StringBuilder sql = new StringBuilder(
                "SELECT l.log_id, l.user_id, l.action_performed, l.timestamp, l.archived_at, u.name AS user_name " +
                        "FROM system_logs l LEFT JOIN users u ON l.user_id = u.user_id WHERE 1=1 "
        );
        List<Object> params = new ArrayList<>();

        if (!includeArchived) {
            sql.append("AND l.archived_at IS NULL ");
        }
        if (fromInclusive != null) {
            sql.append("AND l.timestamp >= ? ");
            params.add(Timestamp.valueOf(fromInclusive));
        }
        if (toExclusive != null) {
            sql.append("AND l.timestamp < ? ");
            params.add(Timestamp.valueOf(toExclusive));
        }
        if (search != null && !search.isBlank()) {
            sql.append("AND (LOWER(l.action_performed) LIKE ? OR LOWER(COALESCE(u.name, '')) LIKE ?) ");
            String pattern = "%" + search.trim().toLowerCase() + "%";
            params.add(pattern);
            params.add(pattern);
        }
        sql.append("ORDER BY l.timestamp DESC LIMIT ? OFFSET ?");
        params.add(safeLimit);
        params.add(safeOffset);

        List<SystemLog> logs = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection()) {
            ensureSchema(conn);
            try (PreparedStatement stmt = conn.prepareStatement(sql.toString())) {
                bindParams(stmt, params);
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        logs.add(mapResultSetToLog(rs));
                    }
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return logs;
    }

    public int countLogs(LocalDateTime fromInclusive, LocalDateTime toExclusive, String search, boolean includeArchived) {
        StringBuilder sql = new StringBuilder(
                "SELECT COUNT(*) AS total " +
                        "FROM system_logs l LEFT JOIN users u ON l.user_id = u.user_id WHERE 1=1 "
        );
        List<Object> params = new ArrayList<>();

        if (!includeArchived) {
            sql.append("AND l.archived_at IS NULL ");
        }
        if (fromInclusive != null) {
            sql.append("AND l.timestamp >= ? ");
            params.add(Timestamp.valueOf(fromInclusive));
        }
        if (toExclusive != null) {
            sql.append("AND l.timestamp < ? ");
            params.add(Timestamp.valueOf(toExclusive));
        }
        if (search != null && !search.isBlank()) {
            sql.append("AND (LOWER(l.action_performed) LIKE ? OR LOWER(COALESCE(u.name, '')) LIKE ?) ");
            String pattern = "%" + search.trim().toLowerCase() + "%";
            params.add(pattern);
            params.add(pattern);
        }

        try (Connection conn = DatabaseConfig.getConnection()) {
            ensureSchema(conn);
            try (PreparedStatement stmt = conn.prepareStatement(sql.toString())) {
                bindParams(stmt, params);
                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        return rs.getInt("total");
                    }
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return 0;
    }

    public int countLogsSince(LocalDateTime fromInclusive, boolean includeArchived) {
        return countLogs(fromInclusive, null, null, includeArchived);
    }

    public int archiveLogs(LocalDateTime fromInclusive, LocalDateTime toExclusive) {
        if (fromInclusive == null || toExclusive == null || !fromInclusive.isBefore(toExclusive)) {
            return 0;
        }

        String sql = "UPDATE system_logs SET archived_at = CURRENT_TIMESTAMP " +
                "WHERE archived_at IS NULL AND timestamp >= ? AND timestamp < ?";
        try (Connection conn = DatabaseConfig.getConnection()) {
            ensureSchema(conn);
            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setTimestamp(1, Timestamp.valueOf(fromInclusive));
                stmt.setTimestamp(2, Timestamp.valueOf(toExclusive));
                return stmt.executeUpdate();
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return 0;
    }

    public boolean logMaintenanceAction(int userId, String action) {
        String sql = "INSERT INTO system_logs (user_id, action_performed, timestamp) VALUES (?, ?, CURRENT_TIMESTAMP)";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, userId);
            stmt.setString(2, action);
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    private SystemLog mapResultSetToLog(ResultSet rs) throws SQLException {
        SystemLog log = new SystemLog();
        log.setLogId(rs.getInt("log_id"));
        int userId = rs.getInt("user_id");
        log.setUserId(rs.wasNull() ? null : userId);
        log.setUserName(rs.getString("user_name"));
        log.setAction(rs.getString("action_performed"));
        Timestamp timestamp = rs.getTimestamp("timestamp");
        if (timestamp != null) {
            log.setTimestamp(timestamp.toLocalDateTime());
        }
        Timestamp archivedAt = rs.getTimestamp("archived_at");
        if (archivedAt != null) {
            log.setArchivedAt(archivedAt.toLocalDateTime());
        }
        return log;
    }

    private void ensureSchema(Connection conn) throws SQLException {
        if (schemaChecked) {
            return;
        }

        synchronized (SystemDAO.class) {
            if (schemaChecked) {
                return;
            }
            try (Statement stmt = conn.createStatement()) {
                if (!columnExists(conn, "system_logs", "archived_at")) {
                    stmt.executeUpdate("ALTER TABLE system_logs ADD COLUMN archived_at DATETIME NULL");
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

    private void bindParams(PreparedStatement stmt, List<Object> params) throws SQLException {
        int index = 1;
        for (Object param : params) {
            if (param instanceof Timestamp) {
                stmt.setTimestamp(index++, (Timestamp) param);
            } else if (param instanceof Integer) {
                stmt.setInt(index++, (Integer) param);
            } else if (param instanceof String) {
                stmt.setString(index++, (String) param);
            } else {
                stmt.setObject(index++, param);
            }
        }
    }
}
