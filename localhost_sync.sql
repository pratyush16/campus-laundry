-- ==============================================================
-- CampusLaundry: Localhost Synchronization Script
-- Synchronizes Localhost (laundry) to match Aiven Cloud (defaultdb)
-- Open and execute this in MySQL Workbench on your Local Connection
-- ==============================================================

USE laundry;

-- --------------------------------------------------------------
-- 1. TABLES: Create admin_users table (Missing in Localhost)
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_users (
  admin_id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(30) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(60) NOT NULL,
  role ENUM('warden','vendor','superadmin') NOT NULL DEFAULT 'warden',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login DATETIME DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (admin_id),
  UNIQUE KEY username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed Admin Accounts
INSERT INTO admin_users (admin_id, username, password_hash, full_name, role, is_active, last_login, created_at)
VALUES 
(1, 'admin', '$2b$12$tWF25FktoaMaCQZe3srlZuQN1jjrMMpNJ/EVpJ3Mk842NAO7y9p5i', 'System Administrator', 'superadmin', 1, '2026-10-31 09:32:12', '2026-10-26 14:10:21'),
(2, 'warden_b', '$2b$12$zt1cx4qmnqtRAkwsdzjvXeG7uKX6ZxM68Q2QaNYueq0AVrcewBOpy', 'Hostel Warden', 'warden', 1, NULL, '2026-10-26 14:10:22'),
(3, 'vendor_sparkle', '$2b$12$vCzVYVygL3Q./A1z3QKiLOWRem85ESNhCa14T0wwYS8lbj1iX8sry', 'Sparkle Wash Admin', 'vendor', 1, NULL, '2026-10-26 14:10:23')
ON DUPLICATE KEY UPDATE full_name=VALUES(full_name);

-- --------------------------------------------------------------
-- 2. SCHEMA NORMALIZATION: 3NF Refactoring on laundry_transaction
-- (Removes redundant Vendor_ID transitive dependency)
-- --------------------------------------------------------------
SET @fk_exists = (
    SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS 
    WHERE CONSTRAINT_SCHEMA = 'laundry' AND TABLE_NAME = 'laundry_transaction' AND CONSTRAINT_NAME = 'fk2_vendor_id'
);
SET @drop_fk_stmt = IF(@fk_exists > 0, 'ALTER TABLE laundry_transaction DROP FOREIGN KEY fk2_vendor_id;', 'SELECT 1;');
PREPARE stmt FROM @drop_fk_stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS 
    WHERE TABLE_SCHEMA = 'laundry' AND TABLE_NAME = 'laundry_transaction' AND COLUMN_NAME = 'Vendor_ID'
);
SET @drop_col_stmt = IF(@col_exists > 0, 'ALTER TABLE laundry_transaction DROP COLUMN Vendor_ID;', 'SELECT 1;');
PREPARE stmt FROM @drop_col_stmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- --------------------------------------------------------------
-- 3. DATA SYNCHRONIZATION: Sync Students, Orders & Line Items
-- --------------------------------------------------------------

-- Update Student Cycle Balances to match Aiven Cloud
UPDATE students SET cycle_used = 0, cycle_remaining = 30 WHERE std_id = '2402050088';
UPDATE students SET cycle_used = 0, cycle_remaining = 30 WHERE std_id = '2502050112';
UPDATE students SET quota = 30, cycle_used = 1, cycle_remaining = 29 WHERE std_id = '2502050650';
UPDATE students SET cycle_used = 11, cycle_remaining = 19 WHERE std_id = '2502050680';
UPDATE students SET cycle_used = 0, cycle_remaining = 30 WHERE std_id = '2602050045';

-- Clear legacy test orders
DELETE FROM transaction_item;
DELETE FROM laundry_transaction;

-- Insert 6 production transactions from Aiven
INSERT INTO laundry_transaction 
(Transaction_ID, std_id, Drop_Point_ID, Drop_Off_Date, Expected_Completion_Date, Actual_Completion_Date, Total_Weight, Cycles_Deducted, Status)
VALUES
('TXN1001', '2502050680', 'DP01', '2026-10-15', '2026-10-18', '2026-10-18', 5.70, 1, 'Completed'),
('TXN1002', '2502050680', 'DP02', '2026-10-21', '2026-10-24', '2026-10-21', 7.50, 2, 'Completed'),
('TXN1003', '2502050680', 'DP01', '2026-10-23', '2026-10-28', '2026-10-23', 5.70, 1, 'Completed'),
('TXN1004', '2502050650', 'DP01', '2026-10-26', '2026-10-29', '2026-10-26', 2.15, 1, 'Completed'),
('TXN1005', '2502050680', 'DP01', '2026-10-27', '2026-10-30', '2026-10-27', 2.40, 1, 'Completed'),
('TXN1006', '2502050680', 'DP01', '2026-10-31', '2026-11-05', NULL, 5.45, 1, 'Submitted');

-- Insert 23 transaction items from Aiven
INSERT INTO transaction_item (Transaction_ID, Item_ID, Quantity) VALUES
('TXN1001', 'ITM01', 8),
('TXN1001', 'ITM02', 3),
('TXN1001', 'ITM05', 2),
('TXN1001', 'ITM09', 3),
('TXN1002', 'ITM01', 1),
('TXN1002', 'ITM02', 3),
('TXN1002', 'ITM05', 2),
('TXN1002', 'ITM10', 11),
('TXN1003', 'ITM01', 6),
('TXN1003', 'ITM02', 3),
('TXN1003', 'ITM03', 1),
('TXN1003', 'ITM05', 1),
('TXN1003', 'ITM06', 2),
('TXN1003', 'ITM09', 3),
('TXN1004', 'ITM01', 5),
('TXN1004', 'ITM05', 2),
('TXN1005', 'ITM03', 4),
('TXN1006', 'ITM01', 5),
('TXN1006', 'ITM02', 3),
('TXN1006', 'ITM03', 1),
('TXN1006', 'ITM05', 1),
('TXN1006', 'ITM06', 2),
('TXN1006', 'ITM09', 3);

-- --------------------------------------------------------------
-- 4. VIEWS: Recreate all 4 Modular & Composite Views
-- --------------------------------------------------------------
CREATE OR REPLACE VIEW vw_student_profile AS
SELECT 
    std_id,
    std_name,
    contact,
    hostel,
    room,
    academic_year
FROM students;

CREATE OR REPLACE VIEW vw_student_quota_burn AS
SELECT 
    std_id,
    quota,
    cycle_used,
    cycle_remaining,
    ROUND((cycle_used / quota) * 100, 1) AS burn_percentage,
    CASE 
        WHEN cycle_remaining <= 0 THEN 'Quota Exhausted'
        WHEN cycle_remaining <= 5 THEN 'Critical (Low Quota)'
        WHEN (cycle_used / quota) * 100 > 70 THEN 'Accelerated Burn'
        ELSE 'Optimal Pace'
    END AS pace_status
FROM students;

CREATE OR REPLACE VIEW vw_student_active_cycle AS
SELECT 
    t.std_id,
    t.Transaction_ID,
    t.Status,
    t.Total_Weight,
    t.Drop_Point_ID,
    dp.Location AS drop_point_location,
    t.Drop_Off_Date,
    t.Expected_Completion_Date
FROM (
    SELECT 
        Transaction_ID,
        std_id,
        Drop_Point_ID,
        Drop_Off_Date,
        Expected_Completion_Date,
        Total_Weight,
        Cycles_Deducted,
        Status,
        ROW_NUMBER() OVER (
            PARTITION BY std_id 
            ORDER BY Drop_Off_Date DESC, Transaction_ID DESC
        ) AS rn
    FROM laundry_transaction
    WHERE Status NOT IN ('Completed', 'Cancelled')
) t
LEFT JOIN drop_point dp ON t.Drop_Point_ID = dp.Drop_Point_ID
WHERE t.rn = 1;

CREATE OR REPLACE VIEW vw_student_portal_overview AS
SELECT 
    p.std_id,
    p.std_name,
    p.contact,
    p.hostel,
    p.room,
    p.academic_year,
    q.quota,
    q.cycle_used,
    q.cycle_remaining,
    q.burn_percentage,
    q.pace_status,
    a.Transaction_ID AS active_transaction_id,
    a.Status AS active_status,
    a.Total_Weight AS active_total_weight,
    a.Drop_Point_ID AS active_drop_point_id,
    a.drop_point_location AS active_drop_point_location,
    a.Drop_Off_Date AS active_drop_off_date,
    a.Expected_Completion_Date AS active_expected_completion_date
FROM vw_student_profile p
JOIN vw_student_quota_burn q ON p.std_id = q.std_id
LEFT JOIN vw_student_active_cycle a ON p.std_id = a.std_id;

-- --------------------------------------------------------------
-- 5. TRIGGERS: Triggers with updated 10-digit phone validation
-- --------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_admin_login_timestamp;
DELIMITER //
CREATE TRIGGER trg_admin_login_timestamp
BEFORE UPDATE ON admin_users
FOR EACH ROW
BEGIN
    IF NEW.last_login IS NOT NULL AND (OLD.last_login IS NULL OR NEW.last_login != OLD.last_login) THEN
        SET NEW.last_login = NOW();
    END IF;
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_validate_student_insert;
DELIMITER //
CREATE TRIGGER trg_validate_student_insert
BEFORE INSERT ON students
FOR EACH ROW
BEGIN
    IF LENGTH(NEW.std_id) != 10 OR NEW.std_id NOT REGEXP '^[0-9]{10}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: wrong student ID';
    END IF;

    IF LENGTH(CAST(NEW.contact AS CHAR)) != 10 OR CAST(NEW.contact AS CHAR) NOT REGEXP '^[0-9]{10}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Phone number must be exactly 10 digits.';
    END IF;

    IF NEW.hostel NOT REGEXP '^(B([1-9]|1[0-2])|G[1-8])$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Invalid hostel. Allowed hostels are B1 to B12 and G1 to G8 only.';
    END IF;

    IF NEW.quota NOT IN (15, 30) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Quota cycles must be either 15 or 30.';
    END IF;

    IF NEW.cycle_remaining IS NULL THEN
        SET NEW.cycle_remaining = NEW.quota;
    END IF;
    IF NEW.cycle_used IS NULL THEN
        SET NEW.cycle_used = 0;
    END IF;
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_validate_student_update;
DELIMITER //
CREATE TRIGGER trg_validate_student_update
BEFORE UPDATE ON students
FOR EACH ROW
BEGIN
    IF LENGTH(NEW.std_id) != 10 OR NEW.std_id NOT REGEXP '^[0-9]{10}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: wrong student ID';
    END IF;

    IF LENGTH(CAST(NEW.contact AS CHAR)) != 10 OR CAST(NEW.contact AS CHAR) NOT REGEXP '^[0-9]{10}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Phone number must be exactly 10 digits.';
    END IF;

    IF NEW.hostel NOT REGEXP '^(B([1-9]|1[0-2])|G[1-8])$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Invalid hostel. Allowed hostels are B1 to B12 and G1 to G8 only.';
    END IF;

    IF NEW.quota NOT IN (15, 30) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Quota cycles must be either 15 or 30.';
    END IF;
END //
DELIMITER ;

-- --------------------------------------------------------------
-- 6. STORED PROCEDURES: Create & Update Procedures
-- --------------------------------------------------------------

-- 6.1 sp_AuthenticateAdmin
DROP PROCEDURE IF EXISTS sp_AuthenticateAdmin;
DELIMITER //
CREATE PROCEDURE sp_AuthenticateAdmin(
    IN p_username VARCHAR(30)
)
BEGIN
    SELECT admin_id, username, password_hash, full_name, role, is_active, last_login
    FROM admin_users
    WHERE username = p_username AND is_active = TRUE;
END //
DELIMITER ;

-- 6.2 sp_ToggleAdminStatus
DROP PROCEDURE IF EXISTS sp_ToggleAdminStatus;
DELIMITER //
CREATE PROCEDURE sp_ToggleAdminStatus(
    IN p_admin_id INT,
    IN p_new_status BOOLEAN
)
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_superadmin_count INT;

    SELECT role INTO v_role FROM admin_users WHERE admin_id = p_admin_id;

    IF v_role = 'superadmin' AND p_new_status = FALSE THEN
        SELECT COUNT(*) INTO v_superadmin_count 
        FROM admin_users 
        WHERE role = 'superadmin' AND is_active = TRUE;
        
        IF v_superadmin_count <= 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Security Violation: Cannot deactivate the sole active superadministrator.';
        END IF;
    END IF;

    UPDATE admin_users
    SET is_active = p_new_status
    WHERE admin_id = p_admin_id;
END //
DELIMITER ;

-- 6.3 sp_GetStudentPortalData
DROP PROCEDURE IF EXISTS sp_GetStudentPortalData;
DELIMITER //
CREATE PROCEDURE sp_GetStudentPortalData(IN p_std_id VARCHAR(20))
BEGIN
    -- Result Set 1: Student Overview Cards (from vw_student_portal_overview)
    SELECT * 
    FROM vw_student_portal_overview 
    WHERE std_id = p_std_id;

    -- Result Set 2: Recent 10 Laundry Orders with Drop Point & Vendor info
    SELECT 
        t.Transaction_ID,
        t.std_id,
        t.Drop_Point_ID,
        dp.Location AS drop_point_location,
        dp.Vendor_ID,
        v.Vendor_Name AS vendor_name,
        t.Drop_Off_Date,
        t.Expected_Completion_Date,
        t.Total_Weight,
        t.Cycles_Deducted,
        t.Status
    FROM laundry_transaction t
    JOIN drop_point dp ON t.Drop_Point_ID = dp.Drop_Point_ID
    JOIN vendor v ON dp.Vendor_ID = v.Vendor_ID
    WHERE t.std_id = p_std_id
    ORDER BY t.Drop_Off_Date DESC, t.Transaction_ID DESC
    LIMIT 10;
END //
DELIMITER ;

-- 6.4 sp_GetHostelDashboardMetrics (Optimized 3NF & Cross Join)
DROP PROCEDURE IF EXISTS sp_GetHostelDashboardMetrics;
DELIMITER //
CREATE PROCEDURE sp_GetHostelDashboardMetrics()
BEGIN
    SELECT 
        t.total_transactions,
        t.active_loads,
        t.completed_loads,
        t.avg_load_kg,
        s.total_students,
        s.total_cycles_used,
        s.total_campus_quota,
        dp.active_kiosks
    FROM (
        SELECT 
            COUNT(*) AS total_transactions,
            COUNT(CASE WHEN Status NOT IN ('Completed', 'Cancelled') THEN 1 END) AS active_loads,
            COUNT(CASE WHEN Status = 'Completed' THEN 1 END) AS completed_loads,
            ROUND(AVG(Total_Weight), 2) AS avg_load_kg
        FROM laundry_transaction
    ) t
    CROSS JOIN (
        SELECT 
            COUNT(*) AS total_students,
            COALESCE(SUM(cycle_used), 0) AS total_cycles_used,
            COALESCE(SUM(quota), 0) AS total_campus_quota
        FROM students
    ) s
    CROSS JOIN (
        SELECT 
            COUNT(*) AS active_kiosks
        FROM drop_point
        WHERE Operational_Status = 'Active'
    ) dp;
END //
DELIMITER ;
