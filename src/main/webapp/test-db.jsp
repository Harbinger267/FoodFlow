<%@ page import="java.sql.*" %>
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
            
            out.println("<h2>Database Statistics</h2>");
            out.println("<div class='stat-grid'>");
            out.println("<div class='stat-card'><h3>" + itemCount + "</h3><p>Items</p></div>");
            out.println("<div class='stat-card'><h3>" + userCount + "</h3><p>Users</p></div>");
            out.println("<div class='stat-card'><h3>" + damageCount + "</h3><p>Damages</p></div>");
            out.println("<div class='stat-card'><h3>" + supplyCount + "</h3><p>Supplies</p></div>");
            out.println("</div>");
            
            // Show sample data
            out.println("<h2>Sample Items (First 5)</h2>");
            rs = stmt.executeQuery("SELECT * FROM items LIMIT 5");
            out.println("<table>");
            out.println("<tr><th>ID</th><th>Name</th><th>Category</th><th>Stock</th><th>Status</th></tr>");
            while (rs.next()) {
                out.println("<tr>");
                out.println("<td>" + rs.getInt("item_id") + "</td>");
                out.println("<td>" + rs.getString("name") + "</td>");
                out.println("<td>" + rs.getString("category") + "</td>");
                out.println("<td>" + rs.getDouble("stock") + " " + rs.getString("unit_of_measure") + "</td>");
                out.println("<td>" + rs.getString("status") + "</td>");
                out.println("</tr>");
            }
            rs.close();
            out.println("</table>");
            
            out.println("<div class='success'>");
            out.println("<h2>✓ DATABASE CONNECTION SUCCESSFUL!</h2>");
            out.println("<p>Your Java application can connect to MySQL and retrieve data.</p>");
            out.println("<p>Total records in database: " + (itemCount + userCount + damageCount + supplyCount) + "</p>");
            out.println("</div>");
            
            stmt.close();
            conn.close();
            
        } catch (ClassNotFoundException e) {
            out.println("<div class='error'>");
            out.println("<h2>✗ DRIVER ERROR</h2>");
            out.println("<p>MySQL JDBC Driver not found!</p>");
            out.println("<pre>" + e.getMessage() + "</pre>");
            out.println("</div>");
        } catch (SQLException e) {
            out.println("<div class='error'>");
            out.println("<h2>✗ DATABASE CONNECTION FAILED</h2>");
            out.println("<p>Cannot connect to MySQL server</p>");
            out.println("<pre>" + e.getMessage() + "</pre>");
            out.println("<p><strong>Common causes:</strong></p>");
            out.println("<ul>");
            out.println("<li>MySQL service is not running</li>");
            out.println("<li>Database 'foodflow' doesn't exist</li>");
            out.println("<li>Wrong username or password</li>");
            out.println("</ul>");
            out.println("</div>");
        } catch (Exception e) {
            out.println("<div class='error'>");
            out.println("<h2>✗ UNEXPECTED ERROR</h2>");
            out.println("<pre>" + e.getMessage() + "</pre>");
            out.println("</div>");
        }
    %>
    
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
