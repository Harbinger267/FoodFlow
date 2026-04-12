<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    String role = (String) session.getAttribute("role");
    if(role == null || !role.equals("storekeeper")){
        response.sendRedirect("login.jsp");
    }

    String msg = (String) session.getAttribute("msg");
    if(msg != null){
        out.println("<p style='color:green;'>" + msg + "</p>");
        session.removeAttribute("msg");
    }
%>

<h2>Update Food & Utensils</h2>

<form action="updateItem" method="post">
    Item Name: <input type="text" name="name" required><br><br>
    Quantity: <input type="number" name="quantity" min="1" required><br><br>
    <input type="submit" value="Update Item">
</form>