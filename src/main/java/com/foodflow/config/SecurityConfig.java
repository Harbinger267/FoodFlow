package com.foodflow.config;

import com.foodflow.model.User;

public class SecurityConfig {

    public static boolean isAdmin(User user) {
        return user != null && user.getRole() == User.Role.ADMIN;
    }

    public static boolean isDepartmentHead(User user) {
        return user != null && user.getRole() == User.Role.DEPARTMENT_HEAD;
    }

    public static boolean isStoreKeeper(User user) {
        return user != null && user.getRole() == User.Role.STOREKEEPER;
    }

    public static boolean canViewReports(User user) {
        return isAdmin(user) || isDepartmentHead(user);
    }

    public static boolean canManageInventory(User user) {
        return isStoreKeeper(user);
    }

    public static boolean canManageUsers(User user) {
        return isAdmin(user);
    }

    public static boolean canApproveRequests(User user) {
        return isDepartmentHead(user);
    }

    public static boolean canCreateRequests(User user) {
        return isStoreKeeper(user);
    }

    public static boolean canRecordOperationalData(User user) {
        return isStoreKeeper(user);
    }
}
