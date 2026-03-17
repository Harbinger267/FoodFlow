USE foodflow;

-- CREATE
INSERT INTO items (name, category, item_type, stock, unit_of_measure, description, status)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- READ
SELECT item_id, name, category, item_type, stock, unit_of_measure, description, status
FROM items
ORDER BY name ASC;

SELECT item_id, name, category, item_type, stock, unit_of_measure, description, status
FROM items
WHERE item_id = ?;

SELECT item_id, name, category, item_type, stock, unit_of_measure, status
FROM items
WHERE category = ?
ORDER BY name ASC;

SELECT item_id, name, category, item_type, stock, unit_of_measure, status
FROM items
WHERE item_type = ?
ORDER BY name ASC;

SELECT item_id, name, category, item_type, stock, unit_of_measure, status
FROM items
WHERE stock <= ?
AND status IN ('AVAILABLE', 'DAMAGED')
ORDER BY stock ASC, name ASC;

SELECT item_id, name, category, item_type, stock, unit_of_measure, status
FROM items
WHERE stock = 0 OR status = 'OUT_OF_STOCK'
ORDER BY name ASC;

SELECT item_id, name, category, item_type, stock, unit_of_measure, status
FROM items
WHERE LOWER(name) LIKE LOWER(CONCAT('%', ?, '%'))
ORDER BY name ASC;

SELECT item_id, name, category, item_type, stock, unit_of_measure, status
FROM items
WHERE status = ?
ORDER BY name ASC;

-- UPDATE
UPDATE items
SET name = ?, category = ?, item_type = ?, unit_of_measure = ?, description = ?, status = ?
WHERE item_id = ?;

UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

UPDATE items
SET status = CASE
    WHEN stock = 0 THEN 'OUT_OF_STOCK'
    ELSE 'AVAILABLE'
END
WHERE item_id = ?
AND status != 'INACTIVE';

UPDATE items
SET status = CASE
    WHEN stock = 0 THEN 'OUT_OF_STOCK'
    ELSE 'AVAILABLE'
END
WHERE status != 'INACTIVE';

UPDATE items
SET status = 'INACTIVE'
WHERE item_id = ?;

UPDATE items
SET status = 'AVAILABLE'
WHERE item_id = ?;

-- DELETE
UPDATE items
SET status = 'INACTIVE'
WHERE item_id = ?;

DELETE FROM items
WHERE item_id = ?;

-- ANALYTICS
SELECT category, item_type, COUNT(*) AS item_count, SUM(stock) AS total_stock
FROM items
GROUP BY category, item_type
ORDER BY category ASC, item_type ASC;

SELECT i.item_id, i.name, i.item_type, i.unit_of_measure, COALESCE(SUM(s.quantity), 0) AS total_supplied
FROM items i
LEFT JOIN supply s ON i.item_id = s.item_id
    AND s.supply_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.name, i.item_type, i.unit_of_measure
ORDER BY total_supplied DESC
LIMIT 10;

SELECT i.item_id, i.name, i.item_type, i.unit_of_measure, COALESCE(SUM(it.quantity_issued), 0) AS total_issued
FROM items i
LEFT JOIN issue_transactions it ON i.item_id = it.item_id
    AND it.issued_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.name, i.item_type, i.unit_of_measure
ORDER BY total_issued DESC
LIMIT 10;

SELECT i.item_id, i.name, i.item_type, i.unit_of_measure, COALESCE(SUM(bt.quantity_borrowed), 0) AS total_borrowed
FROM items i
LEFT JOIN borrow_transactions bt ON i.item_id = bt.item_id
    AND bt.borrow_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY i.item_id, i.name, i.item_type, i.unit_of_measure
ORDER BY total_borrowed DESC
LIMIT 10;

SELECT EXISTS (
    SELECT 1 FROM items
    WHERE LOWER(name) = LOWER(?)
    AND status != 'INACTIVE'
) AS item_exists;