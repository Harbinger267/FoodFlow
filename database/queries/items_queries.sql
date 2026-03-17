USE foodflow;

-- =========================================
-- CREATE OPERATIONS
-- =========================================

-- Insert a new item
INSERT INTO items (name, category, stock, unit_of_measure, description, status)
VALUES (?, ?, ?, ?, ?, ?);

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all items
SELECT
    item_id,
    name,
    category,
    stock,
    unit_of_measure,
    description,
    status
FROM items
ORDER BY name ASC;

-- Get item by ID
SELECT
    item_id,
    name,
    category,
    stock,
    unit_of_measure,
    description,
    status
FROM items
WHERE item_id = ?;

-- Get items by category
SELECT
    item_id,
    name,
    category,
    stock,
    unit_of_measure,
    status
FROM items
WHERE category = ?
ORDER BY name ASC;

-- Get low stock items (threshold is a parameter)
SELECT
    item_id,
    name,
    category,
    stock,
    unit_of_measure,
    status
FROM items
WHERE stock <= ?
AND status IN ('AVAILABLE', 'LOW_STOCK')
ORDER BY stock ASC, name ASC;

-- Get out of stock items
SELECT
    item_id,
    name,
    category,
    stock,
    unit_of_measure,
    status
FROM items
WHERE stock = 0
OR status = 'OUT_OF_STOCK'
ORDER BY name ASC;

-- Search items by name (case-insensitive)
SELECT
    item_id,
    name,
    category,
    stock,
    unit_of_measure,
    status
FROM items
WHERE LOWER(name) LIKE LOWER(CONCAT('%', ?, '%'))
ORDER BY name ASC;

-- Get items by status
SELECT
    item_id,
    name,
    category,
    stock,
    unit_of_measure,
    status
FROM items
WHERE status = ?
ORDER BY name ASC;

-- =========================================
-- UPDATE OPERATIONS
-- =========================================

-- Update item details
UPDATE items
SET
    name = ?,
    category = ?,
    unit_of_measure = ?,
    description = ?,
    status = ?
WHERE item_id = ?;

-- Update item stock (increase)
UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

-- Update item stock (decrease)
UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

-- Update status from a threshold value
UPDATE items
SET status = CASE
    WHEN stock = 0 THEN 'OUT_OF_STOCK'
    WHEN stock <= ? THEN 'LOW_STOCK'
    ELSE 'AVAILABLE'
END
WHERE item_id = ?;

-- Bulk update status from a threshold value
UPDATE items
SET status = CASE
    WHEN stock = 0 THEN 'OUT_OF_STOCK'
    WHEN stock <= ? THEN 'LOW_STOCK'
    ELSE 'AVAILABLE'
END
WHERE status != 'DISCONTINUED';

-- Discontinue an item
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

-- Soft delete (recommended)
UPDATE items
SET status = 'DISCONTINUED'
WHERE item_id = ?;

-- Hard delete (use with caution)
DELETE FROM items
WHERE item_id = ?;

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Item count and stock by category
SELECT
    category,
    COUNT(*) AS item_count,
    SUM(stock) AS total_stock
FROM items
GROUP BY category
ORDER BY item_count DESC, category ASC;

-- Top supplied items (last 30 days)
SELECT
    i.item_id,
    i.name,
    i.category,
    i.unit_of_measure,
    COALESCE(SUM(s.quantity), 0) AS total_supplied
FROM items i
LEFT JOIN supply s ON i.item_id = s.item_id
    AND s.supply_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.name, i.category, i.unit_of_measure
ORDER BY total_supplied DESC
LIMIT 10;

-- Top borrowed items (last 30 days)
SELECT
    i.item_id,
    i.name,
    i.category,
    i.unit_of_measure,
    COALESCE(SUM(bt.quantity_borrowed), 0) AS total_borrowed
FROM items i
LEFT JOIN borrow_transactions bt ON i.item_id = bt.item_id
    AND bt.borrow_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.name, i.category, i.unit_of_measure
ORDER BY total_borrowed DESC
LIMIT 10;

-- Check if active item exists by name
SELECT EXISTS (
    SELECT 1
    FROM items
    WHERE LOWER(name) = LOWER(?)
    AND status != 'DISCONTINUED'
) AS item_exists;