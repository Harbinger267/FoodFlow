

USE foodflow;

-- =========================================
-- INVENTORY REPORTS
-- =========================================

-- Current inventory status report
SELECT 
    i.item_id,
    i.item_name,
    c.category_name,
    i.current_stock,
    i.unit_type,
    i.reorder_level,
    i.status,
    CASE 
        WHEN i.current_stock = 0 THEN 'Critical'
        WHEN i.current_stock < i.reorder_level THEN 'Low'
        ELSE 'OK'
    END AS stock_status,
    CASE 
        WHEN i.current_stock < i.reorder_level THEN i.reorder_level - i.current_stock
        ELSE 0
    END AS quantity_to_reorder
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.status IN ('AVAILABLE', 'LOW_STOCK', 'OUT_OF_STOCK')
ORDER BY 
    CASE 
        WHEN i.current_stock = 0 THEN 1
        WHEN i.current_stock < i.reorder_level THEN 2
        ELSE 3
    END,
    i.item_name ASC;

-- Inventory valuation report (add cost column when implemented)
SELECT 
    c.category_name,
    COUNT(i.item_id) AS item_count,
    SUM(i.current_stock) AS total_units,
    'Add cost tracking for valuation' AS note
FROM categories c
LEFT JOIN items i ON c.category_id = i.category_id AND i.status = 'AVAILABLE'
GROUP BY c.category_id, c.category_name
ORDER BY total_units DESC;

-- Items requiring immediate reorder
SELECT 
    i.item_id,
    i.item_name,
    c.category_name,
    i.current_stock,
    i.reorder_level,
    i.unit_type,
    (i.reorder_level - i.current_stock) AS shortage,
    GROUP_CONCAT(DISTINCT u.user_name SEPARATOR ', ') AS last_recorded_by
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
LEFT JOIN stock_transactions st ON i.item_id = st.item_id
LEFT JOIN users u ON st.user_id = u.user_id
WHERE i.current_stock < i.reorder_level
AND i.status = 'AVAILABLE'
GROUP BY i.item_id, i.item_name, c.category_name, i.current_stock, i.reorder_level, i.unit_type
ORDER BY shortage DESC;

-- =========================================
-- STOCK MOVEMENT REPORTS
-- =========================================

-- Stock movement summary for a period
SELECT 
    i.item_id,
    i.item_name,
    c.category_name,
    i.current_stock AS opening_stock,
    COALESCE(supply.total_in, 0) AS stock_in,
    COALESCE(usage_out.total_out, 0) AS stock_out,
    COALESCE(damage.total_damaged, 0) AS damaged,
    (i.current_stock + COALESCE(supply.total_in, 0) - COALESCE(usage_out.total_out, 0) - COALESCE(damage.total_damaged, 0)) AS closing_stock
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_in
    FROM stock_transactions
    WHERE transaction_type = 'IN'
    AND transaction_date BETWEEN ? AND ?
    GROUP BY item_id
) supply ON i.item_id = supply.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_out
    FROM stock_transactions
    WHERE transaction_type = 'OUT'
    AND transaction_date BETWEEN ? AND ?
    GROUP BY item_id
) usage_out ON i.item_id = usage_out.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_damaged
    FROM stock_transactions
    WHERE transaction_type = 'DAMAGED'
    AND transaction_date BETWEEN ? AND ?
    GROUP BY item_id
) damage ON i.item_id = damage.item_id
WHERE i.status = 'AVAILABLE'
ORDER BY i.item_name ASC;

-- Transaction history by item
SELECT 
    st.transaction_id,
    st.transaction_date,
    st.transaction_type,
    i.item_name,
    st.quantity,
    i.unit_type,
    u.user_name AS processed_by,
    r.role_title AS processed_by_role,
    st.notes
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN users u ON st.user_id = u.user_id
INNER JOIN roles r ON u.role_id = r.role_id
WHERE st.item_id = ?
ORDER BY st.transaction_date DESC;

-- Net stock change by item (for a period)
SELECT 
    i.item_id,
    i.item_name,
    c.category_name,
    SUM(CASE WHEN st.transaction_type = 'IN' THEN st.quantity ELSE 0 END) AS total_in,
    SUM(CASE WHEN st.transaction_type = 'OUT' THEN st.quantity ELSE 0 END) AS total_out,
    SUM(CASE WHEN st.transaction_type = 'DAMAGED' THEN st.quantity ELSE 0 END) AS total_damaged,
    SUM(CASE 
        WHEN st.transaction_type = 'IN' THEN st.quantity
        WHEN st.transaction_type IN ('OUT', 'DAMAGED') THEN -st.quantity
        ELSE 0
    END) AS net_change
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
LEFT JOIN stock_transactions st ON i.item_id = st.item_id
    AND st.transaction_date BETWEEN ? AND ?
WHERE i.status = 'AVAILABLE'
GROUP BY i.item_id, i.item_name, c.category_name
HAVING net_change != 0
ORDER BY net_change DESC;

-- =========================================
-- USER ACTIVITY REPORTS
-- =========================================

-- User activity summary
SELECT 
    u.user_id,
    u.user_name,
    r.role_title,
    COUNT(DISTINCT st.transaction_id) AS transactions_processed,
    SUM(CASE WHEN st.transaction_type = 'IN' THEN st.quantity ELSE 0 END) AS supplies_handled,
    SUM(CASE WHEN st.transaction_type = 'OUT' THEN st.quantity ELSE 0 END) AS usage_recorded,
    SUM(CASE WHEN st.transaction_type = 'DAMAGED' THEN st.quantity ELSE 0 END) AS damages_recorded
FROM users u
INNER JOIN roles r ON u.role_id = r.role_id
LEFT JOIN stock_transactions st ON u.user_id = st.user_id
WHERE st.transaction_date BETWEEN ? AND ?
GROUP BY u.user_id, u.user_name, r.role_title
ORDER BY transactions_processed DESC;

-- System logs report
SELECT 
    sl.log_id,
    u.user_name,
    r.role_title,
    sl.action_performed,
    sl.timestamp
FROM system_logs sl
INNER JOIN users u ON sl.user_id = u.user_id
INNER JOIN roles r ON u.role_id = r.role_id
WHERE sl.timestamp BETWEEN ? AND ?
ORDER BY sl.timestamp DESC
LIMIT 100;

-- Most active users (by transaction count)
SELECT 
    u.user_id,
    u.user_name,
    r.role_title,
    COUNT(st.transaction_id) AS transaction_count,
    DATE(MAX(st.transaction_date)) AS last_active_date
FROM users u
INNER JOIN roles r ON u.role_id = r.role_id
INNER JOIN stock_transactions st ON u.user_id = st.user_id
WHERE st.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY u.user_id, u.user_name, r.role_title
ORDER BY transaction_count DESC
LIMIT 10;

-- =========================================
-- STORE REQUEST REPORTS
-- =========================================

-- Store request status report
SELECT 
    sr.request_id,
    sr.requester_id,
    req.user_name AS requester_name,
    sr.approver_id,
    app.user_name AS approver_name,
    sr.status,
    sr.request_date,
    sr.approved_date,
    sr.notes,
    COUNT(rd.detail_id) AS items_count,
    SUM(rd.quantity_requested) AS total_items_requested
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN users app ON sr.approver_id = app.user_id
LEFT JOIN request_details rd ON sr.request_id = rd.request_id
GROUP BY sr.request_id, sr.requester_id, req.user_name, sr.approver_id, app.user_name, 
         sr.status, sr.request_date, sr.approved_date, sr.notes
ORDER BY sr.request_date DESC;

-- Pending requests awaiting approval
SELECT 
    sr.request_id,
    req.user_name AS requester_name,
    sr.request_date,
    sr.notes,
    COUNT(rd.detail_id) AS items_count,
    GROUP_CONCAT(CONCAT(i.item_name, ' (', rd.quantity_requested, ' ', i.unit_type, ')') SEPARATOR '; ') AS requested_items
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN request_details rd ON sr.request_id = rd.request_id
LEFT JOIN items i ON rd.item_id = i.item_id
WHERE sr.status = 'PENDING'
GROUP BY sr.request_id, req.user_name, sr.request_date, sr.notes
ORDER BY sr.request_date ASC;

-- Request approval timeline analysis
SELECT 
    sr.request_id,
    req.user_name AS requester_name,
    sr.request_date,
    sr.approved_date,
    TIMESTAMPDIFF(HOUR, sr.request_date, sr.approved_date) AS approval_time_hours,
    sr.status
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
WHERE sr.status = 'APPROVED'
AND sr.approved_date IS NOT NULL
ORDER BY approval_time_hours DESC;

-- =========================================
-- CATEGORY ANALYSIS REPORTS
-- =========================================

-- Category-wise stock summary
SELECT 
    c.category_id,
    c.category_name,
    COUNT(i.item_id) AS item_count,
    SUM(i.current_stock) AS total_stock,
    SUM(CASE WHEN i.current_stock < i.reorder_level THEN 1 ELSE 0 END) AS low_stock_items,
    SUM(CASE WHEN i.current_stock = 0 THEN 1 ELSE 0 END) AS out_of_stock_items
FROM categories c
LEFT JOIN items i ON c.category_id = i.category_id AND i.status IN ('AVAILABLE', 'LOW_STOCK', 'OUT_OF_STOCK')
GROUP BY c.category_id, c.category_name
ORDER BY total_stock DESC;

-- Category consumption analysis
SELECT 
    c.category_name,
    COUNT(DISTINCT st.item_id) AS items_consumed,
    SUM(st.quantity) AS total_consumed,
    COUNT(st.transaction_id) AS transaction_count
FROM categories c
INNER JOIN items i ON c.category_id = i.category_id
INNER JOIN stock_transactions st ON i.item_id = st.item_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_date BETWEEN ? AND ?
GROUP BY c.category_id, c.category_name
ORDER BY total_consumed DESC;

-- =========================================
-- PERIODIC REPORTS
-- =========================================

-- Daily summary report
SELECT 
    'Supplies Received' AS metric,
    COUNT(*) AS count,
    SUM(quantity) AS total_quantity
FROM stock_transactions
WHERE transaction_type = 'IN' AND DATE(transaction_date) = CURDATE()

UNION ALL

SELECT 
    'Items Consumed' AS metric,
    COUNT(*) AS count,
    SUM(quantity) AS total_quantity
FROM stock_transactions
WHERE transaction_type = 'OUT' AND DATE(transaction_date) = CURDATE()

UNION ALL

SELECT 
    'Damage Incidents' AS metric,
    COUNT(*) AS count,
    SUM(quantity) AS total_quantity
FROM stock_transactions
WHERE transaction_type = 'DAMAGED' AND DATE(transaction_date) = CURDATE();

-- Monthly executive summary
SELECT 
    YEAR(st.transaction_date) AS year,
    MONTH(st.transaction_date) AS month,
    COUNT(DISTINCT st.transaction_id) AS total_transactions,
    SUM(CASE WHEN st.transaction_type = 'IN' THEN st.quantity ELSE 0 END) AS total_supplied,
    SUM(CASE WHEN st.transaction_type = 'OUT' THEN st.quantity ELSE 0 END) AS total_consumed,
    SUM(CASE WHEN st.transaction_type = 'DAMAGED' THEN st.quantity ELSE 0 END) AS total_damaged,
    COUNT(DISTINCT st.user_id) AS active_users,
    COUNT(DISTINCT sr.request_id) AS total_requests
FROM stock_transactions st
LEFT JOIN store_requests sr ON YEAR(st.transaction_date) = YEAR(sr.request_date) 
    AND MONTH(st.transaction_date) = MONTH(sr.request_date)
WHERE st.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY YEAR(st.transaction_date), MONTH(st.transaction_date)
ORDER BY year DESC, month DESC;

-- =========================================
-- ALERTS AND NOTIFICATIONS
-- =========================================

-- Low stock alerts
SELECT 
    i.item_id,
    i.item_name,
    c.category_name,
    i.current_stock,
    i.reorder_level,
    i.unit_type,
    'LOW STOCK' AS alert_type,
    CONCAT('Only ', i.current_stock, ' ', i.unit_type, ' remaining (Reorder level: ', i.reorder_level, ')') AS alert_message
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.current_stock < i.reorder_level
AND i.status = 'AVAILABLE'
ORDER BY (i.reorder_level - i.current_stock) DESC;

-- Out of stock alerts
SELECT 
    i.item_id,
    i.item_name,
    c.category_name,
    i.current_stock,
    i.unit_type,
    'OUT OF STOCK' AS alert_type,
    CONCAT('Item completely out of stock. Immediate action required.') AS alert_message
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.current_stock = 0
AND i.status = 'AVAILABLE';

-- High damage rate alert (items with >10% damage rate)
SELECT 
    i.item_id,
    i.item_name,
    c.category_name,
    SUM(dl.quantity) AS total_damaged,
    (SUM(dl.quantity) * 100.0 / SUM(COALESCE(st.quantity, dl.quantity))) AS damage_rate,
    'HIGH DAMAGE RATE' AS alert_type
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN damage_log dl ON i.item_id = dl.item_id
LEFT JOIN stock_transactions st ON i.item_id = st.item_id AND st.transaction_type = 'IN'
    AND st.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.item_name, c.category_name
HAVING damage_rate > 10
ORDER BY damage_rate DESC;

-- =========================================
-- CUSTOM DATE RANGE REPORTS
-- =========================================

-- Comprehensive report for custom date range
SELECT 
    'Inventory Summary' AS report_section,
    COUNT(DISTINCT i.item_id) AS total_items,
    SUM(CASE WHEN i.current_stock > 0 THEN 1 ELSE 0 END) AS items_in_stock,
    SUM(CASE WHEN i.current_stock = 0 THEN 1 ELSE 0 END) AS items_out_of_stock,
    SUM(CASE WHEN i.current_stock < i.reorder_level AND i.current_stock > 0 THEN 1 ELSE 0 END) AS items_low_stock
FROM items i
WHERE i.status IN ('AVAILABLE', 'LOW_STOCK', 'OUT_OF_STOCK')

UNION ALL

SELECT 
    'Transactions' AS report_section,
    COUNT(st.transaction_id) AS total_transactions,
    SUM(CASE WHEN st.transaction_type = 'IN' THEN 1 ELSE 0 END) AS supply_transactions,
    SUM(CASE WHEN st.transaction_type = 'OUT' THEN 1 ELSE 0 END) AS usage_transactions,
    SUM(CASE WHEN st.transaction_type = 'DAMAGED' THEN 1 ELSE 0 END) AS damage_transactions
FROM stock_transactions st
WHERE st.transaction_date BETWEEN ? AND ?

UNION ALL

SELECT 
    'Requests' AS report_section,
    COUNT(sr.request_id) AS total_requests,
    SUM(CASE WHEN sr.status = 'APPROVED' THEN 1 ELSE 0 END) AS approved_requests,
    SUM(CASE WHEN sr.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_requests,
    SUM(CASE WHEN sr.status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected_requests
FROM store_requests sr
WHERE sr.request_date BETWEEN ? AND ?;
