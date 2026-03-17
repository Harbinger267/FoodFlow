USE foodflow;

-- CREATE
INSERT INTO supply (item_id, quantity, supplier, supply_date, recorded_by)
VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?);

UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

-- READ
SELECT s.supply_id, s.item_id, i.name AS item_name, i.category, i.item_type, i.unit_of_measure,
       s.quantity, s.supplier, s.supply_date, s.recorded_by,
       COALESCE(u.name, 'N/A') AS recorded_by_name,
       COALESCE(u.role, 'N/A') AS recorded_by_role
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
LEFT JOIN users u ON s.recorded_by = u.user_id
ORDER BY s.supply_date DESC;

SELECT s.supply_id, s.item_id, i.name AS item_name, i.category, i.item_type, i.unit_of_measure,
       s.quantity, s.supplier, s.supply_date,
       COALESCE(u.name, 'N/A') AS recorded_by_name,
       COALESCE(u.email, 'N/A') AS recorded_by_email
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
LEFT JOIN users u ON s.recorded_by = u.user_id
WHERE s.supply_id = ?;

SELECT s.supply_id, s.item_id, i.name AS item_name, i.category, i.item_type, i.unit_of_measure,
       s.quantity, s.supplier, s.supply_date, COALESCE(u.name, 'N/A') AS recorded_by_name
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
LEFT JOIN users u ON s.recorded_by = u.user_id
WHERE s.supply_date BETWEEN ? AND ?
ORDER BY s.supply_date DESC;

SELECT s.supply_id, s.quantity, s.supplier, s.supply_date, COALESCE(u.name, 'N/A') AS recorded_by_name
FROM supply s
LEFT JOIN users u ON s.recorded_by = u.user_id
WHERE s.item_id = ?
ORDER BY s.supply_date DESC;

SELECT s.supply_id, s.item_id, i.name AS item_name, s.quantity, s.supplier, s.supply_date
FROM supply s
INNER JOIN items i ON s.item_id = i.item_id
WHERE s.recorded_by = ?
ORDER BY s.supply_date DESC;

SELECT i.item_id, i.name, i.unit_of_measure,
       COALESCE(SUM(s.quantity), 0) AS total_received,
       COUNT(s.supply_id) AS supply_count
FROM items i
LEFT JOIN supply s ON i.item_id = s.item_id
    AND s.supply_date BETWEEN ? AND ?
GROUP BY i.item_id, i.name, i.unit_of_measure
ORDER BY total_received DESC;

-- UPDATE
UPDATE supply
SET supplier = ?
WHERE supply_id = ?;

UPDATE supply
SET quantity = ?
WHERE supply_id = ?;

-- DELETE
UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

DELETE FROM supply
WHERE supply_id = ?;

-- ANALYTICS
SELECT DATE(supply_date) AS supply_day, COUNT(*) AS transaction_count, SUM(quantity) AS total_quantity
FROM supply
GROUP BY DATE(supply_date)
ORDER BY supply_day DESC;

SELECT YEAR(supply_date) AS year, MONTH(supply_date) AS month,
       COUNT(*) AS transaction_count, SUM(quantity) AS total_quantity
FROM supply
GROUP BY YEAR(supply_date), MONTH(supply_date)
ORDER BY year DESC, month DESC;

SELECT supplier, COUNT(*) AS delivery_count, SUM(quantity) AS total_quantity
FROM supply
WHERE supply_date BETWEEN ? AND ?
GROUP BY supplier
ORDER BY total_quantity DESC;