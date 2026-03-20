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
        usage.setIssuedTo(issuedTo);

        String type = item.getItemType().toUpperCase();
        if ("FOOD".equals(type)) {
            usage.setStatus(Usage.Status.ISSUED);
            return usageDAO.addIssueUsage(usage);
        }

        usage.setStatus(Usage.Status.BORROWED);
        return usageDAO.addBorrowUsage(usage);
    }
}
