<<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>View Reports</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f0f2f5; text-align: center; }
        h1 { color: #333; margin-top: 50px; }
        .actions { margin-top: 50px; display: flex; justify-content: center; gap: 30px; }
        .actions a { 
            display: inline-block; 
            padding: 15px 25px; 
            background-color: #2196F3; 
            color: white; 
            text-decoration: none; 
            font-size: 16px; 
            border-radius: 6px; 
            transition: background-color 0.3s;
        }
        .actions a:hover { background-color: #0b7dda; }
        .back { margin-top: 40px; display: inline-block; padding: 10px 20px; background-color: #555; color: white; text-decoration: none; border-radius: 6px; }
        .back:hover { background-color: #333; }
    </style>
</head>
<body>

<h1>View Reports</h1>

<div class="actions">
    <a href="dailyReport.jsp">Daily Report</a>
    <a href="monthlyReport.jsp">Monthly Report</a>
    <a href="annualReport.jsp">Annual Report</a>
</div>

<a href="admin.jsp" class="back">Back to Dashboard</a>

</body>
</html>