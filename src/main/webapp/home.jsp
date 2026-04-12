<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:if test="${empty sessionScope.user}">
    <c:redirect url="/login.jsp" />
</c:if>
<jsp:useBean id="userSession" class="com.foodflow.model.UserSessionBean" scope="session" />
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FoodFlow — Redirecting...</title>
    <script>
        // Store user info in sessionStorage
        var uName = "${not empty userSession.authenticatedAt ? userSession.fullName : sessionScope.user.fullName}";
        var uRole = "${not empty userSession.authenticatedAt ? userSession.role : sessionScope.user.role}";
        var uId = "${not empty userSession.authenticatedAt ? userSession.userId : sessionScope.user.userId}";
        sessionStorage.setItem('userName', uName);
        sessionStorage.setItem('userRole', uRole);
        sessionStorage.setItem('userId', uId);
        
        // Redirect to main application
        window.location.href = '${pageContext.request.contextPath}/index.html?v=20260421';
    </script>
</head>
<body>
    <p>Redirecting to FoodFlow...</p>
</body>
</html>
