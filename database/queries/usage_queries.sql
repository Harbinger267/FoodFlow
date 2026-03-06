
USE foodflow;

-- =========================================
-- CREATE OPERATIONS
-- =========================================

-- Record usage/consumption (stock OUT)
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, transaction_date, reference_id, notes)
VALUES (?, ?, 'OUT', ?, CURRENT_TIMESTAMP, ?, ?);

-- Update item stock after usage
UPDATE items 
SET current_stock = current_stock - ?
WHERE item_id = ?
AND current_stock >= ?;

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all usage transactions (stock OUT)
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    i.unit_type,
    st.quantity,
    st.transaction_date,
    st.user_id,
    u.user_name AS recorded_by,
    r.role_title AS recorded_by_role,
    st.reference_id,
    st.notes
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN users u ON st.user_id = u.user_id
INNER JOIN roles r ON u.role_id = r.role_id
WHERE st.transaction_type = 'OUT'
ORDER BY st.transaction_date DESC;

-- Get usage transaction by ID
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    i.unit_type,
    st.quantity,
    st.transaction_date,
    st.user_id,
    u.user_name AS recorded_by,
    u.email_address AS recorded_by_email,
    st.reference_id,
    st.notes
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_id = ?;

-- Get usage by date range
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    c.category_name,
    st.quantity,
    i.unit_type,
    st.transaction_date,
    u.user_name AS recorded_by,
    st.notes
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_date BETWEEN ? AND ?
ORDER BY st.transaction_date DESC;

-- Get usage by item
SELECT 
    st.transaction_id,
    st.quantity,
    st.transaction_date,
    u.user_name AS recorded_by,
    st.notes
FROM stock_transactions st
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'OUT'
AND st.item_id = ?
ORDER BY st.transaction_date DESC;

-- Get usage by user who recorded
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    st.quantity,
    st.transaction_date,
    st.notes
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
WHERE st.transaction_type = 'OUT'
AND st.user_id = ?
ORDER BY st.transaction_date DESC;

-- Get total usage per item (within date range)
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    COALESCE(SUM(st.quantity), 0) AS total_consumed,
    COUNT(st.transaction_id) AS usage_count
FROM items i
LEFT JOIN stock_transactions st ON i.item_id = st.item_id 
    AND st.transaction_type = 'OUT'
    AND st.transaction_date BETWEEN ? AND ?
WHERE i.status = 'AVAILABLE'
GROUP BY i.item_id, i.item_name, i.unit_type
ORDER BY total_consumed DESC;

-- Get daily usage summary
SELECT 
    DATE(st.transaction_date) AS usage_date,
    COUNT(st.transaction_id) AS transaction_count,
    SUM(st.quantity) AS total_quantity
FROM stock_transactions st
WHERE st.transaction_type = 'OUT'
GROUP BY DATE(st.transaction_date)
ORDER BY usage_date DESC;

-- Get monthly usage summary
SELECT 
    YEAR(st.transaction_date) AS year,
    MONTH(st.transaction_date) AS month,
    COUNT(st.transaction_id) AS transaction_count,
    SUM(st.quantity) AS total_quantity
FROM stock_transactions st
WHERE st.transaction_type = 'OUT'
GROUP BY YEAR(st.transaction_date), MONTH(st.transaction_date)
ORDER BY year DESC, month DESC;

-- Get usage by category (within date range)
SELECT 
    c.category_id,
    c.category_name,
    COUNT(st.transaction_id) AS transaction_count,
    SUM(st.quantity) AS total_quantity
FROM categories c
LEFT JOIN items i ON c.category_id = i.category_id
LEFT JOIN stock_transactions st ON i.item_id = st.item_id 
    AND st.transaction_type = 'OUT'
    AND st.transaction_date BETWEEN ? AND ?
GROUP BY c.category_id, c.category_name
ORDER BY total_quantity DESC;

-- Get recent usage (last 7 days)
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    st.quantity,
    st.transaction_date,
    u.user_name AS recorded_by
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
ORDER BY st.transaction_date DESC;

-- Get usage linked to store requests
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    st.quantity,
    st.transaction_date,
    sr.request_id,
    sr.status AS request_status,
    u.user_name AS recorded_by
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN users u ON st.user_id = u.user_id
LEFT JOIN store_requests sr ON st.reference_id = sr.request_id
WHERE st.transaction_type = 'OUT'
AND st.reference_id IS NOT NULL
ORDER BY st.transaction_date DESC;

-- =========================================
-- UPDATE OPERATIONS
-- =========================================

-- Update usage transaction notes
UPDATE stock_transactions
SET notes = ?
WHERE transaction_id = ?
AND transaction_type = 'OUT';

-- Correct usage quantity (with audit trail - recommended to create adjustment transaction instead)
UPDATE stock_transactions
SET quantity = ?
WHERE transaction_id = ?
AND transaction_type = 'OUT';

-- =========================================
-- DELETE OPERATIONS
-- =========================================

-- Void a usage transaction (soft delete - recommended)
UPDATE stock_transactions
SET notes = CONCAT(notes, ' [VOIDED]')
WHERE transaction_id = ?
AND transaction_type = 'OUT';

-- Remove usage transaction and adjust stock (use with caution)
-- Step 1: Get the quantity to reverse
-- Step 2: Update items stock
UPDATE items 
SET current_stock = current_stock + ?
WHERE item_id = ?;

-- Step 3: Delete transaction
DELETE FROM stock_transactions
WHERE transaction_id = ?
AND transaction_type = 'OUT';

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Get average daily consumption
SELECT 
    AVG(daily_total) AS avg_daily_consumption
FROM (
    SELECT 
        DATE(transaction_date) AS day,
        SUM(quantity) AS daily_total
    FROM stock_transactions
    WHERE transaction_type = 'OUT'
    AND transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY DATE(transaction_date)
) AS daily_usage;

-- Get consumption rate by item (units per day)
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    SUM(st.quantity) AS total_consumed,
    DATEDIFF(MAX(st.transaction_date), MIN(st.transaction_date)) AS days_tracked,
    CASE 
        WHEN DATEDIFF(MAX(st.transaction_date), MIN(st.transaction_date)) > 0 
        THEN SUM(st.quantity) / DATEDIFF(MAX(st.transaction_date), MIN(st.transaction_date))
        ELSE SUM(st.quantity)
    END AS avg_daily_consumption
FROM items i
INNER JOIN stock_transactions st ON i.item_id = st.item_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.item_name, i.unit_type
ORDER BY avg_daily_consumption DESC;

-- Compare current month usage vs previous month
SELECT 
    'Current Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_quantity
FROM stock_transactions
WHERE transaction_type = 'OUT'
AND YEAR(transaction_date) = YEAR(CURDATE())
AND MONTH(transaction_date) = MONTH(CURDATE())

UNION ALL

SELECT 
    'Previous Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_quantity
FROM stock_transactions
WHERE transaction_type = 'OUT'
AND YEAR(transaction_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
AND MONTH(transaction_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));

-- Get usage patterns by day of week
SELECT 
    DAYNAME(transaction_date) AS day_of_week,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_quantity,
    AVG(quantity) AS avg_transaction_size
FROM stock_transactions
WHERE transaction_type = 'OUT'
AND transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY DAYNAME(transaction_date), DAYOFWEEK(transaction_date)
ORDER BY DAYOFWEEK(transaction_date);

-- Get top consuming items for specific period
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    c.category_name,
    SUM(st.quantity) AS total_consumed,
    COUNT(st.transaction_id) AS usage_frequency
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN stock_transactions st ON i.item_id = st.item_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_date BETWEEN ? AND ?
GROUP BY i.item_id, i.item_name, i.unit_type, c.category_name
ORDER BY total_consumed DESC
LIMIT 10;

-- Estimate days until stockout based on current consumption
SELECT 
    i.item_id,
    i.item_name,
    i.current_stock,
    i.unit_type,
    COALESCE(usage_stats.avg_daily_consumption, 0) AS avg_daily_consumption,
    CASE 
        WHEN COALESCE(usage_stats.avg_daily_consumption, 0) > 0 
        THEN i.current_stock / usage_stats.avg_daily_consumption
        ELSE NULL
    END AS estimated_days_until_stockout
FROM items i
LEFT JOIN (
    SELECT 
        item_id,
        AVG(daily_consumption) AS avg_daily_consumption
    FROM (
        SELECT 
            item_id,
            DATE(transaction_date) AS day,
            SUM(quantity) AS daily_consumption
        FROM stock_transactions
        WHERE transaction_type = 'OUT'
        AND transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        GROUP BY item_id, DATE(transaction_date)
    ) AS daily_usage
    GROUP BY item_id
) AS usage_stats ON i.item_id = usage_stats.item_id
WHERE i.status = 'AVAILABLE'
ORDER BY estimated_days_until_stockout ASC;
