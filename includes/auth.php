<?php
/* =============================================================================
   /includes/auth.php
   -----------------------------------------------------------------------------
   Central session + role guard + user loader.

   Every role dashboard starts with:
       require_once __DIR__ . '/../includes/auth.php';
       require_role(['faculty','professor']);   // or whatever the role is

   After require_once, these variables are populated and safe to use:
       $pdo          — PDO connection
       $user_id      — $_SESSION['user_id']
       $user_data    — assoc row from users for the current user
       $current_role — lowercase role string, e.g. 'faculty'
       $display_name — 'First Last' or username fallback
   ============================================================================= */

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}
date_default_timezone_set('Asia/Manila');

/* -------------------------------------------------------------------------
   15-MINUTE IDLE TIMEOUT — identical to the old dashboard.php behaviour.
   ------------------------------------------------------------------------- */
$timeout_duration = 900;
if (isset($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > $timeout_duration)) {
    session_unset();
    session_destroy();
    header("Location: ../index.php?login_error=expired");
    exit();
}
$_SESSION['last_activity'] = time();

/* -------------------------------------------------------------------------
   DATABASE CONNECTION
   ------------------------------------------------------------------------- */
require_once __DIR__ . '/../database.php';   // provides $pdo

/* -------------------------------------------------------------------------
   SESSION USER PRESENCE
   ------------------------------------------------------------------------- */
if (!isset($_SESSION['user_id'])) {
    header("Location: ../index.php?login_error=expired");
    exit();
}

$user_id = (int)$_SESSION['user_id'];

/* -------------------------------------------------------------------------
   LOAD FULL USER ROW
   ------------------------------------------------------------------------- */
$user_stmt = $pdo->prepare("
    SELECT id, username, email, role, student_id, first_name, last_name, phone, department, course, department_course
    FROM users
    WHERE id = ?
    LIMIT 1
");
$user_stmt->execute([$user_id]);
$user_data = $user_stmt->fetch(PDO::FETCH_ASSOC);

if (!$user_data) {
    session_unset();
    session_destroy();
    header("Location: ../index.php?login_error=expired");
    exit();
}

$current_role = strtolower($user_data['role'] ?? $_SESSION['role'] ?? '');

$display_name = trim(($user_data['first_name'] ?? '') . ' ' . ($user_data['last_name'] ?? ''));
if ($display_name === '') {
    $display_name = $user_data['username'] ?? 'User';
}

/* -------------------------------------------------------------------------
   ROLE GUARD HELPER
   ------------------------------------------------------------------------- */
function require_role(array $allowed_roles): void {
    global $current_role;
    $allowed = array_map('strtolower', $allowed_roles);
    if (!in_array($current_role, $allowed, true)) {
        header("Location: ../index.php?login_error=forbidden");
        exit();
    }
}