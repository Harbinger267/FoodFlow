<!DOCTYPE html>
<html>
<head>
    <title>Login</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
<div class="container">
    <form action="LoginServlet" method="post">
        <h2>Login</h2>

        <input type="text" name="username" placeholder="Username" required><br><br>
        <input type="password" name="password" placeholder="Password" required><br><br>

        <select name="role">
            <option value="admin">Admin</option>
            <option value="manager">Manager</option>
            <option value="store">Store Keeper</option>
        </select><br><br>

        <button type="submit">Login</button>
    </form>
</div>
</body>
</html>