package com.foodflow.model;

public class Damage {
    private int damageId;
    private int itemId;
    private String itemName;
    private double quantity;
    private String description;
    private String reportedBy;
    private Integer reportedByUserId;
    private String recordedByName;
    private String damageType;
    private String disposition = "DISPOSED";
    private String dateString;   // replaces LocalDate - avoids Gson serialization issues
    private String reportDate;   // replaces LocalDate reportDate

    public String getDateString() { return dateString; }
    public void setDateString(String dateString) { this.dateString = dateString; }

    public String getReportDate() { return reportDate; }
    public void setReportDate(String reportDate) { this.reportDate = reportDate; }

    public int getDamageId() { return damageId; }
    public void setDamageId(int damageId) { this.damageId = damageId; }

    public int getItemId() { return itemId; }
    public void setItemId(int itemId) { this.itemId = itemId; }

    public String getItemName() { return itemName; }
    public void setItemName(String itemName) { this.itemName = itemName; }

    public double getQuantity() { return quantity; }
    public void setQuantity(double quantity) { this.quantity = quantity; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getReportedBy() { return reportedBy; }
    public void setReportedBy(String reportedBy) { this.reportedBy = reportedBy; }

    public Integer getReportedByUserId() { return reportedByUserId; }
    public void setReportedByUserId(Integer reportedByUserId) { this.reportedByUserId = reportedByUserId; }

    public String getRecordedByName() { return recordedByName; }
    public void setRecordedByName(String recordedByName) { this.recordedByName = recordedByName; }

    public String getDamageType() { return damageType; }
    public void setDamageType(String damageType) { this.damageType = damageType; }

    public String getDisposition() { return disposition; }
    public void setDisposition(String disposition) { this.disposition = disposition; }

    public String getStatus() { return disposition; }
    public void setStatus(String status) { this.disposition = status; }
}
