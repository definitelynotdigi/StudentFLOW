/* =============================================================================
   StudentFLOW — Finance Workflow Migration
   -----------------------------------------------------------------------------
   Adds the approval-workflow layer to the EXISTING financial_ledgers table.

   Design:
     - NON-DESTRUCTIVE. No DROP, no TRUNCATE, no table recreation.
     - Existing rows are back-filled with status='approved' so nothing that
       was previously visible to students disappears.
     - Safe to re-run: every ADD COLUMN is guarded by INFORMATION_SCHEMA.

   Workflow introduced:
       draft ──▶ submitted ──▶ approved
                     │
                     └──▶ returned ──▶ draft (edit) ──▶ submitted ──▶ ...

       voided   (preserved, excluded from totals, cannot be edited)
   ============================================================================= */

USE student_portal_db;

SET @db := DATABASE();

/* -----------------------------------------------------------------------------
   1. Add workflow columns (each guarded)
   ----------------------------------------------------------------------------- */

/* finance_id — which Finance user created this row */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='finance_id') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN finance_id INT UNSIGNED DEFAULT NULL AFTER student_id',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* fee_category */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='fee_category') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN fee_category VARCHAR(60) DEFAULT NULL AFTER description',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* semester */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='semester') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN semester VARCHAR(50) DEFAULT NULL',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* school_year */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='school_year') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN school_year VARCHAR(20) DEFAULT NULL',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* status */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='status') = 0,
  "ALTER TABLE financial_ledgers ADD COLUMN status ENUM('draft','submitted','approved','returned','voided') NOT NULL DEFAULT 'approved'",
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* admin_id — which admin last reviewed this row */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='admin_id') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN admin_id INT UNSIGNED DEFAULT NULL AFTER status',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* submitted_at */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='submitted_at') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN submitted_at DATETIME DEFAULT NULL',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* reviewed_at */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='reviewed_at') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN reviewed_at DATETIME DEFAULT NULL',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* reviewed_by */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='reviewed_by') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN reviewed_by INT UNSIGNED DEFAULT NULL',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* admin_remarks */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND COLUMN_NAME='admin_remarks') = 0,
  'ALTER TABLE financial_ledgers ADD COLUMN admin_remarks TEXT DEFAULT NULL',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* -----------------------------------------------------------------------------
   2. Back-fill existing rows so nothing that was already visible disappears
   ----------------------------------------------------------------------------- */
UPDATE financial_ledgers
   SET status = 'approved'
 WHERE status IS NULL
    OR status NOT IN ('draft','submitted','approved','returned','voided');

UPDATE financial_ledgers
   SET finance_id = created_by
 WHERE finance_id IS NULL AND created_by IS NOT NULL;

/* -----------------------------------------------------------------------------
   3. Indexes (safe)
   ----------------------------------------------------------------------------- */
SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND INDEX_NAME='idx_ledger_status') = 0,
  'ALTER TABLE financial_ledgers ADD INDEX idx_ledger_status (status)',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND INDEX_NAME='idx_ledger_finance') = 0,
  'ALTER TABLE financial_ledgers ADD INDEX idx_ledger_finance (finance_id)',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA=@db AND TABLE_NAME='financial_ledgers' AND INDEX_NAME='idx_ledger_admin') = 0,
  'ALTER TABLE financial_ledgers ADD INDEX idx_ledger_admin (admin_id)',
  'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

/* -----------------------------------------------------------------------------
   4. Verify
   ----------------------------------------------------------------------------- */
SELECT column_name, column_type, is_nullable, column_default
  FROM INFORMATION_SCHEMA.COLUMNS
 WHERE table_schema = @db
   AND table_name   = 'financial_ledgers'
 ORDER BY ordinal_position;