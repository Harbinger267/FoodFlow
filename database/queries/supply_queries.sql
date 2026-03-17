USE foodflow;

-- =========================================
-- CREATE OPERATIONS
-- =========================================

-- Record new supply receipt
INSERT INTO supply (item_id, quantity, supplier, supply_date, recorded_by)
VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?);

-- Update item stock after supply receipt
UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all supply records
SELECT
    s.supply_id,
    s.item_id,
    i.name AS item_name,
    i.category,
    i.unit_of_measure,
    s.quantity,
    s.supplier,
    s.supply_date,
    s.recorded_by,
    u.name AS recorded_by_name,
    u.role AS recorded_by_role
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
INNER JOIN users u ON s.recorded_by = u.user_id
ORDER BY s.supply_date DESC;

-- Get supply record by ID
SELECT
    s.supply_id,
    s.item_id,
    i.name AS item_name,
    i.category,
    i.unit_of_measure,
    s.quantity,
    s.supplier,
    s.supply_date,
    u.name AS recorded_by_name,
    u.email AS recorded_by_email
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
INNER JOIN users u ON s.recorded_by = u.user_id
WHERE s.supply_id = ?;

-- Get supplies by date range
SELECT
    s.supply_id,
    s.item_id,
    i.name AS item_name,
    i.category,
    i.unit_of_measure,
    s.quantity,
    s.supplier,
    s.supply_date,
    u.name AS recorded_by_name
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
INNER JOIN users u ON s.recorded_by = u.user_id
WHERE s.supply_date BETWEEN ? AND ?
ORDER BY s.supply_date DESC;

-- Get supplies by item
SELECT
    s.supply_id,
    s.quantity,
    s.supplier,
    s.supply_date,
    u.name AS recorded_by_name
FROM supply s
INNER JOIN users u ON s.recorded_by = u.user_id
WHERE s.item_id = ?
ORDER BY s.supply_date DESC;

-- Get supplies by user
SELECT
    s.supply_id,
    s.item_id,
    i.name AS item_name,
    s.quantity,
    s.supplier,
    s.supply_date
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
WHERE s.recorded_by = ?
ORDER BY s.supply_date DESC;

-- Total supplies per item (date range)
SELECT
    i.item_id,
    i.name,
    i.unit_of_measure,
    COALESCE(SUM(s.quantity), 0) AS total_received,
    COUNT(s.supply_id) AS supply_count
FROM items i
LEFT JOIN supply s ON i.item_id = s.item_id
    AND s.supply_date BETWEEN ? AND ?
GROUP BY i.item_id, i.name, i.unit_of_measure
ORDER BY total_received DESC;

-- Daily supply summary
SELECT
    DATE(s.supply_date) AS supply_day,
    COUNT(s.supply_id) AS transaction_count,
    SUM(s.quantity) AS total_quantity
FROM supply s
GROUP BY DATE(s.supply_date)
ORDER BY supply_day DESC;

-- Monthly supply summary
SELECT
    YEAR(s.supply_date) AS year,
    MONTH(s.supply_date) AS month,
    COUNT(s.supply_id) AS transaction_count,
    SUM(s.quantity) AS total_quantity
FROM supply s
GROUP BY YEAR(s.supply_date), MONTH(s.supply_date)
ORDER BY year DESC, month DESC;

-- Supplies by supplier (date range)
SELECT
    s.supplier,
    COUNT(s.supply_id) AS delivery_count,
    SUM(s.quantity) AS total_quantity
FROM supply s
WHERE s.supply_date BETWEEN ? AND ?
GROUP BY s.supplier
ORDER BY total_quantity DESC;

-- =========================================
-- UPDATE OPERATIONS
-- =========================================

-- Update supplier name
UPDATE supply
SET supplier = ?
WHERE supply_id = ?;

-- Correct supply quantity
UPDATE supply
SET quantity = ?
WHERE supply_id = ?;

-- =========================================
-- DELETE OPERATIONS
-- =========================================

-- Reverse stock effect before deleting supply record
UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

-- Delete supply record
DELETE FROM supply
WHERE supply_id = ?;

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Average daily supply over last 30 days
SELECT
    AVG(daily_total) AS avg_daily_supply
FROM (
    SELECT
        DATE(supply_date) AS day,
        SUM(quantity) AS daily_total
    FROM supply
    WHERE supply_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY DATE(supply_date)
) AS daily_supplies;

-- Compare current month vs previous month supply volume
SELECT
    'Current Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_quantity
FROM supply
WHERE YEAR(supply_date) = YEAR(CURDATE())
AND MONTH(supply_date) = MONTH(CURDATE())

UNION ALL

SELECT
    'Previous Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_quantity
FROM supply
WHERE YEAR(supply_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
AND MONTH(supply_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));