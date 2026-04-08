<%@ page import="java.sql.*" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Connection Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 900px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        h1 { color: #2c3e50; }
        .success { 
            background: #27ae60; 
            color: white; 
            padding: 20px; 
            border-radius: 8px;
            margin: 20px 0;
        }
        .error { 
            background: #e74c3c; 
            color: white; 
            padding: 20px; 
            border-radius: 8px;
            margin: 20px 0;
        }
        .info {
            background: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #3498db;
            color: white;
        }
        pre {
            background: #ecf0f1;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
        }
        .stat-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .stat-card {
            background: #3498db;
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-card h3 {
            margin: 0;
            font-size: 32px;
        }
        .stat-card p {
            margin: 5px 0 0 0;
            opacity: 0.9;
        }
    </style>
</head>
<body>
    <h1>🗄️ FoodFlow Database Connection Test</h1>
    
    <div class="info">
        <h2>Connection Details</h2>
        <p><strong>Host:</strong> localhost:3306</p>
        <p><strong>Database:</strong> foodflow</p>
        <p><strong>User:</strong> root</p>
        <p><strong>Driver:</strong> MySQL JDBC Driver 8.4.0</p>
    </div>
    
    <%
        Connection conn = null;
        try {
            // Load driver
            Class.forName("com.mysql.cj.jdbc.Driver");
            out.println("<div style='background:#fff;padding:10px;border-left:4px solid #3498db;margin:20px 0;'>✓ MySQL JDBC Driver loaded successfully</div>");
            
            // Connect to database
            conn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/foodflow",
                "root",
                "cess123."
            );
            out.println("<div style='background:#fff;padding:10px;border-left:4px solid #27ae60;margin:20px 0;'>✓ Connected to MySQL successfully</div>");
            
            // Get database statistics
            Statement stmt = conn.createStatement();
            
            // Count items
            ResultSet rs = stmt.executeQuery("SELECT COUNT(*) as count FROM items");
            int itemCount = 0;
            if (rs.next()) {
                itemCount = rs.getInt("count");
            }
            rs.close();
            
            // Count users
            rs = stmt.executeQuery("SELECT COUNT(*) as count FROM users");
            int userCount = 0;
            if (rs.next()) {
                userCount = rs.getInt("count");
            }
            rs.close();
            
            // Count damages
            rs = stmt.executeQuery("SELECT COUNT(*) as count FROM damage_log");
            int damageCount = 0;
            if (rs.next()) {
                damageCount = rs.getInt("count");
            }
            rs.close();
            
            // Count supplies
            rs = stmt.executeQuery("SELECT COUNT(*) as count FROM supply");
            int supplyCount = 0;
            if (rs.next()) {
                supplyCount = rs.getInt("count");
            }
            rs.close();
            
            // Set attributes for EL
            request.setAttribute("itemCount", itemCount);
            request.setAttribute("userCount", userCount);
            request.setAttribute("damageCount", damageCount);
            request.setAttribute("supplyCount", supplyCount);
            request.setAttribute("totalCount", itemCount + userCount + damageCount + supplyCount);
            request.setAttribute("dbSuccess", true);
            
            // Show sample data
            java.util.List<java.util.Map<String, Object>> sampleItems = new java.util.ArrayList<>();
            rs = stmt.executeQuery("SELECT * FROM items LIMIT 5");
            while (rs.next()) {
                java.util.Map<String, Object> item = new java.util.HashMap<>();
                item.put("item_id", rs.getInt("item_id"));
                item.put("name", rs.getString("name"));
                item.put("category", rs.getString("category"));
                item.put("stock", rs.getDouble("stock"));
                item.put("unit_of_measure", rs.getString("unit_of_measure"));
                item.put("status", rs.getString("status"));
                sampleItems.add(item);
            }
            rs.close();
            request.setAttribute("sampleItems", sampleItems);
            
            stmt.close();
            conn.close();
            
        } catch (ClassNotFoundException e) {
            request.setAttribute("errorType", "driver");
            request.setAttribute("errorMessage", e.getMessage());
        } catch (SQLException e) {
            request.setAttribute("errorType", "connection");
            request.setAttribute("errorMessage", e.getMessage());
        } catch (Exception e) {
            request.setAttribute("errorType", "unexpected");
            request.setAttribute("errorMessage", e.getMessage());
        }
    %>
    
    <!-- EL-based rendering -->
    <c:if test="${dbSuccess}">
        <h2>Database Statistics</h2>
        <div class='stat-grid'>
            <div class='stat-card'><h3>${itemCount}</h3><p>Items</p></div>
            <div class='stat-card'><h3>${userCount}</h3><p>Users</p></div>
            <div class='stat-card'><h3>${damageCount}</h3><p>Damages</p></div>
            <div class='stat-card'><h3>${supplyCount}</h3><p>Supplies</p></div>
        </div>
        
        <h2>Sample Items (First 5)</h2>
        <table>
            <tr><th>ID</th><th>Name</th><th>Category</th><th>Stock</th><th>Status</th></tr>
            <c:forEach var="item" items="${sampleItems}">
                <tr>
                    <td>${item.item_id}</td>
                    <td>${item.name}</td>
                    <td>${item.category}</td>
                    <td>${item.stock} ${item.unit_of_measure}</td>
                    <td>${item.status}</td>
                </tr>
            </c:forEach>
        </table>
        
        <div class='success'>
            <h2>✓ DATABASE CONNECTION SUCCESSFUL!</h2>
            <p>Your Java application can connect to MySQL and retrieve data.</p>
            <p>Total records in database: ${totalCount}</p>
        </div>
    </c:if>
    
    <c:if test="${errorType eq 'driver'}">
        <div class='error'>
            <h2>✗ DRIVER ERROR</h2>
            <p>MySQL JDBC Driver not found!</p>
            <pre>${errorMessage}</pre>
        </div>
    </c:if>
    
    <c:if test="${errorType eq 'connection'}">
        <div class='error'>
            <h2>✗ DATABASE CONNECTION FAILED</h2>
            <p>Cannot connect to MySQL server</p>
            <pre>${errorMessage}</pre>
            <p><strong>Common causes:</strong></p>
            <ul>
                <li>MySQL service is not running</li>
                <li>Database 'foodflow' doesn't exist</li>
                <li>Wrong username or password</li>
            </ul>
        </div>
    </c:if>
    
    <c:if test="${errorType eq 'unexpected'}">
        <div class='error'>
            <h2>✗ UNEXPECTED ERROR</h2>
            <pre>${errorMessage}</pre>
        </div>
    </c:if>
    
    <div class="info">
        <h2>Next Steps</h2>
        <ol>
            <li>If you see <strong>SUCCESS</strong> above, your database is working!
                <ul>
                    <li>Go back to: <a href="index.html">Main Application</a></li>
                    <li>Test API: <a href="api/items?action=getAll">Get All Items</a></li>
                </ul>
            </li>
            <li>If you see an <strong>ERROR</strong>:
                <ul>
                    <li>Check if MySQL service is running</li>
                    <li>Verify database exists: <code>SHOW DATABASES;</code></li>
                    <li>Run schema.sql and sample_data.sql if database is empty</li>
                    <li>Check password in DatabaseConfig.java matches your MySQL</li>
                </ul>
            </li>
        </ol>
    </div>
</body>
</html>
