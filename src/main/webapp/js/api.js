/**
 * FoodFlow API Service Layer
 * Handles all HTTP requests to backend servlets
 */

// Get context root (e.g., "/mavenproject1")
const CONTEXT_ROOT = window.location.pathname.split('/')[1] 
    ? '/' + window.location.pathname.split('/')[1] 
    : '';
console.log('Context Root:', CONTEXT_ROOT);

const ENDPOINTS = {
    ITEMS: `${CONTEXT_ROOT}/api/items`,
    DAMAGE: `${CONTEXT_ROOT}/api/damage`,
    USAGE: `${CONTEXT_ROOT}/api/usage`,
    DASHBOARD: `${CONTEXT_ROOT}/api/dashboard`,
    REQUESTS: `${CONTEXT_ROOT}/api/requests`,
    ACCOUNT: `${CONTEXT_ROOT}/api/account`,
    USERS: `${CONTEXT_ROOT}/admin/users`
};

/**
 * Generic fetch wrapper with error handling
 */
async function fetchAPI(endpoint, options = {}) {
    const defaultOptions = {
        headers: {
            'Accept': 'application/json',
        },
    };

    const config = { ...defaultOptions, ...options };

    try {
        console.log('Fetching:', endpoint, config);
        const response = await fetch(endpoint, config);
        
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('text/html')) {
            const htmlText = await response.text();
            console.error('Received HTML instead of JSON:', htmlText.substring(0, 200));
            throw new Error('Server returned HTML error page. Check servlet mapping and server logs.');
        }
        
        if (!response.ok) {
            let errorMessage = `HTTP ${response.status}`;
            try {
                const errorData = await response.json();
                errorMessage = errorData.error || errorMessage;
            } catch (e) {
                console.error('Non-JSON error response:', response.status);
            }
            throw new Error(errorMessage);
        }
        
        return await response.json();
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

/**
 * Items API
 */
const ItemsAPI = {
    getAll() {
        return fetchAPI(`${ENDPOINTS.ITEMS}?action=getAll`);
    },

    getById(itemId) {
        return fetchAPI(`${ENDPOINTS.ITEMS}?action=getById&itemId=${itemId}`);
    },

    search(query) {
        return fetchAPI(`${ENDPOINTS.ITEMS}?action=search&q=${encodeURIComponent(query)}`);
    },

    async add(itemData) {
        const params = new URLSearchParams();
        params.append('action', 'add');
        params.append('itemName', itemData.itemName);
        params.append('category', itemData.category);
        params.append('itemType', itemData.itemType || 'FOOD');
        params.append('unit', itemData.unit || 'Pieces');
        params.append('description', itemData.description || '');
        params.append('quantity', itemData.quantity);
        params.append('minStockLevel', itemData.minStockLevel || 10);

        try {
            const response = await fetch(ENDPOINTS.ITEMS, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            console.log('Add item response status:', response.status);
            return await response.json();
        } catch (error) {
            console.error('Error adding item:', error);
            throw error;
        }
    },

    async update(itemId, stock, status) {
        const params = new URLSearchParams();
        params.append('action', 'update');
        params.append('itemId', itemId);
        params.append('stock', stock);
        params.append('status', status);

        try {
            const response = await fetch(ENDPOINTS.ITEMS, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            return await response.json();
        } catch (error) {
            console.error('Error updating item:', error);
            throw error;
        }
    },

    async replenish(itemId, quantity) {
        const params = new URLSearchParams();
        params.append('action', 'replenish');
        params.append('itemId', itemId);
        params.append('quantity', quantity);

        try {
            const response = await fetch(ENDPOINTS.ITEMS, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            return await response.json();
        } catch (error) {
            console.error('Error replenishing item:', error);
            throw error;
        }
    }
};

/**
 * Damage API
 */
const DamageAPI = {
    getAll() {
        return fetchAPI(`${ENDPOINTS.DAMAGE}?action=getAll`);
    },

    getByItemId(itemId) {
        return fetchAPI(`${ENDPOINTS.DAMAGE}?action=getByItemId&itemId=${itemId}`);
    },

    getTypes() {
        return fetchAPI(`${ENDPOINTS.DAMAGE}?action=getTypes`);
    },

    getDispositions() {
        return fetchAPI(`${ENDPOINTS.DAMAGE}?action=getDispositions`);
    },

    async add(damageData) {
        const params = new URLSearchParams();
        params.append('action', 'add');
        params.append('itemId', damageData.itemId);
        params.append('quantity', damageData.quantity);
        params.append('damageType', damageData.damageType || 'Other');
        params.append('reportedBy', damageData.reportedBy || '');
        params.append('disposition', damageData.disposition || 'DISPOSED');

        try {
            const response = await fetch(ENDPOINTS.DAMAGE, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            return await response.json();
        } catch (error) {
            console.error('Error recording damage:', error);
            throw error;
        }
    },

    async updateStatus(damageId, status) {
        const params = new URLSearchParams();
        params.append('action', 'updateStatus');
        params.append('damageId', damageId);
        params.append('status', status);

        try {
            const response = await fetch(ENDPOINTS.DAMAGE, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            return await response.json();
        } catch (error) {
            console.error('Error updating damage status:', error);
            throw error;
        }
    }
};

/**
 * Usage API (Staff Checkouts)
 */
const UsageAPI = {
    getAll() {
        return fetchAPI(`${ENDPOINTS.USAGE}?action=getAll`);
    },

    getByItemId(itemId) {
        return fetchAPI(`${ENDPOINTS.USAGE}?action=getByItemId&itemId=${itemId}`);
    },

    getItems() {
        return fetchAPI(`${ENDPOINTS.USAGE}?action=getItems`);
    },

    async add(usageData) {
        const params = new URLSearchParams();
        params.append('action', 'add');
        params.append('itemId', usageData.itemId);
        params.append('quantity', usageData.quantity);
        params.append('staffName', usageData.staffName || '');
        params.append('department', usageData.department || 'Internal Department');

        try {
            const response = await fetch(ENDPOINTS.USAGE, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            return await response.json();
        } catch (error) {
            console.error('Error recording usage:', error);
            throw error;
        }
    },

    async updateStatus(usageId, status) {
        const params = new URLSearchParams();
        params.append('action', 'updateStatus');
        params.append('usageId', usageId);
        params.append('status', status);

        try {
            const response = await fetch(ENDPOINTS.USAGE, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            return await response.json();
        } catch (error) {
            console.error('Error updating usage status:', error);
            throw error;
        }
    },

    async recordReturn(usageId, quantity) {
        const params = new URLSearchParams();
        params.append('action', 'recordReturn');
        params.append('usageId', usageId);
        params.append('quantity', quantity);

        try {
            const response = await fetch(ENDPOINTS.USAGE, {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: params
            });
            return await response.json();
        } catch (error) {
            console.error('Error recording return:', error);
            throw error;
        }
    }
};

/**
 * Dashboard API
 */
const DashboardAPI = {
    getStats(range = '30d') {
        return fetchAPI(`${ENDPOINTS.DASHBOARD}?action=stats&range=${encodeURIComponent(range)}`);
    },

    getLowStock() {
        return fetchAPI(`${ENDPOINTS.DASHBOARD}?action=lowStock`);
    },

    getSystemAlerts(range = '30d') {
        return fetchAPI(`${ENDPOINTS.DASHBOARD}?action=systemAlerts&range=${encodeURIComponent(range)}`);
    },

    getRecentActivity(range = '30d') {
        return fetchAPI(`${ENDPOINTS.DASHBOARD}?action=recentActivity&range=${encodeURIComponent(range)}`);
    },

    getChartData(range = '30d') {
        return fetchAPI(`${ENDPOINTS.DASHBOARD}?action=charts&range=${encodeURIComponent(range)}`);
    },

    getSystemLogs(filters = {}) {
        const params = new URLSearchParams();
        params.append('action', 'systemLogs');
        params.append('range', filters.range || '30d');
        params.append('page', filters.page || 1);
        params.append('pageSize', filters.pageSize || 50);
        params.append('includeArchived', filters.includeArchived ? 'true' : 'false');
        if (filters.search) {
            params.append('search', filters.search);
        }
        if (filters.from) {
            params.append('from', filters.from);
        }
        if (filters.to) {
            params.append('to', filters.to);
        }
        return fetchAPI(`${ENDPOINTS.DASHBOARD}?${params.toString()}`);
    },

    archiveLogs(filters = {}) {
        const params = new URLSearchParams();
        params.append('action', 'archiveLogs');
        params.append('range', filters.range || '30d');
        if (filters.from) {
            params.append('from', filters.from);
        }
        if (filters.to) {
            params.append('to', filters.to);
        }

        return fetchAPI(ENDPOINTS.DASHBOARD, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params
        });
    },

    getAll() {
        return fetchAPI(ENDPOINTS.DASHBOARD);
    }
};

/**
 * Requests API
 */
const RequestsAPI = {
    getMine() {
        return fetchAPI(`${ENDPOINTS.REQUESTS}?action=mine`);
    },

    getPending() {
        return fetchAPI(`${ENDPOINTS.REQUESTS}?action=pending`);
    },

    getAll() {
        return fetchAPI(ENDPOINTS.REQUESTS);
    },

    async create(requestData) {
        const params = new URLSearchParams();
        params.append('action', 'create');
        params.append('itemId', requestData.itemId);
        params.append('quantity', requestData.quantity);
        params.append('notes', requestData.notes || '');

        return fetchAPI(ENDPOINTS.REQUESTS, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params
        });
    },

    async approve(requestId) {
        const params = new URLSearchParams();
        params.append('action', 'approve');
        params.append('requestId', requestId);

        return fetchAPI(ENDPOINTS.REQUESTS, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params
        });
    },

    async reject(requestId, rejectionNote) {
        const params = new URLSearchParams();
        params.append('action', 'reject');
        params.append('requestId', requestId);
        if (typeof rejectionNote === 'string') {
            params.append('rejectionNote', rejectionNote);
        }

        return fetchAPI(ENDPOINTS.REQUESTS, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params
        });
    }
};

/**
 * Admin Users API
 */
const UsersAPI = {
    list() {
        return fetchAPI(`${ENDPOINTS.USERS}?action=list`);
    },

    async create(userData) {
        const params = new URLSearchParams();
        params.append('action', 'add');
        params.append('username', userData.username);
        params.append('email', userData.email);
        params.append('role', userData.role);
        params.append('tempPassword', userData.tempPassword);

        const response = await fetch(ENDPOINTS.USERS, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params
        });
        return await response.json();
    },

    async update(userData) {
        const params = new URLSearchParams();
        params.append('action', 'update');
        params.append('userId', userData.userId);
        params.append('username', userData.username);
        params.append('email', userData.email);
        params.append('role', userData.role);
        params.append('status', userData.status);

        const response = await fetch(ENDPOINTS.USERS, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params
        });
        return await response.json();
    },

    async resetPassword(userId, tempPassword) {
        const params = new URLSearchParams();
        params.append('action', 'resetPassword');
        params.append('userId', userId);
        params.append('tempPassword', tempPassword);

        const response = await fetch(ENDPOINTS.USERS, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params
        });
        return await response.json();
    },

    async remove(userId) {
        const params = new URLSearchParams();
        params.append('action', 'delete');
        params.append('userId', userId);

        const response = await fetch(ENDPOINTS.USERS, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: params
        });
        return await response.json();
    }
};

/**
 * Authenticated account API
 */
const AccountAPI = {
    getProfile() {
        return fetchAPI(ENDPOINTS.ACCOUNT);
    },

    async updateCredentials(data) {
        const params = new URLSearchParams();
        params.append('action', 'updateCredentials');
        params.append('username', data.username || '');
        params.append('currentPassword', data.currentPassword || '');
        params.append('newPassword', data.newPassword || '');

        return fetchAPI(ENDPOINTS.ACCOUNT, {
            method: 'POST',
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: params
        });
    }
};

// Export all APIs
window.FoodFlowAPI = {
    items: ItemsAPI,
    damage: DamageAPI,
    usage: UsageAPI,
    dashboard: DashboardAPI,
    requests: RequestsAPI,
    users: UsersAPI,
    account: AccountAPI,
    fetchAPI
};
