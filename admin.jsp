<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Admin Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f0f2f5; text-align: center; }
        h1 { color: #333; margin-top: 50px; }
        .dashboard { display: flex; justify-content: center; margin-top: 50px; gap: 30px; }
        .card { background-color: #fff; padding: 20px 30px; border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,0.2); width: 200px; }
        .card h2 { font-size: 18px; margin-bottom: 10px; color: #555; }
        .card p { font-size: 14px; margin-bottom: 20px; color: #777; }
        .card a { display: inline-block; padding: 8px 15px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 4px; }
        .card a:hover { background-color: #45a049; }
    </style>
</head>
<body>

<h1>Admin Dashboard</h1>

<div class="dashboard">
    <!-- Manage Users -->
    <div class="card">
        <h2>Manage Users</h2>
        <p>Add, edit, or remove users</p>
        <a href="manageUsers.jsp">Go</a>
    </div>

    <!-- View Reports -->
    <div class="card">
        <h2>View Reports</h2>
        <p>Check system usage reports</p>
        <a href="viewReports.jsp">Go</a>
    </div>

    <!-- Settings -->
    <div class="card">
        <h2>Settings</h2>
        <p>Update system configuration</p>
        <a href="settings.jsp">Go</a>
    </div>
</div>

</body>
</html>