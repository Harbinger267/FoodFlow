USE foodflow;

-- =========================================
-- CREATE OPERATIONS
-- =========================================

-- Record damage incident
INSERT INTO damage_log (item_id, quantity, damage_date, description, reported_by)
VALUES (?, ?, CURRENT_TIMESTAMP, ?, ?);

-- Reduce stock after damage
UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

-- =========================================
-- READ OPERATIONS
-- =========================================

-- Get all damage incidents with details
SELECT
    dl.damage_id,
    dl.item_id,
    i.name AS item_name,
    i.category,
    i.unit_of_measure,
    dl.quantity,
    dl.damage_date,
    dl.description,
    dl.reported_by,
    u.name AS reported_by_name,
    u.role AS reported_by_role
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN users u ON dl.reported_by = u.user_id
ORDER BY dl.damage_date DESC;

-- Get damage incident by ID
SELECT
    dl.damage_id,
    dl.item_id,
    i.name AS item_name,
    i.category,
    i.unit_of_measure,
    dl.quantity,
    dl.damage_date,
    dl.description,
    dl.reported_by,
    u.name AS reported_by_name,
    u.email AS reported_by_email
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_id = ?;

-- Get damage reports by date range
SELECT
    dl.damage_id,
    dl.item_id,
    i.name AS item_name,
    i.category,
    dl.quantity,
    dl.damage_date,
    dl.description,
    u.name AS reported_by_name
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_date BETWEEN ? AND ?
ORDER BY dl.damage_date DESC;

-- Get damage reports by item
SELECT
    dl.damage_id,
    dl.quantity,
    dl.damage_date,
    dl.description,
    u.name AS reported_by_name
FROM damage_log dl
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.item_id = ?
ORDER BY dl.damage_date DESC;

-- Get damage reports by user
SELECT
    dl.damage_id,
    dl.item_id,
    i.name AS item_name,
    dl.quantity,
    dl.damage_date,
    dl.description
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
WHERE dl.reported_by = ?
ORDER BY dl.damage_date DESC;

-- Daily damage summary
SELECT
    DATE(dl.damage_date) AS damage_day,
    COUNT(dl.damage_id) AS incident_count,
    SUM(dl.quantity) AS total_damaged
FROM damage_log dl
GROUP BY DATE(dl.damage_date)
ORDER BY damage_day DESC;

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

-- Restore stock before deleting damage record
UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

-- Delete damage record
DELETE FROM damage_log
WHERE damage_id = ?;

-- =========================================
-- ANALYTICS QUERIES
-- =========================================

-- Total damages per item for a period
SELECT
    i.item_id,
    i.name,
    i.category,
    i.unit_of_measure,
    COALESCE(SUM(dl.quantity), 0) AS total_damaged,
    COUNT(dl.damage_id) AS damage_incidents
FROM items i
LEFT JOIN damage_log dl ON i.item_id = dl.item_id
    AND dl.damage_date BETWEEN ? AND ?
GROUP BY i.item_id, i.name, i.category, i.unit_of_measure
HAVING damage_incidents > 0
ORDER BY total_damaged DESC;

-- Damage rate by item (damaged vs supplied over last 90 days)
SELECT
    i.item_id,
    i.name,
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

-- Compare current month vs previous month damages
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