<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>FoodFlow - School Inventory</title>
    <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;600;700;800&family=Source+Code+Pro:wght@500;700&display=swap" rel="stylesheet" />
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css" rel="stylesheet" />
    <link rel="stylesheet" href="<%= request.getContextPath() %>/css/landing.css?v=20260420" />
</head>
<body class="lp-body light-mode">
    <header class="lp-topbar">
        <div class="lp-topbar-inner">
            <a href="<%= request.getContextPath() %>/landing.jsp" class="lp-brand">
                <span class="lp-brand-icon" aria-hidden="true"><i class="fa-solid fa-utensils"></i></span>
                <span class="lp-brand-copy">
                    <strong>FoodFlow</strong>
                    <small>School Catering Inventory</small>
                </span>
            </a>

            <button class="icon-btn" id="themeBtn" aria-label="Switch to dark mode">
                <i class="fa-solid fa-sun"></i>
            </button>
        </div>
    </header>

    <main class="lp-main">
        <section class="lp-hero">
            <h1>FoodFlow</h1>
            <p class="lp-subtext">
                A simple school inventory system for tracking stock, handling approvals, and generating reports
                across Store Keeper, Department Head, and Admin roles.
            </p>
            <div class="lp-hero-actions">
                <a href="<%= request.getContextPath() %>/login.jsp" class="lp-btn lp-btn-primary">Sign In</a>
                <a href="#workflow" class="lp-btn lp-btn-outline">Workflow</a>
            </div>
        </section>

        <section class="lp-workflow" id="workflow">
            <h2>Workflow Overview</h2>
            <div class="lp-workflow-cards">
                <article class="lp-workflow-card">
                    <span>1</span>
                    <h3>Record Inventory</h3>
                    <p>Store Keeper updates stock levels and daily issuing or damage events.</p>
                </article>
                <article class="lp-workflow-card">
                    <span>2</span>
                    <h3>Approve or Reject Requests</h3>
                    <p>Department Head reviews requests and applies accountable decisions.</p>
                </article>
                <article class="lp-workflow-card">
                    <span>3</span>
                    <h3>Generate Reports</h3>
                    <p>Users export stock, damage, and issuing records for school follow-up.</p>
                </article>
            </div>
        </section>
    </main>

    <footer class="lp-footer">
        <div class="lp-footer-inner">
            <div class="lp-footer-copy">
                <strong>FoodFlow</strong>
                <span>Built for school inventory operations.</span>
            </div>
            <nav class="lp-footer-links" aria-label="Footer links">
                <a href="#">Contact Support</a>
                <a href="#">Privacy Policy</a>
                <a href="#">Terms &amp; Conditions</a>
            </nav>
            <p>&copy; <%= java.time.Year.now() %> FoodFlow</p>
        </div>
    </footer>

    <script>
        (function initThemeToggle() {
            const themeBtn = document.getElementById('themeBtn');
            const body = document.body;
            if (!themeBtn) {
                return;
            }

            const icon = themeBtn.querySelector('i');
            const savedTheme = localStorage.getItem('foodflowTheme');
            const shouldUseLight = savedTheme ? savedTheme === 'light' : true;
            applyThemeState(shouldUseLight);

            themeBtn.addEventListener('click', () => {
                const nextIsLight = !body.classList.contains('light-mode');
                applyThemeState(nextIsLight);
                localStorage.setItem('foodflowTheme', nextIsLight ? 'light' : 'dark');
            });

            function applyThemeState(isLight) {
                body.classList.toggle('light-mode', isLight);
                if (icon) {
                    icon.classList.toggle('fa-sun', isLight);
                    icon.classList.toggle('fa-moon', !isLight);
                }
                themeBtn.setAttribute('aria-label', isLight ? 'Switch to dark mode' : 'Switch to light mode');
            }
        })();
    </script>
</body>
</html>
