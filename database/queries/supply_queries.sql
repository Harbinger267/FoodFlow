
USE foodflow;

-- =========================================
-- CREATE OPERATIONS
-- =========================================

-- Record new supply receipt (stock IN)
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, transaction_date, reference_id, notes)
VALUES (?, ?, 'IN', ?, CURRENT_TIMESTAMP, ?, ?);

-- Update item stock after supply receipt
UPDATE items 
SET current_stock = current_stock + ?
WHERE item_id = ?;

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all supply transactions (stock IN)
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
WHERE st.transaction_type = 'IN'
ORDER BY st.transaction_date DESC;

-- Get supply transaction by ID
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
WHERE st.transaction_type = 'IN'
AND st.transaction_id = ?;

-- Get supplies by date range
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
WHERE st.transaction_type = 'IN'
AND st.transaction_date BETWEEN ? AND ?
ORDER BY st.transaction_date DESC;

-- Get supplies by item
SELECT 
    st.transaction_id,
    st.quantity,
    st.transaction_date,
    u.user_name AS recorded_by,
    st.notes
FROM stock_transactions st
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'IN'
AND st.item_id = ?
ORDER BY st.transaction_date DESC;

-- Get supplies by user who recorded
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    st.quantity,
    st.transaction_date,
    st.notes
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
WHERE st.transaction_type = 'IN'
AND st.user_id = ?
ORDER BY st.transaction_date DESC;

-- Get total supplies received per item (within date range)
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    COALESCE(SUM(st.quantity), 0) AS total_received,
    COUNT(st.transaction_id) AS supply_count
FROM items i
LEFT JOIN stock_transactions st ON i.item_id = st.item_id 
    AND st.transaction_type = 'IN'
    AND st.transaction_date BETWEEN ? AND ?
WHERE i.status = 'AVAILABLE'
GROUP BY i.item_id, i.item_name, i.unit_type
ORDER BY total_received DESC;

-- Get daily supply summary
SELECT 
    DATE(st.transaction_date) AS supply_date,
    COUNT(st.transaction_id) AS transaction_count,
    SUM(st.quantity) AS total_quantity
FROM stock_transactions st
WHERE st.transaction_type = 'IN'
GROUP BY DATE(st.transaction_date)
ORDER BY supply_date DESC;

-- Get monthly supply summary
SELECT 
    YEAR(st.transaction_date) AS year,
    MONTH(st.transaction_date) AS month,
    COUNT(st.transaction_id) AS transaction_count,
    SUM(st.quantity) AS total_quantity
FROM stock_transactions st
WHERE st.transaction_type = 'IN'
GROUP BY YEAR(st.transaction_date), MONTH(st.transaction_date)
ORDER BY year DESC, month DESC;

-- Get supplies by category (within date range)
SELECT 
    c.category_id,
    c.category_name,
    COUNT(st.transaction_id) AS transaction_count,
    SUM(st.quantity) AS total_quantity
FROM categories c
LEFT JOIN items i ON c.category_id = i.category_id
LEFT JOIN stock_transactions st ON i.item_id = st.item_id 
    AND st.transaction_type = 'IN'
    AND st.transaction_date BETWEEN ? AND ?
GROUP BY c.category_id, c.category_name
ORDER BY total_quantity DESC;

-- Get recent supplies (last 7 days)
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
WHERE st.transaction_type = 'IN'
AND st.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
ORDER BY st.transaction_date DESC;

-- =========================================
-- UPDATE OPERATIONS
-- =========================================

-- Update supply transaction notes
UPDATE stock_transactions
SET notes = ?
WHERE transaction_id = ?
AND transaction_type = 'IN';

-- Correct supply quantity (with audit trail - recommended to create adjustment transaction instead)
UPDATE stock_transactions
SET quantity = ?
WHERE transaction_id = ?
AND transaction_type = 'IN';

-- =========================================
-- DELETE OPERATIONS
-- =========================================

-- Void a supply transaction (soft delete - recommended)
UPDATE stock_transactions
SET notes = CONCAT(notes, ' [VOIDED]')
WHERE transaction_id = ?
AND transaction_type = 'IN';

-- Remove supply transaction and adjust stock (use with caution)
-- Step 1: Get the quantity to reverse
-- Step 2: Update items stock
UPDATE items 
SET current_stock = current_stock - ?
WHERE item_id = ?;

-- Step 3: Delete transaction
DELETE FROM stock_transactions
WHERE transaction_id = ?
AND transaction_type = 'IN';

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Get average daily supply receipt
SELECT 
    AVG(daily_total) AS avg_daily_supply
FROM (
    SELECT 
        DATE(transaction_date) AS day,
        SUM(quantity) AS daily_total
    FROM stock_transactions
    WHERE transaction_type = 'IN'
    AND transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY DATE(transaction_date)
) AS daily_supplies;

-- Get supplier performance (if tracking suppliers in notes or separate table)
SELECT 
    SUBSTRING_INDEX(SUBSTRING_INDEX(notes, 'supplier:', -1), ' ', 1) AS supplier_name,
    COUNT(*) AS delivery_count,
    SUM(quantity) AS total_delivered
FROM stock_transactions
WHERE transaction_type = 'IN'
AND notes LIKE '%supplier:%'
GROUP BY supplier_name
ORDER BY total_delivered DESC;

-- Compare current month supplies vs previous month
SELECT 
    'Current Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_quantity
FROM stock_transactions
WHERE transaction_type = 'IN'
AND YEAR(transaction_date) = YEAR(CURDATE())
AND MONTH(transaction_date) = MONTH(CURDATE())

UNION ALL

SELECT 
    'Previous Month' AS period,
    COUNT(*) AS transaction_count,
    SUM(quantity) AS total_quantity
FROM stock_transactions
WHERE transaction_type = 'IN'
AND YEAR(transaction_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
AND MONTH(transaction_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));
