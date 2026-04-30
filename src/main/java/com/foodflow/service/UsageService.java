package com.foodflow.service;

import com.foodflow.dao.ItemDAO;
import com.foodflow.dao.UsageDAO;
import com.foodflow.model.Item;
import com.foodflow.model.Usage;

public class UsageService {
    private final UsageDAO usageDAO = new UsageDAO();
    private final ItemDAO itemDAO = new ItemDAO();

    public boolean recordUsage(int itemId, double quantity, int userId) {
        return recordUsage(itemId, quantity, userId, "Internal Department");
    }

    public boolean recordUsage(int itemId, double quantity, int userId, String issuedTo) {
        return recordUsage(itemId, quantity, userId, issuedTo, null);
    }

    public boolean recordUsage(int itemId, double quantity, int userId, String staffName, String department) {
        if (itemId <= 0 || quantity <= 0 || userId <= 0) {
            return false;
        }

        Item item = itemDAO.getItemById(itemId);
        if (item == null || item.getItemType() == null || item.getItemType().isBlank()) {
            return false;
        }

        Usage usage = new Usage();
        usage.setItemId(itemId);
        usage.setQuantity(quantity);
        usage.setRecordedBy(userId);
        usage.setIssuedTo(buildRecipient(staffName, department));

        if (isConsumableItem(item)) {
            usage.setStatus(Usage.Status.ISSUED);
            return usageDAO.addIssueUsage(usage);
        }

        usage.setStatus(Usage.Status.BORROWED);
        return usageDAO.addBorrowUsage(usage);
    }

    private String buildRecipient(String staffName, String department) {
        String normalizedName = staffName == null ? "" : staffName.trim();
        String normalizedDepartment = department == null ? "" : department.trim();

        if (!normalizedName.isEmpty() && !normalizedDepartment.isEmpty()) {
            return normalizedName + " (" + normalizedDepartment + ")";
        }
        if (!normalizedName.isEmpty()) {
            return normalizedName;
        }
        if (!normalizedDepartment.isEmpty()) {
            return normalizedDepartment;
        }
        return "Internal Department";
    }

    private boolean isConsumableItem(Item item) {
        if (item == null) {
            return true;
        }

        String type = item.getItemType() == null ? "" : item.getItemType().trim().toUpperCase();
        if ("FOOD".equals(type)) {
            return true;
        }

        String category = item.getCategory() == null ? "" : item.getCategory().trim().toUpperCase();
        if ("PERISHABLE".equals(category)) {
            return true;
        }

        String name = item.getName() == null ? "" : item.getName().trim().toLowerCase();
        return name.contains("detergent")
                || name.contains("soap")
                || name.contains("bleach")
                || name.contains("disinfect")
                || name.contains("banana")
                || name.contains("rice")
                || name.contains("flour")
                || name.contains("oil")
                || name.contains("sugar")
                || name.contains("salt");
    }
}
