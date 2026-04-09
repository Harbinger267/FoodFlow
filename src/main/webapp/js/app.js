/**
 * FoodFlow Inventory Management System - Main Application
 * Integrates frontend with backend servlets
 */

// Global state
let availableItems = [];
let damageRecords = [];
let usageRecords = [];
let requestRecords = [];
let dashboardStats = {};
let rolePolicy = null;
let latestActivityEntries = [];

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
    const userContext = loadUserInfo();
    rolePolicy = (userContext && userContext.policy) ? userContext.policy : getRolePolicy('STOREKEEPER');
    applyRoleDashboardPolicy();
    initRoleActionHandlers();
    loadAllData();
    initCharts();
    initModals();
    initGlobalSearch();
});

/**
 * Load user information from session
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

        if (hasCapability('canCreateRequests') || hasCapability('canApproveRequests')) {
            console.log('Loading request records...');
            await loadRequestRecords();
        }
        
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
        applyRoleStatLabels(stats);
        
        // Update stat cards
        animateValue('totalItems', 0, stats.totalItems || 0, 1000);
        animateValue('inStockCount', 0, stats.inStock || 0, 1000);
        animateValue('damagedCount', 0, stats.damagedCount || 0, 1000);
        const fourthMetric = hasCapability('canViewSystemLogs')
            ? (stats.systemLogCount || 0)
            : (stats.pendingRequests || 0);
        animateValue('staffCheckouts', 0, fourthMetric, 1000);
        
        // Update low stock badge
        const lowStockData = await FoodFlowAPI.dashboard.getLowStock();
        document.getElementById('lowStockBadge').textContent = lowStockData.count || 0;
        
        // Populate low stock list
        populateLowStockList(lowStockData.items || []);
        
        // Load recent activity
        const activity = await FoodFlowAPI.dashboard.getRecentActivity();
        const mergedActivity = mergeRoleActivities(activity.items || []);
        latestActivityEntries = mergedActivity;
        populateRecentActivity(mergedActivity);
        renderSystemLogTable(mergedActivity);
        
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

async function loadRequestRecords() {
    try {
        if (hasCapability('canApproveRequests')) {
            requestRecords = await FoodFlowAPI.requests.getPending();
        } else if (hasCapability('canCreateRequests')) {
            requestRecords = await FoodFlowAPI.requests.getMine();
        } else {
            requestRecords = [];
        }
        renderRequestQueue();
        populateRequestItemSelector();
    } catch (error) {
        console.error('Failed to load requests:', error);
        requestRecords = [];
        renderRequestQueue();
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
            if (this.classList.contains('role-hidden')) {
                return;
            }
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
    if (!isPageAllowed(pageName)) {
        const fallbackPage = getDefaultAllowedPage();
        if (fallbackPage !== pageName) {
            showPage(fallbackPage);
        }
        return;
    }

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
            'requests': 'Store Requests',
            'available': 'Inventory',
            'damaged': 'Damaged Items',
            'perishable': 'Perishable Goods',
            'nonperishable': 'Non-Perishable Goods',
            'staffrecords': 'Issued Items',
            'adminusers': 'Manage Users',
            'adminops': 'System Operations',
            'logs': 'Activity Logs',
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
function initGlobalSearch() {
    const searchInput = document.getElementById('globalSearch');

    if (!searchInput) {
        return;
    }

    if (!hasCapability('canSearchItems')) {
        searchInput.disabled = true;
        searchInput.placeholder = 'Search disabled for this role';
        return;
    }
    
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
function applyRoleDashboardPolicy() {
    const allowedPages = rolePolicy && rolePolicy.allowedPages
        ? rolePolicy.allowedPages
        : ['dashboard'];

    // Sidebar nav visibility
    document.querySelectorAll('.nav-item').forEach((navItem) => {
        const page = navItem.dataset.page;
        const isAllowed = allowedPages.includes(page);
        navItem.classList.toggle('role-hidden', !isAllowed);
        navItem.style.display = isAllowed ? '' : 'none';
        if (!isAllowed) {
            navItem.classList.remove('active');
        }
    });

    // Section visibility
    document.querySelectorAll('.page').forEach((page) => {
        const pageName = page.id.replace('page-', '');
        const isAllowed = allowedPages.includes(pageName);
        page.style.display = isAllowed ? '' : 'none';
        if (!isAllowed) {
            page.classList.remove('active');
        }
    });

    // Hide section labels that no longer have visible items after them
    document.querySelectorAll('.nav-menu .nav-section-label').forEach((label) => {
        let hasVisibleItem = false;
        let current = label.nextElementSibling;
        while (current && !current.classList.contains('nav-section-label')) {
            if (current.classList.contains('nav-item') && current.style.display !== 'none') {
                hasVisibleItem = true;
                break;
            }
            current = current.nextElementSibling;
        }
        label.style.display = hasVisibleItem ? '' : 'none';
    });

    // Modal launch buttons
    const addItemBtn = document.getElementById('openAddItemModalBtn');
    const addDamageBtn = document.getElementById('openAddDamagedModalBtn');
    const addUsageBtn = document.getElementById('openAddStaffCheckoutModalBtn');
    if (addItemBtn) addItemBtn.style.display = hasCapability('canUpdateInventory') ? '' : 'none';
    if (addDamageBtn) addDamageBtn.style.display = hasCapability('canRecordDamages') ? '' : 'none';
    if (addUsageBtn) addUsageBtn.style.display = hasCapability('canRecordIssuedItems') ? '' : 'none';

    const requestCreateCard = document.getElementById('requestCreateCard');
    const requestQueueCard = document.getElementById('requestQueueCard');
    if (requestCreateCard) {
        requestCreateCard.style.display = hasCapability('canCreateRequests') ? '' : 'none';
    }
    if (requestQueueCard) {
        requestQueueCard.className = hasCapability('canCreateRequests') ? 'col-xl-7' : 'col-xl-12';
    }

    const adminUsersPage = document.getElementById('page-adminusers');
    const adminOpsPage = document.getElementById('page-adminops');
    const logsPage = document.getElementById('page-logs');
    if (adminUsersPage) adminUsersPage.style.display = hasCapability('canManageUsers') ? '' : 'none';
    if (adminOpsPage) adminOpsPage.style.display = hasCapability('canSystemMaintenance') ? '' : 'none';
    if (logsPage) logsPage.style.display = hasCapability('canViewSystemLogs') ? '' : 'none';

    // Reports nav/page hard guard
    const reportsNav = document.querySelector('.nav-item[data-page="reports"]');
    const reportsPage = document.getElementById('page-reports');
    if (!hasCapability('canViewReports')) {
        if (reportsNav) reportsNav.style.display = 'none';
        if (reportsPage) reportsPage.style.display = 'none';
    }

    // Set active page to role default
    const defaultPage = getDefaultAllowedPage();
    const defaultNav = document.querySelector(`.nav-item[data-page="${defaultPage}"]`);
    if (defaultNav) {
        document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));
        defaultNav.classList.add('active');
    }
    showPage(defaultPage);
}

function applyRoleStatLabels(stats) {
    const labels = (rolePolicy && rolePolicy.statLabels) || {};
    const totalLabel = document.getElementById('statLabelTotal');
    const inStockLabel = document.getElementById('statLabelInStock');
    const damagedLabel = document.getElementById('statLabelDamaged');
    const fourthLabel = document.getElementById('statLabelFourth');

    if (totalLabel) totalLabel.textContent = labels.total || 'Total Items';
    if (inStockLabel) inStockLabel.textContent = labels.inStock || 'In Stock';
    if (damagedLabel) damagedLabel.textContent = labels.damaged || 'Damaged Items';
    if (fourthLabel) {
        if (hasCapability('canViewSystemLogs')) {
            fourthLabel.textContent = labels.fourth || 'System Logs';
        } else if (hasCapability('canApproveRequests')) {
            fourthLabel.textContent = labels.fourth || 'Pending Approvals';
        } else {
            fourthLabel.textContent = labels.fourth || 'Pending Requests';
        }
    }
}

function mergeRoleActivities(serverActivities) {
    const activities = serverActivities || [];
    const hasServerRoleTasks = activities.some((act) =>
        typeof act.description === 'string' && act.description.startsWith('[Role Task]')
    );
    const roleActivities = hasServerRoleTasks ? [] : getRoleTaskActivityEntries();
    const merged = roleActivities.concat(activities);
    return merged.slice(0, 12);
}

function getRoleTaskActivityEntries() {
    const entries = [];
    const tasks = getRoleActivityLog();
    const nowIso = new Date().toISOString();
    tasks.forEach((task) => {
        entries.push({
            type: 'role',
            description: `[Role Task] ${task}`,
            quantity: 0,
            date: nowIso
        });
    });
    return entries;
}

function getDefaultAllowedPage() {
    if (rolePolicy && rolePolicy.defaultPage && isPageAllowed(rolePolicy.defaultPage)) {
        return rolePolicy.defaultPage;
    }
    const allowed = rolePolicy && rolePolicy.allowedPages;
    if (allowed && allowed.length > 0) {
        return allowed[0];
    }
    return 'dashboard';
}

function isPageAllowed(pageName) {
    const allowed = rolePolicy && rolePolicy.allowedPages;
    if (!allowed || allowed.length === 0) {
        return pageName === 'dashboard';
    }
    return allowed.includes(pageName);
}

function initRoleActionHandlers() {
    const submitRequestBtn = document.getElementById('submitRequestBtn');
    if (submitRequestBtn) {
        submitRequestBtn.addEventListener('click', submitStoreRequest);
    }

    const requestTableBody = document.getElementById('requestTableBody');
    if (requestTableBody) {
        requestTableBody.addEventListener('click', async (event) => {
            const approveBtn = event.target.closest('[data-request-approve]');
            const rejectBtn = event.target.closest('[data-request-reject]');
            if (approveBtn) {
                await decideStoreRequest(parseInt(approveBtn.dataset.requestApprove, 10), 'approve');
            }
            if (rejectBtn) {
                await decideStoreRequest(parseInt(rejectBtn.dataset.requestReject, 10), 'reject');
            }
        });
    }

    bindAdminAction('adminAddUserBtn', 'User management flow: Add User');
    bindAdminAction('adminUpdateUserBtn', 'User management flow: Update User');
    bindAdminAction('adminDeleteUserBtn', 'User management flow: Delete User');
    bindAdminAction('adminBackupBtn', 'Database backup queued');
    bindAdminAction('adminRestoreBtn', 'Database restore queued');
    bindAdminAction('adminMaintenanceBtn', 'System maintenance queued');
}

function bindAdminAction(elementId, message) {
    const el = document.getElementById(elementId);
    if (!el) return;
    el.addEventListener('click', () => {
        if (!hasCapability('canManageUsers') && !hasCapability('canSystemMaintenance')) {
            showToast('Access denied: admin only action', 'danger');
            return;
        }
        showToast(message, 'info');
    });
}

async function submitStoreRequest() {
    if (!hasCapability('canCreateRequests')) {
        showToast('Access denied: only Store Keeper can create requests', 'danger');
        return;
    }

    const itemId = parseInt((document.getElementById('requestItemSelect') || {}).value, 10);
    const quantity = parseFloat((document.getElementById('requestQty') || {}).value);
    const notes = ((document.getElementById('requestNotes') || {}).value || '').trim();

    if (!itemId || !quantity || quantity <= 0) {
        showToast('Select item and quantity before submitting', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.requests.create({ itemId, quantity, notes });
        if (result && result.success) {
            showToast('Store request submitted', 'success');
            document.getElementById('requestQty').value = '';
            document.getElementById('requestNotes').value = '';
            await loadRequestRecords();
            await loadDashboardData();
        } else {
            showToast((result && result.message) || 'Failed to submit request', 'danger');
        }
    } catch (error) {
        console.error('Request submit failed:', error);
        showToast('Error submitting request: ' + error.message, 'danger');
    }
}

async function decideStoreRequest(requestId, action) {
    if (!hasCapability('canApproveRequests')) {
        showToast('Access denied: only Department Head can approve/reject', 'danger');
        return;
    }
    if (!requestId || Number.isNaN(requestId)) {
        showToast('Invalid request selected', 'warning');
        return;
    }

    try {
        const result = action === 'approve'
            ? await FoodFlowAPI.requests.approve(requestId)
            : await FoodFlowAPI.requests.reject(requestId);
        if (result && result.success) {
            showToast(action === 'approve' ? 'Request approved' : 'Request rejected', 'success');
            await loadRequestRecords();
            await loadDashboardData();
        } else {
            showToast((result && result.message) || 'Could not update request', 'danger');
        }
    } catch (error) {
        console.error('Request decision failed:', error);
        showToast('Error updating request: ' + error.message, 'danger');
    }
}

function populateRequestItemSelector() {
    const selector = document.getElementById('requestItemSelect');
    if (!selector) return;

    if (!hasCapability('canCreateRequests')) {
        selector.innerHTML = '<option value="">Not available for this role</option>';
        selector.disabled = true;
        return;
    }

    selector.disabled = false;
    const options = ['<option value="">Select Item</option>'];
    availableItems.forEach((item) => {
        options.push(`<option value="${item.itemId}">${escapeHtml(item.name)} (Stock: ${item.currentStock})</option>`);
    });
    selector.innerHTML = options.join('');
}

function renderRequestQueue() {
    const body = document.getElementById('requestTableBody');
    if (!body) return;
    if (!requestRecords || requestRecords.length === 0) {
        body.innerHTML = '<tr><td colspan="6" class="text-muted">No requests found</td></tr>';
        return;
    }

    const canApprove = hasCapability('canApproveRequests');
    const rows = requestRecords.map((request) => {
        const status = (request.status || 'PENDING').toUpperCase();
        let actionHtml = '<span class="text-muted">View</span>';
        if (canApprove && status === 'PENDING') {
            actionHtml = `
                <button class="btn-action-sm" data-request-approve="${request.requestId}" title="Approve">
                  <i class="fa-solid fa-check"></i>
                </button>
                <button class="btn-action-sm" data-request-reject="${request.requestId}" title="Reject">
                  <i class="fa-solid fa-xmark"></i>
                </button>
            `;
        }
        return `
            <tr>
              <td>${request.requestId}</td>
              <td>${escapeHtml(request.requesterName || 'Store Keeper')}</td>
              <td>${escapeHtml(request.itemName || 'Item')}</td>
              <td>${request.quantityRequested || 0}</td>
              <td>${getStatusBadge(status)}</td>
              <td>${actionHtml}</td>
            </tr>
        `;
    });
    body.innerHTML = rows.join('');
}

function renderSystemLogTable(activities) {
    const tableBody = document.getElementById('systemLogsTableBody');
    if (!tableBody) return;
    const rows = (activities || []).map((entry) => {
        const rawDate = entry.date ? new Date(entry.date) : null;
        const dateText = rawDate && !Number.isNaN(rawDate.getTime()) ? rawDate.toLocaleString() : 'Recent';
        return `
            <tr>
              <td>${escapeHtml((entry.type || 'activity').toUpperCase())}</td>
              <td>${escapeHtml(entry.description || 'Activity recorded')}</td>
              <td>${entry.quantity || 0}</td>
              <td>${escapeHtml(dateText)}</td>
            </tr>
        `;
    });
    tableBody.innerHTML = rows.length > 0
        ? rows.join('')
        : '<tr><td colspan="4" class="text-muted">No activity logs</td></tr>';
}

function escapeHtml(value) {
    const text = String(value == null ? '' : value);
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
