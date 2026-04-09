<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>FoodFlow - School Inventory System</title>
    <link href="https://fonts.googleapis.com/css2?family=Exo+2:wght@300;400;600;700;900&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet" />
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css" rel="stylesheet" />
    <link rel="stylesheet" href="<%= request.getContextPath() %>/css/index.css?v=20260409" />
    <link rel="stylesheet" href="<%= request.getContextPath() %>/css/landing.css?v=20260409" />
</head>
<body class="landing-body">
    <div class="landing-shell">
        <header class="landing-topbar card-panel">
            <div class="landing-brand">
                <span class="landing-brand-icon"><i class="fas fa-utensils"></i></span>
                <span class="landing-brand-copy">
                    <strong>FoodFlow</strong>
                    <small>School Inventory System</small>
                </span>
            </div>

            <div class="landing-top-actions">
                <button type="button" id="landingThemeBtn" class="icon-btn" aria-label="Toggle theme">
                    <i class="fa-solid fa-moon"></i>
                </button>
                <a class="btn-primary-action" href="<%= request.getContextPath() %>/login.jsp">
                    <i class="fa-solid fa-right-to-bracket"></i> Log In
                </a>
            </div>
        </header>

        <main class="landing-main">
            <section class="landing-hero card-panel">
                <h1>FoodFlow</h1>
                <p>
                    FoodFlow helps schools manage stock with clear role responsibilities, request approvals,
                    and day-to-day inventory visibility for safer and more reliable operations.
                </p>
            </section>

            <section class="landing-grid">
                <article class="card-panel landing-card">
                    <h2><i class="fa-solid fa-users"></i> System Roles</h2>
                    <ul>
                        <li><strong>Admin (ICT):</strong> manages users, maintenance, logs, and backup operations.</li>
                        <li><strong>Department Head:</strong> reviews store requests, approvals, and reporting insights.</li>
                        <li><strong>StoreKeeper:</strong> updates stock, records issues/damage, and handles inventory workflow.</li>
                    </ul>
                </article>

                <article class="card-panel landing-card">
                    <h2><i class="fa-solid fa-chart-column"></i> Snapshot</h2>
                    <div class="landing-metrics">
                        <div class="metric-box">
                            <span class="metric-value">3</span>
                            <span class="metric-label">Active Roles</span>
                        </div>
                        <div class="metric-box">
                            <span class="metric-value">9</span>
                            <span class="metric-label">Core Tables</span>
                        </div>
                        <div class="metric-box">
                            <span class="metric-value">4</span>
                            <span class="metric-label">API Modules</span>
                        </div>
                    </div>
                </article>
            </section>
        </main>

        <footer class="landing-footer card-panel">
            <div class="landing-footer-main">
                <strong>FoodFlow</strong>
                <span>Built by Flow Systems</span>
            </div>

            <nav class="landing-footer-links" aria-label="Footer links">
                <a href="#">Contact Support</a>
                <a href="#">Privacy Policy</a>
                <a href="#">Terms &amp; Conditions</a>
            </nav>

            <div class="landing-socials" aria-label="Social media links">
                <a href="#" aria-label="Facebook"><i class="fa-brands fa-facebook-f"></i></a>
                <a href="#" aria-label="X"><i class="fa-brands fa-x-twitter"></i></a>
                <a href="#" aria-label="Instagram"><i class="fa-brands fa-instagram"></i></a>
                <a href="#" aria-label="LinkedIn"><i class="fa-brands fa-linkedin-in"></i></a>
            </div>
        </footer>
    </div>

    <script>
        (function initLandingTheme() {
            const storageKey = 'foodflow-theme';
            const themeBtn = document.getElementById('landingThemeBtn');
            const icon = themeBtn.querySelector('i');
            const body = document.body;

            const applyTheme = (isLight) => {
                body.classList.toggle('light-mode', isLight);
                icon.classList.toggle('fa-sun', isLight);
                icon.classList.toggle('fa-moon', !isLight);
            };

            const savedTheme = localStorage.getItem(storageKey);
            applyTheme(savedTheme === 'light');

            themeBtn.addEventListener('click', () => {
                const nextIsLight = !body.classList.contains('light-mode');
                applyTheme(nextIsLight);
                localStorage.setItem(storageKey, nextIsLight ? 'light' : 'dark');
            });
        })();
    </script>
</body>
</html>
