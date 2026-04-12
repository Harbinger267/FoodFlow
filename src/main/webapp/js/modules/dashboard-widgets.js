/* Dashboard widget rendering helpers */

function populateLowStockList(items) {
    populateDashboardAlerts(items, 'stock');
}

function populateDashboardAlerts(items, mode) {
    const container = document.getElementById('lowStockList');
    if (!container) {
        return;
    }

    container.innerHTML = '';
    const list = Array.isArray(items) ? items : [];
    
    if (list.length === 0) {
        const emptyMessage = mode === 'system'
            ? 'No recent system alerts'
            : 'No low stock alerts';
        container.innerHTML = `<div class="alert-item"><span class="text-muted">${emptyMessage}</span></div>`;
        return;
    }

    if (mode === 'system') {
        list.forEach((item) => {
            const severity = item.severity === 'danger' ? 'danger' : (item.severity === 'warn' ? 'warn' : 'info');
            const iconClass = severity === 'danger'
                ? 'fa-circle-xmark'
                : (severity === 'warn' ? 'fa-triangle-exclamation' : 'fa-circle-info');
            const label = severity === 'danger'
                ? 'Critical'
                : (severity === 'warn' ? 'Attention' : 'Info');
            const alertItem = `
                <div class="alert-item ${severity}">
                    <i class="fa-solid ${iconClass} alert-item-icon"></i>
                    <span class="alert-item-name">${escapeDashboardText(item.message || 'System event')}</span>
                    <span class="alert-item-qty">${label}</span>
                </div>
            `;
            container.innerHTML += alertItem;
        });
        return;
    }

    list.forEach((item) => {
        const alertItem = `
            <div class="alert-item warn">
                <i class="fa-solid fa-triangle-exclamation alert-item-icon"></i>
                <span class="alert-item-name">${escapeDashboardText(item.name || 'Item')}</span>
                <span class="alert-item-qty">${item.currentStock || 0} left</span>
            </div>
        `;
        container.innerHTML += alertItem;
    });
}

/**
 * Populate recent activity
 */
function populateRecentActivity(activities) {
    const container = document.getElementById('recentActivity');
    container.innerHTML = '';
    
    if (activities.length === 0) {
        container.innerHTML = '<div class="text-muted">No recent activity</div>';
        return;
    }
    
    activities.forEach(act => {
        const type = act.type || 'add';
        const icon = type === 'damage' ? 'damage' : (type === 'role' ? 'info' : 'add');
        const iconClass = icon === 'damage'
            ? 'fa-triangle-exclamation'
            : (icon === 'info' ? 'fa-list-check' : 'fa-circle-check');
        const quantityLine = Number(act.quantity || 0) > 0
            ? `<small class="text-muted">Qty: ${act.quantity}</small>`
            : `<small class="text-muted">${type === 'role' ? 'Role workflow' : 'Activity entry'}</small>`;
        const parsedDate = act.date ? new Date(act.date) : null;
        const dateText = parsedDate && !Number.isNaN(parsedDate.getTime())
            ? parsedDate.toLocaleDateString()
            : 'Recent';
        const activityItem = `
            <div class="activity-item">
                <div class="activity-icon ${icon}">
                    <i class="fa-solid ${iconClass}"></i>
                </div>
                <div class="activity-text">
                    ${act.description || 'Activity recorded'}<br>
                    ${quantityLine}
                </div>
                <span class="activity-time">${dateText}</span>
            </div>
        `;
        container.innerHTML += activityItem;
    });
}

function escapeDashboardText(value) {
    const text = String(value == null ? '' : value);
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

