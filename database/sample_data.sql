USE foodflow;

-- =========================================
-- ROLES
-- =========================================
INSERT INTO roles (role_title) VALUES
('ADMIN'),
('DEPARTMENT_HEAD'),
('COOK');

-- =========================================
-- USERS
-- =========================================
INSERT INTO users (user_name, email_address, password_hash, role_id, is_active) VALUES
('System Admin', 'admin@foodflow.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 1, TRUE),
('Department Head', 'head@foodflow.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 2, TRUE),
('Head Cook', 'cook1@foodflow.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 3, TRUE),
('Assistant Cook', 'cook2@foodflow.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 3, TRUE);

-- =========================================
-- CATEGORIES
-- =========================================
INSERT INTO categories (category_name) VALUES
('PERISHABLE'),
('NON_PERISHABLE'),
('UTENSILS'),
('CLEANING_SUPPLIES');

-- =========================================
-- ITEMS
-- =========================================
INSERT INTO items (item_name, unit_type, reorder_level, category_id, current_stock, status) VALUES
('Sugar', 'kg', 20.0, 2, 100.0, 'AVAILABLE'),
('Kales', 'kg', 5.0, 1, 50.0, 'AVAILABLE'),
('Cups', 'pcs', 50.0, 3, 200.0, 'AVAILABLE'),
('Plates', 'pcs', 30.0, 3, 150.0, 'AVAILABLE'),
('Rice', 'kg', 25.0, 2, 80.0, 'AVAILABLE'),
('Cooking Oil', 'liters', 10.0, 2, 40.0, 'AVAILABLE'),
('Detergent', 'liters', 5.0, 4, 15.0, 'LOW_STOCK'),
('Tomatoes', 'kg', 10.0, 1, 25.0, 'AVAILABLE'),
('Onions', 'kg', 8.0, 1, 30.0, 'AVAILABLE'),
('Spoons', 'pcs', 100.0, 3, 250.0, 'AVAILABLE');

-- =========================================
-- STORE REQUESTS
-- =========================================
INSERT INTO store_requests (requester_id, approver_id, status, request_date, approved_date, notes) VALUES
(3, 2, 'APPROVED', '2026-03-01 08:00:00', '2026-03-01 08:30:00', 'Weekly kitchen supplies'),
(4, 2, 'PENDING', '2026-03-05 09:00:00', NULL, 'Urgent requirement for lunch service'),
(3, 2, 'REJECTED', '2026-02-28 10:00:00', '2026-02-28 11:00:00', 'Excessive quantity requested');

-- =========================================
-- REQUEST DETAILS
-- =========================================
INSERT INTO request_details (request_id, item_id, quantity_requested, quantity_approved) VALUES
(1, 1, 20.0, 20.0),
(1, 5, 30.0, 30.0),
(1, 6, 10.0, 10.0),
(2, 2, 15.0, 0.0),
(2, 8, 10.0, 0.0),
(3, 3, 100.0, 0.0);

-- =========================================
-- STOCK TRANSACTIONS
-- =========================================
-- Stock IN transactions
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, transaction_date, reference_id, notes) VALUES
(1, 1, 'IN', 50.0, '2026-03-01 09:00:00', NULL, 'Initial stock from supplier'),
(2, 3, 'IN', 30.0, '2026-03-01 09:30:00', NULL, 'Fresh delivery from vendor'),
(3, 1, 'IN', 100.0, '2026-03-01 10:00:00', NULL, 'Bulk purchase'),
(5, 1, 'IN', 50.0, '2026-03-02 08:00:00', NULL, 'Monthly rice supply'),
(6, 3, 'IN', 20.0, '2026-03-02 08:30:00', NULL, 'Cooking oil refill');

-- Stock OUT transactions (Usage)
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, transaction_date, reference_id, notes) VALUES
(1, 3, 'OUT', 10.0, '2026-03-01 12:00:00', NULL, 'Used for lunch preparation'),
(2, 3, 'OUT', 5.0, '2026-03-01 12:30:00', NULL, 'Kales used in cooking'),
(5, 4, 'OUT', 15.0, '2026-03-02 13:00:00', NULL, 'Rice consumed during lunch'),
(6, 3, 'OUT', 3.0, '2026-03-03 12:00:00', NULL, 'Cooking oil usage');

-- Damaged items
INSERT INTO stock_transactions (item_id, user_id, transaction_type, quantity, transaction_date, reference_id, notes) VALUES
(3, 3, 'DAMAGED', 5.0, '2026-03-01 14:00:00', NULL, 'Cups cracked during handling'),
(4, 4, 'DAMAGED', 3.0, '2026-03-02 15:00:00', NULL, 'Plates chipped');

-- =========================================
-- DAMAGE LOG
-- =========================================
INSERT INTO damage_log (item_id, quantity, damage_date, description, reported_by) VALUES
(3, 5.0, '2026-03-01 14:00:00', 'Cracked during lunch service - accidental drop', 3),
(4, 3.0, '2026-03-02 15:00:00', 'Chipped plates discovered during inventory check', 4),
(10, 10.0, '2026-03-03 10:00:00', 'Bent spoons found in storage', 3);

-- =========================================
-- SYSTEM LOGS
-- =========================================
INSERT INTO system_logs (user_id, action_performed, timestamp) VALUES
(1, 'User logged in', '2026-03-01 08:00:00'),
(1, 'Approved store request #1', '2026-03-01 08:30:00'),
(3, 'Recorded supply transaction for Sugar', '2026-03-01 09:00:00'),
(3, 'Logged usage of Kales', '2026-03-01 12:30:00'),
(3, 'Reported damage for Cups', '2026-03-01 14:00:00'),
(4, 'Created new store request #2', '2026-03-05 09:00:00'),
(2, 'Reviewed pending requests', '2026-03-05 10:00:00'),
(1, 'Generated monthly report', '2026-03-05 11:00:00');