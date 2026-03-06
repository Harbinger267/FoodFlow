# FoodFlow Query Quick Reference

## Parameter Legend
- `?` = Placeholder for prepared statement parameters
- Parameters are 1-indexed in JDBC

---

## ITEMS QUERIES (items_queries.sql)

### Create Item
```sql
INSERT INTO items (item_name, unit_type, reorder_level, category_id, current_stock, status)
VALUES (?, ?, ?, ?, ?, 'AVAILABLE');
```
**Parameters:** 1=itemName, 2=unitType, 3=reorderLevel, 4=categoryId, 5=initialStock

### Get All Items
```sql
SELECT i.*, c.category_name FROM items i
LEFT JOIN categories c ON i.category_id = c.category_id
ORDER BY i.item_name ASC;
```

### Get Item by ID
```sql
SELECT i.*, c.category_name FROM items i
LEFT JOIN categories c ON i.category_id = c.category_id
WHERE i.item_id = ?;
```

### Get Low Stock Items
```sql
SELECT i.*, c.category_name, (i.reorder_level - i.current_stock) AS shortage_amount
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.current_stock < i.reorder_level AND i.status = 'AVAILABLE'
ORDER BY shortage_amount DESC;
```

### Update Item Stock (Increase)
```sql
UPDATE items SET current_stock = current_stock + ? WHERE item_id = ?;
```

### Update Item Stock (Decrease)
```sql
UPDATE items SET current_stock = current_stock - ? 
WHERE item_id = ? AND current_stock >= ?;
```

---

## SUPPLY QUERIES (supply_queries.sql)

### Record Supply Receipt
```sql
-- Insert transaction
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, notes)
VALUES (?, ?, 'IN', ?, ?);

-- Update stock
UPDATE items SET current_stock = current_stock + ? WHERE item_id = ?;
```

### Get Supplies by Date Range
```sql
SELECT st.*, i.item_name, c.category_name, u.user_name AS recorded_by
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'IN'
AND st.transaction_date BETWEEN ? AND ?
ORDER BY st.transaction_date DESC;
```

### Get Total Supplies per Item (Monthly)
```sql
SELECT i.item_id, i.item_name, SUM(st.quantity) AS total_received
FROM items i
LEFT JOIN stock_transactions st ON i.item_id = st.item_id 
    AND st.transaction_type = 'IN'
    AND st.transaction_date BETWEEN ? AND ?
GROUP BY i.item_id, i.item_name
ORDER BY total_received DESC;
```

---

## USAGE QUERIES (usage_queries.sql)

### Record Usage/Consumption
```sql
-- Insert transaction
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, notes)
VALUES (?, ?, 'OUT', ?, ?);

-- Update stock
UPDATE items SET current_stock = current_stock - ? 
WHERE item_id = ? AND current_stock >= ?;
```

### Get Usage by Date Range
```sql
SELECT st.*, i.item_name, c.category_name, u.user_name AS recorded_by
FROM stock_transactions st
INNER JOIN items i ON st.item_id = i.item_id
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN users u ON st.user_id = u.user_id
WHERE st.transaction_type = 'OUT'
AND st.transaction_date BETWEEN ? AND ?
ORDER BY st.transaction_date DESC;
```

### Estimate Days Until Stockout
```sql
SELECT i.item_id, i.item_name, i.current_stock,
       COALESCE(usage_stats.avg_daily_consumption, 0) AS avg_daily_consumption,
       CASE WHEN COALESCE(usage_stats.avg_daily_consumption, 0) > 0 
            THEN i.current_stock / usage_stats.avg_daily_consumption
            ELSE NULL END AS estimated_days_until_stockout
FROM items i
LEFT JOIN (
    SELECT item_id, AVG(daily_consumption) AS avg_daily_consumption
    FROM (
        SELECT item_id, DATE(transaction_date) AS day, SUM(quantity) AS daily_consumption
        FROM stock_transactions
        WHERE transaction_type = 'OUT'
        AND transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        GROUP BY item_id, DATE(transaction_date)
    ) AS daily_usage
    GROUP BY item_id
) AS usage_stats ON i.item_id = usage_stats.item_id
WHERE i.status = 'AVAILABLE';
```

---

## DAMAGE QUERIES (damage_queries.sql)

### Record Damage Incident
```sql
-- Insert damage log
INSERT INTO damage_log (item_id, quantity, description, reported_by)
VALUES (?, ?, ?, ?);

-- Insert transaction
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, reference_id, notes)
VALUES (?, ?, 'DAMAGED', ?, LAST_INSERT_ID(), ?);

-- Update stock
UPDATE items SET current_stock = current_stock - ? WHERE item_id = ?;
```

### Get Damage Reports by Date Range
```sql
SELECT dl.*, i.item_name, c.category_name, u.user_name AS reported_by
FROM damage_log dl
INNER JOIN items i ON dl.item_id = i.item_id
INNER JOIN categories c ON i.category_id = c.category_id
INNER JOIN users u ON dl.reported_by = u.user_id
WHERE dl.damage_date BETWEEN ? AND ?
ORDER BY dl.damage_date DESC;
```

### Get Damage Rate by Item
```sql
SELECT i.item_id, i.item_name, SUM(dl.quantity) AS total_damaged,
       (SUM(dl.quantity) * 100.0 / SUM(COALESCE(st.quantity, dl.quantity))) AS damage_percentage
FROM items i
INNER JOIN damage_log dl ON i.item_id = dl.item_id
LEFT JOIN stock_transactions st ON i.item_id = st.item_id AND st.transaction_type = 'IN'
GROUP BY i.item_id, i.item_name
HAVING total_damaged > 0
ORDER BY damage_percentage DESC;
```

---

## REPORT QUERIES (report_queries.sql)

### Current Inventory Status
```sql
SELECT i.item_id, i.item_name, c.category_name, i.current_stock, i.unit_type,
       i.reorder_level, i.status,
       CASE WHEN i.current_stock = 0 THEN 'Critical'
            WHEN i.current_stock < i.reorder_level THEN 'Low'
            ELSE 'OK' END AS stock_status
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.status IN ('AVAILABLE', 'LOW_STOCK', 'OUT_OF_STOCK')
ORDER BY CASE WHEN i.current_stock = 0 THEN 1
              WHEN i.current_stock < i.reorder_level THEN 2
              ELSE 3 END, i.item_name ASC;
```

### Stock Movement Summary (Period)
```sql
SELECT i.item_id, i.item_name, c.category_name,
       i.current_stock AS opening_stock,
       COALESCE(supply.total_in, 0) AS stock_in,
       COALESCE(usage_out.total_out, 0) AS stock_out,
       COALESCE(damage.total_damaged, 0) AS damaged
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_in
    FROM stock_transactions WHERE transaction_type = 'IN'
    AND transaction_date BETWEEN ? AND ?
    GROUP BY item_id
) supply ON i.item_id = supply.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_out
    FROM stock_transactions WHERE transaction_type = 'OUT'
    AND transaction_date BETWEEN ? AND ?
    GROUP BY item_id
) usage_out ON i.item_id = usage_out.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS total_damaged
    FROM stock_transactions WHERE transaction_type = 'DAMAGED'
    AND transaction_date BETWEEN ? AND ?
    GROUP BY item_id
) damage ON i.item_id = damage.item_id;
```

### Pending Store Requests
```sql
SELECT sr.request_id, req.user_name AS requester_name, sr.request_date, sr.notes,
       COUNT(rd.detail_id) AS items_count,
       GROUP_CONCAT(CONCAT(i.item_name, ' (', rd.quantity_requested, ' ', i.unit_type, ')') 
       SEPARATOR '; ') AS requested_items
FROM store_requests sr
INNER JOIN users req ON sr.requester_id = req.user_id
LEFT JOIN request_details rd ON sr.request_id = rd.request_id
LEFT JOIN items i ON rd.item_id = i.item_id
WHERE sr.status = 'PENDING'
GROUP BY sr.request_id, req.user_name, sr.request_date, sr.notes
ORDER BY sr.request_date ASC;
```

### User Activity Summary
```sql
SELECT u.user_id, u.user_name, r.role_title,
       COUNT(DISTINCT st.transaction_id) AS transactions_processed,
       SUM(CASE WHEN st.transaction_type = 'IN' THEN st.quantity ELSE 0 END) AS supplies_handled,
       SUM(CASE WHEN st.transaction_type = 'OUT' THEN st.quantity ELSE 0 END) AS usage_recorded,
       SUM(CASE WHEN st.transaction_type = 'DAMAGED' THEN st.quantity ELSE 0 END) AS damages_recorded
FROM users u
INNER JOIN roles r ON u.role_id = r.role_id
LEFT JOIN stock_transactions st ON u.user_id = st.user_id
WHERE st.transaction_date BETWEEN ? AND ?
GROUP BY u.user_id, u.user_name, r.role_title
ORDER BY transactions_processed DESC;
```

### Low Stock Alerts
```sql
SELECT i.item_id, i.item_name, c.category_name, i.current_stock, i.reorder_level, i.unit_type,
       'LOW STOCK' AS alert_type,
       CONCAT('Only ', i.current_stock, ' ', i.unit_type, ' remaining (Reorder level: ', i.reorder_level, ')') AS alert_message
FROM items i
INNER JOIN categories c ON i.category_id = c.category_id
WHERE i.current_stock < i.reorder_level AND i.status = 'AVAILABLE'
ORDER BY (i.reorder_level - i.current_stock) DESC;
```

---

## Common JDBC Patterns

### Execute Query with Results
```java
String query = "SELECT * FROM items WHERE item_id = ?";
try (PreparedStatement stmt = connection.prepareStatement(query)) {
    stmt.setInt(1, itemId);
    try (ResultSet rs = stmt.executeQuery()) {
        while (rs.next()) {
            // Process results
        }
    }
}
```

### Execute Update (INSERT/UPDATE/DELETE)
```java
String query = "UPDATE items SET current_stock = ? WHERE item_id = ?";
try (PreparedStatement stmt = connection.prepareStatement(query)) {
    stmt.setDouble(1, newStock);
    stmt.setInt(2, itemId);
    int rowsAffected = stmt.executeUpdate();
}
```

### Transaction Management
```java
connection.setAutoCommit(false);
try {
    // Execute multiple statements
    stmt1.executeUpdate();
    stmt2.executeUpdate();
    connection.commit();
} catch (SQLException e) {
    connection.rollback();
    throw e;
} finally {
    connection.setAutoCommit(true);
}
```

---

## Date Format Examples

### Last 7 Days
```sql
WHERE transaction_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
```

### Last 30 Days
```sql
WHERE transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
```

### Current Month
```sql
WHERE YEAR(transaction_date) = YEAR(CURDATE())
AND MONTH(transaction_date) = MONTH(CURDATE())
```

### Custom Range
```sql
WHERE transaction_date BETWEEN '2026-03-01' AND '2026-03-31'
```

---

## Aggregation Functions

### Count
```sql
SELECT COUNT(*) AS total_count FROM items;
```

### Sum
```sql
SELECT SUM(quantity) AS total_quantity FROM stock_transactions;
```

### Average
```sql
SELECT AVG(quantity) AS avg_quantity FROM stock_transactions;
```

### Group By
```sql
SELECT category_id, COUNT(*) AS item_count 
FROM items 
GROUP BY category_id;
```

### Having Clause
```sql
SELECT category_id, COUNT(*) AS item_count 
FROM items 
GROUP BY category_id
HAVING COUNT(*) > 5;
```
