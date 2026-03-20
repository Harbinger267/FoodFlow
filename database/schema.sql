CREATE DATABASE IF NOT EXISTS foodflow;
USE foodflow;

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('ADMIN', 'DEPARTMENT_HEAD', 'STOREKEEPER') NOT NULL,
    status ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE items (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL,
    item_type ENUM('FOOD', 'UTENSIL', 'TOOL') NOT NULL,
    stock DOUBLE NOT NULL DEFAULT 0,
    unit_of_measure VARCHAR(50) NOT NULL,
    description TEXT,
    status ENUM('AVAILABLE', 'OUT_OF_STOCK', 'DAMAGED', 'INACTIVE') NOT NULL DEFAULT 'AVAILABLE'
);

CREATE TABLE supply (
    supply_id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    quantity DOUBLE NOT NULL,
    supplier VARCHAR(100) NOT NULL,
    supply_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    recorded_by INT NULL,
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE,
    FOREIGN KEY (recorded_by) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE issue_transactions (
    issue_id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    quantity_issued DOUBLE NOT NULL,
    issued_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    issued_by INT NULL,
    issued_to VARCHAR(100) NOT NULL,
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE,
    FOREIGN KEY (issued_by) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE borrow_transactions (
    borrow_id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    quantity_borrowed DOUBLE NOT NULL,
    quantity_returned DOUBLE NOT NULL DEFAULT 0,
    borrow_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    return_date DATETIME NULL,
    status ENUM('BORROWED', 'PARTIALLY_RETURNED', 'RETURNED', 'LOST') NOT NULL DEFAULT 'BORROWED',
    recorded_by INT NULL,
    borrower_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE,
    FOREIGN KEY (recorded_by) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE damage_log (
    damage_id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    quantity DOUBLE NOT NULL,
    damage_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    reported_by INT NULL,
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE,
    FOREIGN KEY (reported_by) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE store_requests (
    request_id INT PRIMARY KEY AUTO_INCREMENT,
    requester_id INT NOT NULL,
    approver_id INT NULL,
    status ENUM('PENDING', 'APPROVED', 'REJECTED') NOT NULL DEFAULT 'PENDING',
    request_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_date DATETIME NULL,
    notes TEXT,
    FOREIGN KEY (requester_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (approver_id) REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE request_details (
    detail_id INT PRIMARY KEY AUTO_INCREMENT,
    request_id INT NOT NULL,
    item_id INT NOT NULL,
    quantity_requested DOUBLE NOT NULL,
    quantity_approved DOUBLE NOT NULL DEFAULT 0,
    FOREIGN KEY (request_id) REFERENCES store_requests(request_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE
);

CREATE TABLE system_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NULL,
    action_performed VARCHAR(255) NOT NULL,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

DROP TRIGGER IF EXISTS trg_issue_food_only;
DROP TRIGGER IF EXISTS trg_borrow_non_food_only;

DELIMITER //
CREATE TRIGGER trg_issue_food_only
BEFORE INSERT ON issue_transactions
FOR EACH ROW
BEGIN
    DECLARE v_item_type VARCHAR(20);
    SELECT item_type INTO v_item_type
    FROM items
    WHERE item_id = NEW.item_id;

    IF v_item_type IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Item not found for issue transaction.';
    END IF;

    IF v_item_type <> 'FOOD' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only FOOD items can be inserted into issue_transactions.';
    END IF;
END//

CREATE TRIGGER trg_borrow_non_food_only
BEFORE INSERT ON borrow_transactions
FOR EACH ROW
BEGIN
    DECLARE v_item_type VARCHAR(20);
    SELECT item_type INTO v_item_type
    FROM items
    WHERE item_id = NEW.item_id;

    IF v_item_type IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Item not found for borrow transaction.';
    END IF;

    IF v_item_type = 'FOOD' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'FOOD items must be recorded in issue_transactions, not borrow_transactions.';
    END IF;
END//
DELIMITER ;
