
USE foodflow;

-- =========================================
-- CREATE OPERATIONS
-- =========================================

-- Insert a new item
INSERT INTO items (item_name, unit_type, reorder_level, category_id, current_stock, status)
VALUES (?, ?, ?, ?, ?, 'AVAILABLE');

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all items with category information
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    i.reorder_level,
    i.current_stock,
    i.status,
    c.category_name,
    i.created_at
FROM items i
LEFT JOIN categories c ON i.category_id = c.category_id
ORDER BY i.item_name ASC;

-- Get item by ID with category details
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    i.reorder_level,
    i.current_stock,
    i.status,
    c.category_id AS category_id,
    c.category_name,
    i.created_at
FROM items i
LEFT JOIN categories c ON i.category_id = c.category_id
WHERE i.item_id = ?;

-- Get items by category
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    i.reorder_level,
    i.current_stock,
    i.status,
    c.category_name
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE c.category_name = ?
ORDER BY i.item_name ASC;

-- Get low stock items (below reorder level)
SELECT 
    i.item_id,
    i.item_name,
    i.current_stock,
    i.reorder_level,
    i.unit_type,
    c.category_name,
    (i.reorder_level - i.current_stock) AS shortage_amount
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.current_stock < i.reorder_level
AND i.status = 'AVAILABLE'
ORDER BY shortage_amount DESC;

-- Get out of stock items
SELECT 
    i.item_id,
    i.item_name,
    i.current_stock,
    i.unit_type,
    c.category_name
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.current_stock = 0
AND i.status = 'AVAILABLE';

-- Search items by name (case-insensitive)
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    i.current_stock,
    i.status,
    c.category_name
FROM items i
LEFT JOIN categories c ON i.category_id = c.category_id
WHERE LOWER(i.item_name) LIKE LOWER(CONCAT('%', ?, '%'))
ORDER BY i.item_name ASC;

-- Get items by status
SELECT 
    i.item_id,
    i.item_name,
    i.current_stock,
    i.unit_type,
    i.status,
    c.category_name
FROM items i
LEFT JOIN categories c ON i.category_id = c.category_id
WHERE i.status = ?
ORDER BY i.item_name ASC;

-- Get total inventory value (if cost tracking is added later)
SELECT 
    COUNT(*) AS total_items,
    SUM(current_stock) AS total_stock_units
FROM items
WHERE status = 'AVAILABLE';

-- =========================================
-- UPDATE OPERATIONS
-- =========================================

-- Update item details
UPDATE items
SET 
    item_name = ?,
    unit_type = ?,
    reorder_level = ?,
    category_id = ?,
    status = ?
WHERE item_id = ?;

-- Update item stock (increase)
UPDATE items
SET current_stock = current_stock + ?
WHERE item_id = ?;

-- Update item stock (decrease)
UPDATE items
SET current_stock = current_stock - ?
WHERE item_id = ?
AND current_stock >= ?;

-- Update item status based on stock level
UPDATE items
SET status = CASE
    WHEN current_stock = 0 THEN 'OUT_OF_STOCK'
    WHEN current_stock < reorder_level THEN 'LOW_STOCK'
    ELSE 'AVAILABLE'
END
WHERE item_id = ?;

-- Bulk update status for all items
UPDATE items
SET status = CASE
    WHEN current_stock = 0 THEN 'OUT_OF_STOCK'
    WHEN current_stock < reorder_level THEN 'LOW_STOCK'
    ELSE 'AVAILABLE'
END
WHERE status != 'DISCONTINUED';

-- Deactivate/discontinue an item
UPDATE items
SET status = 'DISCONTINUED'
WHERE item_id = ?;

-- Reactivate an item
UPDATE items
SET status = 'AVAILABLE'
WHERE item_id = ?;

-- =========================================
-- DELETE OPERATIONS
-- =========================================

-- Soft delete (mark as discontinued)
UPDATE items
SET status = 'DISCONTINUED'
WHERE item_id = ?;

-- Hard delete (use with caution - will affect transaction history)
-- Recommended: Use soft delete instead
DELETE FROM items
WHERE item_id = ?;

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Get items count by category
SELECT 
    c.category_name,
    COUNT(i.item_id) AS item_count,
    SUM(i.current_stock) AS total_stock
FROM categories c
LEFT JOIN items i ON c.category_id = i.category_id AND i.status = 'AVAILABLE'
GROUP BY c.category_id, c.category_name
ORDER BY item_count DESC;

-- Get top consumed items (based on OUT transactions)
SELECT 
    i.item_id,
    i.item_name,
    i.unit_type,
    SUM(st.quantity) AS total_consumed,
    c.category_name
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN stock_transactions st ON i.item_id = st.item_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.item_name, i.unit_type, c.category_name
ORDER BY total_consumed DESC
LIMIT 10;

-- Check if item exists by name
SELECT EXISTS(
    SELECT 1 FROM items 
    WHERE LOWER(item_name) = LOWER(?)
    AND status != 'DISCONTINUED'
) AS item_exists;
