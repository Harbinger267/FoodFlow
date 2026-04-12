function togglePassword() {
    const passwordInput = document.getElementById('password');
    const toggleButton = document.querySelector('.password-toggle i');

    if (!passwordInput || !toggleButton) {
        return;
    }

    if (passwordInput.type === 'password') {
        passwordInput.type = 'text';
        toggleButton.classList.remove('fa-eye');
        toggleButton.classList.add('fa-eye-slash');
    } else {
        passwordInput.type = 'password';
        toggleButton.classList.remove('fa-eye-slash');
        toggleButton.classList.add('fa-eye');
    }
}

function initLoginThemeToggle() {
    const themeBtn = document.getElementById('loginThemeBtn');
    const body = document.body;

    if (!themeBtn || !body) {
        return;
    }

    const icon = themeBtn.querySelector('i');
    const savedTheme = localStorage.getItem('foodflowTheme');
    const shouldUseLight = savedTheme ? savedTheme === 'light' : false;
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
}

function initAlertAutoHide() {
    const alerts = document.querySelectorAll('.alert');
    alerts.forEach((alert) => {
        setTimeout(() => {
            alert.style.opacity = '0';
            alert.style.transform = 'translateY(-10px)';
            setTimeout(() => {
                alert.remove();
            }, 300);
        }, 5000);
    });
}

document.addEventListener('DOMContentLoaded', () => {
    initLoginThemeToggle();
    initAlertAutoHide();
});
