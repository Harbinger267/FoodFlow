<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<%
    String role = (String) session.getAttribute("role");

    // Security check
    if (role == null || !role.equals("storekeeper")) {
        response.sendRedirect("login.jsp");
        return;
    }

    String username = (String) session.getAttribute("username");
%>

<!DOCTYPE html>
<html>
<head>
    <title>Store Keeper Dashboard</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f6f9;
            margin: 0;
        }

        .header {
            background-color: #2c3e50;
            color: white;
            padding: 15px;
            text-align: center;
        }

        .container {
            padding: 20px;
        }

        .welcome {
            margin-bottom: 20px;
            font-size: 18px;
        }

        .dashboard {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
        }

        .card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0px 2px 5px rgba(0,0,0,0.2);
            transition: 0.3s;
        }

        .card:hover {
            transform: scale(1.05);
        }

        .card a {
            text-decoration: none;
            color: #2c3e50;
            font-weight: bold;
        }

        .logout {
            margin-top: 20px;
            text-align: center;
        }

        .logout a {
            color: red;
            text-decoration: none;
            font-weight: bold;
        }
    </style>
</head>

<body>

<div class="header">
    <h2>Store Keeper Dashboard</h2>
</div>

<div class="container">

    <div class="welcome">
        Welcome, <strong><%= username %></strong>
    </div>

    <div class="dashboard">

        <div class="card">
            <a href="updateItems.jsp">Update Food & Utensils</a>
        </div>

        <div class="card">
            <a href="storeRequest.jsp">Make Store Requests</a>
        </div>

        <div class="card">
            <a href="usedItems.jsp">Record Used Items</a>
        </div>

        <div class="card">
            <a href="currentStock.jsp">Record Current Stock</a>
        </div>

        <div class="card">
            <a href="damagedItems.jsp">Record Damaged Items</a>
        </div>

        <div class="card">
            <a href="viewItems">View / Search Items</a>
        </div>

    </div>

    <div class="logout">
        <a href="logout">Logout</a>
    </div>

</div>

</body>
</html>