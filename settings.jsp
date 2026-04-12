<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Settings</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f0f2f5; text-align: center; }
        h1 { color: #333; margin-top: 50px; }
        .actions { margin-top: 50px; display: flex; justify-content: center; gap: 30px; flex-wrap: wrap; }
        .actions a { 
            display: inline-block; 
            padding: 15px 25px; 
            background-color: #FF9800; 
            color: white; 
            text-decoration: none; 
            font-size: 16px; 
            border-radius: 6px; 
            transition: background-color 0.3s;
        }
        .actions a:hover { background-color: #e68a00; }
        .back { margin-top: 40px; display: inline-block; padding: 10px 20px; background-color: #555; color: white; text-decoration: none; border-radius: 6px; }
        .back:hover { background-color: #333; }
    </style>
</head>
<body>

<h1>Settings</h1>

<div class="actions">
    <a href="updateConfig.jsp">Update Configuration</a>
    <a href="changePassword.jsp">Change Admin Password</a>
</div>

<a href="admin.jsp" class="back">Back to Dashboard</a>

</body>
</html>