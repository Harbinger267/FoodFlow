<%@ page import="java.sql.*" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html>
<head>
    <title>Simple Database Test</title>
    <style>
        body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
        .success { background: #27ae60; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .error { background: #e74c3c; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; border: 1px solid #ddd; text-align: left; }
        th { background: #3498db; color: white; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🔍 Simple Database Connection Test</h1>
    
    <%
        try {
            out.println("<div style='background:#fff;padding:10px;'>Step 1: Loading MySQL Driver...</div>");
            Class.forName("com.mysql.cj.jdbc.Driver");
            out.println("<div style='background:#27ae60;color:white;padding:10px;'>✓ Driver loaded successfully</div>");
            
            out.println("<div style='background:#fff;padding:10px;margin-top:10px;'>Step 2: Connecting to MySQL...</div>");
            Connection conn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/foodflow",
                "root",
                "cess123."
            );
            out.println("<div style='background:#27ae60;color:white;padding:10px;margin-top:10px;'>✓ Connected to foodflow database!</div>");
            
            out.println("<div style='background:#fff;padding:10px;margin-top:10px;'>Step 3: Testing items table...</div>");
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT COUNT(*) as count FROM items");
            
            int itemCount = 0;
            if (rs.next()) {
                itemCount = rs.getInt("count");
                request.setAttribute("itemCount", itemCount);
                request.setAttribute("dbSuccess", true);
            }
            rs.close();
            
            // Show actual data
            if (itemCount > 0) {
                java.util.List<java.util.Map<String, Object>> items = new java.util.ArrayList<>();
                rs = stmt.executeQuery("SELECT item_id, name, category, stock, unit_of_measure, status FROM items LIMIT 5");
                while (rs.next()) {
                    java.util.Map<String, Object> item = new java.util.HashMap<>();
                    item.put("item_id", rs.getInt("item_id"));
                    item.put("name", rs.getString("name"));
                    item.put("category", rs.getString("category"));
                    item.put("stock", rs.getDouble("stock"));
                    item.put("unit_of_measure", rs.getString("unit_of_measure"));
                    item.put("status", rs.getString("status"));
                    items.add(item);
                }
                rs.close();
                request.setAttribute("sampleItems", items);
                request.setAttribute("hasData", true);
            } else {
                request.setAttribute("hasData", false);
            }
            
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
            e.printStackTrace();
        }
    %>
    
    <!-- EL-based rendering -->
    <c:if test="${dbSuccess}">
        <div class='success'>
            <h2>✓ SUCCESS! Database is working!</h2>
            <p>Found <strong>${itemCount} items</strong> in the items table.</p>
        </div>
        
        <c:if test="${hasData}">
            <h3>Sample Data from items table:</h3>
            <table>
                <tr><th>ID</th><th>Name</th><th>Category</th><th>Stock</th><th>Unit</th><th>Status</th></tr>
                <c:forEach var="item" items="${sampleItems}">
                    <tr>
                        <td>${item.item_id}</td>
                        <td>${item.name}</td>
                        <td>${item.category}</td>
                        <td>${item.stock}</td>
                        <td>${item.unit_of_measure}</td>
                        <td>${item.status}</td>
                    </tr>
                </c:forEach>
            </table>
            
            <div style='background:#fff;padding:10px;margin-top:20px;border-left:4px solid #27ae60;'>
                <h3>✅ Next Steps:</h3>
                <ol>
                    <li>Go back to NetBeans</li>
                    <li>Right-click FoodFlow project → Clean and Build</li>
                    <li>Wait for BUILD SUCCESSFUL</li>
                    <li>Right-click FoodFlow → Run</li>
                    <li>The application should now work!</li>
                </ol>
            </div>
        </c:if>
        
        <c:if test="${!hasData}">
            <div class='error'>
                <h2>⚠️ Database exists but has NO DATA!</h2>
                <p>The items table is empty.</p>
                <p><strong>Action needed:</strong> Run sample_data.sql to populate the database.</p>
            </div>
        </c:if>
    </c:if>
    
    <c:if test="${errorType eq 'driver'}">
        <div class='error'>
            <h2>✗ MySQL Driver Not Found!</h2>
            <pre>${errorMessage}</pre>
            <p><strong>Fix:</strong> Check pom.xml has mysql-connector-j dependency</p>
        </div>
    </c:if>
    
    <c:if test="${errorType eq 'connection'}">
        <div class='error'>
            <h2>✗ Cannot Connect to MySQL!</h2>
            <pre>${errorMessage}</pre>
            <p><strong>Common causes:</strong></p>
            <ul>
                <li>MySQL service is not running - Start it with: net start MySQL80</li>
                <li>Database 'foodflow' doesn't exist - Create it in MySQL Workbench</li>
                <li>Wrong password - Check DatabaseConfig.java has correct password</li>
            </ul>
        </div>
    </c:if>
    
    <c:if test="${errorType eq 'unexpected'}">
        <div class='error'>
            <h2>✗ Unexpected Error</h2>
            <pre>${errorMessage}</pre>
        </div>
    </c:if>
    
    <div style="margin-top:30px;padding:20px;background:#f8f9fa;border-radius:5px;">
        <h3>Debug Information:</h3>
        <p><strong>Database URL:</strong> jdbc:mysql://localhost:3306/foodflow</p>
        <p><strong>User:</strong> root</p>
        <p><strong>Driver:</strong> com.mysql.cj.jdbc.Driver</p>
        <p><strong>Test Page Location:</strong> src/main/webapp/simple-db-test.jsp</p>
    </div>
</body>
</html>
