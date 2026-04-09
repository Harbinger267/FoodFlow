/* Dashboard widget rendering helpers */

function populateLowStockList(items) {
    const container = document.getElementById('lowStockList');
    container.innerHTML = '';
    
    if (items.length === 0) {
        container.innerHTML = '<div class="alert-item"><span class="text-muted">No low stock alerts</span></div>';
        return;
    }
    
    items.forEach(item => {
        const alertItem = `
            <div class="alert-item warn">
                <i class="fa-solid fa-triangle-exclamation alert-item-icon"></i>
                <span class="alert-item-name">${item.name}</span>
                <span class="alert-item-qty">${item.currentStock} left</span>
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

