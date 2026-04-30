/**
 * FoodFlow Inventory Management System - Main Application
 * Integrates frontend with backend servlets
 */

// Global state
let availableItems = [];
let damageRecords = [];
let usageRecords = [];
let requestRecords = [];
let adminUsers = [];
let adminUsersLoadError = '';
let pendingAdminDeleteUserId = 0;
let dashboardStats = {};
let rolePolicy = null;
let latestActivityEntries = [];
let selectedTrendRange = '30d';
let systemLogEntries = [];
let logsFilterState = {
    range: '30d',
    search: '',
    includeArchived: false,
    archiveFrom: '',
    archiveTo: '',
    page: 1,
    pageSize: 50,
    total: 0
};

// DataTables instances
let availableTable;
let damagedTable;
let perishableTable;
let nonperishableTable;
let staffTable;
let availableFilterValue = 'ALL';
let availableFilterHookAdded = false;
let pendingGlobalSearchQuery = '';
let globalSearchDebounceTimer = null;

// Chart instances
let stockTrendChart;
let categoryPieChart;

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
    selectedTrendRange = localStorage.getItem('foodflowTrendRange') || '30d';
    logsFilterState.range = selectedTrendRange;
    applyRoleBranding();
    applyRoleDashboardPolicy();
    initRoleActionHandlers();
    loadAllData();
    initCharts();
    initModals();
    initGlobalSearch();
    initAvailableTableFilter();
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
        
        const needsInventoryData = hasCapability('canViewInventory')
            || hasCapability('canUpdateInventory')
            || hasCapability('canCreateRequests')
            || hasCapability('canSearchItems');
        const needsDamageData = hasCapability('canRecordDamages') || hasCapability('canViewReports');
        const needsUsageData = hasCapability('canRecordIssuedItems') || hasCapability('canViewReports');

        if (needsInventoryData) {
            console.log('Loading items...');
            await loadItems();
        } else {
            availableItems = [];
        }

        if (needsDamageData) {
            console.log('Loading damage records...');
            await loadDamageRecords();
        } else {
            damageRecords = [];
        }

        if (needsUsageData) {
            console.log('Loading usage records...');
            await loadUsageRecords();
        } else {
            usageRecords = [];
        }

        if (hasCapability('canCreateRequests') || hasCapability('canApproveRequests')) {
            console.log('Loading request records...');
            await loadRequestRecords();
        }

        if (hasCapability('canManageUsers')) {
            console.log('Loading admin users...');
            await loadAdminUsers();
        } else {
            adminUsers = [];
            adminUsersLoadError = '';
            renderAdminUsersTable();
        }
        
        showLoading(false);
        
        const needsDataTables = needsInventoryData || needsDamageData || needsUsageData;
        if (needsDataTables) {
            // Initialize tables after data is loaded
            initializeDataTables();
        }

        renderReportsOverview();
        
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
        const stats = await FoodFlowAPI.dashboard.getStats(selectedTrendRange);
        syncSessionContextFromServer(stats);
        console.log('Dashboard stats:', stats);
        dashboardStats = stats;
        applyRoleStatLabels(stats);
        applyDashboardPanelCopy();
        const isAdminDashboard = hasCapability('canViewSystemLogs');
        
        // Update stat cards
        if (isAdminDashboard) {
            animateValue('totalItems', 0, stats.totalUsers || 0, 1000);
            animateValue('inStockCount', 0, stats.activeUsers || 0, 1000);
            animateValue('damagedCount', 0, stats.adminUsers || 0, 1000);
            animateValue('staffCheckouts', 0, stats.systemLogCount || 0, 1000);
        } else {
            animateValue('totalItems', 0, stats.totalItems || 0, 1000);
            animateValue('inStockCount', 0, stats.inStock || 0, 1000);
            animateValue('damagedCount', 0, stats.damagedCount || 0, 1000);
            animateValue('staffCheckouts', 0, stats.pendingRequests || 0, 1000);
        }
        
        // Update dashboard alert panel
        if (isAdminDashboard) {
            const systemAlerts = await FoodFlowAPI.dashboard.getSystemAlerts(selectedTrendRange);
            document.getElementById('lowStockBadge').textContent = systemAlerts.count || 0;
            populateDashboardAlerts(systemAlerts.items || [], 'system');
        } else {
            const lowStockData = await FoodFlowAPI.dashboard.getLowStock();
            document.getElementById('lowStockBadge').textContent = lowStockData.count || 0;
            populateDashboardAlerts(lowStockData.items || [], 'stock');
        }
        
        // Load recent activity
        const activity = await FoodFlowAPI.dashboard.getRecentActivity(selectedTrendRange);
        const mergedActivity = mergeRoleActivities(activity.items || []);
        latestActivityEntries = mergedActivity;
        populateRecentActivity(mergedActivity);
        if (isAdminDashboard) {
            await loadSystemLogs(true);
        } else {
            systemLogEntries = [];
            renderSystemLogTable([]);
        }
        
        // Update charts
        await updateCharts();
        
    } catch (error) {
        console.error('Failed to load dashboard data:', error);
        throw error; // Re-throw to stop loading
    }
}

function normalizeRoleValue(roleValue) {
    if (typeof normalizeUserRole === 'function') {
        return normalizeUserRole(roleValue);
    }
    const normalized = String(roleValue || '')
        .toUpperCase()
        .trim()
        .replace(/[\s-]+/g, '_');
    if (normalized === 'STORE_KEEPER') {
        return 'STOREKEEPER';
    }
    if (normalized === 'DEPARTMENT_HEAD' || normalized === 'STOREKEEPER' || normalized === 'ADMIN') {
        return normalized;
    }
    return 'STOREKEEPER';
}

function syncSessionContextFromServer(statsPayload) {
    if (!statsPayload || typeof statsPayload !== 'object') {
        return false;
    }

    const normalizedServerRole = normalizeRoleValue(statsPayload.role);
    const serverName = String(statsPayload.userName || '').trim();
    const parsedServerUserId = parseInt(statsPayload.userId, 10);
    const hasServerUserId = Number.isInteger(parsedServerUserId) && parsedServerUserId > 0;

    const currentRole = (typeof getCurrentRole === 'function')
        ? getCurrentRole()
        : normalizeRoleValue(sessionStorage.getItem('userRole'));
    const currentName = String(sessionStorage.getItem('userName') || '').trim();
    const parsedCurrentUserId = parseInt(sessionStorage.getItem('userId'), 10);
    const hasCurrentUserId = Number.isInteger(parsedCurrentUserId) && parsedCurrentUserId > 0;

    let changed = false;

    if (normalizedServerRole && currentRole !== normalizedServerRole) {
        sessionStorage.setItem('userRole', normalizedServerRole);
        changed = true;
    }

    if (serverName && currentName !== serverName) {
        sessionStorage.setItem('userName', serverName);
        changed = true;
    }

    if (hasServerUserId && (!hasCurrentUserId || parsedCurrentUserId !== parsedServerUserId)) {
        sessionStorage.setItem('userId', String(parsedServerUserId));
        changed = true;
    }

    if (!changed) {
        return false;
    }

    const refreshedContext = loadUserInfo();
    rolePolicy = (refreshedContext && refreshedContext.policy)
        ? refreshedContext.policy
        : getRolePolicy(normalizedServerRole || 'STOREKEEPER');
    applyRoleBranding();
    applyRoleDashboardPolicy();
    console.warn('Session context refreshed from server:', {
        role: normalizedServerRole || currentRole,
        userName: serverName || currentName,
        userId: hasServerUserId ? parsedServerUserId : parsedCurrentUserId
    });
    return true;
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
        const rows = await FoodFlowAPI.damage.getAll();
        damageRecords = (rows || []).map((entry) => ({
            ...entry,
            disposition: String(entry.disposition || entry.status || 'DISPOSED').toUpperCase(),
            reportedBy: entry.reportedBy || 'Unknown Staff',
            recordedByName: entry.recordedByName || 'Store Keeper',
            damageType: entry.damageType || entry.description || 'Other'
        }));
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
        const rows = await FoodFlowAPI.usage.getAll();
        usageRecords = (rows || []).map((entry) => ({
            ...entry,
            status: String(entry.status || 'ISSUED').toUpperCase(),
            issuedTo: entry.issuedTo || 'Internal Department',
            recordedByName: entry.recordedByName || entry.itemUserName || 'Store Keeper'
        }));
        console.log('Loaded', usageRecords.length, 'usage records');
    } catch (error) {
        console.error('Failed to load usage records:', error);
        throw error;
    }
}

async function loadRequestRecords() {
    try {
        if (hasCapability('canApproveRequests')) {
            requestRecords = await FoodFlowAPI.requests.getAll();
        } else if (hasCapability('canCreateRequests')) {
            requestRecords = await FoodFlowAPI.requests.getMine();
        } else {
            requestRecords = [];
        }
        requestRecords = sortRequestRecordsForQueue(requestRecords);
        renderRequestQueue();
        populateRequestItemSelector();
        renderReportsOverview();
    } catch (error) {
        console.error('Failed to load requests:', error);
        requestRecords = [];
        renderRequestQueue();
        renderReportsOverview();
    }
}

async function loadAdminUsers() {
    if (!hasCapability('canManageUsers')) {
        adminUsers = [];
        adminUsersLoadError = '';
        renderAdminUsersTable();
        return;
    }

    try {
        const payload = await FoodFlowAPI.users.list();
        if (!payload || payload.error) {
            throw new Error((payload && payload.error) || 'Could not load users');
        }
        if (!Array.isArray(payload.users)) {
            throw new Error('Unexpected user list response');
        }
        adminUsersLoadError = '';
        adminUsers = payload.users;
        renderAdminUsersTable();
    } catch (error) {
        console.error('Failed to load admin users:', error);
        adminUsers = [];
        adminUsersLoadError = error && error.message ? error.message : 'Could not load users';
        renderAdminUsersTable();
        showToast('Unable to load user list: ' + adminUsersLoadError, 'warning');
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
            search: "Search:",
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
    ensureAvailableFilterHook();
    refreshAvailableFilterOptions();
    applyAvailableTableFilter();
    
    // Damaged Items Table
    damagedTable = $('#damagedTable').DataTable({
        data: damageRecords.map(damage => [
            damage.damageId,
            damage.itemName || 'Item #' + damage.itemId,
            damage.damageType || damage.description || 'Unknown',
            damage.quantity,
            getDamageDispositionBadge(damage.disposition || damage.status || 'DISPOSED'),
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
            usage.issuedTo || usage.itemUserName || 'Staff',
            usage.itemName || 'Item #' + usage.itemId,
            usage.quantity,
            getUsageStatusBadge(usage.status || 'ISSUED'),
            getUsageActionButtons(usage)
        ]),
        order: [[0, 'desc']],
        pageLength: 10
    });

    if (pendingGlobalSearchQuery) {
        runGlobalSearch(pendingGlobalSearchQuery, false);
    }
}

/**
 * Update charts with latest data
 */
async function updateCharts() {
    try {
        const chartData = await FoodFlowAPI.dashboard.getChartData(selectedTrendRange);
        const isAdminDashboard = hasCapability('canViewSystemLogs');
        const textColor = getCssVariable('--text-primary', '#1f2937');
        const gridColor = getCssVariable('--border-color', 'rgba(31, 106, 42, 0.18)');
        const primaryColor = getCssVariable('--navy-400', '#1f6a2a');
        const secondaryColor = getCssVariable('--navy-500', '#2f7d35');
        const accentColor = getCssVariable('--accent-cyan', '#2f7d35');
        const dangerColor = getCssVariable('--accent-red', '#b3261e');
        
        // Stock Trend Chart
        if (stockTrendChart) {
            stockTrendChart.destroy();
        }
        const ctx1 = document.getElementById('stockTrendChart').getContext('2d');
        const trendLabels = isAdminDashboard
            ? (chartData.systemActivityLabels || getRecentDayLabels(7))
            : (chartData.trendLabels || getRecentDayLabels(7));
        const trendData = isAdminDashboard
            ? (chartData.systemActivityTrend || [0, 0, 0, 0, 0, 0, 0])
            : (chartData.stockTrend || [0, 0, 0, 0, 0, 0, 0]);
        const trendSeriesLabel = chartData.trendSeriesLabel || (isAdminDashboard ? 'System Events' : 'Net Inventory Movements');
        stockTrendChart = new Chart(ctx1, {
            type: 'line',
            data: {
                labels: trendLabels,
                datasets: [{
                    label: trendSeriesLabel,
                    data: trendData,
                    borderColor: primaryColor,
                    backgroundColor: isAdminDashboard ? 'rgba(47, 125, 53, 0.14)' : 'rgba(59, 130, 246, 0.1)',
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
                        beginAtZero: isAdminDashboard,
                        ticks: {
                            color: textColor
                        },
                        grid: {
                            color: gridColor
                        }
                    },
                    x: {
                        ticks: {
                            color: textColor
                        },
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
        const categories = isAdminDashboard
            ? (chartData.userRoleDistribution || { 'Admin': 0, 'Department Head': 0, 'Store Keeper': 0 })
            : (chartData.categoryDistribution || { 'Perishable': 45, 'Non-Perishable': 55 });
        categoryPieChart = new Chart(ctx2, {
            type: 'pie',
            data: {
                labels: Object.keys(categories),
                datasets: [{
                    data: Object.values(categories),
                    backgroundColor: isAdminDashboard
                        ? [secondaryColor, accentColor, dangerColor]
                        : ['#3b82f6', '#06b6d4', '#10b981', '#f59e0b'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            color: textColor,
                            padding: 15
                        }
                    }
                }
            }
        });

        syncDashboardRangeControls();
        
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
    const mobileMedia = window.matchMedia('(max-width: 991px)');

    function applyDesktopState(collapsed) {
        sidebar.classList.toggle('collapsed', collapsed);
        mainWrapper.classList.toggle('collapsed', collapsed);
    }

    function closeMobileSidebar() {
        sidebar.classList.remove('mobile-expanded');
    }

    function syncSidebarForViewport() {
        if (mobileMedia.matches) {
            closeMobileSidebar();
            applyDesktopState(false);
            return;
        }

        const savedCollapsed = localStorage.getItem('foodflowSidebarCollapsed');
        const shouldCollapse = savedCollapsed === 'true';
        applyDesktopState(shouldCollapse);
    }

    syncSidebarForViewport();

    toggleBtn.addEventListener('click', (event) => {
        event.preventDefault();
        if (mobileMedia.matches) {
            sidebar.classList.toggle('mobile-expanded');
            return;
        }

        const nextCollapsed = !sidebar.classList.contains('collapsed');
        applyDesktopState(nextCollapsed);
        localStorage.setItem('foodflowSidebarCollapsed', nextCollapsed ? 'true' : 'false');
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
            if (mobileMedia.matches) {
                closeMobileSidebar();
            }
        });
    });

    document.addEventListener('click', (event) => {
        if (!mobileMedia.matches || !sidebar.classList.contains('mobile-expanded')) {
            return;
        }
        if (sidebar.contains(event.target)) {
            return;
        }
        closeMobileSidebar();
    });

    window.addEventListener('resize', syncSidebarForViewport);
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
        const currentRole = getCurrentRole();
        const dashboardTitle = currentRole === 'ADMIN'
            ? 'Admin Dashboard'
            : 'Dashboard';
        const titles = {
            'dashboard': dashboardTitle,
            'requests': 'Store Requests',
            'available': 'Inventory',
            'damaged': 'Damaged Items',
            'perishable': 'Perishable Goods',
            'nonperishable': 'Non-Perishable Goods',
            'staffrecords': 'Issued Items',
            'reports': 'Reports',
            'adminusers': 'Manage Users',
            'adminops': 'System Operations',
            'logs': 'Activity Logs'
        };
        
        pageTitle.textContent = titles[pageName] || 'Dashboard';
        bcActive.textContent = titles[pageName] || 'Dashboard';
        
        // Refresh DataTables when showing page
        setTimeout(() => {
            if (availableTable) availableTable.columns.adjust();
            if (damagedTable) damagedTable.columns.adjust();
            if (staffTable) staffTable.columns.adjust();
        }, 100);

        if (pageName === 'reports') {
            renderReportsOverview();
        }

        if (pageName === 'logs' && hasCapability('canViewSystemLogs')) {
            loadSystemLogs(false);
        }
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
    if (!themeBtn) {
        return;
    }

    const icon = themeBtn.querySelector('i');
    const savedTheme = localStorage.getItem('foodflowTheme');
    const shouldUseLight = savedTheme ? savedTheme === 'light' : true;

    applyThemeState(shouldUseLight);

    themeBtn.addEventListener('click', () => {
        const nextIsLight = !body.classList.contains('light-mode');
        applyThemeState(nextIsLight);
        localStorage.setItem('foodflowTheme', nextIsLight ? 'light' : 'dark');
        setTimeout(() => updateCharts(), 50);
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
        const query = this.value.trim();
        pendingGlobalSearchQuery = query;

        if (globalSearchDebounceTimer) {
            clearTimeout(globalSearchDebounceTimer);
        }
        globalSearchDebounceTimer = setTimeout(() => {
            runGlobalSearch(query, false);
        }, 150);
    });

    searchInput.addEventListener('keydown', function(event) {
        if (event.key !== 'Enter') {
            return;
        }
        event.preventDefault();
        const query = this.value.trim();
        pendingGlobalSearchQuery = query;
        runGlobalSearch(query, true);
    });
}

function initAvailableTableFilter() {
    const filterSelect = document.getElementById('availableCategoryFilter');
    if (!filterSelect) {
        return;
    }

    filterSelect.addEventListener('change', function() {
        availableFilterValue = this.value || 'ALL';
        applyAvailableTableFilter();
    });

    refreshAvailableFilterOptions();
}

function refreshAvailableFilterOptions() {
    const filterSelect = document.getElementById('availableCategoryFilter');
    if (!filterSelect) {
        return;
    }

    const previousValue = filterSelect.value || availableFilterValue || 'ALL';
    const categorySet = new Set();
    const statusSet = new Set();

    (availableItems || []).forEach((item) => {
        const category = String(item.category || '').trim();
        const status = String(item.status || '').trim().toUpperCase();
        if (category) {
            categorySet.add(category);
        }
        if (status) {
            statusSet.add(status);
        }
    });

    const statusOrder = ['AVAILABLE', 'LOW_STOCK', 'OUT_OF_STOCK', 'DAMAGED'];
    const statusOptions = statusOrder.filter((status) => statusSet.has(status));
    statusSet.forEach((status) => {
        if (!statusOptions.includes(status)) {
            statusOptions.push(status);
        }
    });

    const categoryOptions = Array.from(categorySet).sort((a, b) => a.localeCompare(b));
    const options = ['<option value="ALL">All Items</option>'];

    statusOptions.forEach((status) => {
        options.push(`<option value="STATUS:${escapeHtml(status)}">Status: ${escapeHtml(formatFilterLabel(status))}</option>`);
    });
    categoryOptions.forEach((category) => {
        options.push(`<option value="CATEGORY:${escapeHtml(category)}">Category: ${escapeHtml(category)}</option>`);
    });

    filterSelect.innerHTML = options.join('');
    filterSelect.value = options.some((opt) => opt.includes(`value="${previousValue}"`))
        ? previousValue
        : 'ALL';
    availableFilterValue = filterSelect.value;
}

function ensureAvailableFilterHook() {
    if (availableFilterHookAdded || typeof $ === 'undefined' || !$.fn || !$.fn.dataTable) {
        return;
    }

    $.fn.dataTable.ext.search.push(function(settings, data) {
        if (!availableTable || settings.nTable !== availableTable.table().node()) {
            return true;
        }

        const filter = availableFilterValue || 'ALL';
        if (filter === 'ALL') {
            return true;
        }

        const category = String(data[2] || '').toUpperCase();
        const statusText = stripHtmlTags(String(data[5] || '')).toUpperCase();

        if (filter.startsWith('STATUS:')) {
            const wantedStatus = filter.substring(7).toUpperCase();
            return statusText.includes(wantedStatus.replace(/_/g, ' '));
        }
        if (filter.startsWith('CATEGORY:')) {
            const wantedCategory = filter.substring(9).toUpperCase();
            return category === wantedCategory;
        }
        return true;
    });

    availableFilterHookAdded = true;
}

function applyAvailableTableFilter() {
    if (!availableTable) {
        return;
    }
    availableTable.draw();
}

function stripHtmlTags(value) {
    return String(value || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function formatFilterLabel(statusCode) {
    return String(statusCode || '')
        .toLowerCase()
        .split('_')
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join(' ');
}

function runGlobalSearch(query, forceNavigate) {
    const normalizedQuery = String(query || '').trim();

    if (!normalizedQuery) {
        clearAllTableSearches();
        return;
    }

    const activePage = getActivePageName();
    let targetPage = activePage;
    let targetTable = getSearchableTableForPage(activePage);

    if (!targetTable && isPageAllowed('available')) {
        targetPage = 'available';
        targetTable = availableTable;
    }

    const shouldNavigate = forceNavigate || (!targetTable && normalizedQuery.length >= 2);
    if (shouldNavigate && targetPage !== activePage && isPageAllowed(targetPage)) {
        setActiveNavItem(targetPage);
        showPage(targetPage);
        targetTable = getSearchableTableForPage(targetPage);
    }

    if (!targetTable && targetPage === 'available') {
        targetTable = availableTable;
    }

    if (targetTable) {
        targetTable.search(normalizedQuery).draw();
        return;
    }

    pendingGlobalSearchQuery = normalizedQuery;
}

function getActivePageName() {
    const activePage = document.querySelector('.page.active');
    if (!activePage || !activePage.id) {
        return 'dashboard';
    }
    return activePage.id.replace('page-', '');
}

function getSearchableTableForPage(pageName) {
    if (pageName === 'available') return availableTable;
    if (pageName === 'damaged') return damagedTable;
    if (pageName === 'staffrecords') return staffTable;
    if (pageName === 'perishable') return perishableTable;
    if (pageName === 'nonperishable') return nonperishableTable;
    return null;
}

function clearAllTableSearches() {
    [availableTable, damagedTable, perishableTable, nonperishableTable, staffTable].forEach((table) => {
        if (table) {
            table.search('').draw();
        }
    });
}

function setActiveNavItem(pageName) {
    const nav = document.querySelector(`.nav-item[data-page="${pageName}"]`);
    if (!nav) {
        return;
    }
    document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));
    nav.classList.add('active');
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

    // Set active page to role default
    const defaultPage = getDefaultAllowedPage();
    const defaultNav = document.querySelector(`.nav-item[data-page="${defaultPage}"]`);
    if (defaultNav) {
        document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));
        defaultNav.classList.add('active');
    }
    showPage(defaultPage);
    applyDashboardPanelCopy();
}

function applyRoleStatLabels(stats) {
    const labels = (rolePolicy && rolePolicy.statLabels) || {};
    const totalLabel = document.getElementById('statLabelTotal');
    const inStockLabel = document.getElementById('statLabelInStock');
    const damagedLabel = document.getElementById('statLabelDamaged');
    const fourthLabel = document.getElementById('statLabelFourth');
    const rangeLabel = getRangeLabel(selectedTrendRange);

    if (totalLabel) totalLabel.textContent = labels.total || 'Total Items';
    if (inStockLabel) inStockLabel.textContent = labels.inStock || 'In Stock';
    if (damagedLabel) damagedLabel.textContent = labels.damaged || 'Damaged Items';
    if (fourthLabel) {
        if (hasCapability('canViewSystemLogs')) {
            fourthLabel.textContent = `${labels.fourth || 'System Logs'} (${rangeLabel})`;
        } else if (hasCapability('canApproveRequests')) {
            fourthLabel.textContent = labels.fourth || 'Pending Approvals';
        } else {
            fourthLabel.textContent = labels.fourth || 'Pending Requests';
        }
    }
}

function applyRoleBranding() {
    const currentRole = getCurrentRole();
    const sidebarBrandTitle = document.getElementById('sidebarBrandTitle');
    const sidebarBrandSub = document.getElementById('sidebarBrandSub');
    const pageTitle = document.getElementById('pageTitle');
    const bcActive = document.getElementById('bcActive');

    let brandTitle = 'Inventory';
    let brandSub = 'MANAGEMENT';
    let dashboardTitle = 'Dashboard';

    if (currentRole === 'ADMIN') {
        brandTitle = 'Admin';
        brandSub = 'DASHBOARD';
        dashboardTitle = 'Admin Dashboard';
    } else if (currentRole === 'DEPARTMENT_HEAD') {
        brandTitle = 'Department';
        brandSub = 'HEAD';
        dashboardTitle = 'Dashboard';
    }

    if (sidebarBrandTitle) {
        sidebarBrandTitle.textContent = brandTitle;
    }
    if (sidebarBrandSub) {
        sidebarBrandSub.textContent = brandSub;
    }
    if (pageTitle && pageTitle.textContent.trim() === 'Dashboard') {
        pageTitle.textContent = dashboardTitle;
    }
    if (bcActive && bcActive.textContent.trim() === 'Dashboard') {
        bcActive.textContent = dashboardTitle;
    }
}

function applyDashboardPanelCopy() {
    const isAdminDashboard = hasCapability('canViewSystemLogs');
    const rangeLabel = getRangeLabel(selectedTrendRange);

    const primaryChartTitle = document.getElementById('dashboardPrimaryChartTitle');
    const secondaryChartTitle = document.getElementById('dashboardSecondaryChartTitle');
    const alertsTitle = document.getElementById('dashboardAlertsTitle');

    if (primaryChartTitle) {
        primaryChartTitle.innerHTML = isAdminDashboard
            ? `<i id="dashboardPrimaryChartIcon" class="fa-solid fa-chart-line"></i> System Activity (${rangeLabel})`
            : `<i id="dashboardPrimaryChartIcon" class="fa-solid fa-chart-line"></i> Inventory Movements (${rangeLabel})`;
    }
    if (secondaryChartTitle) {
        secondaryChartTitle.innerHTML = isAdminDashboard
            ? '<i id="dashboardSecondaryChartIcon" class="fa-solid fa-users"></i> User Role Distribution'
            : '<i id="dashboardSecondaryChartIcon" class="fa-solid fa-chart-pie"></i> Category Split';
    }
    if (alertsTitle) {
        alertsTitle.innerHTML = isAdminDashboard
            ? '<i id="dashboardAlertsIcon" class="fa-solid fa-triangle-exclamation"></i> System Alerts'
            : '<i id="dashboardAlertsIcon" class="fa-solid fa-triangle-exclamation"></i> Low Stock Alerts';
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
            const invoiceBtn = event.target.closest('[data-request-invoice]');
            const viewBtn = event.target.closest('[data-request-view]');
            if (approveBtn) {
                await decideStoreRequest(parseInt(approveBtn.dataset.requestApprove, 10), 'approve');
            }
            if (rejectBtn) {
                openRejectRequestModal(parseInt(rejectBtn.dataset.requestReject, 10));
            }
            if (invoiceBtn) {
                exportRequestInvoice(parseInt(invoiceBtn.dataset.requestInvoice, 10));
            }
            if (viewBtn) {
                viewStoreRequestDetails(parseInt(viewBtn.dataset.requestView, 10));
            }
        });
    }

    const saveRejectRequestBtn = document.getElementById('saveRejectRequestBtn');
    if (saveRejectRequestBtn) {
        saveRejectRequestBtn.addEventListener('click', submitStoreRequestRejection);
    }

    const adminCreateUserBtn = document.getElementById('adminCreateUserBtn');
    if (adminCreateUserBtn) {
        adminCreateUserBtn.addEventListener('click', submitAdminUserCreate);
    }

    const adminUsersTableBody = document.getElementById('adminUsersTableBody');
    if (adminUsersTableBody) {
        adminUsersTableBody.addEventListener('click', handleAdminUsersTableActions);
    }

    const adminSaveUserUpdateBtn = document.getElementById('adminSaveUserUpdateBtn');
    if (adminSaveUserUpdateBtn) {
        adminSaveUserUpdateBtn.addEventListener('click', saveAdminUserUpdate);
    }

    const adminSavePasswordResetBtn = document.getElementById('adminSavePasswordResetBtn');
    if (adminSavePasswordResetBtn) {
        adminSavePasswordResetBtn.addEventListener('click', saveAdminPasswordReset);
    }

    const userBadge = document.getElementById('userBadge');
    if (userBadge) {
        userBadge.addEventListener('click', openAccountSettingsModal);
    }

    const saveAccountSettingsBtn = document.getElementById('saveAccountSettingsBtn');
    if (saveAccountSettingsBtn) {
        saveAccountSettingsBtn.addEventListener('click', submitAccountSettingsUpdate);
    }

    const adminConfirmDeleteUserBtn = document.getElementById('adminConfirmDeleteUserBtn');
    if (adminConfirmDeleteUserBtn) {
        adminConfirmDeleteUserBtn.addEventListener('click', confirmAdminUserDelete);
    }

    const exportLogsPdfBtn = document.getElementById('exportLogsPdfBtn');
    if (exportLogsPdfBtn) {
        exportLogsPdfBtn.addEventListener('click', exportSystemLogsPdf);
    }

    const dashboardTrendRange = document.getElementById('dashboardTrendRange');
    if (dashboardTrendRange) {
        dashboardTrendRange.value = selectedTrendRange;
        dashboardTrendRange.addEventListener('change', async () => {
            selectedTrendRange = dashboardTrendRange.value || '30d';
            logsFilterState.range = selectedTrendRange;
            logsFilterState.page = 1;
            const logsRangeFilter = document.getElementById('logsRangeFilter');
            if (logsRangeFilter) {
                logsRangeFilter.value = selectedTrendRange;
            }
            localStorage.setItem('foodflowTrendRange', selectedTrendRange);
            applyRoleStatLabels(dashboardStats || {});
            applyDashboardPanelCopy();
            await loadDashboardData();
        });
    }

    const logsRangeFilter = document.getElementById('logsRangeFilter');
    if (logsRangeFilter) {
        logsRangeFilter.value = logsFilterState.range;
    }
    const logsSearchInput = document.getElementById('logsSearchInput');
    if (logsSearchInput) {
        logsSearchInput.value = logsFilterState.search;
        logsSearchInput.addEventListener('keydown', async (event) => {
            if (event.key === 'Enter') {
                event.preventDefault();
                await applySystemLogFilters();
            }
        });
    }
    const logsIncludeArchived = document.getElementById('logsIncludeArchived');
    if (logsIncludeArchived) {
        logsIncludeArchived.checked = Boolean(logsFilterState.includeArchived);
    }
    const logsApplyFilterBtn = document.getElementById('logsApplyFilterBtn');
    if (logsApplyFilterBtn) {
        logsApplyFilterBtn.addEventListener('click', applySystemLogFilters);
    }
    const logsArchiveBtn = document.getElementById('logsArchiveBtn');
    if (logsArchiveBtn) {
        logsArchiveBtn.addEventListener('click', openArchiveLogsModal);
    }
    const confirmArchiveLogsBtn = document.getElementById('confirmArchiveLogsBtn');
    if (confirmArchiveLogsBtn) {
        confirmArchiveLogsBtn.addEventListener('click', submitArchiveLogs);
    }
    const logsPrevPageBtn = document.getElementById('logsPrevPageBtn');
    if (logsPrevPageBtn) {
        logsPrevPageBtn.addEventListener('click', async () => {
            if (logsFilterState.page <= 1) {
                return;
            }
            logsFilterState.page -= 1;
            await loadSystemLogs(false);
        });
    }
    const logsNextPageBtn = document.getElementById('logsNextPageBtn');
    if (logsNextPageBtn) {
        logsNextPageBtn.addEventListener('click', async () => {
            const pageCount = Math.max(1, Math.ceil((logsFilterState.total || 0) / logsFilterState.pageSize));
            if (logsFilterState.page >= pageCount) {
                return;
            }
            logsFilterState.page += 1;
            await loadSystemLogs(false);
        });
    }

    bindClick('exportStockPdfBtn', exportStockReportPdf);
    bindClick('exportStockCsvBtn', exportStockReportCsv);
    bindClick('exportDamagePdfBtn', exportDamageReportPdf);
    bindClick('exportDamageCsvBtn', exportDamageReportCsv);
    bindClick('exportUsagePdfBtn', exportUsageReportPdf);
    bindClick('exportUsageCsvBtn', exportUsageReportCsv);

    bindAdminAction('adminBackupBtn', 'Database backup queued');
    bindAdminAction('adminRestoreBtn', 'Database restore queued');
    bindAdminAction('adminMaintenanceBtn', 'System maintenance queued');
}

function bindClick(elementId, handler) {
    const el = document.getElementById(elementId);
    if (!el) return;
    el.addEventListener('click', handler);
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

async function decideStoreRequest(requestId, action, rejectionNote) {
    if (!requestId || Number.isNaN(requestId)) {
        showToast('Invalid request selected', 'warning');
        return false;
    }

    try {
        const result = action === 'approve'
            ? await FoodFlowAPI.requests.approve(requestId)
            : await FoodFlowAPI.requests.reject(requestId, rejectionNote || '');
        if (result && result.success) {
            showToast(action === 'approve' ? 'Request approved' : 'Request rejected', 'success');
            if (action === 'approve' && window.confirm('Request approved. Generate invoice now?')) {
                exportRequestInvoice(requestId, true);
            }
            await loadRequestRecords();
            await loadDashboardData();
            return true;
        } else {
            showToast((result && (result.message || result.error)) || 'Could not update request', 'danger');
            return false;
        }
    } catch (error) {
        console.error('Request decision failed:', error);
        showToast('Error updating request: ' + error.message, 'danger');
        return false;
    }
}

function openRejectRequestModal(requestId) {
    const request = (requestRecords || []).find((entry) => Number(entry.requestId) === Number(requestId));
    if (!request) {
        showToast('Request not found', 'warning');
        return;
    }

    const idEl = document.getElementById('rejectRequestId');
    const summaryEl = document.getElementById('rejectRequestSummary');
    const noteEl = document.getElementById('rejectRequestNote');
    const modalEl = document.getElementById('rejectRequestModal');

    if (!idEl || !summaryEl || !noteEl || !modalEl) {
        showToast('Reject-request modal is unavailable', 'danger');
        return;
    }

    idEl.value = String(request.requestId);
    summaryEl.value = `#${request.requestId} - ${request.itemName || 'Item'} (${request.quantityRequested || 0})`;
    noteEl.value = '';

    const modal = new bootstrap.Modal(modalEl);
    modal.show();
}

async function submitStoreRequestRejection() {
    const requestId = parseInt((document.getElementById('rejectRequestId') || {}).value, 10);
    const note = ((document.getElementById('rejectRequestNote') || {}).value || '').trim();

    if (!requestId || Number.isNaN(requestId)) {
        showToast('Invalid request selected', 'warning');
        return;
    }

    const success = await decideStoreRequest(requestId, 'reject', note);
    if (success) {
        closeModal('rejectRequestModal');
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
        const viewButton = `
            <button class="btn-action-sm" data-request-view="${request.requestId}" title="View Details">
              <i class="fa-solid fa-eye"></i>
            </button>
        `;
        let actionHtml = viewButton;
        if (canApprove && status === 'PENDING') {
            actionHtml = `
                <button class="btn-action-sm" data-request-approve="${request.requestId}" title="Approve">
                  <i class="fa-solid fa-check"></i>
                </button>
                <button class="btn-action-sm" data-request-reject="${request.requestId}" title="Reject">
                  <i class="fa-solid fa-xmark"></i>
                </button>
                ${viewButton}
            `;
        } else if (canApprove && status === 'APPROVED') {
            actionHtml = `
                <button class="btn-action-sm" data-request-invoice="${request.requestId}" title="Generate Invoice">
                  <i class="fa-solid fa-file-invoice"></i>
                </button>
                ${viewButton}
            `;
        }
        const quantity = status === 'APPROVED'
            ? (request.quantityApproved || request.quantityRequested || 0)
            : (request.quantityRequested || 0);
        return `
            <tr>
              <td>${request.requestId}</td>
              <td>${escapeHtml(request.requesterName || 'Store Keeper')}</td>
              <td>${escapeHtml(request.itemName || 'Item')}</td>
              <td>${quantity}</td>
              <td>${getRequestStatusBadge(status)}</td>
              <td>${actionHtml}</td>
            </tr>
        `;
    });
    body.innerHTML = rows.join('');
}

function splitRequestNotes(rawNotes) {
    const text = String(rawNotes || '').trim();
    const marker = 'Department Rejection Note:';
    if (!text) {
        return { requesterNotes: '', rejectionReason: '' };
    }
    const markerIndex = text.lastIndexOf(marker);
    if (markerIndex < 0) {
        return { requesterNotes: text, rejectionReason: '' };
    }
    return {
        requesterNotes: text.slice(0, markerIndex).trim(),
        rejectionReason: text.slice(markerIndex + marker.length).trim()
    };
}

function viewStoreRequestDetails(requestId) {
    const request = (requestRecords || []).find((entry) => Number(entry.requestId) === Number(requestId));
    if (!request) {
        showToast('Request details not found', 'warning');
        return;
    }

    if (typeof openSharedDetailsModal !== 'function') {
        showToast('Details modal is unavailable', 'danger');
        return;
    }

    const status = (request.status || 'PENDING').toUpperCase();
    const notesSplit = splitRequestNotes(request.notes);
    const requestedQty = Number(request.quantityRequested || 0);
    const approvedQty = Number(request.quantityApproved || 0);
    const finalQty = status === 'APPROVED' ? approvedQty : requestedQty;
    const decisionDateLabel = status === 'REJECTED' ? 'Rejected Date' : 'Approved Date';
    const decisionByLabel = status === 'REJECTED' ? 'Rejected By' : 'Approved By';
    const decisionBy = request.approverName || 'Department Head';
    const requesterNotes = notesSplit.requesterNotes || 'No requester note.';
    const rejectionReason = notesSplit.rejectionReason || '';
    const statusBadge = getRequestStatusBadge(status);

    const bodyHtml = `
        <div class="detail-grid">
            <div class="detail-item">
                <div class="detail-label">Request ID</div>
                <div class="detail-value">${request.requestId}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Status</div>
                <div class="detail-value">${statusBadge}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Requester</div>
                <div class="detail-value">${escapeHtml(request.requesterName || 'Store Keeper')}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Item</div>
                <div class="detail-value">${escapeHtml(request.itemName || 'Inventory Item')}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Quantity Requested</div>
                <div class="detail-value">${requestedQty}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">${status === 'APPROVED' ? 'Quantity Approved' : 'Quantity'}</div>
                <div class="detail-value">${finalQty}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">Request Date</div>
                <div class="detail-value">${escapeHtml(formatDateTimeValue(request.requestDate))}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">${decisionDateLabel}</div>
                <div class="detail-value">${escapeHtml(formatDateTimeValue(request.approvedDate))}</div>
            </div>
            <div class="detail-item">
                <div class="detail-label">${decisionByLabel}</div>
                <div class="detail-value">${escapeHtml(decisionBy)}</div>
            </div>
            <div class="detail-item" style="grid-column: 1 / -1;">
                <div class="detail-label">Requester Note</div>
                <div class="detail-value">${escapeHtml(requesterNotes)}</div>
            </div>
            ${status === 'REJECTED'
                ? `
            <div class="detail-item" style="grid-column: 1 / -1;">
                <div class="detail-label">Rejection Reason</div>
                <div class="detail-value">${escapeHtml(rejectionReason || 'No rejection reason provided.')}</div>
            </div>
            `
                : ''}
        </div>
    `;

    openSharedDetailsModal('Request Details', 'fa-file-lines', bodyHtml);
}

function getRequestStatusBadge(status) {
    const normalized = (status || 'PENDING').toUpperCase();
    if (normalized === 'PENDING') {
        return '<span class="badge badge-amber">Pending</span>';
    }
    if (normalized === 'APPROVED') {
        return '<span class="badge badge-green">Approved</span>';
    }
    if (normalized === 'REJECTED') {
        return '<span class="badge badge-red">Rejected</span>';
    }
    return `<span class="badge badge-blue">${escapeHtml(normalized)}</span>`;
}

function sortRequestRecordsForQueue(records) {
    const list = Array.isArray(records) ? records.slice() : [];
    const priority = { PENDING: 0, APPROVED: 1, REJECTED: 2 };
    list.sort((a, b) => {
        const aStatus = (a.status || 'PENDING').toUpperCase();
        const bStatus = (b.status || 'PENDING').toUpperCase();
        const aPriority = Object.prototype.hasOwnProperty.call(priority, aStatus) ? priority[aStatus] : 3;
        const bPriority = Object.prototype.hasOwnProperty.call(priority, bStatus) ? priority[bStatus] : 3;
        if (aPriority !== bPriority) {
            return aPriority - bPriority;
        }

        const aDate = toSortableTime(a.requestDate || a.approvedDate);
        const bDate = toSortableTime(b.requestDate || b.approvedDate);
        return bDate - aDate;
    });
    return list;
}

function renderReportsOverview() {
    const reportPage = document.getElementById('page-reports');
    if (!reportPage) {
        return;
    }

    const stockRows = buildStockReportRows();
    const damageRows = buildDamageReportRows();
    const usageRows = buildUsageReportRows();

    setText('reportStockCount', stockRows.length);
    setText('reportLowStockCount', stockRows.filter((entry) => entry.status === 'LOW_STOCK').length);
    setText('reportDamageCount', damageRows.length);
    setText('reportDamageQty', sumRows(damageRows, 'quantity'));
    setText('reportUsageCount', usageRows.length);
    setText('reportUsageQty', sumRows(usageRows, 'quantity'));

    renderReportPreview(
        'reportStockPreviewBody',
        stockRows.slice(0, 6),
        (entry) => `
            <tr>
              <td>${escapeHtml(entry.name)}</td>
              <td>${entry.quantity} ${escapeHtml(entry.unit)}</td>
              <td>${getStatusBadge(entry.status)}</td>
            </tr>
        `,
        3,
        'No inventory records'
    );
    renderReportPreview(
        'reportDamagePreviewBody',
        damageRows.slice(0, 6),
        (entry) => `
            <tr>
              <td>${escapeHtml(entry.itemName)}</td>
              <td>${entry.quantity}</td>
              <td>${escapeHtml(formatDateTimeValue(entry.date))}</td>
            </tr>
        `,
        3,
        'No damage records'
    );
    renderReportPreview(
        'reportUsagePreviewBody',
        usageRows.slice(0, 6),
        (entry) => `
            <tr>
              <td>${escapeHtml(entry.itemName)}</td>
              <td>${escapeHtml(entry.issuedTo)}</td>
              <td>${entry.quantity}</td>
            </tr>
        `,
        3,
        'No issuing records'
    );
}

function renderReportPreview(bodyId, rows, rowRenderer, colspan, emptyLabel) {
    const body = document.getElementById(bodyId);
    if (!body) {
        return;
    }
    if (!rows || rows.length === 0) {
        body.innerHTML = `<tr><td colspan="${colspan}" class="text-muted">${emptyLabel}</td></tr>`;
        return;
    }
    body.innerHTML = rows.map((row) => rowRenderer(row)).join('');
}

function setText(elementId, value) {
    const el = document.getElementById(elementId);
    if (!el) {
        return;
    }
    el.textContent = value;
}

function sumRows(rows, field) {
    return rows.reduce((total, row) => total + Number(row[field] || 0), 0);
}

function buildStockReportRows() {
    return (availableItems || []).map((item) => ({
        itemId: item.itemId,
        name: item.name || `Item #${item.itemId}`,
        category: item.category || 'N/A',
        quantity: Number(item.currentStock || 0),
        unit: item.unitOfMeasure || 'Units',
        status: item.status || 'AVAILABLE'
    }));
}

function buildDamageReportRows() {
    return (damageRecords || []).map((entry) => ({
        damageId: entry.damageId,
        itemName: entry.itemName || `Item #${entry.itemId || 'N/A'}`,
        damageType: entry.damageType || entry.description || 'Unknown',
        quantity: Number(entry.quantity || 0),
        reportedBy: entry.reportedBy || 'N/A',
        date: entry.dateString || entry.reportDate || ''
    }));
}

function buildUsageReportRows() {
    return (usageRecords || []).map((entry) => ({
        usageId: entry.usageId,
        itemName: entry.itemName || `Item #${entry.itemId || 'N/A'}`,
        issuedTo: entry.issuedTo || entry.itemUserName || 'N/A',
        quantity: Number(entry.quantity || 0),
        status: entry.status || 'ISSUED',
        date: entry.date || ''
    }));
}

function exportStockReportPdf() {
    if (!hasCapability('canViewReports')) {
        showToast('Access denied: report export requires Department Head role', 'danger');
        return;
    }
    const rows = buildStockReportRows();
    exportRowsToPdf(
        'Stock Report',
        ['ID', 'Item', 'Category', 'Quantity', 'Unit', 'Status'],
        rows.map((entry) => [
            entry.itemId,
            entry.name,
            entry.category,
            entry.quantity,
            entry.unit,
            entry.status
        ]),
        `foodflow-stock-report-${new Date().toISOString().slice(0, 10)}.pdf`
    );
}

function exportStockReportCsv() {
    if (!hasCapability('canViewReports')) {
        showToast('Access denied: report export requires Department Head role', 'danger');
        return;
    }
    const rows = buildStockReportRows().map((entry) => [
        entry.itemId,
        entry.name,
        entry.category,
        entry.quantity,
        entry.unit,
        entry.status
    ]);
    exportRowsToCsv(
        ['ID', 'Item', 'Category', 'Quantity', 'Unit', 'Status'],
        rows,
        `foodflow-stock-report-${new Date().toISOString().slice(0, 10)}.csv`
    );
}

function exportDamageReportPdf() {
    if (!hasCapability('canViewReports')) {
        showToast('Access denied: report export requires Department Head role', 'danger');
        return;
    }
    const rows = buildDamageReportRows();
    exportRowsToPdf(
        'Damage Report',
        ['Ref', 'Item', 'Type', 'Quantity', 'Reported By', 'Date'],
        rows.map((entry) => [
            entry.damageId,
            entry.itemName,
            entry.damageType,
            entry.quantity,
            entry.reportedBy,
            formatDateTimeValue(entry.date)
        ]),
        `foodflow-damage-report-${new Date().toISOString().slice(0, 10)}.pdf`
    );
}

function exportDamageReportCsv() {
    if (!hasCapability('canViewReports')) {
        showToast('Access denied: report export requires Department Head role', 'danger');
        return;
    }
    const rows = buildDamageReportRows().map((entry) => [
        entry.damageId,
        entry.itemName,
        entry.damageType,
        entry.quantity,
        entry.reportedBy,
        formatDateTimeValue(entry.date)
    ]);
    exportRowsToCsv(
        ['Ref', 'Item', 'Type', 'Quantity', 'Reported By', 'Date'],
        rows,
        `foodflow-damage-report-${new Date().toISOString().slice(0, 10)}.csv`
    );
}

function exportUsageReportPdf() {
    if (!hasCapability('canViewReports')) {
        showToast('Access denied: report export requires Department Head role', 'danger');
        return;
    }
    const rows = buildUsageReportRows();
    exportRowsToPdf(
        'Issuing/Borrowing Report',
        ['Ref', 'Item', 'Issued To', 'Quantity', 'Status', 'Date'],
        rows.map((entry) => [
            entry.usageId,
            entry.itemName,
            entry.issuedTo,
            entry.quantity,
            entry.status,
            formatDateTimeValue(entry.date)
        ]),
        `foodflow-issuing-report-${new Date().toISOString().slice(0, 10)}.pdf`
    );
}

function exportUsageReportCsv() {
    if (!hasCapability('canViewReports')) {
        showToast('Access denied: report export requires Department Head role', 'danger');
        return;
    }
    const rows = buildUsageReportRows().map((entry) => [
        entry.usageId,
        entry.itemName,
        entry.issuedTo,
        entry.quantity,
        entry.status,
        formatDateTimeValue(entry.date)
    ]);
    exportRowsToCsv(
        ['Ref', 'Item', 'Issued To', 'Quantity', 'Status', 'Date'],
        rows,
        `foodflow-issuing-report-${new Date().toISOString().slice(0, 10)}.csv`
    );
}

function exportRequestInvoice(requestId, treatAsApproved = false) {
    if (!hasCapability('canApproveRequests')) {
        showToast('Access denied: invoice generation is for Department Head', 'danger');
        return;
    }

    const request = (requestRecords || []).find((entry) => Number(entry.requestId) === Number(requestId));
    if (!request) {
        showToast('Request not found for invoice generation', 'warning');
        return;
    }

    const status = treatAsApproved ? 'APPROVED' : (request.status || 'PENDING').toUpperCase();
    if (status !== 'APPROVED') {
        showToast('Invoice can only be generated for approved requests', 'warning');
        return;
    }

    if (!window.jspdf || !window.jspdf.jsPDF) {
        showToast('PDF export library did not load. Refresh and try again.', 'danger');
        return;
    }

    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ unit: 'pt', format: 'a4' });
    const left = 48;
    const quantity = request.quantityApproved || request.quantityRequested || 0;
    const generatedAt = new Date();
    const approver = sessionStorage.getItem('userName') || 'Department Head';
    let y = drawFoodFlowReportHeader(doc, 'Request Invoice', generatedAt, approver) + 12;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(10);
    doc.text(`Invoice No: FF-REQ-${request.requestId}-${generatedAt.toISOString().slice(0, 10)}`, left, y);
    y += 14;
    y += 10;

    doc.setFont('helvetica', 'bold');
    doc.text('Request Details', left, y);
    y += 14;
    doc.setFont('helvetica', 'normal');
    doc.text(`Request ID: ${request.requestId}`, left, y);
    y += 14;
    doc.text(`Requester: ${request.requesterName || 'Store Keeper'}`, left, y);
    y += 14;
    doc.text(`Item: ${request.itemName || 'Inventory Item'}`, left, y);
    y += 14;
    doc.text(`Quantity Approved: ${quantity}`, left, y);
    y += 14;
    doc.text(`Request Date: ${formatDateTimeValue(request.requestDate)}`, left, y);
    y += 14;
    doc.text(`Approval Date: ${formatDateTimeValue(request.approvedDate || generatedAt.toISOString())}`, left, y);
    y += 18;

    const notes = request.notes ? String(request.notes) : 'No notes provided.';
    doc.setFont('helvetica', 'bold');
    doc.text('Notes', left, y);
    y += 14;
    doc.setFont('helvetica', 'normal');
    const wrappedNotes = doc.splitTextToSize(notes, 500);
    wrappedNotes.forEach((line) => {
        doc.text(line, left, y);
        y += 13;
    });

    y += 18;
    doc.setFontSize(9);
    doc.text('For forwarding to school administration/procurement records.', left, y);

    doc.save(`foodflow-invoice-request-${request.requestId}.pdf`);
    showToast('Invoice generated for approved request', 'success');
}

function parseCssColorToRgb(colorValue, fallback) {
    const value = String(colorValue || '').trim();
    if (!value) {
        return fallback;
    }

    const hexMatch = value.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);
    if (hexMatch) {
        const hex = hexMatch[1];
        if (hex.length === 3) {
            return [
                parseInt(hex[0] + hex[0], 16),
                parseInt(hex[1] + hex[1], 16),
                parseInt(hex[2] + hex[2], 16)
            ];
        }
        return [
            parseInt(hex.slice(0, 2), 16),
            parseInt(hex.slice(2, 4), 16),
            parseInt(hex.slice(4, 6), 16)
        ];
    }

    const rgbMatch = value.match(/^rgba?\(([^)]+)\)$/i);
    if (rgbMatch) {
        const parts = rgbMatch[1]
            .split(',')
            .map((part) => parseFloat(part.trim()))
            .filter((part) => !Number.isNaN(part));
        if (parts.length >= 3) {
            return [
                Math.max(0, Math.min(255, Math.round(parts[0]))),
                Math.max(0, Math.min(255, Math.round(parts[1]))),
                Math.max(0, Math.min(255, Math.round(parts[2])))
            ];
        }
    }

    return fallback;
}

function drawGradientCircleFill(doc, centerX, centerY, radius, startRgb, endRgb) {
    const steps = 60;
    const width = (radius * 2) / steps;

    for (let i = 0; i < steps; i += 1) {
        const t = i / (steps - 1);
        const color = [
            Math.round(startRgb[0] + ((endRgb[0] - startRgb[0]) * t)),
            Math.round(startRgb[1] + ((endRgb[1] - startRgb[1]) * t)),
            Math.round(startRgb[2] + ((endRgb[2] - startRgb[2]) * t))
        ];

        const x = centerX - radius + ((i + 0.5) * width);
        const distanceFromCenter = Math.abs(x - centerX);
        const halfHeight = Math.sqrt(Math.max(0, (radius * radius) - (distanceFromCenter * distanceFromCenter)));
        const yTop = centerY - halfHeight;
        const yBottom = centerY + halfHeight;

        doc.setDrawColor(color[0], color[1], color[2]);
        doc.setLineWidth(Math.max(1, width + 0.2));
        doc.line(x, yTop, x, yBottom);
    }
}

function drawFoodFlowReportHeader(doc, title, generatedAt, generatedBy) {
    const pageWidth = doc.internal.pageSize.getWidth();
    const left = 36;
    const right = pageWidth - 36;
    const logoSize = 30;
    const logoCenterX = left + (logoSize / 2);
    const logoCenterY = 49;
    const accentGreen = parseCssColorToRgb(getCssVariable('--accent-green', '#2f7d35'), [47, 125, 53]);
    const accentRed = parseCssColorToRgb(getCssVariable('--accent-red', '#b3261e'), [179, 38, 30]);
    drawGradientCircleFill(doc, logoCenterX, logoCenterY, logoSize / 2, accentGreen, accentRed);

    // Draw a simple fork + knife mark to match the login/landing logo style.
    doc.setTextColor(255, 255, 255);
    doc.setDrawColor(255, 255, 255);
    const forkX = logoCenterX - 4;
    const forkTop = logoCenterY - 8;
    const forkMid = logoCenterY - 2;
    const forkBottom = logoCenterY + 8;
    doc.setLineWidth(1.3);
    doc.line(forkX - 2.2, forkTop, forkX - 2.2, forkMid);
    doc.line(forkX, forkTop, forkX, forkMid);
    doc.line(forkX + 2.2, forkTop, forkX + 2.2, forkMid);
    doc.line(forkX - 2.6, forkMid, forkX + 2.6, forkMid);
    doc.line(forkX, forkMid, forkX, forkBottom);

    const knifeX = logoCenterX + 5;
    doc.setLineWidth(2.1);
    doc.line(knifeX, logoCenterY - 8, knifeX, logoCenterY + 8);
    doc.setLineWidth(1.2);
    doc.line(knifeX, logoCenterY - 8, knifeX + 2.4, logoCenterY - 5.5);

    doc.setTextColor(0, 0, 0);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(16);
    doc.text('FoodFlow', left + logoSize + 10, 48);
    doc.setFontSize(12);
    doc.text(title, left + logoSize + 10, 64);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.text(`Generated on: ${generatedAt.toLocaleString()}`, right, 48, { align: 'right' });
    doc.text(`Generated by: ${generatedBy}`, right, 62, { align: 'right' });

    doc.setDrawColor(accentGreen[0], accentGreen[1], accentGreen[2]);
    doc.setLineWidth(1);
    doc.line(left, 78, right, 78);
    doc.setDrawColor(180, 180, 180);
    doc.setLineWidth(0.5);

    return 90;
}

function drawTableHeaderRow(doc, headers, columnWidths, x, y, rowHeight) {
    const headerBg = [31, 106, 42];
    let cellX = x;
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);

    headers.forEach((header, index) => {
        const width = columnWidths[index];
        doc.setFillColor(headerBg[0], headerBg[1], headerBg[2]);
        doc.rect(cellX, y, width, rowHeight, 'F');
        doc.setTextColor(255, 255, 255);
        doc.text(String(header || ''), cellX + 6, y + 13);
        cellX += width;
    });

    doc.setTextColor(0, 0, 0);
    return y + rowHeight;
}

function exportRowsToPdf(title, headers, rows, filename) {
    if (!window.jspdf || !window.jspdf.jsPDF) {
        showToast('PDF export library did not load. Refresh and try again.', 'danger');
        return;
    }

    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ unit: 'pt', format: 'a4' });
    const generatedBy = sessionStorage.getItem('userName') || 'Department Head';
    const generatedAt = new Date();
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();
    const left = 36;
    const right = pageWidth - 36;
    const bottom = pageHeight - 44;
    const tableWidth = right - left;
    const safeHeaders = Array.isArray(headers) ? headers : [];
    const safeRows = Array.isArray(rows) ? rows : [];
    const columnCount = Math.max(1, safeHeaders.length);
    const columnWidths = Array(columnCount).fill(tableWidth / columnCount);
    const headerRowHeight = 20;
    const rowPaddingY = 6;
    const rowLineHeight = 11;
    const minRowHeight = 18;

    let y = drawFoodFlowReportHeader(doc, title, generatedAt, generatedBy);
    y = drawTableHeaderRow(doc, safeHeaders, columnWidths, left, y, headerRowHeight);

    if (safeRows.length === 0) {
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(10);
        doc.rect(left, y, tableWidth, 24);
        doc.text('No rows available for this report.', left + 6, y + 16);
    } else {
        safeRows.forEach((row, rowIndex) => {
            const normalizedRow = Array.isArray(row) ? row : [];
            const wrappedCells = [];
            let rowHeight = minRowHeight;

            for (let col = 0; col < columnCount; col += 1) {
                const rawValue = normalizedRow[col];
                const text = String(rawValue == null ? '' : rawValue);
                const wrapped = doc.splitTextToSize(text, columnWidths[col] - 10);
                const cellHeight = Math.max(minRowHeight, (wrapped.length * rowLineHeight) + rowPaddingY + 2);
                wrappedCells.push(wrapped);
                if (cellHeight > rowHeight) {
                    rowHeight = cellHeight;
                }
            }

            if (y + rowHeight > bottom) {
                doc.addPage();
                y = drawFoodFlowReportHeader(doc, `${title} (Continued)`, generatedAt, generatedBy);
                y = drawTableHeaderRow(doc, safeHeaders, columnWidths, left, y, headerRowHeight);
            }

            const stripe = rowIndex % 2 === 0 ? 248 : 255;
            let cellX = left;
            for (let col = 0; col < columnCount; col += 1) {
                doc.setFillColor(stripe, stripe, stripe);
                doc.rect(cellX, y, columnWidths[col], rowHeight, 'F');
                doc.rect(cellX, y, columnWidths[col], rowHeight);
                doc.setFont('helvetica', 'normal');
                doc.setFontSize(9);
                wrappedCells[col].forEach((line, lineIndex) => {
                    doc.text(String(line), cellX + 5, y + rowPaddingY + 8 + (lineIndex * rowLineHeight));
                });
                cellX += columnWidths[col];
            }

            y += rowHeight;
        });
    }

    doc.save(filename);
    showToast(`${title} exported to PDF`, 'success');
}

function exportRowsToCsv(headers, rows, filename) {
    const lines = [headers.map(escapeCsvValue).join(',')];
    (rows || []).forEach((row) => {
        lines.push(row.map(escapeCsvValue).join(','));
    });
    const csv = lines.join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    showToast('Report exported to CSV', 'success');
}

function escapeCsvValue(value) {
    const text = String(value == null ? '' : value);
    if (/[",\r\n]/.test(text)) {
        return `"${text.replace(/"/g, '""')}"`;
    }
    return text;
}

async function submitAdminUserCreate() {
    if (!hasCapability('canManageUsers')) {
        showToast('Access denied: admin only action', 'danger');
        return;
    }

    const username = (document.getElementById('adminNewUsername') || {}).value || '';
    const email = (document.getElementById('adminNewEmail') || {}).value || '';
    const role = (document.getElementById('adminNewRole') || {}).value || '';
    const tempPassword = (document.getElementById('adminNewPassword') || {}).value || '';

    if (!username.trim() || !email.trim() || !role.trim() || !tempPassword.trim()) {
        showToast('Fill in username, email, role, and temp password', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.users.create({
            username: username.trim(),
            email: email.trim(),
            role: role.trim(),
            tempPassword: tempPassword
        });

        if (result && result.success) {
            showToast('User created with temporary credentials', 'success');
            adminUsersLoadError = '';
            document.getElementById('adminNewUsername').value = '';
            document.getElementById('adminNewEmail').value = '';
            document.getElementById('adminNewPassword').value = '';
            await loadAdminUsers();
            await loadDashboardData();
            return;
        }

        showToast((result && (result.error || result.message)) || 'Failed to create user', 'danger');
    } catch (error) {
        console.error('Admin create user failed:', error);
        showToast('Error creating user: ' + error.message, 'danger');
    }
}

function renderAdminUsersTable() {
    const body = document.getElementById('adminUsersTableBody');
    if (!body) {
        return;
    }

    if (!hasCapability('canManageUsers')) {
        body.innerHTML = '<tr><td colspan="6" class="text-muted">Admin access required</td></tr>';
        return;
    }

    if (adminUsersLoadError) {
        body.innerHTML = `<tr><td colspan="6" class="text-muted">Could not load users: ${escapeHtml(adminUsersLoadError)}. Refresh or redeploy and try again.</td></tr>`;
        return;
    }

    if (!adminUsers || adminUsers.length === 0) {
        body.innerHTML = '<tr><td colspan="6" class="text-muted">No users in the database. The recent code changes did not auto-delete test accounts; this usually means this DB currently has no seeded users.</td></tr>';
        return;
    }

    const currentUserId = parseInt(sessionStorage.getItem('userId'), 10);
    const rows = adminUsers.map((user) => {
        const isCurrentUser = currentUserId === Number(user.userId);
        const roleLabel = formatUserRoleLabel(user.role);
        const statusLabel = (user.status || 'ACTIVE').toUpperCase();
        const protectedHint = isCurrentUser ? '<span class="text-muted">Current User</span>' : '';
        return `
            <tr>
              <td>${user.userId}</td>
              <td>${escapeHtml(user.username || user.fullName || 'N/A')}</td>
              <td>${escapeHtml(user.email || 'N/A')}</td>
              <td>${escapeHtml(roleLabel)}</td>
              <td>${escapeHtml(statusLabel)}</td>
              <td>
                <button class="btn-action-sm" data-admin-edit="${user.userId}" title="Edit User">
                  <i class="fa-solid fa-pen"></i>
                </button>
                <button class="btn-action-sm" data-admin-reset="${user.userId}" title="Reset Temp Password">
                  <i class="fa-solid fa-key"></i>
                </button>
                <button class="btn-action-sm danger" data-admin-delete="${user.userId}" title="Delete User" ${isCurrentUser ? 'disabled' : ''}>
                  <i class="fa-solid fa-trash"></i>
                </button>
                ${protectedHint}
              </td>
            </tr>
        `;
    });

    body.innerHTML = rows.join('');
}

function handleAdminUsersTableActions(event) {
    const editBtn = event.target.closest('[data-admin-edit]');
    const resetBtn = event.target.closest('[data-admin-reset]');
    const deleteBtn = event.target.closest('[data-admin-delete]');

    if (editBtn) {
        openAdminEditUserModal(parseInt(editBtn.dataset.adminEdit, 10));
        return;
    }
    if (resetBtn) {
        openAdminResetPasswordModal(parseInt(resetBtn.dataset.adminReset, 10));
        return;
    }
    if (deleteBtn) {
        openAdminDeleteUserModal(parseInt(deleteBtn.dataset.adminDelete, 10));
    }
}

function openAccountSettingsModal() {
    const usernameInput = document.getElementById('accountUsername');
    const currentPasswordInput = document.getElementById('accountCurrentPassword');
    const newPasswordInput = document.getElementById('accountNewPassword');
    const confirmPasswordInput = document.getElementById('accountConfirmPassword');
    const modalEl = document.getElementById('accountSettingsModal');

    if (!usernameInput || !currentPasswordInput || !newPasswordInput || !confirmPasswordInput || !modalEl) {
        showToast('Account settings modal is unavailable on this page', 'danger');
        return;
    }

    usernameInput.value = (sessionStorage.getItem('userName') || '').trim();
    currentPasswordInput.value = '';
    newPasswordInput.value = '';
    confirmPasswordInput.value = '';

    const modal = new bootstrap.Modal(modalEl);
    modal.show();
}

async function submitAccountSettingsUpdate() {
    const usernameInput = document.getElementById('accountUsername');
    const currentPasswordInput = document.getElementById('accountCurrentPassword');
    const newPasswordInput = document.getElementById('accountNewPassword');
    const confirmPasswordInput = document.getElementById('accountConfirmPassword');

    if (!usernameInput || !currentPasswordInput || !newPasswordInput || !confirmPasswordInput) {
        showToast('Account settings form is unavailable', 'danger');
        return;
    }

    const username = (usernameInput.value || '').trim();
    const currentPassword = currentPasswordInput.value || '';
    const newPassword = (newPasswordInput.value || '').trim();
    const confirmNewPassword = (confirmPasswordInput.value || '').trim();
    const existingUsername = (sessionStorage.getItem('userName') || '').trim();

    if (!username) {
        showToast('Username is required', 'warning');
        return;
    }
    if (!currentPassword.trim()) {
        showToast('Current password is required', 'warning');
        return;
    }
    if (newPassword && newPassword !== confirmNewPassword) {
        showToast('New password and confirm password do not match', 'warning');
        return;
    }
    if (newPassword && newPassword.length < 6) {
        showToast('New password must be at least 6 characters', 'warning');
        return;
    }
    if (!newPassword && username === existingUsername) {
        showToast('No account changes detected', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.account.updateCredentials({
            username,
            currentPassword,
            newPassword
        });

        if (!result || !result.success) {
            showToast((result && (result.error || result.message)) || 'Could not update account settings', 'danger');
            return;
        }

        const updatedUserName = (result.userName || username).trim();
        sessionStorage.setItem('userName', updatedUserName);
        if (typeof loadUserInfo === 'function') {
            loadUserInfo();
        }

        closeModal('accountSettingsModal');
        showToast('Account settings updated successfully', 'success');
        await loadDashboardData();
        if (hasCapability('canManageUsers')) {
            await loadAdminUsers();
        }
    } catch (error) {
        console.error('Account settings update failed:', error);
        showToast('Error updating account settings: ' + error.message, 'danger');
    }
}

function openAdminEditUserModal(userId) {
    const user = adminUsers.find((entry) => Number(entry.userId) === Number(userId));
    if (!user) {
        showToast('User not found', 'warning');
        return;
    }

    document.getElementById('adminEditUserId').value = user.userId;
    document.getElementById('adminEditUsername').value = user.username || user.fullName || '';
    document.getElementById('adminEditEmail').value = user.email || '';
    document.getElementById('adminEditRole').value = user.role || 'STOREKEEPER';
    document.getElementById('adminEditStatus').value = (user.status || 'ACTIVE').toUpperCase();

    const modal = new bootstrap.Modal(document.getElementById('adminEditUserModal'));
    modal.show();
}

async function saveAdminUserUpdate() {
    const userId = parseInt(document.getElementById('adminEditUserId').value, 10);
    const username = document.getElementById('adminEditUsername').value || '';
    const email = document.getElementById('adminEditEmail').value || '';
    const role = document.getElementById('adminEditRole').value || '';
    const status = document.getElementById('adminEditStatus').value || 'ACTIVE';

    if (!userId || !username.trim() || !email.trim() || !role.trim()) {
        showToast('Fill all required update fields', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.users.update({
            userId,
            username: username.trim(),
            email: email.trim(),
            role: role.trim(),
            status: status.trim().toUpperCase()
        });

        if (result && result.success) {
            showToast('User updated successfully', 'success');
            adminUsersLoadError = '';
            closeModal('adminEditUserModal');
            await loadAdminUsers();
            await loadDashboardData();
            return;
        }

        showToast((result && (result.error || result.message)) || 'Failed to update user', 'danger');
    } catch (error) {
        console.error('Admin update user failed:', error);
        showToast('Error updating user: ' + error.message, 'danger');
    }
}

function openAdminResetPasswordModal(userId) {
    const user = adminUsers.find((entry) => Number(entry.userId) === Number(userId));
    if (!user) {
        showToast('User not found', 'warning');
        return;
    }
    document.getElementById('adminResetUserId').value = user.userId;
    document.getElementById('adminResetPasswordValue').value = '';

    const modal = new bootstrap.Modal(document.getElementById('adminResetPasswordModal'));
    modal.show();
}

async function saveAdminPasswordReset() {
    const userId = parseInt(document.getElementById('adminResetUserId').value, 10);
    const tempPassword = (document.getElementById('adminResetPasswordValue') || {}).value || '';

    if (!userId || !tempPassword.trim()) {
        showToast('Provide a temporary password', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.users.resetPassword(userId, tempPassword);
        if (result && result.success) {
            showToast('Temporary password reset', 'success');
            closeModal('adminResetPasswordModal');
            return;
        }

        showToast((result && (result.error || result.message)) || 'Failed to reset password', 'danger');
    } catch (error) {
        console.error('Admin reset password failed:', error);
        showToast('Error resetting password: ' + error.message, 'danger');
    }
}

function openAdminDeleteUserModal(userId) {
    if (!userId || Number.isNaN(userId)) {
        showToast('Invalid user selected', 'warning');
        return;
    }

    const currentUserId = parseInt(sessionStorage.getItem('userId'), 10);
    if (currentUserId === Number(userId)) {
        showToast('You cannot delete your own account', 'warning');
        return;
    }

    const user = adminUsers.find((entry) => Number(entry.userId) === Number(userId));
    if (!user) {
        showToast('User not found', 'warning');
        return;
    }

    const summaryEl = document.getElementById('adminDeleteUserSummary');
    const hiddenIdEl = document.getElementById('adminDeleteUserId');
    const modalEl = document.getElementById('adminDeleteUserModal');

    if (!summaryEl || !hiddenIdEl || !modalEl) {
        showToast('Delete confirmation modal is unavailable on this page', 'danger');
        return;
    }

    pendingAdminDeleteUserId = Number(userId);
    hiddenIdEl.value = String(userId);
    summaryEl.value = `${user.username || user.fullName || `User #${userId}`} (${formatUserRoleLabel(user.role)})`;

    const modal = new bootstrap.Modal(modalEl);
    modal.show();
}

function confirmAdminUserDelete() {
    const hiddenIdEl = document.getElementById('adminDeleteUserId');
    const selectedId = pendingAdminDeleteUserId || parseInt((hiddenIdEl || {}).value, 10);
    deleteAdminUser(selectedId);
}

async function deleteAdminUser(userId) {
    if (!userId || Number.isNaN(userId)) {
        showToast('Invalid user selected', 'warning');
        return;
    }

    const currentUserId = parseInt(sessionStorage.getItem('userId'), 10);
    if (currentUserId === Number(userId)) {
        showToast('You cannot delete your own account', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.users.remove(userId);
        if (result && result.success) {
            pendingAdminDeleteUserId = 0;
            closeModal('adminDeleteUserModal');
            showToast('User deleted successfully', 'success');
            adminUsersLoadError = '';
            await loadAdminUsers();
            await loadDashboardData();
            return;
        }

        showToast((result && (result.error || result.message)) || 'Failed to delete user', 'danger');
    } catch (error) {
        console.error('Admin delete user failed:', error);
        showToast('Error deleting user: ' + error.message, 'danger');
    }
}

function formatUserRoleLabel(role) {
    if (!role) {
        return 'Unknown';
    }
    if (role === 'DEPARTMENT_HEAD') {
        return 'Department Head';
    }
    if (role === 'STOREKEEPER' || role === 'STORE_KEEPER') {
        return 'Store Keeper';
    }
    if (role === 'ADMIN') {
        return 'Admin';
    }
    return role;
}

function syncDashboardRangeControls() {
    const trendRange = document.getElementById('dashboardTrendRange');
    if (trendRange && trendRange.value !== selectedTrendRange) {
        trendRange.value = selectedTrendRange;
    }

    const logsRange = document.getElementById('logsRangeFilter');
    if (logsRange && logsRange.value !== logsFilterState.range) {
        logsRange.value = logsFilterState.range;
    }
}

async function applySystemLogFilters() {
    logsFilterState.page = 1;
    await loadSystemLogs(false);
}

async function loadSystemLogs(resetPage = false) {
    if (!hasCapability('canViewSystemLogs')) {
        return;
    }

    const rangeEl = document.getElementById('logsRangeFilter');
    const searchEl = document.getElementById('logsSearchInput');
    const includeArchivedEl = document.getElementById('logsIncludeArchived');
    const archiveFromEl = document.getElementById('logsArchiveFrom');
    const archiveToEl = document.getElementById('logsArchiveTo');

    logsFilterState.range = (rangeEl && rangeEl.value) ? rangeEl.value : logsFilterState.range;
    logsFilterState.search = (searchEl && searchEl.value) ? searchEl.value.trim() : '';
    logsFilterState.includeArchived = Boolean(includeArchivedEl && includeArchivedEl.checked);
    logsFilterState.archiveFrom = (archiveFromEl && archiveFromEl.value) ? archiveFromEl.value : '';
    logsFilterState.archiveTo = (archiveToEl && archiveToEl.value) ? archiveToEl.value : '';
    if (resetPage) {
        logsFilterState.page = 1;
    }

    try {
        const payload = await FoodFlowAPI.dashboard.getSystemLogs({
            range: logsFilterState.range,
            search: logsFilterState.search,
            includeArchived: logsFilterState.includeArchived,
            page: logsFilterState.page,
            pageSize: logsFilterState.pageSize,
            from: logsFilterState.archiveFrom,
            to: logsFilterState.archiveTo
        });
        systemLogEntries = Array.isArray(payload.items) ? payload.items : [];
        logsFilterState.total = Number(payload.total || 0);
        renderSystemLogTable(systemLogEntries);

        const summary = document.getElementById('logsSummaryText');
        if (summary) {
            const start = logsFilterState.total === 0 ? 0 : ((logsFilterState.page - 1) * logsFilterState.pageSize) + 1;
            const end = Math.min(logsFilterState.total, logsFilterState.page * logsFilterState.pageSize);
            const windowLabel = (logsFilterState.archiveFrom || logsFilterState.archiveTo)
                ? `${logsFilterState.archiveFrom || '...'} to ${logsFilterState.archiveTo || '...'}`
                : getRangeLabel(logsFilterState.range);
            summary.textContent = `Showing ${start}-${end} of ${logsFilterState.total} logs (${windowLabel})`;
        }

        const pageCount = Math.max(1, Math.ceil(logsFilterState.total / logsFilterState.pageSize));
        const prevBtn = document.getElementById('logsPrevPageBtn');
        const nextBtn = document.getElementById('logsNextPageBtn');
        if (prevBtn) {
            prevBtn.disabled = logsFilterState.page <= 1;
        }
        if (nextBtn) {
            nextBtn.disabled = logsFilterState.page >= pageCount;
        }
    } catch (error) {
        console.error('Failed loading system logs:', error);
        showToast('Error loading system logs: ' + error.message, 'danger');
    }
}

function openArchiveLogsModal() {
    if (!hasCapability('canViewSystemLogs')) {
        showToast('Access denied: admin only action', 'danger');
        return;
    }

    const fromInput = document.getElementById('logsArchiveFrom');
    const toInput = document.getElementById('logsArchiveTo');
    const from = (fromInput && fromInput.value) ? fromInput.value : (logsFilterState.archiveFrom || '');
    const to = (toInput && toInput.value) ? toInput.value : (logsFilterState.archiveTo || '');
    const archiveFromValue = document.getElementById('archiveFromValue');
    const archiveToValue = document.getElementById('archiveToValue');
    const archiveWindowLabel = document.getElementById('archiveWindowLabel');
    if (!archiveFromValue || !archiveToValue || !archiveWindowLabel) {
        showToast('Archive modal is unavailable on this page', 'danger');
        return;
    }

    archiveFromValue.value = from;
    archiveToValue.value = to;
    const label = (from || to)
        ? `${from || '...'} to ${to || '...'}`
        : `${getRangeLabel(logsFilterState.range)} (current filter)`;
    archiveWindowLabel.value = label;

    const modal = new bootstrap.Modal(document.getElementById('archiveLogsModal'));
    modal.show();
}

async function submitArchiveLogs() {
    const from = ((document.getElementById('archiveFromValue') || {}).value || '').trim();
    const to = ((document.getElementById('archiveToValue') || {}).value || '').trim();
    if ((from && !to) || (!from && to)) {
        showToast('Provide both archive from and to dates', 'warning');
        return;
    }
    if (!from && !to && String(logsFilterState.range || '').toLowerCase() === 'all') {
        showToast('Select archive dates or choose a bounded range before archiving', 'warning');
        return;
    }

    try {
        const result = await FoodFlowAPI.dashboard.archiveLogs({
            range: logsFilterState.range,
            from: from,
            to: to
        });
        if (result && result.success) {
            closeModal('archiveLogsModal');
            showToast(result.message || 'Logs archived', 'success');
            await loadDashboardData();
            return;
        }
        showToast((result && result.message) || 'Failed to archive logs', 'danger');
    } catch (error) {
        showToast('Error archiving logs: ' + error.message, 'danger');
    }
}

function renderSystemLogTable(activities) {
    const tableBody = document.getElementById('systemLogsTableBody');
    if (!tableBody) return;
    const rows = (activities || []).map((entry) => {
        const dateText = formatActivityDate(entry.date || entry.timestamp);
        const archivedBadge = entry.archived
            ? ' <span class="badge badge-blue">Archived</span>'
            : '';
        return `
            <tr>
              <td>${escapeHtml(entry.description || 'Activity recorded')}${archivedBadge}</td>
              <td>${escapeHtml(resolveActivityActor(entry))}</td>
              <td>${escapeHtml(dateText)}</td>
            </tr>
        `;
    });
    tableBody.innerHTML = rows.length > 0
        ? rows.join('')
        : '<tr><td colspan="3" class="text-muted">No activity logs</td></tr>';
}

function exportSystemLogsPdf() {
    if (!hasCapability('canViewSystemLogs')) {
        showToast('Access denied: admin only action', 'danger');
        return;
    }

    if (!window.jspdf || !window.jspdf.jsPDF) {
        showToast('PDF export library did not load. Refresh and try again.', 'danger');
        return;
    }

    const entries = Array.isArray(systemLogEntries) ? systemLogEntries : [];
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ unit: 'pt', format: 'a4' });
    const generatedBy = sessionStorage.getItem('userName') || 'Admin';
    const generatedAt = new Date();
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();
    const left = 40;
    const right = pageWidth - 40;
    const bottom = pageHeight - 48;
    const lineHeight = 16;
    let y = drawFoodFlowReportHeader(doc, 'System Activity Log Report', generatedAt, generatedBy) + 14;

    if (entries.length === 0) {
        doc.setFontSize(11);
        doc.text('No log entries were available at export time.', left, y);
    } else {
        entries.forEach((entry, index) => {
            const happened = entry.description || 'Activity recorded';
            const actor = resolveActivityActor(entry);
            const when = formatActivityDate(entry.date);
            const block = [
                `${index + 1}. What happened: ${happened}`,
                `By who: ${actor}`,
                `When: ${when}`
            ];

            const wrappedLines = [];
            block.forEach((line) => {
                const parts = doc.splitTextToSize(line, right - left);
                parts.forEach((part) => wrappedLines.push(part));
            });

            const blockHeight = wrappedLines.length * lineHeight + 8;
            if (y + blockHeight > bottom) {
                doc.addPage();
                y = drawFoodFlowReportHeader(doc, 'System Activity Log Report (Continued)', generatedAt, generatedBy) + 14;
            }

            doc.setFont('helvetica', 'normal');
            doc.setFontSize(10);
            wrappedLines.forEach((line) => {
                doc.text(line, left, y);
                y += lineHeight;
            });
            y += 8;
        });
    }

    const dateStamp = generatedAt.toISOString().slice(0, 10);
    doc.save(`foodflow-system-logs-${dateStamp}.pdf`);
    showToast('System logs exported to PDF', 'success');
}

function resolveActivityActor(entry) {
    if (entry && typeof entry.userName === 'string' && entry.userName.trim().length > 0) {
        return entry.userName.trim();
    }
    if (entry && typeof entry.actor === 'string' && entry.actor.trim().length > 0) {
        return entry.actor.trim();
    }

    const description = (entry && entry.description) ? String(entry.description) : '';
    if (description.startsWith('[Role Task]')) {
        return 'System';
    }

    const requesterMatch = description.match(/from\s+(.+?)\s+for/i);
    if (requesterMatch && requesterMatch[1]) {
        return requesterMatch[1].trim();
    }

    return sessionStorage.getItem('userName') || 'System';
}

function getRangeLabel(rangeValue) {
    const normalized = String(rangeValue || '').toLowerCase();
    if (normalized === '7d' || normalized === 'week') return 'Past Week';
    if (normalized === '30d' || normalized === 'month') return 'Past Month';
    if (normalized === '365d' || normalized === 'year') return 'Past Year';
    if (normalized === 'all') return 'All Time';
    return 'Selected Range';
}

function formatActivityDate(rawValue) {
    const parsed = rawValue ? new Date(rawValue) : null;
    if (parsed && !Number.isNaN(parsed.getTime())) {
        return parsed.toLocaleString();
    }
    return 'Recent';
}

function formatDateTimeValue(rawValue) {
    const parsed = rawValue ? new Date(rawValue) : null;
    if (parsed && !Number.isNaN(parsed.getTime())) {
        return parsed.toLocaleString();
    }
    return 'N/A';
}

function toSortableTime(rawValue) {
    const parsed = rawValue ? new Date(rawValue) : null;
    if (parsed && !Number.isNaN(parsed.getTime())) {
        return parsed.getTime();
    }
    return 0;
}

function getCssVariable(variableName, fallback) {
    const styles = getComputedStyle(document.body);
    const value = styles.getPropertyValue(variableName);
    return value && value.trim() ? value.trim() : fallback;
}

function getRecentDayLabels(numberOfDays) {
    const labels = [];
    for (let i = numberOfDays - 1; i >= 0; i -= 1) {
        const day = new Date();
        day.setDate(day.getDate() - i);
        labels.push(`${day.getMonth() + 1}/${day.getDate()}`);
    }
    return labels;
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
