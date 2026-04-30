/* Table badge/action formatters */

function getStatusBadge(status) {
    const normalized = String(status || '').toUpperCase();
    const badges = {
        'AVAILABLE': '<span class="badge badge-green">Available</span>',
        'LOW_STOCK': '<span class="badge badge-warn">Low Stock</span>',
        'OUT_OF_STOCK': '<span class="badge badge-red">Out of Stock</span>',
        'DAMAGED': '<span class="badge badge-red">Damaged</span>'
    };
    return badges[normalized] || '<span class="badge badge-blue">' + normalized + '</span>';
}

function getUsageStatusBadge(status) {
    const normalized = String(status || 'ISSUED').toUpperCase();
    const badges = {
        ISSUED: '<span class="badge badge-cyan">Issued</span>',
        BORROWED: '<span class="badge badge-amber">Borrowed</span>',
        PARTIALLY_RETURNED: '<span class="badge badge-blue">Partially Returned</span>',
        RETURNED: '<span class="badge badge-green">Returned</span>',
        LOST: '<span class="badge badge-red">Lost</span>'
    };
    return badges[normalized] || '<span class="badge badge-blue">' + normalized + '</span>';
}

function getDamageDispositionBadge(disposition) {
    const normalized = String(disposition || 'DISPOSED').toUpperCase();
    const badges = {
        DISPOSED: '<span class="badge badge-red">Disposed</span>',
        REPLACED: '<span class="badge badge-green">Replaced</span>',
        UNDER_REPAIR: '<span class="badge badge-amber">Under Repair</span>',
        REPAIRED: '<span class="badge badge-cyan">Repaired</span>'
    };
    return badges[normalized] || '<span class="badge badge-blue">' + normalized + '</span>';
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
        <button class="btn-action-sm" onclick="editItem(${item.itemId})" title="Replenish Stock">
            <i class="fa-solid fa-plus"></i>
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
    const canUpdate = typeof hasCapability === 'function' && hasCapability('canRecordDamages');
    const updateButton = canUpdate
        ? `
        <button class="btn-action-sm" onclick="openDamageDispositionModal(${damage.damageId})" title="Update Disposition">
            <i class="fa-solid fa-pen-to-square"></i>
        </button>
    `
        : '';

    return `
        <button class="btn-action-sm" onclick="viewDamage(${damage.damageId})" title="View">
            <i class="fa-solid fa-eye"></i>
        </button>
        ${updateButton}
    `;
}

/**
 * Helper: Get action buttons for usage
 */
function getUsageActionButtons(usage) {
    const normalizedStatus = String(usage.status || 'ISSUED').toUpperCase();
    const canUpdate = typeof hasCapability === 'function' && hasCapability('canRecordIssuedItems');
    const isBorrowFlow = normalizedStatus === 'BORROWED' || normalizedStatus === 'PARTIALLY_RETURNED';
    const returnButton = canUpdate && isBorrowFlow
        ? `
        <button class="btn-action-sm" onclick="openReturnModal(${usage.usageId})" title="Record Return">
            <i class="fa-solid fa-arrow-rotate-left"></i>
        </button>
    `
        : '';
    const lostButton = canUpdate && isBorrowFlow
        ? `
        <button class="btn-action-sm danger" onclick="openLostModal(${usage.usageId})" title="Mark Lost">
            <i class="fa-solid fa-triangle-exclamation"></i>
        </button>
    `
        : '';

    return `
        <button class="btn-action-sm" onclick="viewUsage(${usage.usageId})" title="View">
            <i class="fa-solid fa-eye"></i>
        </button>
        ${returnButton}
        ${lostButton}
    `;
}

