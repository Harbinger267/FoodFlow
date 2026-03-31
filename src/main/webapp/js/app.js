/**
 * FoodFlow Inventory Management System - Main Application
 * Integrates frontend with backend servlets
 */

// Global state
let availableItems = [];
let damageRecords = [];
let usageRecords = [];
let dashboardStats = {};

// DataTables instances
let availableTable;
let damagedTable;
let perishableTable;
let nonperishableTable;
let staffTable;

// Chart instances
let stockTrendChart;
let categoryPieChart;
let damagedBarChart;
let stockStatusChart;

/**
 * Initialize application on DOM ready
 */
document.addEventListener('DOMContentLoaded', function() {
    console.log('FoodFlow Application Initializing...');
    
    // Initialize all components
    initSidebar();
    initDateDisplay();
    initThemeToggle();
    loadAllData();
    initCharts();
    initModals();
    initGlobalSearch();
});

/**
 * Load all data from backend servlets
 */
async function loadAllData() {
    try {
        // Show loading state
        showLoading(true);
        
        console.log('Starting data load...');
        
        // Load dashboard data
        console.log('Loading dashboard...');
        await loadDashboardData();
        
        // Load items
        console.log('Loading items...');
        await loadItems();
        
        // Load damage records
        console.log('Loading damage records...');
        await loadDamageRecords();
        
        // Load usage records
        console.log('Loading usage records...');
        await loadUsageRecords();
        
        showLoading(false);
        
        // Initialize tables after data is loaded
        initializeDataTables();
        
        console.log('All data loaded successfully');
        showToast('System loaded successfully', 'success');
    } catch (error) {
        console.error('Error loading data:', error);
        showLoading(false);
        
        // Show detailed error
        let errorMsg = 'Error loading data. ';
        if (error.message.includes('HTML')) {
            errorMsg += 'Server returned error page. Check Tomcat logs.';
        } else if (error.message.includes('404')) {
            errorMsg += 'API endpoints not found. Redeploy application.';
        } else if (error.message.includes('500')) {
            errorMsg += 'Server error. Check database connection.';
        } else {
            errorMsg += 'Please check server connection.';
        }
        
        showToast(errorMsg, 'danger');
        
        // Show debug info in console
        console.error('=== DEBUG INFO ===');
        console.error('Error:', error);
        console.error('Stack:', error.stack);
        console.error('==================');
    }
}

/**
 * Load dashboard statistics and charts
 */
async function loadDashboardData() {
    try {
        console.log('Fetching dashboard stats...');
        const stats = await FoodFlowAPI.dashboard.getStats();
        console.log('Dashboard stats:', stats);
        dashboardStats = stats;
        
        // Update stat cards
        animateValue('totalItems', 0, stats.totalItems || 0, 1000);
        animateValue('inStockCount', 0, stats.inStock || 0, 1000);
        animateValue('damagedCount', 0, stats.damagedCount || 0, 1000);
        animateValue('staffCheckouts', 0, stats.pendingRequests || 0, 1000);
        
        // Update low stock badge
        const lowStockData = await FoodFlowAPI.dashboard.getLowStock();
        document.getElementById('lowStockBadge').textContent = lowStockData.count || 0;
        
        // Populate low stock list
        populateLowStockList(lowStockData.items || []);
        
        // Load recent activity
        const activity = await FoodFlowAPI.dashboard.getRecentActivity();
        populateRecentActivity(activity.items || []);
        
        // Update charts
        await updateCharts();
        
    } catch (error) {
        console.error('Failed to load dashboard data:', error);
        throw error; // Re-throw to stop loading
    }
}

/**
 * Load all items from backend
 */
async function loadItems() {
    try {
        console.log('Fetching items...');
        availableItems = await FoodFlowAPI.items.getAll();
        console.log('Loaded', availableItems.length, 'items');
        
        // Tables will be populated after DataTables initialization
    } catch (error) {
        console.error('Failed to load items:', error);
        throw error;
    }
}

/**
 * Load damage records
 */
async function loadDamageRecords() {
    try {
        console.log('Fetching damage records...');
        damageRecords = await FoodFlowAPI.damage.getAll();
        console.log('Loaded', damageRecords.length, 'damage records');
    } catch (error) {
        console.error('Failed to load damage records:', error);
        throw error;
    }
}

/**
 * Load usage records
 */
async function loadUsageRecords() {
    try {
        console.log('Fetching usage records...');
        usageRecords = await FoodFlowAPI.usage.getAll();
        console.log('Loaded', usageRecords.length, 'usage records');
    } catch (error) {
        console.error('Failed to load usage records:', error);
        throw error;
    }
}

/**
 * Initialize DataTables
 */
function initializeDataTables() {
    // Destroy existing instances if they exist
    if (availableTable) availableTable.destroy();
    if (damagedTable) damagedTable.destroy();
    if (perishableTable) perishableTable.destroy();
    if (nonperishableTable) nonperishableTable.destroy();
    if (staffTable) staffTable.destroy();
    
    // Available Stock Table
    availableTable = $('#availableTable').DataTable({
        data: availableItems.map(item => [
            item.itemId,
            item.name,
            item.category,
            item.currentStock,
            item.unitOfMeasure || 'Pieces',
            getStatusBadge(item.status),
            getActionButtons(item)
        ]),
        order: [[1, 'asc']],
        pageLength: 10,
        language: {
            search: "Filter:",
            lengthMenu: "Show _MENU_ entries",
            info: "Showing _START_ to _END_ of _TOTAL_ entries",
            paginate: {
                first: '<i class="fa-solid fa-angles-left"></i>',
                last: '<i class="fa-solid fa-angles-right"></i>',
                next: '<i class="fa-solid fa-chevron-right"></i>',
                previous: '<i class="fa-solid fa-chevron-left"></i>'
            }
        }
    });
    
    // Damaged Items Table
    damagedTable = $('#damagedTable').DataTable({
        data: damageRecords.map(damage => [
            damage.damageId,
            damage.itemName || 'Item #' + damage.itemId,
            damage.description || damage.damageType || 'Unknown',
            damage.quantity,
            damage.status || 'PENDING',
            getDamageActionButtons(damage)
        ]),
        order: [[0, 'desc']],
        pageLength: 10
    });
    
    // Perishable Goods Table
    const perishableItems = availableItems.filter(item => 
        item.category === 'Perishable' || item.itemType === 'FOOD'
    );
    perishableTable = $('#perishableTable').DataTable({
        data: perishableItems.map(item => [
            item.itemId,
            item.name,
            item.currentStock,
            item.expiryDate || 'N/A',
            getExpiryBadge(item),
            getActionButtons(item)
        ]),
        order: [[3, 'asc']],
        pageLength: 10
    });
    
    // Non-Perishable Goods Table
    const nonPerishableItems = availableItems.filter(item => 
        item.category === 'Non-Perishable' || item.itemType !== 'FOOD'
    );
    nonperishableTable = $('#nonperishableTable').DataTable({
        data: nonPerishableItems.map(item => [
            item.itemId,
            item.name,
            item.currentStock,
            item.supplier || 'N/A',
            getStatusBadge(item.status),
            getActionButtons(item)
        ]),
        order: [[1, 'asc']],
        pageLength: 10
    });
    
    // Staff Checkout Table
    staffTable = $('#staffTable').DataTable({
        data: usageRecords.map(usage => [
            usage.usageId,
            usage.itemUserName || usage.issuedTo || 'Staff',
            usage.itemName || 'Item #' + usage.itemId,
            usage.quantity,
            usage.status || 'ISSUED',
            getUsageActionButtons(usage)
        ]),
        order: [[0, 'desc']],
        pageLength: 10
    });
}

/**
 * Update charts with latest data
 */
async function updateCharts() {
    try {
        const chartData = await FoodFlowAPI.dashboard.getChartData();
        
        // Stock Trend Chart
        if (stockTrendChart) {
            stockTrendChart.destroy();
        }
        const ctx1 = document.getElementById('stockTrendChart').getContext('2d');
        stockTrendChart = new Chart(ctx1, {
            type: 'line',
            data: {
                labels: ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7'],
                datasets: [{
                    label: 'Stock Level',
                    data: chartData.stockTrend || [120, 132, 101, 134, 90, 130, 145],
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.1)',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: false,
                        grid: {
                            color: 'rgba(30, 74, 158, 0.1)'
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
        
        // Category Pie Chart
        if (categoryPieChart) {
            categoryPieChart.destroy();
        }
        const ctx2 = document.getElementById('categoryPieChart').getContext('2d');
        const categories = chartData.categoryDistribution || { 'Perishable': 45, 'Non-Perishable': 55 };
        categoryPieChart = new Chart(ctx2, {
            type: 'pie',
            data: {
                labels: Object.keys(categories),
                datasets: [{
                    data: Object.values(categories),
                    backgroundColor: ['#3b82f6', '#06b6d4', '#10b981', '#f59e0b'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            color: '#e2e8f0',
                            padding: 15
                        }
                    }
                }
            }
        });
        
        // Damaged Bar Chart
        if (damagedBarChart) {
            damagedBarChart.destroy();
        }
        const ctx3 = document.getElementById('damagedBarChart').getContext('2d');
        const damageTypes = chartData.damageByType || { 'Broken': 12, 'Expired': 8, 'Water Damaged': 5 };
        damagedBarChart = new Chart(ctx3, {
            type: 'bar',
            data: {
                labels: Object.keys(damageTypes),
                datasets: [{
                    label: 'Quantity',
                    data: Object.values(damageTypes),
                    backgroundColor: 'rgba(239, 68, 68, 0.7)',
                    borderColor: '#ef4444',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: 'rgba(30, 74, 158, 0.1)'
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
        
    } catch (error) {
        console.error('Error updating charts:', error);
    }
}

/**
 * Sidebar functionality
 */
function initSidebar() {
    const sidebar = document.getElementById('sidebar');
    const mainWrapper = document.getElementById('mainWrapper');
    const toggleBtn = document.getElementById('sidebarToggle');
    const navItems = document.querySelectorAll('.nav-item');
    
    toggleBtn.addEventListener('click', () => {
        sidebar.classList.toggle('collapsed');
        mainWrapper.classList.toggle('collapsed');
    });
    
    navItems.forEach(item => {
        item.addEventListener('click', function() {
            navItems.forEach(n => n.classList.remove('active'));
            this.classList.add('active');
            
            const page = this.dataset.page;
            showPage(page);
        });
    });
}

/**
 * Show specific page
 */
function showPage(pageName) {
    const pages = document.querySelectorAll('.page');
    const pageTitle = document.getElementById('pageTitle');
    const bcActive = document.getElementById('bcActive');
    
    pages.forEach(page => page.classList.remove('active'));
    
    const targetPage = document.getElementById(`page-${pageName}`);
    if (targetPage) {
        targetPage.classList.add('active');
        
        // Update page title
        const titles = {
            'dashboard': 'Dashboard',
            'available': 'Available Stock',
            'damaged': 'Damaged Items',
            'perishable': 'Perishable Goods',
            'nonperishable': 'Non-Perishable Goods',
            'staffrecords': 'Staff Records',
            'reports': 'Reports'
        };
        
        pageTitle.textContent = titles[pageName] || 'Dashboard';
        bcActive.textContent = titles[pageName] || 'Dashboard';
        
        // Refresh DataTables when showing page
        setTimeout(() => {
            if (availableTable) availableTable.columns.adjust();
            if (damagedTable) damagedTable.columns.adjust();
        }, 100);
    }
}

/**
 * Display current date
 */
function initDateDisplay() {
    const dateElement = document.getElementById('currentDate');
    const now = new Date();
    const options = { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' };
    dateElement.textContent = now.toLocaleDateString('en-US', options);
}

/**
 * Theme toggle functionality
 */
function initThemeToggle() {
    const themeBtn = document.getElementById('themeBtn');
    const body = document.body;
    const icon = themeBtn.querySelector('i');
    
    themeBtn.addEventListener('click', () => {
        body.classList.toggle('light-mode');
        
        if (body.classList.contains('light-mode')) {
            icon.classList.remove('fa-moon');
            icon.classList.add('fa-sun');
        } else {
            icon.classList.remove('fa-sun');
            icon.classList.add('fa-moon');
        }
    });
}

/**
 * Modal initialization
 */
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

/**
 * Close modal
 */
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
    
    toastBody.textContent = message;
    toastEl.className = `toast align-items-center text-white border-0 bg-${type}`;
    
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

/**
 * Global search functionality
 */
function initGlobalSearch() {
    const searchInput = document.getElementById('globalSearch');
    
    searchInput.addEventListener('input', function() {
        const query = this.value;
        
        if (query.length > 2) {
            // Search in available items table
            if (availableTable) {
                availableTable.search(query).draw();
            }
        } else {
            if (availableTable) {
                availableTable.search('').draw();
            }
        }
    });
}

/**
 * Helper: Get status badge HTML
 */
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
    return `
        <button class="btn-action-sm" onclick="viewItem(${item.itemId})" title="View">
            <i class="fa-solid fa-eye"></i>
        </button>
        <button class="btn-action-sm" onclick="editItem(${item.itemId})" title="Edit">
            <i class="fa-solid fa-pen"></i>
        </button>
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

/**
 * View item details
 */
async function viewItem(itemId) {
    try {
        const item = await FoodFlowAPI.items.getById(itemId);
        
        const body = document.getElementById('viewItemBody');
        body.innerHTML = `
            <div class="detail-grid">
                <div class="detail-item">
                    <div class="detail-label">Item Name</div>
                    <div class="detail-value">${item.name}</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">Category</div>
                    <div class="detail-value">${item.category}</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">Current Stock</div>
                    <div class="detail-value">${item.currentStock} ${item.unitOfMeasure || ''}</div>
                </div>
                <div class="detail-item">
                    <div class="detail-label">Status</div>
                    <div class="detail-value">${getStatusBadge(item.status)}</div>
                </div>
            </div>
        `;
        
        const modal = new bootstrap.Modal(document.getElementById('viewItemModal'));
        modal.show();
    } catch (error) {
        showToast('Error loading item details: ' + error.message, 'danger');
    }
}

/**
 * Populate low stock list
 */
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
        const icon = act.type === 'damage' ? 'damage' : 'add';
        const iconClass = icon === 'damage' ? 'fa-triangle-exclamation' : 'fa-circle-check';
        const activityItem = `
            <div class="activity-item">
                <div class="activity-icon ${icon}">
                    <i class="fa-solid ${iconClass}"></i>
                </div>
                <div class="activity-text">
                    ${act.description || 'Activity recorded'}<br>
                    <small class="text-muted">Qty: ${act.quantity || 0}</small>
                </div>
                <span class="activity-time">${act.date ? new Date(act.date).toLocaleDateString() : 'Recent'}</span>
            </div>
        `;
        container.innerHTML += activityItem;
    });
}

/**
 * Initialize charts placeholder
 */
function initCharts() {
    // Charts will be initialized when data is loaded
}

/**
 * Edit item (placeholder)
 */
function editItem(itemId) {
    showToast('Edit functionality coming soon', 'info');
}

/**
 * View damage details (placeholder)
 */
function viewDamage(damageId) {
    showToast('View damage functionality coming soon', 'info');
}

/**
 * View usage details (placeholder)
 */
function viewUsage(usageId) {
    showToast('View usage functionality coming soon', 'info');
}
