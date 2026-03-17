USE foodflow;

INSERT INTO users (name, email, password, role, status) VALUES
('Admin User', 'admin@foodflow.com', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'ADMIN', 'ACTIVE'),
('Department Head', 'head@foodflow.com', '7fb69d64d085e299af365f6783a4f0e3c77b6fd4bf14febdb3af8ba0416f777d', 'DEPARTMENT_HEAD', 'ACTIVE'),
('Store Keeper', 'keeper@foodflow.com', '3fef5c1bb564c29eb2f645042e37dbb360d322f66361148424f8b13258530c46', 'STORE_KEEPER', 'ACTIVE');

INSERT INTO items (name, category, stock, unit_of_measure, description, status) VALUES
('Maize Flour', 'FOOD', 95, 'kg', 'Main ugali flour stock', 'AVAILABLE'),
('Rice', 'FOOD', 68, 'kg', 'Dry rice for lunch service', 'AVAILABLE'),
('Cooking Oil', 'FOOD', 36, 'liters', 'Bulk kitchen oil', 'AVAILABLE'),
('Plates', 'UTENSIL', 140, 'pcs', 'Dining plates', 'AVAILABLE'),
('Spoons', 'UTENSIL', 180, 'pcs', 'Serving spoons', 'AVAILABLE'),
('Detergent', 'CLEANING', 14, 'liters', 'Store cleaning supply', 'LOW_STOCK'),
('Beans', 'FOOD', 44, 'kg', 'Dry beans for weekly menu', 'AVAILABLE');

INSERT INTO supply (item_id, quantity, supplier, supply_date, recorded_by) VALUES
(1, 45, 'Central Millers', '2026-03-01 08:30:00', 3),
(2, 30, 'Town Wholesalers', '2026-03-02 09:15:00', 3),
(4, 50, 'Utensil Hub', '2026-03-03 10:00:00', 3),
(6, 8, 'CleanPro Supplies', '2026-03-04 11:20:00', 3),
(7, 20, 'Agro Foods', '2026-03-05 08:05:00', 3);

INSERT INTO borrow_transactions (
    item_id, quantity_borrowed, quantity_returned, borrow_date, return_date, status, recorded_by
) VALUES
(4, 20, 20, '2026-03-05 12:30:00', '2026-03-05 17:10:00', 'RETURNED', 3),
(5, 30, 24, '2026-03-06 07:45:00', '2026-03-06 15:40:00', 'PARTIALLY_RETURNED', 3),
(4, 12, 0, '2026-03-07 09:25:00', NULL, 'BORROWED', 3),
(6, 4, 0, '2026-03-08 10:05:00', NULL, 'LOST', 3);

INSERT INTO damage_log (item_id, quantity, damage_date, description, reported_by) VALUES
(4, 6, '2026-03-07 14:30:00', 'Plates chipped during service', 3),
(5, 4, '2026-03-08 08:20:00', 'Spoons bent during washing', 3),
(6, 1, '2026-03-08 13:10:00', 'Detergent bottle leaked in storage', 3);

INSERT INTO store_requests (requester_id, approver_id, status, request_date, approved_date, notes) VALUES
(3, 2, 'APPROVED', '2026-03-03 09:00:00', '2026-03-03 10:00:00', 'Weekly top-up for maize flour and oil'),
(3, NULL, 'PENDING', '2026-03-08 09:30:00', NULL, 'Need more detergent and spoons'),
(3, 2, 'REJECTED', '2026-03-02 08:45:00', '2026-03-02 09:10:00', 'Requested quantity exceeded immediate need');

INSERT INTO request_details (request_id, item_id, quantity_requested, quantity_approved) VALUES
(1, 1, 30, 25),
(1, 3, 10, 8),
(2, 6, 12, 0),
(2, 5, 25, 0),
(3, 2, 50, 0);

INSERT INTO system_logs (user_id, action_performed, timestamp) VALUES
(1, 'Opened admin dashboard', '2026-03-08 08:00:00'),
(2, 'Approved store request #1', '2026-03-03 10:00:00'),
(3, 'Recorded supply for maize flour', '2026-03-01 08:30:00'),
(3, 'Recorded utensil borrow transaction', '2026-03-07 09:25:00'),
(3, 'Logged damage for plates', '2026-03-07 14:30:00');
