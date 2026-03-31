<%@ page import="java.sql.*" %>
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
                out.println("<div class='success'>");
                out.println("<h2>✓ SUCCESS! Database is working!</h2>");
                out.println("<p>Found <strong>" + itemCount + " items</strong> in the items table.</p>");
                out.println("</div>");
            }
            rs.close();
            
            // Show actual data
            if (itemCount > 0) {
                out.println("<h3>Sample Data from items table:</h3>");
                rs = stmt.executeQuery("SELECT item_id, name, category, stock, unit_of_measure, status FROM items LIMIT 5");
                out.println("<table>");
                out.println("<tr><th>ID</th><th>Name</th><th>Category</th><th>Stock</th><th>Unit</th><th>Status</th></tr>");
                while (rs.next()) {
                    out.println("<tr>");
                    out.println("<td>" + rs.getInt("item_id") + "</td>");
                    out.println("<td>" + rs.getString("name") + "</td>");
                    out.println("<td>" + rs.getString("category") + "</td>");
                    out.println("<td>" + rs.getDouble("stock") + "</td>");
                    out.println("<td>" + rs.getString("unit_of_measure") + "</td>");
                    out.println("<td>" + rs.getString("status") + "</td>");
                    out.println("</tr>");
                }
                rs.close();
                out.println("</table>");
                
                out.println("<div style='background:#fff;padding:10px;margin-top:20px;border-left:4px solid #27ae60;'>");
                out.println("<h3>✅ Next Steps:</h3>");
                out.println("<ol>");
                out.println("<li>Go back to NetBeans</li>");
                out.println("<li>Right-click FoodFlow project → Clean and Build</li>");
                out.println("<li>Wait for BUILD SUCCESSFUL</li>");
                out.println("<li>Right-click FoodFlow → Run</li>");
                out.println("<li>The application should now work!</li>");
                out.println("</ol>");
                out.println("</div>");
            } else {
                out.println("<div class='error'>");
                out.println("<h2>⚠️ Database exists but has NO DATA!</h2>");
                out.println("<p>The items table is empty.</p>");
                out.println("<p><strong>Action needed:</strong> Run sample_data.sql to populate the database.</p>");
                out.println("</div>");
            }
            
            stmt.close();
            conn.close();
            
        } catch (ClassNotFoundException e) {
            out.println("<div class='error'>");
            out.println("<h2>✗ MySQL Driver Not Found!</h2>");
            out.println("<pre>" + e.getMessage() + "</pre>");
            out.println("<p><strong>Fix:</strong> Check pom.xml has mysql-connector-j dependency</p>");
            out.println("</div>");
        } catch (SQLException e) {
            out.println("<div class='error'>");
            out.println("<h2>✗ Cannot Connect to MySQL!</h2>");
            out.println("<pre>" + e.getMessage() + "</pre>");
            out.println("<p><strong>Common causes:</strong></p>");
            out.println("<ul>");
            out.println("<li>MySQL service is not running - Start it with: net start MySQL80</li>");
            out.println("<li>Database 'foodflow' doesn't exist - Create it in MySQL Workbench</li>");
            out.println("<li>Wrong password - Check DatabaseConfig.java has correct password</li>");
            out.println("</ul>");
            out.println("</div>");
        } catch (Exception e) {
            out.println("<div class='error'>");
            out.println("<h2>✗ Unexpected Error</h2>");
            out.println("<pre>" + e.getMessage() + "</pre>");
            out.println("</div>");
            e.printStackTrace();
        }
    %>
    
    <div style="margin-top:30px;padding:20px;background:#f8f9fa;border-radius:5px;">
        <h3>Debug Information:</h3>
        <p><strong>Database URL:</strong> jdbc:mysql://localhost:3306/foodflow</p>
        <p><strong>User:</strong> root</p>
        <p><strong>Driver:</strong> com.mysql.cj.jdbc.Driver</p>
        <p><strong>Test Page Location:</strong> src/main/webapp/simple-db-test.jsp</p>
    </div>
</body>
</html>
