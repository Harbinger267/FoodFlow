# 🗄️ Database Setup & Verification

## Problem

The error "Server returned error page" happens because **the database might not exist or has no data**.

---

## ✅ Step 1: Verify MySQL is Running

### Windows:
1. Press `Windows + R`
2. Type: `services.msc`
3. Look for: **MySQL80** or **MySQL**
4. Status should be: **Running**

**If not running:**
- Right-click → Start
- Or open Command Prompt as Administrator and run:
  ```cmd
  net start MySQL80
  ```

---

## ✅ Step 2: Test Database Connection

### Option A: Using MySQL Workbench (Recommended)

1. **Open MySQL Workbench**
2. **Click on your Local instance** (usually "Local instance MySQL80")
3. **Password:** `cess123.`
4. **In SQL Editor, run:**
   ```sql
   SHOW DATABASES;
   ```
5. **Do you see `foodflow` in the list?**
   - ✅ Yes → Database exists, skip to Step 3
   - ❌ No → Database doesn't exist, continue below

---

### Option B: Using Command Prompt

1. **Open Command Prompt**
2. **Run:**
   ```cmd
   mysql -u root -p
   ```
3. **Enter password:** `cess123.`
4. **Run:**
   ```sql
   SHOW DATABASES;
   ```
5. **Do you see `foodflow`?**
   - ✅ Yes → Database exists
   - ❌ No → Need to create it

---

## ✅ Step 3: Create Database (If Missing)

**In MySQL Workbench or Command Prompt:**

```sql
-- 1. Create database
CREATE DATABASE IF NOT EXISTS foodflow;

-- 2. Use it
USE foodflow;

-- 3. Run schema
SOURCE C:/Users/cessi/Documents/Projects/FoodFlow/database/schema.sql;

-- 4. Load sample data
SOURCE C:/Users/cessi/Documents/Projects/FoodFlow/database/sample_data.sql;

-- 5. Verify tables exist
SHOW TABLES;

-- 6. Verify items have data
SELECT * FROM items;
```

**Expected result:**
- Should show 7 items in the items table
- Tables: damage_log, items, issue_transactions, request_details, store_requests, supply, system_logs, users, borrow_transactions

---

## ✅ Step 4: Verify Data Exists

**Run these queries:**

```sql
USE foodflow;

-- Check items
SELECT COUNT(*) as item_count FROM items;
-- Should return: 7

-- Check users
SELECT COUNT(*) as user_count FROM users;
-- Should return: 3

-- Check if you can select from all tables
SELECT * FROM items LIMIT 5;
SELECT * FROM users;
```

**If COUNT returns 0 or error:**
- Run the sample_data.sql file again
- Or tell me what error you get

---

## ✅ Step 5: Test Database Connection from Java

**Create test file:** `src/main/webapp/test-db.jsp`

```jsp
<%@ page import="java.sql.*" %>
<html>
<body>
<h1>Database Connection Test</h1>
<%
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        Connection conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/foodflow",
            "root",
            "cess123."
        );
        
        out.println("<h2 style='color:green'>✓ SUCCESS!</h2>");
        out.println("<p>Connected to MySQL successfully</p>");
        
        // Test query
        Statement stmt = conn.createStatement();
        ResultSet rs = stmt.executeQuery("SELECT COUNT(*) as count FROM items");
        
        if (rs.next()) {
            out.println("<p>Items in database: <strong>" + rs.getInt("count") + "</strong></p>");
        }
        
        rs.close();
        stmt.close();
        conn.close();
        
    } catch (Exception e) {
        out.println("<h2 style='color:red'>✗ FAILED</h2>");
        out.println("<pre>Error: " + e.getMessage() + "</pre>");
        e.printStackTrace();
    }
%>
</body>
</html>
```

**Then visit:** `http://localhost:8080/FoodFlow/test-db.jsp`

**Expected:** Green success message showing item count  
**If error:** Shows exact database connection error

---

## 🎯 Common Issues & Solutions

### Issue 1: "Can't connect to MySQL server"

**Meaning:** MySQL not running

**Solution:**
```cmd
net start MySQL80
```

---

### Issue 2: "Unknown database 'foodflow'"

**Meaning:** Database doesn't exist

**Solution:**
```sql
CREATE DATABASE foodflow;
USE foodflow;
SOURCE C:/Users/cessi/Documents/Projects/FoodFlow/database/schema.sql;
SOURCE C:/Users/cessi/Documents/Projects/FoodFlow/database/sample_data.sql;
```

---

### Issue 3: "Access denied for user 'root'@'localhost'"

**Meaning:** Wrong password

**Solution:**
- Edit: `src/main/java/com/foodflow/config/DatabaseConfig.java`
- Change password to match your MySQL root password
- Currently set to: `cess123.`

---

### Issue 4: Table exists but no data

**Meaning:** Sample data not loaded

**Solution:**
```sql
USE foodflow;
SOURCE C:/Users/cessi/Documents/Projects/FoodFlow/database/sample_data.sql;
SELECT * FROM items;
```

Should show 7 items.

---

## 📊 What Data Should Exist

After running sample_data.sql:

### Users (3 users):
- Admin User (admin@foodflow.com)
- Department Head (head@foodflow.com)
- Store Keeper (keeper@foodflow.com)

### Items (7 items):
1. Maize Flour - 95 kg
2. Rice - 68 kg
3. Cooking Oil - 36 liters
4. Plates - 140 pcs
5. Spoons - 180 pcs
6. Serving Tongs - 22 pcs
7. Detergent - 0 liters (OUT_OF_STOCK)

### Other Data:
- 5 supply records
- 3 issue transactions
- 4 borrow transactions
- 3 damage records
- 3 store requests

---

## 🔍 Quick Diagnostic Commands

**In MySQL Workbench:**

```sql
-- 1. Does database exist?
SHOW DATABASES LIKE 'foodflow';

-- 2. Are tables created?
USE foodflow;
SHOW TABLES;

-- 3. Is there data?
SELECT 
    (SELECT COUNT(*) FROM items) as items,
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM damage_log) as damages;
```

**Expected output:**
```
items: 7
users: 3
damages: 3
```

---

## ✅ Final Verification Checklist

After setup, verify:

- [ ] MySQL service is running
- [ ] Can connect with password: `cess123.`
- [ ] Database `foodflow` exists
- [ ] All 9 tables exist
- [ ] Items table has 7 rows
- [ ] Users table has 3 rows
- [ ] Can run: `SELECT * FROM items;` without errors

---

## 🚀 After Database is Set Up

**Then rebuild and redeploy:**

1. **In NetBeans:**
   - Right-click FoodFlow → Clean and Build
   - Right-click FoodFlow → Run

2. **Test API directly:**
   ```
   http://localhost:8080/FoodFlow/api/items?action=getAll
   ```
   
   **Should show:** JSON with 7 items

3. **Check NetBeans Output:**
   ```
   ItemAPI.doGet called - Action: getAll
   Fetching all items from database...
   Retrieved 7 items from database
   ```

---

## 📞 Tell Me:

After trying these steps:

1. **Does `SHOW DATABASES;` show `foodflow`?**
2. **Does `SELECT * FROM items;` work?**
3. **How many items are in the database?**
4. **What does test-db.jsp show when you visit it?**

This will tell us exactly where the problem is! 🎯
