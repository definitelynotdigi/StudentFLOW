/* ============================================================
   GRC STUDENT PORTAL (StudentFLOW) — COMPLETE DATABASE SETUP
   ------------------------------------------------------------
   This is a clean, from-scratch build of every table the PHP
   code in this project actually uses:

     - index.php          (landing page, register, login, forgot pw)
     - authenticate.php    (login handler)
     - dashboard.php        (admin / faculty / student dashboard)
     - check_student_id.php (AJAX master-list verification)
     - print.php             (grades / ledger / enrollment print-outs)
     - send_message.php    (support chat)
     - database.php / config.php (connection settings)

   Import this ONE file into a fresh database and everything
   will work end-to-end: register -> OTP verify -> login ->
   dashboard -> grades -> master list -> chat -> print.

   Safe to re-run: every CREATE uses IF NOT EXISTS and every
   seed INSERT uses a WHERE NOT EXISTS guard, so running this
   twice will not duplicate data or throw errors.
   ============================================================ */

CREATE DATABASE IF NOT EXISTS student_portal_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE student_portal_db;

SET FOREIGN_KEY_CHECKS = 0;


/* ============================================================
   1. USERS
   Every login, registration, and profile field the code reads
   or writes (see index.php reg_submit_details / authenticate.php).
   ============================================================ */
CREATE TABLE IF NOT EXISTS users (
    id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    username           VARCHAR(50)  NOT NULL UNIQUE,
    email              VARCHAR(150) NOT NULL UNIQUE,
    password_hash      VARCHAR(255) NOT NULL,

    role               ENUM('Admin', 'Department', 'Professor', 'Faculty', 'Student')
                        NOT NULL DEFAULT 'Student',

    student_id         VARCHAR(50)  DEFAULT NULL,

    first_name         VARCHAR(100) DEFAULT NULL,
    last_name          VARCHAR(100) DEFAULT NULL,
    phone              VARCHAR(30)  DEFAULT NULL,

    department         VARCHAR(100) DEFAULT NULL,
    course             VARCHAR(100) DEFAULT NULL,
    department_course  VARCHAR(150) DEFAULT NULL,

    otp_code           VARCHAR(20)  DEFAULT NULL,
    otp_expires        DATETIME     DEFAULT NULL,
    is_verified        TINYINT(1)   NOT NULL DEFAULT 0,

    failed_attempts    INT          NOT NULL DEFAULT 0,
    lockout_until      DATETIME     DEFAULT NULL,

    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_users_role (role),
    INDEX idx_users_student_id (student_id),
    INDEX idx_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   2. STUDENT MASTER LIST
   Admin-controlled allow-list. A row starts 'pending' when the
   admin adds it, and flips to 'active' once a matching account
   exists in `users` (handled by index.php on OTP verify, and by
   dashboard.php's auto-sync on every admin page load).
   ============================================================ */
CREATE TABLE IF NOT EXISTS student_masterlist (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    student_id   VARCHAR(50)  NOT NULL UNIQUE,
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL,
    department   VARCHAR(100) DEFAULT NULL,
    course       VARCHAR(100) DEFAULT NULL,
    status       ENUM('pending', 'active') DEFAULT 'pending',
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   3. ACADEMIC RECORDS
   Grades encoded by faculty, released to a student's dashboard.
   ============================================================ */
CREATE TABLE IF NOT EXISTS academic_records (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    faculty_id          INT UNSIGNED NOT NULL,
    student_id          INT UNSIGNED NOT NULL,

    subject_code        VARCHAR(50)  NOT NULL,
    subject_title       VARCHAR(150) NOT NULL,
    grade               DECIMAL(5,2) DEFAULT NULL,

    semester            VARCHAR(50)  NOT NULL,
    academic_year       VARCHAR(50)  NOT NULL,

    is_released         TINYINT(1) NOT NULL DEFAULT 0,
    cleared_by_faculty   TINYINT(1) NOT NULL DEFAULT 0,
    cleared_by_student   TINYINT(1) NOT NULL DEFAULT 0,

    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_academic_student (student_id),
    INDEX idx_academic_faculty (faculty_id),
    INDEX idx_academic_subject (subject_code),

    CONSTRAINT fk_academic_faculty FOREIGN KEY (faculty_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_academic_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,

    UNIQUE KEY unique_student_subject (student_id, subject_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   4. ANNOUNCEMENTS
   ============================================================ */
CREATE TABLE IF NOT EXISTS announcements (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    content     TEXT NOT NULL,
    posted_by   VARCHAR(150) DEFAULT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_announcements_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   5. SUPPORT / CHAT MESSAGES
   Student <-> Admin chat thread, keyed by the student's user id.
   ============================================================ */
CREATE TABLE IF NOT EXISTS support_messages (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id     INT UNSIGNED NOT NULL,
    sender_role ENUM('student', 'admin') NOT NULL DEFAULT 'student',
    message     TEXT NOT NULL,
    is_read     TINYINT(1) NOT NULL DEFAULT 0,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_support_user (user_id),
    INDEX idx_support_read (is_read),

    CONSTRAINT fk_support_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   6. FACULTY SUBMISSIONS
   Tracks a faculty member routing a batch of grades to a
   specific admin/department ID for clearance.
   ============================================================ */
CREATE TABLE IF NOT EXISTS faculty_submissions (
    id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    faculty_id         INT UNSIGNED NOT NULL,
    student_id         INT UNSIGNED NOT NULL,
    admin_id           INT UNSIGNED DEFAULT NULL,

    admin_target_id    VARCHAR(50) NOT NULL,
    submission_status  VARCHAR(20) NOT NULL DEFAULT 'submitted',
    cleared_by_admin   TINYINT(1)  NOT NULL DEFAULT 0,

    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_submission_faculty (faculty_id),
    INDEX idx_submission_student (student_id),
    INDEX idx_submission_admin (admin_target_id),
    INDEX idx_submission_status (cleared_by_admin),

    CONSTRAINT fk_submission_faculty FOREIGN KEY (faculty_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_submission_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_submission_admin   FOREIGN KEY (admin_id)   REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


/* ============================================================
   7. FINANCIAL LEDGERS
   print.php and dashboard.php both SELECT from this table even
   though the feature to add charges/payments was removed from
   the UI. Kept here so those pages don't throw a
   "table doesn't exist" error; it will simply read as empty
   unless you insert rows yourself.
   ============================================================ */
CREATE TABLE IF NOT EXISTS financial_ledgers (
    id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id        INT UNSIGNED NOT NULL,
    faculty_id        INT UNSIGNED DEFAULT NULL,
    description       VARCHAR(255) NOT NULL,
    amount            DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    transaction_type  ENUM('Charge', 'Payment') NOT NULL DEFAULT 'Charge',
    transaction_date  DATE NOT NULL,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_ledger_student (student_id),
    INDEX idx_ledger_faculty (faculty_id),
    INDEX idx_ledger_date (transaction_date),

    CONSTRAINT fk_ledger_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_ledger_faculty FOREIGN KEY (faculty_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;


/* ============================================================
   8. SEED DATA
   ------------------------------------------------------------
   All three demo accounts below share the password:

        Grc@Portal123

   The hash is a real bcrypt hash (verified against PHP's
   password_verify()), not a placeholder — you can log in with
   it immediately after importing this file.
   ============================================================ */

-- 8a. Admin account
INSERT INTO users (username, email, password_hash, role, student_id, first_name, last_name, department, course, department_course, is_verified)
SELECT 'admin1', 'admin@grcportal.com',
       '$2b$12$3ACuFcXq46HSnVEDFT1HnudbZQ/ckMkFYPGbWWWGrlRCb8PhfSAkm',
       'Admin', 'ADM-01-01111', 'System', 'Administrator', 'Administration', NULL, 'Administration', 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin1');

-- 8b. Faculty / Professor account
INSERT INTO users (username, email, password_hash, role, student_id, first_name, last_name, phone, department, course, department_course, is_verified)
SELECT 'prof_smith', 'smith@grcportal.com',
       '$2b$12$3ACuFcXq46HSnVEDFT1HnudbZQ/ckMkFYPGbWWWGrlRCb8PhfSAkm',
       'Professor', 'FAC-001', 'John', 'Smith', '555-0192', 'College of Computer Studies', NULL, 'College of Computer Studies', 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'prof_smith');

-- 8c. Student account (fully registered — will show as "Active" in the master list)
INSERT INTO users (username, email, password_hash, role, student_id, first_name, last_name, phone, department, course, department_course, is_verified)
SELECT 'student_jane', 'jane@grcportal.com',
       '$2b$12$3ACuFcXq46HSnVEDFT1HnudbZQ/ckMkFYPGbWWWGrlRCb8PhfSAkm',
       'Student', '2024-01-00002', 'Jane', 'Doe', '555-0143', 'College of Computer Studies', 'BSIT', 'College of Computer Studies - BSIT', 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'student_jane');

-- 8d. Master list: one student already registered (Jane, above — will read as Active)
INSERT INTO student_masterlist (student_id, first_name, last_name, department, course, status)
SELECT '2024-01-00002', 'Jane', 'Doe', 'College of Computer Studies', 'BSIT', 'active'
WHERE NOT EXISTS (SELECT 1 FROM student_masterlist WHERE student_id = '2024-01-00002');

-- 8e. Master list: one student added by admin but who has NOT registered yet (stays Pending)
INSERT INTO student_masterlist (student_id, first_name, last_name, department, course, status)
SELECT '2024-01-00001', 'Juan', 'Dela Cruz', 'College of Computer Studies', 'BSIT', 'pending'
WHERE NOT EXISTS (SELECT 1 FROM student_masterlist WHERE student_id = '2024-01-00001');

-- 8f. Sample announcement
INSERT INTO announcements (title, content, posted_by)
SELECT 'Welcome to StudentFLOW', 'Welcome to the Global Reciprocal Colleges Student and Faculty Portal.', 'System Administrator'
WHERE NOT EXISTS (SELECT 1 FROM announcements WHERE title = 'Welcome to StudentFLOW');

-- 8g. Sample academic records for the registered student (Jane / prof_smith)
INSERT INTO academic_records (faculty_id, student_id, subject_code, subject_title, grade, semester, academic_year, is_released, cleared_by_faculty, cleared_by_student)
SELECT f.id, s.id, 'CS101', 'Introduction to Computer Science', 1.50, '1st Semester', '2026-2027', 1, 0, 0
FROM users f JOIN users s
WHERE f.username = 'prof_smith' AND s.username = 'student_jane'
  AND NOT EXISTS (SELECT 1 FROM academic_records ar WHERE ar.student_id = s.id AND ar.subject_code = 'CS101');

INSERT INTO academic_records (faculty_id, student_id, subject_code, subject_title, grade, semester, academic_year, is_released, cleared_by_faculty, cleared_by_student)
SELECT f.id, s.id, 'DB201', 'Database Management Systems', 1.75, '1st Semester', '2026-2027', 1, 0, 0
FROM users f JOIN users s
WHERE f.username = 'prof_smith' AND s.username = 'student_jane'
  AND NOT EXISTS (SELECT 1 FROM academic_records ar WHERE ar.student_id = s.id AND ar.subject_code = 'DB201');


/* ============================================================
   9. VERIFY INSTALLATION
   Run this file, then check the counts below look right:
   users=3, student_masterlist=2, academic_records=2,
   announcements=1, support_messages=0, faculty_submissions=0,
   financial_ledgers=0.
   ============================================================ */
SELECT 'users' AS table_name, COUNT(*) AS records FROM users
UNION ALL SELECT 'student_masterlist', COUNT(*) FROM student_masterlist
UNION ALL SELECT 'academic_records', COUNT(*) FROM academic_records
UNION ALL SELECT 'announcements', COUNT(*) FROM announcements
UNION ALL SELECT 'support_messages', COUNT(*) FROM support_messages
UNION ALL SELECT 'faculty_submissions', COUNT(*) FROM faculty_submissions
UNION ALL SELECT 'financial_ledgers', COUNT(*) FROM financial_ledgers;