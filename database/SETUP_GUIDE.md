# FoodFlow Database Setup Guide

## Overview
This document provides complete instructions for setting up the FoodFlow Inventory Management System database.

## Prerequisites

### Required Software
1. **MySQL Server** (version 8.0 or higher)
   - Download from: https://dev.mysql.com/downloads/mysql/
   
2. **Maven** (version 3.6 or higher)
   - Already configured in pom.xml

### Maven Dependencies
All dependencies are pre-configured in `pom.xml`. When you build the project, Maven will automatically download:
- MySQL Connector/J 8.0.33
- Servlet API 4.0.1
- BCrypt (jbcrypt) 0.4
- HikariCP 4.0.3 (connection pooling)
- Gson 2.10.1
- SLF4J Logging
- Apache Commons Lang3
- JUnit 4.13.2 (testing)

## Database Setup Instructions

### Step 1: Create Database Schema

1. Open MySQL Command Line Client or MySQL Workbench
2. Execute the schema file:

```sql
-- Option A: Using MySQL Command Line
mysql -u root -p < database/schema.sql

-- Option B: Using MySQL Workbench
-- Open database/schema.sql and execute it (Ctrl+Shift+Enter)
```

### Step 2: Load Sample Data

```sql
-- Option A: Using MySQL Command Line
mysql -u root -p foodflow < database/sample_data.sql

-- Option B: Using MySQL Workbench
-- Open database/sample_data.sql and execute it
```

### Step 3: Verify Installation

Run these verification queries:

```sql
USE foodflow;

-- Check tables exist
SHOW TABLES;

-- Expected output:
-- categories
-- damage_log
-- items
-- request_details
-- roles
-- stock_transactions
-- store_requests
-- system_logs
-- users

-- Verify data insertion
SELECT 'Roles' AS table_name, COUNT(*) AS count FROM roles
UNION ALL
SELECT 'Users', COUNT(*) FROM users
UNION ALL
SELECT 'Categories', COUNT(*) FROM categories
UNION ALL
SELECT 'Items', COUNT(*) FROM items
UNION ALL
SELECT 'Store Requests', COUNT(*) FROM store_requests;
```

## Database Structure

### Entity-Relationship Summary (Crow's Foot Notation)

**User Management Section:**
- ROLES (1) → (Many) USERS
- USERS (1) → (Many) SYSTEM_LOGS

**Inventory Section:**
- CATEGORIES (1) → (Many) ITEMS

**Request & Transactions Section:**
- USERS (1) → (Many) STORE_REQUESTS (as Requester)
- USERS (1) → (Many) STORE_REQUESTS (as Approver)
- STORE_REQUESTS (1) → (Many) REQUEST_DETAILS
- ITEMS (1) → (Many) REQUEST_DETAILS
- ITEMS (1) → (Many) STOCK_TRANSACTIONS
- USERS (1) → (Many) STOCK_TRANSACTIONS
- ITEMS (1) → (Many) DAMAGE_LOG
- USERS (1) → (Many) DAMAGE_LOG

### Tables Description

1. **roles** - User roles (ADMIN, DEPARTMENT_HEAD, COOK)
2. **users** - System users with role assignments
3. **system_logs** - Audit trail of user actions
4. **categories** - Item categories (PERISHABLE, NON_PERISHABLE, etc.)
5. **items** - Inventory items with stock levels
6. **store_requests** - Store requisition workflow
7. **request_details** - Individual items in store requests
8. **stock_transactions** - Unified transaction log (IN/OUT/DAMAGED)
9. **damage_log** - Damage incident tracking

## Query Files Reference

### 1. items_queries.sql
**Purpose:** Complete CRUD operations for inventory items
**Key Operations:**
- Create, Read, Update, Delete items
- Search and filter by category/status
- Low stock alerts
- Stock level management

### 2. supply_queries.sql
**Purpose:** Manage stock-in transactions
**Key Operations:**
- Record new supplies
- Track supplies by date/item/user
- Supply analytics and reporting

### 3. usage_queries.sql
**Purpose:** Manage stock-out transactions (consumption)
**Key Operations:**
- Record usage/consumption
- Track usage patterns
- Consumption analytics
- Days-until-stockout estimation

### 4. damage_queries.sql
**Purpose:** Track damaged items
**Key Operations:**
- Record damage incidents
- Damage analysis by item/category
- Damage rate calculations
- Recurring damage identification

### 5. report_queries.sql
**Purpose:** Comprehensive reporting and analytics
**Key Reports:**
- Current inventory status
- Stock movement summaries
- User activity reports
- Store request status
- Category analysis
- Alerts and notifications

## Using Queries in Java Servlets

### Example: Getting All Items

```java
@WebServlet("/items")
public class ItemServlet extends HttpServlet {
    private Connection connection;
    
    @Override
    public void init() throws ServletException {
        // Initialize database connection
        connection = DatabaseConfig.getConnection();
    }
    
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        String query = "SELECT * FROM items_queries.sql -- Get all items with category";
        // Actually use the query from items_queries.sql
        
        try (PreparedStatement stmt = connection.prepareStatement(query);
             ResultSet rs = stmt.executeQuery()) {
            
            List<Item> items = new ArrayList<>();
            while (rs.next()) {
                Item item = new Item(
                    rs.getInt("item_id"),
                    rs.getString("item_name"),
                    // ... other fields
                );
                items.add(item);
            }
            
            request.setAttribute("items", items);
            request.getRequestDispatcher("/views/items.jsp").forward(request, response);
        } catch (SQLException e) {
            throw new ServletException("Database error", e);
        }
    }
}
```

### Example: Recording a Supply Transaction

```java
@WebServlet("/api/supply/add")
public class SupplyServlet extends HttpServlet {
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        int itemId = Integer.parseInt(request.getParameter("itemId"));
        double quantity = Double.parseDouble(request.getParameter("quantity"));
        int userId = getCurrentUserId(request); // Your method
        
        String supplyQuery = "INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, notes) VALUES (?, ?, 'IN', ?, ?)";
        String updateStockQuery = "UPDATE items SET current_stock = current_stock + ? WHERE item_id = ?";
        
        try (Connection conn = DatabaseConfig.getConnection();
             PreparedStatement supplyStmt = conn.prepareStatement(supplyQuery);
             PreparedStatement updateStmt = conn.prepareStatement(updateStockQuery)) {
            
            conn.setAutoCommit(false);
            
            // Record transaction
            supplyStmt.setInt(1, itemId);
            supplyStmt.setInt(2, userId);
            supplyStmt.setDouble(3, quantity);
            supplyStmt.setString(4, "Supply received");
            supplyStmt.executeUpdate();
            
            // Update stock
            updateStmt.setDouble(1, quantity);
            updateStmt.setInt(2, itemId);
            updateStmt.executeUpdate();
            
            conn.commit();
            response.setStatus(HttpServletResponse.SC_OK);
            
        } catch (SQLException e) {
            conn.rollback();
            throw new ServletException("Transaction failed", e);
        }
    }
}
```

## Testing the Database

### Test Queries

Run these to verify everything works:

```sql
-- 1. Get all items with categories
SELECT i.item_name, c.category_name, i.current_stock, i.unit_type
FROM items i
JOIN categories c ON i.category_id = c.category_id;

-- 2. Get low stock items
SELECT item_name, current_stock, reorder_level
FROM items
WHERE current_stock < reorder_level;

-- 3. Get recent transactions
SELECT st.transaction_id, i.item_name, st.transaction_type, st.quantity, st.transaction_date
FROM stock_transactions st
JOIN items i ON st.item_id = i.item_id
ORDER BY st.transaction_date DESC
LIMIT 10;

-- 4. Get pending store requests
SELECT sr.request_id, u.user_name AS requester, sr.request_date
FROM store_requests sr
JOIN users u ON sr.requester_id = u.user_id
WHERE sr.status = 'PENDING';

-- 5. Get user activity
SELECT u.user_name, COUNT(st.transaction_id) AS transactions
FROM users u
LEFT JOIN stock_transactions st ON u.user_id = st.user_id
GROUP BY u.user_id
ORDER BY transactions DESC;
```

## Default Login Credentials

From sample_data.sql:

| Role | Email | Password Hash | Notes |
|------|-------|---------------|-------|
| ADMIN | admin@foodflow.com | $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy | Change in production |
| DEPARTMENT_HEAD | head@foodflow.com | $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy | Change in production |
| COOK | cook1@foodflow.com | $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy | Change in production |

**Important:** These are test passwords. In production:
- Use BCrypt.hashpw(plainPassword, BCrypt.gensalt()) to hash passwords
- Never store plain text passwords
- Implement password reset functionality

## Maintenance

### Backup Database

```bash
mysqldump -u root -p foodflow > foodflow_backup_$(date +%Y%m%d).sql
```

### Restore from Backup

```bash
mysql -u root -p foodflow < foodflow_backup_YYYYMMDD.sql
```

### Reset Database

```sql
DROP DATABASE IF EXISTS foodflow;
SOURCE database/schema.sql;
SOURCE database/sample_data.sql;
```

## Troubleshooting

### Common Issues

**Issue: Cannot connect to database**
- Solution: Check MySQL service is running
- Verify connection string in DatabaseConfig.java

**Issue: Foreign key constraint errors**
- Solution: Ensure parent records exist before inserting child records
- Insert in order: roles → users → categories → items → transactions

**Issue: Duplicate entry errors**
- Solution: Check for existing records before INSERT
- Use INSERT IGNORE or INSERT ... ON DUPLICATE KEY UPDATE

**Issue: Stock goes negative**
- Solution: Always check current_stock >= quantity before OUT transactions
- Use database triggers or application-level validation

## Next Steps

1. ✅ Database schema created
2. ✅ Sample data loaded
3. ✅ Query files ready
4. ⏭️ Create Java DAO classes based on query files
5. ⏭️ Implement Servlet controllers
6. ⏭️ Build frontend views (JSP/HTML)
7. ⏭️ Deploy to servlet container (Tomcat/Jetty)

## Support

For questions or issues:
- Review the query files for SQL examples
- Check technical documentation in docs/ folder
- Refer to MySQL documentation: https://dev.mysql.com/doc/
