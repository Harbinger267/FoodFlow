USE foodflow;

-- =========================================
-- INVENTORY REPORTS
-- =========================================

-- Current inventory status report
SELECT
    i.item_id,
    i.name AS item_name,
    i.category,
    i.stock,
    i.unit_of_measure,
    i.status,
    CASE
        WHEN i.stock = 0 THEN 'CRITICAL'
        WHEN i.status = 'LOW_STOCK' THEN 'LOW'
        ELSE 'OK'
    END AS stock_health
FROM items i
WHERE i.status IN ('AVAILABLE', 'LOW_STOCK', 'OUT_OF_STOCK')
ORDER BY
    CASE
        WHEN i.stock = 0 THEN 1
        WHEN i.status = 'LOW_STOCK' THEN 2
        ELSE 3
    END,
    i.name ASC;

-- Inventory summary by category
SELECT
    i.category,
    COUNT(i.item_id) AS item_count,
    SUM(i.stock) AS total_stock
FROM items i
GROUP BY i.category
ORDER BY total_stock DESC;

-- =========================================
-- STOCK MOVEMENT REPORTS
-- =========================================

-- Stock movement summary for a period
SELECT
    i.item_id,
    i.name AS item_name,
    i.category,
    COALESCE(sup.total_in, 0) AS stock_in,
    COALESCE(bor.total_out, 0) AS borrowed_out,
    COALESCE(bor.total_returned, 0) AS returned_in,
    COALESCE(dmg.total_damaged, 0) AS damaged_out,
    (COALESCE(sup.total_in, 0) + COALESCE(bor.total_returned, 0) - COALESCE(bor.total_out, 0) - COALESCE(dmg.total_damaged, 0)) AS net_change
FROM items i
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_in
    FROM supply
    WHERE supply_date BETWEEN ? AND ?
    GROUP BY item_id
) sup ON i.item_id = sup.item_id
LEFT JOIN (
    SELECT item_id,
           SUM(quantity_borrowed) AS total_out,
           SUM(quantity_returned) AS total_returned
    FROM borrow_transactions
    WHERE borrow_date BETWEEN ? AND ?
    GROUP BY item_id
) bor ON i.item_id = bor.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_damaged
    FROM damage_log
    WHERE damage_date BETWEEN ? AND ?
    GROUP BY item_id
) dmg ON i.item_id = dmg.item_id
ORDER BY i.name ASC;

-- Transaction history by item (combined)
SELECT
    'SUPPLY' AS event_type,
    s.supply_id AS event_id,
    s.supply_date AS event_date,
    s.quantity AS quantity,
    0 AS quantity_returned,
    s.supplier AS details,
    u.name AS processed_by
FROM supply s
INNER JOIN users u ON s.recorded_by = u.user_id
WHERE s.item_id = ?

UNION ALL

SELECT
    'BORROW' AS event_type,
    bt.borrow_id AS event_id,
    bt.borrow_date AS event_date,
    bt.quantity_borrowed AS quantity,
    bt.quantity_returned AS quantity_returned,
    bt.status AS details,
    u.name AS processed_by
FROM borrow_transactions bt
INNER JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.item_id = ?

UNION ALL

SELECT
    'DAMAGE' AS event_type,
    dl.damage_id AS event_id,
    dl.damage_date AS event_date,
    dl.quantity AS quantity,
    0 AS quantity_returned,
    dl.description AS details,
    u.name AS processed_by
FROM damage_log dl
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.item_id = ?

ORDER BY event_date DESC;

-- =========================================
-- USER ACTIVITY REPORTS
-- =========================================

-- User activity summary across supply/borrow/damage
SELECT
    u.user_id,
    u.name,
    u.role,
    COALESCE(s.supplies_recorded, 0) AS supplies_recorded,
    COALESCE(b.borrows_recorded, 0) AS borrows_recorded,
    COALESCE(d.damages_reported, 0) AS damages_reported,
    (COALESCE(s.supplies_recorded, 0) + COALESCE(b.borrows_recorded, 0) + COALESCE(d.damages_reported, 0)) AS total_actions
FROM users u
LEFT JOIN (
    SELECT recorded_by AS user_id, COUNT(*) AS supplies_recorded
    FROM supply
    WHERE supply_date BETWEEN ? AND ?
    GROUP BY recorded_by
) s ON u.user_id = s.user_id
LEFT JOIN (
    SELECT recorded_by AS user_id, COUNT(*) AS borrows_recorded
    FROM borrow_transactions
    WHERE borrow_date BETWEEN ? AND ?
    GROUP BY recorded_by
) b ON u.user_id = b.user_id
LEFT JOIN (
    SELECT reported_by AS user_id, COUNT(*) AS damages_reported
    FROM damage_log
    WHERE damage_date BETWEEN ? AND ?
    GROUP BY reported_by
) d ON u.user_id = d.user_id
ORDER BY total_actions DESC, u.name ASC;

-- System logs report
SELECT
    sl.log_id,
    u.name AS user_name,
    u.role,
    sl.action_performed,
    sl.timestamp
FROM system_logs sl
INNER JOIN users u ON sl.user_id = u.user_id
WHERE sl.timestamp BETWEEN ? AND ?
ORDER BY sl.timestamp DESC
LIMIT 200;

-- =========================================
-- STORE REQUEST REPORTS
-- =========================================

-- Store request status report
SELECT
    sr.request_id,
    sr.requester_id,
    req.name AS requester_name,
    sr.approver_id,
    app.name AS approver_name,
    sr.status,
    sr.request_date,
    sr.approved_date,
    sr.notes,
    COUNT(rd.detail_id) AS line_items,
    COALESCE(SUM(rd.quantity_requested), 0) AS total_quantity_requested,
    COALESCE(SUM(rd.quantity_approved), 0) AS total_quantity_approved
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN users app ON sr.approver_id = app.user_id
LEFT JOIN request_details rd ON sr.request_id = rd.request_id
GROUP BY
    sr.request_id,
    sr.requester_id,
    req.name,
    sr.approver_id,
    app.name,
    sr.status,
    sr.request_date,
    sr.approved_date,
    sr.notes
ORDER BY sr.request_date DESC;

-- Pending requests with item breakdown
SELECT
    sr.request_id,
    req.name AS requester_name,
    sr.request_date,
    sr.notes,
    COUNT(rd.detail_id) AS line_items,
    GROUP_CONCAT(
        CONCAT(i.name, ' (', rd.quantity_requested, ' ', i.unit_of_measure, ')')
        SEPARATOR '; '
    ) AS requested_items
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN request_details rd ON sr.request_id = rd.request_id
LEFT JOIN items i ON rd.item_id = i.item_id
WHERE sr.status = 'PENDING'
GROUP BY sr.request_id, req.name, sr.request_date, sr.notes
ORDER BY sr.request_date ASC;

-- Approval timeline (hours)
SELECT
    sr.request_id,
    req.name AS requester_name,
    app.name AS approver_name,
    sr.request_date,
    sr.approved_date,
    TIMESTAMPDIFF(HOUR, sr.request_date, sr.approved_date) AS approval_time_hours,
    sr.status
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN users app ON sr.approver_id = app.user_id
WHERE sr.status = 'APPROVED'
AND sr.approved_date IS NOT NULL
ORDER BY approval_time_hours DESC;

-- =========================================
-- PERIODIC SNAPSHOT REPORTS
-- =========================================

-- Daily summary
SELECT
    'SUPPLIES_RECORDED' AS metric,
    COUNT(*) AS event_count,
    COALESCE(SUM(quantity), 0) AS total_quantity
FROM supply
WHERE DATE(supply_date) = CURDATE()

UNION ALL

SELECT
    'BORROWED_OUT' AS metric,
    COUNT(*) AS event_count,
    COALESCE(SUM(quantity_borrowed), 0) AS total_quantity
FROM borrow_transactions
WHERE DATE(borrow_date) = CURDATE()

UNION ALL

SELECT
    'RETURNED_IN' AS metric,
    COUNT(*) AS event_count,
    COALESCE(SUM(quantity_returned), 0) AS total_quantity
FROM borrow_transactions
WHERE DATE(return_date) = CURDATE()

UNION ALL

SELECT
    'DAMAGED' AS metric,
    COUNT(*) AS event_count,
    COALESCE(SUM(quantity), 0) AS total_quantity
FROM damage_log
WHERE DATE(damage_date) = CURDATE();

-- Monthly executive summary
SELECT
    YEAR(period_date) AS year,
    MONTH(period_date) AS month,
    SUM(supplied_qty) AS total_supplied,
    SUM(borrowed_qty) AS total_borrowed,
    SUM(returned_qty) AS total_returned,
    SUM(damaged_qty) AS total_damaged
FROM (
    SELECT DATE(supply_date) AS period_date, SUM(quantity) AS supplied_qty, 0 AS borrowed_qty, 0 AS returned_qty, 0 AS damaged_qty
    FROM supply
    WHERE supply_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE(supply_date)

    UNION ALL

    SELECT DATE(borrow_date) AS period_date, 0 AS supplied_qty, SUM(quantity_borrowed) AS borrowed_qty, SUM(quantity_returned) AS returned_qty, 0 AS damaged_qty
    FROM borrow_transactions
    WHERE borrow_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE(borrow_date)

    UNION ALL

    SELECT DATE(damage_date) AS period_date, 0 AS supplied_qty, 0 AS borrowed_qty, 0 AS returned_qty, SUM(quantity) AS damaged_qty
    FROM damage_log
    WHERE damage_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
    GROUP BY DATE(damage_date)
) movement
GROUP BY YEAR(period_date), MONTH(period_date)
ORDER BY year DESC, month DESC;