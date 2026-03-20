package com.foodflow.dao;

import com.foodflow.config.DatabaseConfig;
import com.foodflow.model.Usage;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

public class UsageDAO {

    public boolean addIssueUsage(Usage usage) {
        String insertSql = "INSERT INTO issue_transactions (item_id, quantity_issued, issued_date, issued_by, issued_to) VALUES (?, ?, ?, ?, ?)";
        String stockSql = "UPDATE items SET stock = stock - ?, status = CASE WHEN stock - ? <= 0 THEN 'OUT_OF_STOCK' ELSE 'AVAILABLE' END WHERE item_id = ? AND stock >= ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement insertStmt = conn.prepareStatement(insertSql);
             PreparedStatement stockStmt = conn.prepareStatement(stockSql)) {
            conn.setAutoCommit(false);
            insertStmt.setInt(1, usage.getItemId());
            insertStmt.setDouble(2, usage.getQuantity());
            insertStmt.setTimestamp(3, Timestamp.valueOf(LocalDateTime.of(usage.getDate(), java.time.LocalTime.NOON)));
            if (usage.getRecordedBy() == null || usage.getRecordedBy() <= 0) {
                insertStmt.setNull(4, java.sql.Types.INTEGER);
            } else {
                insertStmt.setInt(4, usage.getRecordedBy());
            }
            insertStmt.setString(5, usage.getIssuedTo() == null || usage.getIssuedTo().isBlank() ? "Internal Department" : usage.getIssuedTo());
            insertStmt.executeUpdate();

            stockStmt.setDouble(1, usage.getQuantity());
            stockStmt.setDouble(2, usage.getQuantity());
            stockStmt.setInt(3, usage.getItemId());
            stockStmt.setDouble(4, usage.getQuantity());
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

    public boolean addBorrowUsage(Usage usage) {
        String insertSql = "INSERT INTO borrow_transactions (item_id, quantity_borrowed, quantity_returned, borrow_date, return_date, status, recorded_by, borrower_name) VALUES (?, ?, 0, ?, NULL, 'BORROWED', ?, ?)";
        String stockSql = "UPDATE items SET stock = stock - ?, status = CASE WHEN stock - ? <= 0 THEN 'OUT_OF_STOCK' ELSE 'AVAILABLE' END WHERE item_id = ? AND stock >= ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement insertStmt = conn.prepareStatement(insertSql);
             PreparedStatement stockStmt = conn.prepareStatement(stockSql)) {
            conn.setAutoCommit(false);
            insertStmt.setInt(1, usage.getItemId());
            insertStmt.setDouble(2, usage.getQuantity());
            insertStmt.setTimestamp(3, Timestamp.valueOf(LocalDateTime.of(usage.getDate(), java.time.LocalTime.NOON)));
            if (usage.getRecordedBy() == null || usage.getRecordedBy() <= 0) {
                insertStmt.setNull(4, java.sql.Types.INTEGER);
            } else {
                insertStmt.setInt(4, usage.getRecordedBy());
            }
            insertStmt.setString(5, usage.getIssuedTo() == null || usage.getIssuedTo().isBlank() ? "Internal Department" : usage.getIssuedTo());
            insertStmt.executeUpdate();

            stockStmt.setDouble(1, usage.getQuantity());
            stockStmt.setDouble(2, usage.getQuantity());
            stockStmt.setInt(3, usage.getItemId());
            stockStmt.setDouble(4, usage.getQuantity());
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

    public List<Usage> getAllUsage() {
        String sql = "SELECT t.usage_id, t.item_id, t.item_name, t.quantity, t.quantity_returned, t.usage_date, t.status, t.recorded_by, t.recorded_by_name, t.recipient_name " +
                "FROM (" +
                "  SELECT it.issue_id AS usage_id, it.item_id, i.name AS item_name, it.quantity_issued AS quantity, 0 AS quantity_returned, " +
                "         it.issued_date AS usage_date, 'ISSUED' AS status, it.issued_by AS recorded_by, u.name AS recorded_by_name, it.issued_to AS recipient_name " +
                "  FROM issue_transactions it " +
                "  JOIN items i ON it.item_id = i.item_id " +
                "  LEFT JOIN users u ON it.issued_by = u.user_id " +
                "  UNION ALL " +
                "  SELECT bt.borrow_id AS usage_id, bt.item_id, i.name AS item_name, bt.quantity_borrowed AS quantity, bt.quantity_returned AS quantity_returned, " +
                "         bt.borrow_date AS usage_date, bt.status AS status, bt.recorded_by AS recorded_by, u.name AS recorded_by_name, bt.borrower_name AS recipient_name " +
                "  FROM borrow_transactions bt " +
                "  JOIN items i ON bt.item_id = i.item_id " +
                "  LEFT JOIN users u ON bt.recorded_by = u.user_id " +
                ") t ORDER BY t.usage_date DESC";

        List<Usage> usageList = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                usageList.add(mapResultSetToUsage(rs));
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return usageList;
    }

    private Usage mapResultSetToUsage(ResultSet rs) throws SQLException {
        Usage usage = new Usage();
        usage.setUsageId(rs.getInt("usage_id"));
        usage.setItemId(rs.getInt("item_id"));
        usage.setItemName(rs.getString("item_name"));
        usage.setQuantity(rs.getDouble("quantity"));
        usage.setQuantityReturned(rs.getDouble("quantity_returned"));
        int recordedBy = rs.getInt("recorded_by");
        usage.setRecordedBy(rs.wasNull() ? null : recordedBy);
        usage.setItemUserName(rs.getString("recorded_by_name"));
        usage.setIssuedTo(rs.getString("recipient_name"));
        Timestamp timestamp = rs.getTimestamp("usage_date");
        if (timestamp != null) {
            usage.setDate(timestamp.toLocalDateTime().toLocalDate());
        }
        String status = rs.getString("status");
        try {
            usage.setStatus(Usage.Status.valueOf(status));
        } catch (IllegalArgumentException ex) {
            usage.setStatus(Usage.Status.ISSUED);
        }
        return usage;
    }
}
