/* Modal workflows for item/damage/usage actions */

function initModals() {
    // Add Item Modal
    document.getElementById('saveItemBtn').addEventListener('click', saveNewItem);
    
    // Add Damage Modal
    document.getElementById('saveDmgBtn').addEventListener('click', saveDamageReport);
    
    // Add Staff Checkout Modal
    document.getElementById('saveStaffBtn').addEventListener('click', saveStaffCheckout);
    
    // Populate dropdowns when modals are shown
    const addItemModal = document.getElementById('addItemModal');
    const addDamagedModal = document.getElementById('addDamagedModal');
    const addStaffCheckoutModal = document.getElementById('addStaffCheckoutModal');
    
    addItemModal.addEventListener('show.bs.modal', populateItemDropdowns);
    addDamagedModal.addEventListener('show.bs.modal', populateItemDropdowns);
    addStaffCheckoutModal.addEventListener('show.bs.modal', populateItemDropdowns);
}

/**
 * Save new item
 */
async function saveNewItem() {
    if (!hasCapability('canUpdateInventory')) {
        showToast('Access denied: only Store Keeper can update inventory', 'danger');
        return;
    }

    const itemName = document.getElementById('itemName').value;
    const category = document.getElementById('itemCategory').value;
    const quantity = document.getElementById('itemQty').value;
    const unit = document.getElementById('itemUnit').value;
    const minStockLevel = document.getElementById('itemMinLevel').value;
    
    console.log('Saving item:', { itemName, category, quantity, unit, minStockLevel });
    
    if (!itemName || !itemName.trim()) {
        showToast('Item name is required', 'warning');
        return;
    }
    
    if (!category) {
        showToast('Please select a category', 'warning');
        return;
    }
    
    if (!quantity || quantity <= 0) {
        showToast('Quantity must be greater than 0', 'warning');
        return;
    }
    
    const itemData = {
        itemName: itemName.trim(),
        category: category,
        itemType: 'FOOD',
        unit: unit || 'Pieces',
        description: '',
        quantity: parseFloat(quantity),
        minStockLevel: parseFloat(minStockLevel || 10)
    };
    
    console.log('Sending to API:', itemData);
    
    try {
        const result = await FoodFlowAPI.items.add(itemData);
        console.log('API Response:', result);
        
        if (result.success) {
            showToast('Item added successfully', 'success');
            closeModal('addItemModal');
            await loadAllData(); // Reload all data
        } else {
            showToast(result.message || 'Failed to add item', 'danger');
        }
    } catch (error) {
        console.error('Error adding item:', error);
        showToast('Error adding item: ' + error.message, 'danger');
    }
}

/**
 * Save damage report
 */
async function saveDamageReport() {
    if (!hasCapability('canRecordDamages')) {
        showToast('Access denied: only Store Keeper can record damages', 'danger');
        return;
    }

    const itemId = document.getElementById('dmgItemName').value;
    const quantity = document.getElementById('dmgQty').value;
    const damageType = document.getElementById('dmgType').value;
    const reportedBy = document.getElementById('dmgReporter').value;
    
    console.log('Recording damage:', { itemId, quantity, damageType, reportedBy });
    
    if (!itemId) {
        showToast('Please select an item from the dropdown', 'warning');
        return;
    }
    
    if (!quantity || quantity <= 0) {
        showToast('Quantity must be greater than 0', 'warning');
        return;
    }
    
    if (!damageType) {
        showToast('Please select a damage type', 'warning');
        return;
    }
    
    const damageData = {
        itemId: parseInt(itemId),
        quantity: parseInt(quantity),
        damageType: damageType,
        reportedBy: reportedBy || 'Unknown'
    };
    
    console.log('Sending to API:', damageData);
    
    try {
        const result = await FoodFlowAPI.damage.add(damageData);
        console.log('API Response:', result);
        
        if (result.success) {
            showToast('Damage recorded successfully', 'success');
            closeModal('addDamagedModal');
            await loadAllData();
        } else {
            showToast(result.message || 'Failed to record damage', 'danger');
        }
    } catch (error) {
        console.error('Error recording damage:', error);
        showToast('Error recording damage: ' + error.message, 'danger');
    }
}

/**
 * Save staff checkout
 */
async function saveStaffCheckout() {
    if (!hasCapability('canRecordIssuedItems')) {
        showToast('Access denied: only Store Keeper can record issued items', 'danger');
        return;
    }

    const usageData = {
        itemId: parseInt(document.getElementById('staffItemSelect').value),
        quantity: parseInt(document.getElementById('staffQtyTaken').value),
        staffName: document.getElementById('staffName').value,
        department: document.getElementById('staffDept').value
    };
    
    if (!usageData.itemId || !usageData.quantity || !usageData.staffName) {
        showToast('Please fill in all required fields', 'warning');
        return;
    }
    
    try {
        const result = await FoodFlowAPI.usage.add(usageData);
        
        if (result.success) {
            showToast('Checkout logged successfully', 'success');
            closeModal('addStaffCheckoutModal');
            await loadAllData();
        } else {
            showToast(result.message || 'Failed to log checkout', 'danger');
        }
    } catch (error) {
        showToast('Error logging checkout: ' + error.message, 'danger');
    }
}

/**
 * Populate item dropdowns in modals
 */
async function populateItemDropdowns() {
    if (!hasCapability('canViewInventory')) {
        return;
    }

    try {
        const items = await FoodFlowAPI.items.getAll();
        
        const dmgSelect = document.getElementById('dmgItemName');
        const staffSelect = document.getElementById('staffItemSelect');
        
        dmgSelect.innerHTML = '<option value="">Select Item</option>';
        staffSelect.innerHTML = '<option value="">Select Item</option>';
        
        items.forEach(item => {
            const option = `<option value="${item.itemId}">${item.name} (Stock: ${item.currentStock})</option>`;
            dmgSelect.innerHTML += option;
            staffSelect.innerHTML += option;
        });
    } catch (error) {
        console.error('Error populating item dropdowns:', error);
    }
}

