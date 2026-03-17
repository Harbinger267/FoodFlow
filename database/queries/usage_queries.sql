USE foodflow;

-- =========================================
-- CREATE OPERATIONS
-- =========================================

-- Record a borrow/issue transaction from stock
INSERT INTO borrow_transactions (
    item_id,
    quantity_borrowed,
    quantity_returned,
    borrow_date,
    return_date,
    status,
    recorded_by
)
VALUES (?, ?, 0, CURRENT_TIMESTAMP, NULL, ?, ?);

-- Reduce stock when borrowing/issuing
UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

-- =========================================
-- RETURN OPERATIONS
-- =========================================

-- Register returned quantity and recalculate status
UPDATE borrow_transactions
SET
    quantity_returned = quantity_returned + ?,
    return_date = CURRENT_TIMESTAMP,
    status = CASE
        WHEN (quantity_returned + ?) >= quantity_borrowed THEN 'RETURNED'
        WHEN (quantity_returned + ?) > 0 THEN 'PARTIALLY_RETURNED'
        ELSE status
    END
WHERE borrow_id = ?;

-- Add returned quantity back to stock
UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all borrow transactions
SELECT
    bt.borrow_id,
    bt.item_id,
    i.name AS item_name,
    i.category,
    i.unit_of_measure,
    bt.quantity_borrowed,
    bt.quantity_returned,
    (bt.quantity_borrowed - bt.quantity_returned) AS outstanding_quantity,
    bt.borrow_date,
    bt.return_date,
    bt.status,
    bt.recorded_by,
    u.name AS recorded_by_name,
    u.role AS recorded_by_role
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
INNER JOIN users u ON bt.recorded_by = u.user_id
ORDER BY bt.borrow_date DESC;

-- Get borrow transaction by ID
SELECT
    bt.borrow_id,
    bt.item_id,
    i.name AS item_name,
    i.category,
    i.unit_of_measure,
    bt.quantity_borrowed,
    bt.quantity_returned,
    (bt.quantity_borrowed - bt.quantity_returned) AS outstanding_quantity,
    bt.borrow_date,
    bt.return_date,
    bt.status,
    u.name AS recorded_by_name,
    u.email AS recorded_by_email
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
INNER JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.borrow_id = ?;

-- Get borrow transactions by date range
SELECT
    bt.borrow_id,
    bt.item_id,
    i.name AS item_name,
    i.category,
    bt.quantity_borrowed,
    bt.quantity_returned,
    bt.status,
    bt.borrow_date,
    bt.return_date,
    u.name AS recorded_by_name
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
INNER JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.borrow_date BETWEEN ? AND ?
ORDER BY bt.borrow_date DESC;

-- Get borrow transactions by item
SELECT
    bt.borrow_id,
    bt.quantity_borrowed,
    bt.quantity_returned,
    bt.status,
    bt.borrow_date,
    bt.return_date,
    u.name AS recorded_by_name
FROM borrow_transactions bt
INNER JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.item_id = ?
ORDER BY bt.borrow_date DESC;

-- Get transactions by status
SELECT
    bt.borrow_id,
    bt.item_id,
    i.name AS item_name,
    bt.quantity_borrowed,
    bt.quantity_returned,
    (bt.quantity_borrowed - bt.quantity_returned) AS outstanding_quantity,
    bt.borrow_date,
    bt.return_date,
    bt.status
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
WHERE bt.status = ?
ORDER BY bt.borrow_date DESC;

-- Get open transactions (not fully returned)
SELECT
    bt.borrow_id,
    bt.item_id,
    i.name AS item_name,
    bt.quantity_borrowed,
    bt.quantity_returned,
    (bt.quantity_borrowed - bt.quantity_returned) AS outstanding_quantity,
    bt.borrow_date,
    bt.status,
    u.name AS recorded_by_name
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
INNER JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.status IN ('BORROWED', 'PARTIALLY_RETURNED', 'LOST')
ORDER BY bt.borrow_date ASC;

-- Daily borrow summary
SELECT
    DATE(bt.borrow_date) AS borrow_day,
    COUNT(bt.borrow_id) AS transaction_count,
    SUM(bt.quantity_borrowed) AS total_borrowed,
    SUM(bt.quantity_returned) AS total_returned
FROM borrow_transactions bt
GROUP BY DATE(bt.borrow_date)
ORDER BY borrow_day DESC;

-- =========================================
-- UPDATE OPERATIONS
-- =========================================

-- Mark transaction as lost
UPDATE borrow_transactions
SET status = 'LOST',
    return_date = CURRENT_TIMESTAMP
WHERE borrow_id = ?;

-- Manual status correction
UPDATE borrow_transactions
SET status = ?
WHERE borrow_id = ?;

-- =========================================
-- DELETE OPERATIONS
-- =========================================

-- Restore currently outstanding quantity before deleting record
UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

-- Delete borrow transaction record
DELETE FROM borrow_transactions
WHERE borrow_id = ?;

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Total borrowed/returned by item (date range)
SELECT
    i.item_id,
    i.name,
    i.unit_of_measure,
    COALESCE(SUM(bt.quantity_borrowed), 0) AS total_borrowed,
    COALESCE(SUM(bt.quantity_returned), 0) AS total_returned,
    COALESCE(SUM(bt.quantity_borrowed - bt.quantity_returned), 0) AS total_outstanding
FROM items i
LEFT JOIN borrow_transactions bt ON i.item_id = bt.item_id
    AND bt.borrow_date BETWEEN ? AND ?
GROUP BY i.item_id, i.name, i.unit_of_measure
ORDER BY total_borrowed DESC;

-- Return performance summary
SELECT
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN status = 'RETURNED' THEN 1 ELSE 0 END) AS fully_returned_count,
    SUM(CASE WHEN status = 'PARTIALLY_RETURNED' THEN 1 ELSE 0 END) AS partial_return_count,
    SUM(CASE WHEN status = 'LOST' THEN 1 ELSE 0 END) AS lost_count,
    ROUND((SUM(CASE WHEN status = 'RETURNED' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS return_rate_percent
FROM borrow_transactions;

-- Average turnaround time (hours) for returned items
SELECT
    AVG(TIMESTAMPDIFF(HOUR, borrow_date, return_date)) AS avg_return_hours
FROM borrow_transactions
WHERE return_date IS NOT NULL
AND status IN ('RETURNED', 'PARTIALLY_RETURNED');

-- Compare current month vs previous month borrowing volume
SELECT
    'Current Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity_borrowed) AS total_borrowed
FROM borrow_transactions
WHERE YEAR(borrow_date) = YEAR(CURDATE())
AND MONTH(borrow_date) = MONTH(CURDATE())

UNION ALL

SELECT
    'Previous Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity_borrowed) AS total_borrowed
FROM borrow_transactions
WHERE YEAR(borrow_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
AND MONTH(borrow_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));