
<%@ page import="com.catering.util.UserStore" %>
<%@ page import="java.util.List" %>

<h1>Manage Users</h1>

<!-- Add a user -->
<form method="post">
    <label>Add User:</label>
    <input type="text" name="addUser" placeholder="Enter username">
    <input type="submit" value="Add">
</form>

<%
    String message = "";

    // Add user
    String newUser = request.getParameter("addUser");
    if (newUser != null && !newUser.trim().isEmpty()) {
        UserStore.addUser(newUser.trim());
        message = "User '" + newUser + "' added.";
    }

    // Delete user
    String deleteUser = request.getParameter("deleteUser");
    if (deleteUser != null) {
        if (UserStore.deleteUser(deleteUser)) {
            message = "User '" + deleteUser + "' deleted.";
        } else {
            message = "User '" + deleteUser + "' not found.";
        }
    }
%>

<p><b><%= message %></b></p>

<!-- List current users with delete button -->
<h3>Current Users:</h3>
<%
    List<String> users = UserStore.getUsers();
    if (users.isEmpty()) {
        out.println("<p>No users yet.</p>");
    } else {
        for (String user : users) {
%>
            <form method="post" style="display:inline;">
                <%= user %>
                <input type="hidden" name="deleteUser" value="<%= user %>">
                <input type="submit" value="Delete">
            </form>
            <br>
<%
        }
    }
%>

<p><a href="admin.jsp">Back to Dashboard</a></p>