package com.foodflow.dao;

import com.foodflow.config.DatabaseConfig;
import com.foodflow.model.StoreRequest;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

public class StoreRequestDAO {

    public boolean createRequest(StoreRequest request) {
        String requestSql = "INSERT INTO store_requests (requester_id, approver_id, status, request_date, approved_date, notes) VALUES (?, NULL, 'PENDING', CURRENT_TIMESTAMP, NULL, ?)";
        String detailSql = "INSERT INTO request_details (request_id, item_id, quantity_requested, quantity_approved) VALUES (?, ?, ?, 0)";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement requestStmt = conn.prepareStatement(requestSql, Statement.RETURN_GENERATED_KEYS);
             PreparedStatement detailStmt = conn.prepareStatement(detailSql)) {
            conn.setAutoCommit(false);
            requestStmt.setInt(1, request.getRequesterId());
            requestStmt.setString(2, request.getNotes());
            requestStmt.executeUpdate();

            try (ResultSet keys = requestStmt.getGeneratedKeys()) {
                if (!keys.next()) {
                    conn.rollback();
                    return false;
                }
                int requestId = keys.getInt(1);
                detailStmt.setInt(1, requestId);
                detailStmt.setInt(2, request.getItemId());
                detailStmt.setDouble(3, request.getQuantityRequested());
                detailStmt.executeUpdate();
            }

            conn.commit();
            return true;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    public boolean updateRequestStatus(int requestId, int approverId, String status) {
        String requestSql = "UPDATE store_requests " +
                "SET status = ?, approver_id = ?, approved_date = CURRENT_TIMESTAMP " +
                "WHERE request_id = ? AND status = 'PENDING'";
        String detailSql = "UPDATE request_details " +
                "SET quantity_approved = CASE WHEN ? = 'APPROVED' THEN quantity_requested ELSE 0 END " +
                "WHERE request_id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement requestStmt = conn.prepareStatement(requestSql);
             PreparedStatement detailStmt = conn.prepareStatement(detailSql)) {
            String normalized = status == null ? "PENDING" : status.toUpperCase();
            conn.setAutoCommit(false);

            requestStmt.setString(1, normalized);
            requestStmt.setInt(2, approverId);
            requestStmt.setInt(3, requestId);
            int requestRows = requestStmt.executeUpdate();
            if (requestRows == 0) {
                conn.rollback();
                return false;
            }

            detailStmt.setString(1, normalized);
            detailStmt.setInt(2, requestId);
            detailStmt.executeUpdate();

            conn.commit();
            return true;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return false;
    }

    public List<StoreRequest> getAllRequests() {
        return getRequests(null, false);
    }

    public List<StoreRequest> getPendingRequests() {
        return getRequests("PENDING", false);
    }

    public List<StoreRequest> getRequestsForRequester(int requesterId) {
        return getRequests(null, true, requesterId);
    }

    public int countPendingRequests() {
        String sql = "SELECT COUNT(*) FROM store_requests WHERE status = 'PENDING'";
        try (Connection conn = DatabaseConfig.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            return rs.next() ? rs.getInt(1) : 0;
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return 0;
    }

    public int countPendingRequestsForRequester(int requesterId) {
        String sql = "SELECT COUNT(*) FROM store_requests WHERE status = 'PENDING' AND requester_id = ?";
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, requesterId);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return 0;
    }

    private List<StoreRequest> getRequests(String status, boolean filterByRequester, int... requesterId) {
        StringBuilder sql = new StringBuilder(
                "SELECT sr.request_id, sr.requester_id, req.name AS requester_name, sr.approver_id, app.name AS approver_name, " +
                        "sr.status, sr.notes, sr.request_date, sr.approved_date, rd.item_id, i.name AS item_name, " +
                        "rd.quantity_requested, rd.quantity_approved " +
                        "FROM store_requests sr " +
                        "JOIN request_details rd ON sr.request_id = rd.request_id " +
                        "JOIN items i ON rd.item_id = i.item_id " +
                        "JOIN users req ON sr.requester_id = req.user_id " +
                        "LEFT JOIN users app ON sr.approver_id = app.user_id WHERE 1=1 ");
        if (status != null) {
            sql.append("AND sr.status = ? ");
        }
        if (filterByRequester) {
            sql.append("AND sr.requester_id = ? ");
        }
        sql.append("ORDER BY sr.request_date DESC");

        List<StoreRequest> requests = new ArrayList<>();
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql.toString())) {
            int index = 1;
            if (status != null) {
                stmt.setString(index++, status);
            }
            if (filterByRequester) {
                stmt.setInt(index, requesterId[0]);
            }
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    requests.add(mapResultSetToRequest(rs));
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return requests;
    }

    private StoreRequest mapResultSetToRequest(ResultSet rs) throws SQLException {
        StoreRequest request = new StoreRequest();
        request.setRequestId(rs.getInt("request_id"));
        request.setRequesterId(rs.getInt("requester_id"));
        request.setRequesterName(rs.getString("requester_name"));
        int approverId = rs.getInt("approver_id");
        request.setApproverId(rs.wasNull() ? null : approverId);
        request.setApproverName(rs.getString("approver_name"));
        request.setStatus(rs.getString("status"));
        request.setNotes(rs.getString("notes"));
        request.setItemId(rs.getInt("item_id"));
        request.setItemName(rs.getString("item_name"));
        request.setQuantityRequested(rs.getDouble("quantity_requested"));
        request.setQuantityApproved(rs.getDouble("quantity_approved"));
        Timestamp requestTs = rs.getTimestamp("request_date");
        if (requestTs != null) {
            request.setRequestDate(requestTs.toLocalDateTime());
        }
        Timestamp approvedTs = rs.getTimestamp("approved_date");
        if (approvedTs != null) {
            request.setApprovedDate(approvedTs.toLocalDateTime());
        }
        return request;
    }
}
