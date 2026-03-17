USE foodflow;

-- ISSUE CREATE
INSERT INTO issue_transactions (item_id, quantity_issued, issued_date, issued_by, issued_to)
VALUES (?, ?, CURRENT_TIMESTAMP, ?, ?);

UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

-- BORROW CREATE
INSERT INTO borrow_transactions (
    item_id, quantity_borrowed, quantity_returned, borrow_date, return_date, status, recorded_by, borrower_name
)
VALUES (?, ?, 0, CURRENT_TIMESTAMP, NULL, 'BORROWED', ?, ?);

UPDATE items
SET stock = stock - ?
WHERE item_id = ?
AND stock >= ?;

-- RETURN OPERATION
UPDATE borrow_transactions
SET quantity_returned = quantity_returned + ?,
    return_date = CURRENT_TIMESTAMP,
    status = CASE
        WHEN (quantity_returned + ?) >= quantity_borrowed THEN 'RETURNED'
        WHEN (quantity_returned + ?) > 0 THEN 'PARTIALLY_RETURNED'
        ELSE status
    END
WHERE borrow_id = ?;

UPDATE items
SET stock = stock + ?
WHERE item_id = ?;

-- ISSUE READ
SELECT it.issue_id, it.item_id, i.name AS item_name, i.item_type, i.unit_of_measure,
       it.quantity_issued, it.issued_date, it.issued_to,
       COALESCE(u.name, 'N/A') AS issued_by_name,
       COALESCE(u.role, 'N/A') AS issued_by_role
FROM issue_transactions it
INNER JOIN items i ON it.item_id = i.item_id
LEFT JOIN users u ON it.issued_by = u.user_id
ORDER BY it.issued_date DESC;

SELECT it.issue_id, it.item_id, i.name AS item_name, i.item_type, i.unit_of_measure,
       it.quantity_issued, it.issued_date, it.issued_to,
       COALESCE(u.name, 'N/A') AS issued_by_name,
       COALESCE(u.email, 'N/A') AS issued_by_email
FROM issue_transactions it
INNER JOIN items i ON it.item_id = i.item_id
LEFT JOIN users u ON it.issued_by = u.user_id
WHERE it.issue_id = ?;

SELECT it.issue_id, it.item_id, i.name AS item_name, i.category, i.item_type,
       it.quantity_issued, it.issued_date, it.issued_to, COALESCE(u.name, 'N/A') AS issued_by_name
FROM issue_transactions it
INNER JOIN items i ON it.item_id = i.item_id
LEFT JOIN users u ON it.issued_by = u.user_id
WHERE it.issued_date BETWEEN ? AND ?
ORDER BY it.issued_date DESC;

-- BORROW READ
SELECT bt.borrow_id, bt.item_id, i.name AS item_name, i.item_type, i.unit_of_measure,
       bt.borrower_name, bt.quantity_borrowed, bt.quantity_returned,
       (bt.quantity_borrowed - bt.quantity_returned) AS outstanding_quantity,
       bt.borrow_date, bt.return_date, bt.status,
       COALESCE(u.name, 'N/A') AS recorded_by_name,
       COALESCE(u.role, 'N/A') AS recorded_by_role
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
LEFT JOIN users u ON bt.recorded_by = u.user_id
ORDER BY bt.borrow_date DESC;

SELECT bt.borrow_id, bt.item_id, i.name AS item_name, i.item_type, i.unit_of_measure,
       bt.borrower_name, bt.quantity_borrowed, bt.quantity_returned,
       (bt.quantity_borrowed - bt.quantity_returned) AS outstanding_quantity,
       bt.borrow_date, bt.return_date, bt.status,
       COALESCE(u.name, 'N/A') AS recorded_by_name,
       COALESCE(u.email, 'N/A') AS recorded_by_email
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
LEFT JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.borrow_id = ?;

SELECT bt.borrow_id, bt.item_id, i.name AS item_name, i.item_type,
       bt.borrower_name, bt.quantity_borrowed, bt.quantity_returned, bt.status,
       bt.borrow_date, bt.return_date, COALESCE(u.name, 'N/A') AS recorded_by_name
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
LEFT JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.borrow_date BETWEEN ? AND ?
ORDER BY bt.borrow_date DESC;

SELECT bt.borrow_id, bt.quantity_borrowed, bt.quantity_returned, bt.status,
       bt.borrow_date, bt.return_date, bt.borrower_name,
       COALESCE(u.name, 'N/A') AS recorded_by_name
FROM borrow_transactions bt
LEFT JOIN users u ON bt.recorded_by = u.user_id
WHERE bt.item_id = ?
ORDER BY bt.borrow_date DESC;

SELECT bt.borrow_id, bt.item_id, i.name AS item_name, bt.borrower_name,
       bt.quantity_borrowed, bt.quantity_returned,
       (bt.quantity_borrowed - bt.quantity_returned) AS outstanding_quantity,
       bt.borrow_date, bt.return_date, bt.status
FROM borrow_transactions bt
INNER JOIN items i ON bt.item_id = i.item_id
WHERE bt.status = ?
ORDER BY bt.borrow_date DESC;

-- UPDATE
UPDATE issue_transactions
SET issued_to = ?
WHERE issue_id = ?;

UPDATE borrow_transactions
SET status = 'LOST', return_date = CURRENT_TIMESTAMP
WHERE borrow_id = ?;

UPDATE borrow_transactions
SET status = ?
WHERE borrow_id = ?;

-- DELETE
DELETE FROM issue_transactions
WHERE issue_id = ?;

DELETE FROM borrow_transactions
WHERE borrow_id = ?;

-- ANALYTICS
SELECT i.item_id, i.name, i.item_type, i.unit_of_measure,
       COALESCE(SUM(it.quantity_issued), 0) AS total_issued,
       COUNT(it.issue_id) AS issue_count
FROM items i
LEFT JOIN issue_transactions it ON i.item_id = it.item_id
    AND it.issued_date BETWEEN ? AND ?
GROUP BY i.item_id, i.name, i.item_type, i.unit_of_measure
ORDER BY total_issued DESC;

SELECT i.item_id, i.name, i.item_type, i.unit_of_measure,
       COALESCE(SUM(bt.quantity_borrowed), 0) AS total_borrowed,
       COALESCE(SUM(bt.quantity_returned), 0) AS total_returned,
       COALESCE(SUM(bt.quantity_borrowed - bt.quantity_returned), 0) AS total_outstanding
FROM items i
LEFT JOIN borrow_transactions bt ON i.item_id = bt.item_id
    AND bt.borrow_date BETWEEN ? AND ?
GROUP BY i.item_id, i.name, i.item_type, i.unit_of_measure
ORDER BY total_borrowed DESC;

SELECT COUNT(*) AS total_transactions,
       SUM(CASE WHEN status = 'RETURNED' THEN 1 ELSE 0 END) AS returned_count,
       SUM(CASE WHEN status = 'PARTIALLY_RETURNED' THEN 1 ELSE 0 END) AS partial_count,
       SUM(CASE WHEN status = 'LOST' THEN 1 ELSE 0 END) AS lost_count,
       ROUND((SUM(CASE WHEN status = 'RETURNED' THEN 1 ELSE 0 END) * 100.0) / COUNT(*), 2) AS return_rate_percent
FROM borrow_transactions;