package com.foodflow.model;

import java.time.LocalDate;

public class Usage {

    public enum Status {
        ISSUED,
        BORROWED,
        PARTIALLY_RETURNED,
        RETURNED,
        LOST
    }

    private int usageId;
    private int itemId;
    private String itemName;
    private double quantity;
    private String issuedTo;
    private String itemUserName;
    private Integer recordedBy;
    private double quantityReturned;
    private LocalDate date = LocalDate.now();
    private Status status = Status.ISSUED;

    public int getUsageId() { return usageId; }
    public void setUsageId(int usageId) { this.usageId = usageId; }

    public int getItemId() { return itemId; }
    public void setItemId(int itemId) { this.itemId = itemId; }

    public String getItemName() { return itemName; }
    public void setItemName(String itemName) { this.itemName = itemName; }

    public double getQuantity() { return quantity; }
    public void setQuantity(double quantity) { this.quantity = quantity; }

    public String getIssuedTo() { return issuedTo; }
    public void setIssuedTo(String issuedTo) { this.issuedTo = issuedTo; }

    public String getItemUserName() { return itemUserName; }
    public void setItemUserName(String itemUserName) { this.itemUserName = itemUserName; }

    public Integer getRecordedBy() { return recordedBy; }
    public void setRecordedBy(Integer recordedBy) { this.recordedBy = recordedBy; }

    public double getQuantityReturned() { return quantityReturned; }
    public void setQuantityReturned(double quantityReturned) { this.quantityReturned = quantityReturned; }

    public LocalDate getDate() { return date; }
    public void setDate(LocalDate date) { this.date = date; }

    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }
}
