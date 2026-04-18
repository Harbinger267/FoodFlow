<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FoodFlow - Login</title>
    <link href="https://fonts.googleapis.com/css2?family=Exo+2:wght@300;400;600;700;900&display=swap" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/login.css?v=20260420">

</head>
<body>
    <div class="auth-container">
        <div class="auth-card">
            <button type="button" class="theme-toggle-login" id="loginThemeBtn" aria-label="Switch to light mode">
                <i class="fa-solid fa-moon"></i>
            </button>

            <div class="auth-header">
                <div class="auth-logo">
                    <i class="fas fa-utensils"></i>
                </div>
                <h1 class="auth-title">Welcome Back</h1>
                <p class="auth-subtitle">Sign in with your assigned account</p>
            </div>

            <!-- Login Instructions -->
            <div class="login-hint">
                <i class="fas fa-info-circle"></i>
                <strong>Use one of the case-study accounts</strong>: Admin User, Department Head, or Store Keeper.
            </div>

            <!-- Error Message -->
            <c:if test="${not empty error}">
                <div class="alert alert-error">
                    <i class="fas fa-exclamation-circle"></i>
                    <span>${error}</span>
                </div>
            </c:if>

            <!-- Success Message -->
            <c:if test="${not empty success}">
                <div class="alert alert-success">
                    <i class="fas fa-check-circle"></i>
                    <span>${success}</span>
                </div>
            </c:if>

            <!-- Login Form -->
            <form action="${pageContext.request.contextPath}/auth" method="POST">
                <div class="form-group">
                    <label class="form-label" for="username">Username / Full Name</label>
                    <div class="input-wrapper">
                        <input 
                            type="text" 
                            id="username" 
                            name="username" 
                            class="form-control" 
                            placeholder="Enter your full name or username"
                            value="${username}"
                            required
                            autofocus
                        >
                        <i class="fas fa-user"></i>
                    </div>
                    <small style="color: var(--text-muted); font-size: 11px; margin-top: 4px; display: block;">
                        <i class="fas fa-info-circle"></i> Use your full name (e.g., "Admin User") or username
                    </small>
                </div>

                <div class="form-group">
                    <label class="form-label" for="password">Password</label>
                    <div class="input-wrapper">
                        <input 
                            type="password" 
                            id="password" 
                            name="password" 
                            class="form-control" 
                            placeholder="Enter your password"
                            required
                        >
                        <i class="fas fa-lock"></i>
                        <button type="button" class="password-toggle" onclick="togglePassword()">
                            <i class="fas fa-eye"></i>
                        </button>
                    </div>
                </div>

                <button type="submit" class="btn-primary">
                    <i class="fas fa-sign-in-alt"></i> Sign In
                </button>
            </form>

            <div class="auth-footer">
                <a href="${pageContext.request.contextPath}/landing.jsp" class="auth-back-link">
                    <i class="fas fa-arrow-left"></i> Back to Landing Page
                </a>
                <p>Accounts are provisioned by the administrator for this case study.</p>
            </div>
        </div>
    </div>

    <script src="${pageContext.request.contextPath}/js/login.js?v=20260420"></script>

</body>
</html>


