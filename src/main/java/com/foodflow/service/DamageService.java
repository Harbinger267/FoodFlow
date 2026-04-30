package com.foodflow.service;

import com.foodflow.dao.DamageDAO;

public class DamageService {
    private final DamageDAO damageDAO = new DamageDAO();

    public boolean recordDamage(int itemId, double quantity, String reason, int userId) {
        if (itemId <= 0 || quantity <= 0 || userId <= 0) {
            return false;
        }
        return damageDAO.recordDamage(itemId, quantity, reason, userId, null, "DISPOSED");
    }
}
