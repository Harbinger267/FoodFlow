/* Toast and UI feedback utilities */

function closeModal(modalId) {
    const modal = bootstrap.Modal.getInstance(document.getElementById(modalId));
    if (modal) {
        modal.hide();
    }
}

/**
 * Show toast notification
 */
function showToast(message, type = 'info') {
    const toastEl = document.getElementById('appToast');
    const toastBody = document.getElementById('toastBody');
    const closeBtn = toastEl ? toastEl.querySelector('.btn-close') : null;
    const normalizedType = ['success', 'danger', 'warning', 'info'].includes(type) ? type : 'info';
    
    toastBody.textContent = message;
    toastEl.className = `toast align-items-center border-0 toast-${normalizedType}`;
    if (closeBtn) {
        const lightClose = normalizedType === 'danger' || normalizedType === 'success';
        closeBtn.classList.toggle('btn-close-white', lightClose);
    }
    
    const toast = new bootstrap.Toast(toastEl);
    toast.show();
}

/**
 * Animate numeric values
 */
function animateValue(id, start, end, duration) {
    const obj = document.getElementById(id);
    const range = end - start;
    const increment = range / (duration / 50);
    let current = start;
    
    const timer = setInterval(() => {
        current += increment;
        if ((increment > 0 && current >= end) || (increment < 0 && current <= end)) {
            current = end;
            clearInterval(timer);
        }
        obj.textContent = Math.floor(current);
    }, 50);
}

/**
 * Show/hide loading state
 */
function showLoading(show) {
    // Could implement a loading overlay here
    console.log('Loading:', show ? 'started' : 'completed');
}

