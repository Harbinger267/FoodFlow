/* User/session display and role policy helpers */

const ROLE_POLICIES = {
    ADMIN: {
        displayName: "Admin",
        defaultPage: "dashboard",
        allowedPages: ["dashboard", "adminusers", "adminops", "logs", "reports"],
        capabilities: {
            canManageUsers: true,
            canSystemMaintenance: true,
            canDatabaseOps: true,
            canViewSystemLogs: true,
            canViewReports: true,
            canApproveRequests: false,
            canCreateRequests: false,
            canUpdateInventory: false,
            canRecordDamages: false,
            canRecordIssuedItems: false,
            canSearchItems: false,
            canViewInventory: false
        },
        statLabels: {
            total: "Total Items",
            inStock: "In Stock",
            damaged: "Damaged Items",
            fourth: "System Logs"
        },
        activityLog: [
            "Manage users (add, update, delete)",
            "Perform system maintenance",
            "Run backup/restore operations",
            "View system logs",
            "View reports"
        ]
    },
    DEPARTMENT_HEAD: {
        displayName: "Department Head",
        defaultPage: "dashboard",
        allowedPages: ["dashboard", "requests", "reports"],
        capabilities: {
            canManageUsers: false,
            canSystemMaintenance: false,
            canDatabaseOps: false,
            canViewSystemLogs: false,
            canViewReports: true,
            canApproveRequests: true,
            canCreateRequests: false,
            canUpdateInventory: false,
            canRecordDamages: false,
            canRecordIssuedItems: false,
            canSearchItems: false,
            canViewInventory: false
        },
        statLabels: {
            total: "Total Items",
            inStock: "In Stock",
            damaged: "Damaged Items",
            fourth: "Pending Approvals"
        },
        activityLog: [
            "View pending store requests",
            "Approve or reject requests",
            "Generate reports",
            "Review dashboard charts"
        ]
    },
    STOREKEEPER: {
        displayName: "Store Keeper",
        defaultPage: "dashboard",
        allowedPages: ["dashboard", "available", "damaged", "staffrecords", "requests"],
        capabilities: {
            canManageUsers: false,
            canSystemMaintenance: false,
            canDatabaseOps: false,
            canViewSystemLogs: false,
            canViewReports: false,
            canApproveRequests: false,
            canCreateRequests: true,
            canUpdateInventory: true,
            canRecordDamages: true,
            canRecordIssuedItems: true,
            canSearchItems: true,
            canViewInventory: true
        },
        statLabels: {
            total: "Total Items",
            inStock: "In Stock",
            damaged: "Damaged Items",
            fourth: "Issued Records"
        },
        activityLog: [
            "Update supplied inventory",
            "Record issued items",
            "Submit store requests",
            "Record damaged items",
            "View and search item list",
            "Record store status"
        ]
    }
};

function normalizeUserRole(rawRole) {
    const role = (rawRole || "").toUpperCase().trim();
    if (role === "STORE_KEEPER") return "STOREKEEPER";
    if (role === "STOREKEEPER") return "STOREKEEPER";
    if (role === "DEPARTMENT_HEAD") return "DEPARTMENT_HEAD";
    if (role === "ADMIN") return "ADMIN";
    return "STOREKEEPER";
}

function getCurrentRole() {
    return normalizeUserRole(sessionStorage.getItem("userRole"));
}

function getRolePolicy(roleName) {
    const role = normalizeUserRole(roleName);
    return ROLE_POLICIES[role] || ROLE_POLICIES.STOREKEEPER;
}

function hasCapability(capabilityName) {
    const policy = getRolePolicy(getCurrentRole());
    return Boolean(policy.capabilities[capabilityName]);
}

function getRoleActivityLog() {
    const policy = getRolePolicy(getCurrentRole());
    return policy.activityLog.slice();
}

function loadUserInfo() {
    try {
        const userName = sessionStorage.getItem("userName") || "User";
        const role = getCurrentRole();
        const policy = getRolePolicy(role);

        const sidebarName = document.getElementById("sidebarUserName");
        const sidebarRole = document.getElementById("sidebarUserRole");
        const topbarName = document.getElementById("topbarUserName");

        if (sidebarName) sidebarName.textContent = userName;
        if (sidebarRole) sidebarRole.textContent = policy.displayName;
        if (topbarName) topbarName.textContent = userName;

        document.body.dataset.role = role;

        const context = {
            userName,
            role,
            displayRole: policy.displayName,
            policy
        };

        window.currentUserContext = context;
        return context;
    } catch (error) {
        console.error("Error loading user info:", error);
        return {
            userName: "User",
            role: "STOREKEEPER",
            displayRole: "Store Keeper",
            policy: getRolePolicy("STOREKEEPER")
        };
    }
}

window.getCurrentRole = getCurrentRole;
window.getRolePolicy = getRolePolicy;
window.hasCapability = hasCapability;
window.getRoleActivityLog = getRoleActivityLog;
window.loadUserInfo = loadUserInfo;
