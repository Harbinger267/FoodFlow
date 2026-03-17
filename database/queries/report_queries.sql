USE foodflow;

-- INVENTORY REPORTS
SELECT i.item_id, i.name AS item_name, i.category, i.item_type, i.stock, i.unit_of_measure, i.status,
       CASE
           WHEN i.stock = 0 THEN 'CRITICAL'
           WHEN i.stock <= ? THEN 'LOW'
           ELSE 'OK'
       END AS stock_health
FROM items i
WHERE i.status IN ('AVAILABLE', 'OUT_OF_STOCK', 'DAMAGED')
ORDER BY CASE
             WHEN i.stock = 0 THEN 1
             WHEN i.stock <= ? THEN 2
             ELSE 3
         END,
         i.name ASC;

SELECT category, item_type, COUNT(item_id) AS item_count, SUM(stock) AS total_stock
FROM items
GROUP BY category, item_type
ORDER BY category ASC, item_type ASC;

-- STOCK MOVEMENT REPORTS
SELECT i.item_id, i.name AS item_name, i.category, i.item_type,
       COALESCE(sup.total_in, 0) AS supplied,
       COALESCE(iss.total_issued, 0) AS issued,
       COALESCE(bor.total_borrowed, 0) AS borrowed,
       COALESCE(bor.total_returned, 0) AS returned,
       COALESCE(dmg.total_damaged, 0) AS damaged,
       (COALESCE(sup.total_in, 0) + COALESCE(bor.total_returned, 0)
        - COALESCE(iss.total_issued, 0) - COALESCE(bor.total_borrowed, 0) - COALESCE(dmg.total_damaged, 0)) AS net_change
FROM items i
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_in
    FROM supply
    WHERE supply_date BETWEEN ? AND ?
    GROUP BY item_id
) sup ON i.item_id = sup.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity_issued) AS total_issued
    FROM issue_transactions
    WHERE issued_date BETWEEN ? AND ?
    GROUP BY item_id
) iss ON i.item_id = iss.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity_borrowed) AS total_borrowed, SUM(quantity_returned) AS total_returned
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

SELECT 'SUPPLY' AS event_type, s.supply_id AS event_id, s.supply_date AS event_date,
       s.quantity AS quantity, 0 AS quantity_returned, s.supplier AS details,
       COALESCE(u.name, 'N/A') AS processed_by
FROM supply s
LEFT JOIN users u ON s.recorded_by = u.user_id
WHERE s.item_id = ?

UNION ALL

SELECT 'ISSUE' AS event_type, it.issue_id AS event_id, it.issued_date AS event_date,
       it.quantity_issued AS quantity, 0 AS quantity_returned, it.issued_to AS details,
       COALESCE(u.name, 'N/A') AS processed_by
FROM issue_transactions it
LEFT JOIN users u ON it.issued_by = u.user_id
WHERE it.item_id = ?

UNION ALL

SELECT 'BORROW' AS event_type, bt.borrow_id AS event_id, bt.borrow_date AS event_date,
       bt.quantity_borrowed AS quantity, bt.quantity_returned AS quantity_returned,
       CONCAT(bt.borrower_name, ' | ', bt.status) AS details,
       COALESCE(u.name, 'N/A') AS processed_by
FROM borrow_transactions bt
LEFT JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.item_id = ?

UNION ALL

SELECT 'DAMAGE' AS event_type, dl.damage_id AS event_id, dl.damage_date AS event_date,
       dl.quantity AS quantity, 0 AS quantity_returned,
       COALESCE(dl.description, 'N/A') AS details,
       COALESCE(u.name, 'N/A') AS processed_by
FROM damage_log dl
LEFT JOIN users u ON dl.reported_by = u.user_id
WHERE dl.item_id = ?

ORDER BY event_date DESC;

-- USER ACTIVITY REPORTS
SELECT u.user_id, u.name, u.role,
       COALESCE(s.supplies_recorded, 0) AS supplies_recorded,
       COALESCE(it.issues_recorded, 0) AS issues_recorded,
       COALESCE(b.borrows_recorded, 0) AS borrows_recorded,
       COALESCE(d.damages_reported, 0) AS damages_reported,
       (COALESCE(s.supplies_recorded, 0) + COALESCE(it.issues_recorded, 0)
        + COALESCE(b.borrows_recorded, 0) + COALESCE(d.damages_reported, 0)) AS total_actions
FROM users u
LEFT JOIN (
    SELECT recorded_by AS user_id, COUNT(*) AS supplies_recorded
    FROM supply
    WHERE supply_date BETWEEN ? AND ?
    GROUP BY recorded_by
) s ON u.user_id = s.user_id
LEFT JOIN (
    SELECT issued_by AS user_id, COUNT(*) AS issues_recorded
    FROM issue_transactions
    WHERE issued_date BETWEEN ? AND ?
    GROUP BY issued_by
) it ON u.user_id = it.user_id
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

SELECT sl.log_id, COALESCE(u.name, 'N/A') AS user_name, COALESCE(u.role, 'N/A') AS role,
       sl.action_performed, sl.timestamp
FROM system_logs sl
LEFT JOIN users u ON sl.user_id = u.user_id
WHERE sl.timestamp BETWEEN ? AND ?
ORDER BY sl.timestamp DESC
LIMIT 200;

-- STORE REQUEST REPORTS
SELECT sr.request_id, sr.requester_id, req.name AS requester_name,
       sr.approver_id, COALESCE(app.name, 'N/A') AS approver_name,
       sr.status, sr.request_date, sr.approved_date, sr.notes,
       COUNT(rd.detail_id) AS line_items,
       COALESCE(SUM(rd.quantity_requested), 0) AS total_quantity_requested,
       COALESCE(SUM(rd.quantity_approved), 0) AS total_quantity_approved
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN users app ON sr.approver_id = app.user_id
LEFT JOIN request_details rd ON sr.request_id = rd.request_id
GROUP BY sr.request_id, sr.requester_id, req.name, sr.approver_id, app.name,
         sr.status, sr.request_date, sr.approved_date, sr.notes
ORDER BY sr.request_date DESC;

SELECT sr.request_id, req.name AS requester_name, sr.request_date, sr.notes,
       COUNT(rd.detail_id) AS line_items,
       GROUP_CONCAT(CONCAT(i.name, ' (', rd.quantity_requested, ' ', i.unit_of_measure, ')') SEPARATOR '; ') AS requested_items
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN request_details rd ON sr.request_id = rd.request_id
LEFT JOIN items i ON rd.item_id = i.item_id
WHERE sr.status = 'PENDING'
GROUP BY sr.request_id, req.name, sr.request_date, sr.notes
ORDER BY sr.request_date ASC;

SELECT sr.request_id, req.name AS requester_name, COALESCE(app.name, 'N/A') AS approver_name,
       sr.request_date, sr.approved_date,
       TIMESTAMPDIFF(HOUR, sr.request_date, sr.approved_date) AS approval_time_hours,
       sr.status
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN users app ON sr.approver_id = app.user_id
WHERE sr.status = 'APPROVED' AND sr.approved_date IS NOT NULL
ORDER BY approval_time_hours DESC;

-- PERIODIC SNAPSHOT REPORTS
SELECT 'SUPPLIES_RECORDED' AS metric, COUNT(*) AS event_count, COALESCE(SUM(quantity), 0) AS total_quantity
FROM supply
WHERE DATE(supply_date) = CURDATE()

UNION ALL

SELECT 'ISSUED' AS metric, COUNT(*) AS event_count, COALESCE(SUM(quantity_issued), 0) AS total_quantity
FROM issue_transactions
WHERE DATE(issued_date) = CURDATE()

UNION ALL

SELECT 'BORROWED' AS metric, COUNT(*) AS event_count, COALESCE(SUM(quantity_borrowed), 0) AS total_quantity
FROM borrow_transactions
WHERE DATE(borrow_date) = CURDATE()

UNION ALL

SELECT 'RETURNED' AS metric, COUNT(*) AS event_count, COALESCE(SUM(quantity_returned), 0) AS total_quantity
FROM borrow_transactions
WHERE DATE(return_date) = CURDATE()

UNION ALL

SELECT 'DAMAGED' AS metric, COUNT(*) AS event_count, COALESCE(SUM(quantity), 0) AS total_quantity
FROM damage_log
WHERE DATE(damage_date) = CURDATE();