

USE foodflow;

-- Record damage incident (also creates stock transaction)
INSERT INTO damage_log (item_id, quantity, damage_date, description, reported_by)
VALUES (?, ?, CURRENT_TIMESTAMP, ?, ?);

-- Record damage as stock transaction
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, transaction_date, reference_id, notes)
VALUES (?, ?, 'DAMAGED', ?, CURRENT_TIMESTAMP, LAST_INSERT_ID(), ?);

-- Update item stock after damage
UPDATE items 
SET current_stock = current_stock - ?
WHERE item_id = ?
AND current_stock >= ?;

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all damage incidents with details
SELECT 
    dl.damage_id,
    dl.item_id,
    i.item_name,
    i.unit_type,
    dl.quantity,
    dl.damage_date,
    dl.description,
    dl.reported_by,
    u.user_name AS reported_by_name,
    r.role_title AS reported_by_role,
    c.category_name
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN users u ON dl.reported_by = u.user_id
INNER JOIN roles r ON u.role_id = r.role_id
INNER JOIN categories c ON i.category_id = c.category_id
ORDER BY dl.damage_date DESC;

-- Get damage incident by ID
SELECT 
    dl.damage_id,
    dl.item_id,
    i.item_name,
    i.unit_type,
    dl.quantity,
    dl.damage_date,
    dl.description,
    dl.reported_by,
    u.user_name AS reported_by_name,
    u.email_address AS reported_by_email
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_id = ?;

-- Get damage reports by date range
SELECT 
    dl.damage_id,
    dl.item_id,
    i.item_name,
    c.category_name,
    dl.quantity,
    dl.damage_date,
    dl.description,
    u.user_name AS reported_by
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_date BETWEEN ? AND ?
ORDER BY dl.damage_date DESC;

-- Get damage reports by item
SELECT 
    dl.damage_id,
    dl.quantity,
    dl.damage_date,
    dl.description,
    u.user_name AS reported_by
FROM damage_log dl
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.item_id = ?
ORDER BY dl.damage_date DESC;

-- Get damage reports by user who reported
SELECT 
    dl.damage_id,
    dl.item_id,
    i.item_name,
    dl.quantity,
    dl.damage_date,
    dl.description
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
WHERE dl.reported_by = ?
ORDER BY dl.damage_date DESC;

-- Get total damages per item (within date range)
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    COALESCE(SUM(dl.quantity), 0) AS total_damaged,
    COUNT(dl.damage_id) AS damage_count
FROM items i
LEFT JOIN damage_log dl ON i.item_id = dl.item_id 
    AND dl.damage_date BETWEEN ? AND ?
WHERE i.status = 'AVAILABLE'
GROUP BY i.item_id, i.item_name, i.unit_type
HAVING damage_count > 0
ORDER BY total_damaged DESC;

-- Get daily damage summary
SELECT 
    DATE(dl.damage_date) AS damage_date,
    COUNT(dl.damage_id) AS incident_count,
    SUM(dl.quantity) AS total_damaged
FROM damage_log dl
GROUP BY DATE(dl.damage_date)
ORDER BY damage_date DESC;

-- Get monthly damage summary
SELECT 
    YEAR(dl.damage_date) AS year,
    MONTH(dl.damage_date) AS month,
    COUNT(dl.damage_id) AS incident_count,
    SUM(dl.quantity) AS total_damaged
FROM damage_log dl
GROUP BY YEAR(dl.damage_date), MONTH(dl.damage_date)
ORDER BY year DESC, month DESC;

-- Get damages by category (within date range)
SELECT 
    c.category_id,
    c.category_name,
    COUNT(dl.damage_id) AS incident_count,
    SUM(dl.quantity) AS total_damaged,
    COUNT(DISTINCT dl.item_id) AS affected_items
FROM categories c
LEFT JOIN items i ON c.category_id = i.category_id
LEFT JOIN damage_log dl ON i.item_id = dl.item_id 
    AND dl.damage_date BETWEEN ? AND ?
GROUP BY c.category_id, c.category_name
ORDER BY total_damaged DESC;

-- Get recent damages (last 7 days)
SELECT 
    dl.damage_id,
    dl.item_id,
    i.item_name,
    dl.quantity,
    dl.damage_date,
    dl.description,
    u.user_name AS reported_by
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
ORDER BY dl.damage_date DESC;

-- Get damage transactions from stock_transactions table
SELECT 
    st.transaction_id,
    st.item_id,
    i.item_name,
    i.unit_type,
    st.quantity,
    st.transaction_date,
    u.user_name AS recorded_by,
    st.notes
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'DAMAGED'
ORDER BY st.transaction_date DESC;

-- =========================================
-- UPDATE OPERATIONS
-- =========================================

-- Update damage report description
UPDATE damage_log
SET description = ?
WHERE damage_id = ?;

-- =========================================
-- DELETE OPERATIONS
-- =========================================

-- Remove damage record and adjust stock (use with caution)
-- Step 1: Get the quantity to restore
-- Step 2: Update items stock
UPDATE items 
SET current_stock = current_stock + ?
WHERE item_id = ?;

-- Step 3: Delete damage log entry
DELETE FROM damage_log
WHERE damage_id = ?;

-- Note: Also delete corresponding stock transaction if it exists
DELETE FROM stock_transactions
WHERE reference_id = ?
AND transaction_type = 'DAMAGED';

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Get damage rate by item (percentage of stock damaged)
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    SUM(COALESCE(dl.quantity, 0)) AS total_damaged,
    MAX(i.current_stock) AS current_stock,
    CASE 
        WHEN (SUM(COALESCE(st_in.quantity, 0)) + MAX(i.current_stock)) > 0 
        THEN (SUM(COALESCE(dl.quantity, 0)) * 100.0) / (SUM(COALESCE(st_in.quantity, 0)) + MAX(i.current_stock))
        ELSE 0
    END AS damage_percentage
FROM items i
LEFT JOIN damage_log dl ON i.item_id = dl.item_id
LEFT JOIN stock_transactions st_in ON i.item_id = st_in.item_id AND st_in.transaction_type = 'IN'
WHERE i.status = 'AVAILABLE'
GROUP BY i.item_id, i.item_name, i.unit_type
HAVING total_damaged > 0
ORDER BY damage_percentage DESC;

-- Compare current month damages vs previous month
SELECT 
    'Current Month' AS period,
    COUNT(*) AS incident_count,
    SUM(quantity) AS total_damaged
FROM damage_log
WHERE YEAR(damage_date) = YEAR(CURDATE())
AND MONTH(damage_date) = MONTH(CURDATE())

UNION ALL

SELECT 
    'Previous Month' AS period,
    COUNT(*) AS incident_count,
    SUM(quantity) AS total_damaged
FROM damage_log
WHERE YEAR(damage_date) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
AND MONTH(damage_date) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH));

-- Get damage patterns by day of week
SELECT 
    DAYNAME(damage_date) AS day_of_week,
    COUNT(*) AS incident_count,
    SUM(quantity) AS total_damaged,
    AVG(quantity) AS avg_damage_size
FROM damage_log
WHERE damage_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY DAYNAME(damage_date), DAYOFWEEK(damage_date)
ORDER BY DAYOFWEEK(damage_date);

-- Get top damaged items for specific period
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    c.category_name,
    SUM(dl.quantity) AS total_damaged,
    COUNT(dl.damage_id) AS damage_frequency
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN damage_log dl ON i.item_id = dl.item_id
WHERE dl.damage_date BETWEEN ? AND ?
GROUP BY i.item_id, i.item_name, i.unit_type, c.category_name
ORDER BY total_damaged DESC
LIMIT 10;

-- Get financial impact of damages (if cost tracking is added)
SELECT 
    c.category_name,
    COUNT(dl.damage_id) AS incident_count,
    SUM(dl.quantity) AS total_units_damaged,
    'Add cost column to calculate financial impact' AS note
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN categories c ON i.category_id = c.category_id
WHERE dl.damage_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY c.category_id, c.category_name
ORDER BY total_units_damaged DESC;

-- Get damage causes analysis (from description field)
SELECT 
    SUBSTRING_INDEX(SUBSTRING_INDEX(description, ' ', 1), ' ', -1) AS first_word,
    COUNT(*) AS occurrence_count,
    SUM(quantity) AS total_damaged
FROM damage_log
WHERE description IS NOT NULL AND description != ''
GROUP BY first_word
ORDER BY occurrence_count DESC
LIMIT 10;

-- Items with recurring damage issues
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    c.category_name,
    COUNT(dl.damage_id) AS damage_occurrences,
    SUM(dl.quantity) AS total_damaged,
    MIN(dl.damage_date) AS first_incident,
    MAX(dl.damage_date) AS last_incident
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN damage_log dl ON i.item_id = dl.item_id
GROUP BY i.item_id, i.item_name, i.unit_type, c.category_name
HAVING COUNT(dl.damage_id) > 1
ORDER BY damage_occurrences DESC;
