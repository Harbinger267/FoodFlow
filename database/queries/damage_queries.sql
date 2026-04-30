USE foodflow;

-- CREATE
INSERT INTO damage_log (item_id, quantity, damage_date, description, damage_type, disposition, reported_by, reported_by_name)
VALUES (?, ?, CURRENT_TIMESTAMP, ?, ?, ?, ?, ?);

UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

-- READ
SELECT dl.damage_id, dl.item_id, i.name AS item_name, i.category, i.item_type, i.unit_of_measure,
       dl.quantity, dl.damage_date, dl.description, dl.damage_type, dl.disposition,
       dl.reported_by, dl.reported_by_name,
       COALESCE(u.name, 'N/A') AS recorded_by_name,
       COALESCE(u.role, 'N/A') AS recorded_by_role
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
LEFT JOIN users u ON dl.reported_by = u.user_id
ORDER BY dl.damage_date DESC;

SELECT dl.damage_id, dl.item_id, i.name AS item_name, i.category, i.item_type, i.unit_of_measure,
       dl.quantity, dl.damage_date, dl.description, dl.damage_type, dl.disposition,
       dl.reported_by, dl.reported_by_name,
       COALESCE(u.name, 'N/A') AS recorded_by_name,
       COALESCE(u.email, 'N/A') AS recorded_by_email
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
LEFT JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_id = ?;

SELECT dl.damage_id, dl.item_id, i.name AS item_name, i.category, i.item_type,
       dl.quantity, dl.damage_date, dl.description, dl.damage_type, dl.disposition,
       dl.reported_by_name,
       COALESCE(u.name, 'N/A') AS recorded_by_name
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
LEFT JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_date BETWEEN ? AND ?
ORDER BY dl.damage_date DESC;

SELECT dl.damage_id, dl.quantity, dl.damage_date, dl.description, dl.damage_type, dl.disposition,
       dl.reported_by_name, COALESCE(u.name, 'N/A') AS recorded_by_name
FROM damage_log dl
LEFT JOIN users u ON dl.reported_by = u.user_id
WHERE dl.item_id = ?
ORDER BY dl.damage_date DESC;

SELECT dl.damage_id, dl.item_id, i.name AS item_name, dl.quantity, dl.damage_date, dl.description,
       dl.damage_type, dl.disposition, dl.reported_by_name
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
WHERE dl.reported_by = ?
ORDER BY dl.damage_date DESC;

-- UPDATE
UPDATE damage_log
SET description = ?, damage_type = ?, disposition = ?, reported_by_name = ?
WHERE damage_id = ?;

-- DELETE
UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

DELETE FROM damage_log
WHERE damage_id = ?;

-- ANALYTICS
SELECT DATE(damage_date) AS damage_day, COUNT(*) AS incident_count, SUM(quantity) AS total_damaged
FROM damage_log
GROUP BY DATE(damage_date)
ORDER BY damage_day DESC;

SELECT YEAR(damage_date) AS year, MONTH(damage_date) AS month,
       COUNT(*) AS incident_count, SUM(quantity) AS total_damaged
FROM damage_log
GROUP BY YEAR(damage_date), MONTH(damage_date)
ORDER BY year DESC, month DESC;

SELECT i.item_id, i.name, i.category, i.item_type, i.unit_of_measure,
       COALESCE(SUM(dl.quantity), 0) AS total_damaged,
       COUNT(dl.damage_id) AS damage_incidents
FROM items i
LEFT JOIN damage_log dl ON i.item_id = dl.item_id
    AND dl.damage_date BETWEEN ? AND ?
GROUP BY i.item_id, i.name, i.category, i.item_type, i.unit_of_measure
HAVING damage_incidents > 0
ORDER BY total_damaged DESC;

SELECT i.item_id, i.name,
       COALESCE(dmg.total_damaged, 0) AS total_damaged,
       COALESCE(sup.total_supplied, 0) AS total_supplied,
       CASE
           WHEN COALESCE(sup.total_supplied, 0) > 0
           THEN ROUND((COALESCE(dmg.total_damaged, 0) * 100.0) / sup.total_supplied, 2)
           ELSE 0
       END AS damage_rate_percent
FROM items i
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_damaged
    FROM damage_log
    WHERE damage_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY item_id
) dmg ON i.item_id = dmg.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_supplied
    FROM supply
    WHERE supply_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY item_id
) sup ON i.item_id = sup.item_id
WHERE COALESCE(dmg.total_damaged, 0) > 0
ORDER BY damage_rate_percent DESC;
