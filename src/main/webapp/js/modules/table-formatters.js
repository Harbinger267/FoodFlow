/* Table badge/action formatters */

function getStatusBadge(status) {
    const badges = {
        'AVAILABLE': '<span class="badge badge-green">Available</span>',
        'LOW_STOCK': '<span class="badge badge-warn">Low Stock</span>',
        'OUT_OF_STOCK': '<span class="badge badge-red">Out of Stock</span>',
        'DAMAGED': '<span class="badge badge-red">Damaged</span>'
    };
    return badges[status] || '<span class="badge badge-blue">' + status + '</span>';
}

/**
 * Helper: Get expiry badge
 */
function getExpiryBadge(item) {
    return '<span class="expiry-badge fresh"><i class="fa-solid fa-leaf"></i> Fresh</span>';
}

/**
 * Helper: Get action buttons for items
 */
function getActionButtons(item) {
    const canEdit = typeof hasCapability === 'function' && hasCapability('canUpdateInventory');
    const editButton = canEdit
        ? `
        <button class="btn-action-sm" onclick="editItem(${item.itemId})" title="Edit">
            <i class="fa-solid fa-pen"></i>
        </button>
    `
        : '';

    return `
        <button class="btn-action-sm" onclick="viewItem(${item.itemId})" title="View">
            <i class="fa-solid fa-eye"></i>
        </button>
        ${editButton}
    `;
}

/**
 * Helper: Get action buttons for damage
 */
function getDamageActionButtons(damage) {
    return `
        <button class="btn-action-sm" onclick="viewDamage(${damage.damageId})" title="View">
            <i class="fa-solid fa-eye"></i>
        </button>
    `;
}

/**
 * Helper: Get action buttons for usage
 */
function getUsageActionButtons(usage) {
    return `
        <button class="btn-action-sm" onclick="viewUsage(${usage.usageId})" title="View">
            <i class="fa-solid fa-eye"></i>
        </button>
    `;
}

