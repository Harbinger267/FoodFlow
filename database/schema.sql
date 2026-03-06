
CREATE DATABASE IF NOT EXISTS foodflow;
USE foodflow;

-- =========================================
-- ROLES TABLE
-- =========================================

CREATE TABLE roles (
    role_id INT PRIMARY KEY AUTO_INCREMENT,
    role_title VARCHAR(50) NOT NULL UNIQUE -- ADMIN, DEPARTMENT_HEAD, COOK
);

-- =========================================
-- USERS TABLE
-- =========================================

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    user_name VARCHAR(100) NOT NULL,
    email_address VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    last_login DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    role_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE
);

-- =========================================
-- SYSTEM_LOGS TABLE
-- =========================================

CREATE TABLE system_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    action_performed VARCHAR(255) NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- =========================================
-- CATEGORIES TABLE
-- =========================================

CREATE TABLE categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(100) NOT NULL UNIQUE -- PERISHABLE, NON_PERISHABLE, UTENSILS, CLEANING_SUPPLIES
);

-- =========================================
-- ITEMS TABLE
-- =========================================

CREATE TABLE items (
    item_id INT PRIMARY KEY AUTO_INCREMENT,
    item_name VARCHAR(100) NOT NULL,
    unit_type VARCHAR(50) NOT NULL, -- kg, liters, pcs, etc.
    reorder_level DOUBLE DEFAULT 10.0,
    category_id INT NOT NULL,
    current_stock DOUBLE DEFAULT 0.0,
    status VARCHAR(50) DEFAULT 'AVAILABLE', -- AVAILABLE, LOW_STOCK, OUT_OF_STOCK, DISCONTINUED
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- =========================================
-- STORE_REQUESTS TABLE
-- =========================================

CREATE TABLE store_requests (
    request_id INT PRIMARY KEY AUTO_INCREMENT,
    requester_id INT NOT NULL,
    approver_id INT,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    request_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_date DATETIME,
    notes TEXT,
    
    FOREIGN KEY (requester_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (approver_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- =========================================
-- REQUEST_DETAILS TABLE
-- =========================================

CREATE TABLE request_details (
    detail_id INT PRIMARY KEY AUTO_INCREMENT,
    request_id INT NOT NULL,
    item_id INT NOT NULL,
    quantity_requested DOUBLE NOT NULL,
    quantity_approved DOUBLE DEFAULT 0.0,
    
    FOREIGN KEY (request_id) REFERENCES store_requests(request_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE
);

-- =========================================
-- STOCK_TRANSACTIONS TABLE (Unified)
-- =========================================

CREATE TABLE stock_transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    user_id INT NOT NULL,
    transaction_type VARCHAR(50) NOT NULL, -- IN, OUT, DAMAGED, BORROWED, RETURNED
    quantity DOUBLE NOT NULL,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    reference_id INT, -- Can link to request_id or other references
    notes TEXT,
    
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- =========================================
-- DAMAGE LOG TABLE
-- =========================================

CREATE TABLE damage_log (
    damage_id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    quantity DOUBLE NOT NULL,
    damage_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT,
    reported_by INT NOT NULL,
    
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE,
    FOREIGN KEY (reported_by) REFERENCES users(user_id) ON DELETE CASCADE
);