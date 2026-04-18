/* Chart/init placeholder actions */

function initCharts() {
    // Charts will be initialized when data is loaded
}

/**
 * Replenish an existing item's stock
 */
async function editItem(itemId) {
    if (!hasCapability('canUpdateInventory')) {
        showToast('Access denied: only Store Keeper can edit inventory', 'danger');
        return;
    }
    try {
        const cachedItem = (Array.isArray(availableItems) ? availableItems : [])
            .find((entry) => Number(entry.itemId) === Number(itemId));
        const item = cachedItem || await FoodFlowAPI.items.getById(itemId);
        if (!item) {
            showToast('Item not found', 'warning');
            return;
        }

        const modalElement = document.getElementById('replenishItemModal');
        if (!modalElement) {
            showToast('Replenish modal is unavailable on this page', 'danger');
            return;
        }

        const unitLabel = item.unitOfMeasure || 'units';
        document.getElementById('replenishItemId').value = String(item.itemId);
        document.getElementById('replenishItemName').value = item.name || `Item #${item.itemId}`;
        document.getElementById('replenishCurrentStock').value = `${Number(item.currentStock || 0)} ${unitLabel}`;
        document.getElementById('replenishQty').value = '1';

        const modal = new bootstrap.Modal(modalElement);
        modal.show();
    } catch (error) {
        showToast('Error preparing replenish form: ' + error.message, 'danger');
    }
}

async function saveReplenishItem() {
    if (!hasCapability('canUpdateInventory')) {
        showToast('Access denied: only Store Keeper can edit inventory', 'danger');
        return;
    }

    const itemId = parseInt((document.getElementById('replenishItemId') || {}).value, 10);
    const quantityToAdd = parseFloat((document.getElementById('replenishQty') || {}).value);
    const itemLabel = ((document.getElementById('replenishItemName') || {}).value || 'Item').trim();

    if (!itemId || Number.isNaN(itemId)) {
        showToast('Invalid item selected for replenishment', 'warning');
        return;
    }
    if (!quantityToAdd || Number.isNaN(quantityToAdd) || quantityToAdd <= 0) {
        showToast('Quantity to add must be greater than 0', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.items.replenish(itemId, quantityToAdd);
        if (result && result.success) {
            closeModal('replenishItemModal');
            showToast(`${itemLabel} replenished successfully`, 'success');
            await loadAllData();
            return;
        }
        showToast((result && (result.message || result.error)) || 'Failed to replenish item', 'danger');
    } catch (error) {
        showToast('Error replenishing item: ' + error.message, 'danger');
    }
}

function openSharedDetailsModal(title, iconClass, bodyHtml) {
    const titleEl = document.getElementById('viewSharedDetailsTitle');
    const bodyEl = document.getElementById('viewSharedDetailsBody');
    const modalEl = document.getElementById('viewSharedDetailsModal');

    if (!titleEl || !bodyEl || !modalEl) {
        showToast('Details modal is unavailable on this page', 'danger');
        return;
    }

    const safeTitle = String(title || 'Details');
    const safeIcon = String(iconClass || 'fa-eye');
    titleEl.innerHTML = `<i class="fa-solid ${safeIcon}"></i> ${safeTitle}`;
    bodyEl.innerHTML = bodyHtml || '<p class="text-muted">No details available.</p>';

    const modal = new bootstrap.Modal(modalEl);
    modal.show();
}

/**
 * View damage details
 */
function viewDamage(damageId) {
    const damage = (Array.isArray(damageRecords) ? damageRecords : [])
        .find((entry) => Number(entry.damageId) === Number(damageId));
    if (!damage) {
        showToast('Damage record not found', 'warning');
        return;
    }

    const reportedBy = damage.reportedBy || 'Store Keeper';
    const typeOrDescription = damage.damageType || damage.description || 'Unspecified';
    const dateValue = damage.date || damage.reportDate || damage.dateString || '';
    const status = damage.status || 'RECORDED';
    const statusBadge = `<span class="badge badge-blue">${escapeHtml(String(status))}</span>`;

    const bodyHtml = `
        <div class="detail-grid">
            <div class="detail-item">
                <div class="detail-label">Damage Ref</div>
                <div class="detail-value">${damage.damageId}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Item</div>
                <div class="detail-value">${escapeHtml(damage.itemName || `Item #${damage.itemId}`)}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Quantity Damaged</div>
                <div class="detail-value">${Number(damage.quantity || 0)}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Status</div>
                <div class="detail-value">${statusBadge}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Reported By</div>
                <div class="detail-value">${escapeHtml(reportedBy)}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Reported Date</div>
                <div class="detail-value">${escapeHtml(formatDateTimeValue(dateValue))}</div>
            </div>
            <div class="detail-item" style="grid-column: 1 / -1;">
                <div class="detail-label">Damage Details</div>
                <div class="detail-value">${escapeHtml(typeOrDescription)}</div>
            </div>
        </div>
    `;

    openSharedDetailsModal('Damage Record Details', 'fa-triangle-exclamation', bodyHtml);
}

/**
 * View issuing/usage details
 */
function viewUsage(usageId) {
    const usage = (Array.isArray(usageRecords) ? usageRecords : [])
        .find((entry) => Number(entry.usageId) === Number(usageId));
    if (!usage) {
        showToast('Issuing record not found', 'warning');
        return;
    }

    const issuedTo = usage.issuedTo || usage.itemUserName || 'Internal Department';
    const status = usage.status || 'ISSUED';
    const dateValue = usage.date || '';

    const statusBadge = `
        <span class="badge badge-blue">${escapeHtml(String(status))}</span>
    `;

    const bodyHtml = `
        <div class="detail-grid">
            <div class="detail-item">
                <div class="detail-label">Record Ref</div>
                <div class="detail-value">${usage.usageId}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Item</div>
                <div class="detail-value">${escapeHtml(usage.itemName || `Item #${usage.itemId}`)}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Quantity Issued</div>
                <div class="detail-value">${Number(usage.quantity || 0)}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Quantity Returned</div>
                <div class="detail-value">${Number(usage.quantityReturned || 0)}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Issued To</div>
                <div class="detail-value">${escapeHtml(issuedTo)}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Recorded By</div>
                <div class="detail-value">${escapeHtml(usage.itemUserName || 'Store Keeper')}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Date</div>
                <div class="detail-value">${escapeHtml(formatDateTimeValue(dateValue))}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Status</div>
                <div class="detail-value">${statusBadge}</div>
            </div>
        </div>
    `;

    openSharedDetailsModal('Issuing Record Details', 'fa-clipboard-user', bodyHtml);
}

