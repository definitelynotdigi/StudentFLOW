/* =============================================================================
   StudentFLOW — Finance Module Migration
   -----------------------------------------------------------------------------
   Adds the `finance` role and the extra columns needed by the Finance
   dashboard.  NON-DESTRUCTIVE: no DROP, no TRUNCATE, no table recreation.
   Existing users / grades / announcements / messages / ledger rows are
   preserved untouched.

   Safe to re-run: every ADD COLUMN is guarded by INFORMATION_SCHEMA
   checks, every seed INSERT is guarded by WHERE NOT EXISTS.
   ============================================================================= */

USE student_portal_db;

/* -----------------------------------------------------------------------------
   1. WIDEN users.role ENUM to include 'finance'
   ----------------------------------------------------------------------------- */
ALTER TABLE users
    MODIFY COLUMN role
        ENUM('Admin','Department','Professor','Faculty','Student','finance')
        NOT NULL DEFAULT 'Student';

/* -----------------------------------------------------------------------------
   2. EXTEND financial_ledgers  (additive columns only)
   ----------------------------------------------------------------------------- */
SET @db := DATABASE();

/* reference_no */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='reference_no') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN reference_no VARCHAR(50) DEFAULT NULL AFTER description',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* payment_method */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='payment_method') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN payment_method VARCHAR(30) DEFAULT NULL AFTER transaction_type',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* remarks */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='remarks') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN remarks TEXT DEFAULT NULL',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* created_by (Finance user id) */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='created_by') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN created_by INT UNSIGNED DEFAULT NULL',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* updated_at */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='updated_at') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* voided (soft-delete flag) */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='voided') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN voided TINYINT(1) NOT NULL DEFAULT 0',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* void_reason */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='void_reason') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN void_reason VARCHAR(255) DEFAULT NULL',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* voided_by */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='voided_by') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN voided_by INT UNSIGNED DEFAULT NULL',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* voided_at */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='voided_at') = 0,
    'ALTER TABLE financial_ledgers ADD COLUMN voided_at DATETIME DEFAULT NULL',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* -----------------------------------------------------------------------------
   3. OPTIONAL foreign keys — only if the column doesn't already have one.
   These are additive and NOT required for the module to function; the
   application validates IDs itself. If your DB user lacks ALTER privileges
   on keys, skip this whole section — the module still works.
   ----------------------------------------------------------------------------- */
SET @fk := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers'
         AND COLUMN_NAME='created_by' AND REFERENCED_TABLE_NAME='users') = 0,
    'ALTER TABLE financial_ledgers ADD CONSTRAINT fk_ledger_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL',
    'SELECT 1'));
PREPARE s FROM @sql := @fk; EXECUTE s; DEALLOCATE PREPARE s;

/* -----------------------------------------------------------------------------
   4. INDEXES (safe — guarded by INFORMATION_SCHEMA)
   ----------------------------------------------------------------------------- */
SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND INDEX_NAME='idx_ledger_ref') = 0,
    'ALTER TABLE financial_ledgers ADD INDEX idx_ledger_ref (reference_no)',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
       WHERE TABLE_SCHEMA = @db AND TABLE_NAME='financial_ledgers' AND INDEX_NAME='idx_ledger_voided') = 0,
    'ALTER TABLE financial_ledgers ADD INDEX idx_ledger_voided (voided)',
    'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* -----------------------------------------------------------------------------
   5. DEMO FINANCE USER
   -----------------------------------------------------------------------------
   Uses the SAME bcrypt hash as admin1 / prof_smith / student_jane in the
   setup file.  Password:  Grc@Portal123
   ----------------------------------------------------------------------------- */
INSERT INTO users
    (username, email, password_hash, role, student_id,
     first_name, last_name, phone, department, course, department_course, is_verified)
SELECT 'finance01', 'finance@grcportal.com',
       '$2b$12$3ACuFcXq46HSnVEDFT1HnudbZQ/ckMkFYPGbWWWGrlRCb8PhfSAkm',
       'finance', 'FIN-001',
       'Maria', 'Santos', '555-0100',
       'Finance Office', NULL, 'Finance Office', 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'finance01');

/* -----------------------------------------------------------------------------
   6. VERIFY
   ----------------------------------------------------------------------------- */
SELECT 'users' AS table_name, COUNT(*) AS records FROM users
UNION ALL SELECT 'financial_ledgers', COUNT(*) FROM financial_ledgers;