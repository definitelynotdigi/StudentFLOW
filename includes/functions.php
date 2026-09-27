<?php
/* =============================================================================
   /includes/functions.php
   -----------------------------------------------------------------------------
   Shared helpers used by all three role dashboards.
   Moved verbatim from the old dashboard.php — no behavioural changes.
   ============================================================================= */

/* -------------------------------------------------------------------------
   GRADE COLOR THRESHOLD
     grade <  3.00  →  PASSING  (green, text-success)
     grade >= 3.00  →  FAILING  (red,   text-danger)
   3.00 itself is RED — comparison uses >=.
   ------------------------------------------------------------------------- */
if (!defined('GRADE_LIMIT')) {
    define('GRADE_LIMIT', 3.00);
}

function grade_color_class($value, float $limit = 3.00, string $neutral = 'text-muted'): string {
    if ($value === null || $value === '' || $value === '—' || $value === '-') {
        return $neutral;
    }
    if (!is_numeric($value)) {
        return $neutral;
    }
    $n = round((float)$value, 2);
    return $n >= $limit ? 'text-danger' : 'text-success';
}

/* -------------------------------------------------------------------------
   CREATE NOTIFICATION
   Inserts one private notification for one recipient.
   Validates the recipient exists.
   ------------------------------------------------------------------------- */
function create_notification(
    PDO $pdo,
    int $recipientId,
    ?int $senderId,
    string $type,
    string $title,
    string $message,
    ?string $refType = null,
    ?int $refId = null,
    ?string $targetCode = null
) {
    $check = $pdo->prepare("SELECT id FROM users WHERE id = ? LIMIT 1");
    $check->execute([$recipientId]);
    if (!$check->fetch()) {
        return false;
    }

    try {
        $stmt = $pdo->prepare("
            INSERT INTO notifications
                (recipient_user_id, sender_user_id, notification_type, title, message,
                 reference_type, reference_id, target_code, is_read, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, NOW())
        ");
        $stmt->execute([$recipientId, $senderId, $type, $title, $message, $refType, $refId, $targetCode]);
        return (int)$pdo->lastInsertId();
    } catch (Throwable $e) {
        error_log('[notification] insert failed: ' . $e->getMessage());
        return false;
    }
}

/* -------------------------------------------------------------------------
   FIND USER BY CODE (student_id / faculty_id / dept_id) AND ROLE
   Returns one user row or false.
   ------------------------------------------------------------------------- */
function find_user_by_code(PDO $pdo, string $code, array $allowedRoles) {
    $placeholders = implode(',', array_fill(0, count($allowedRoles), '?'));
    $sql = "SELECT id, username, first_name, last_name, role, student_id, email
            FROM users
            WHERE student_id = ? AND LOWER(role) IN ($placeholders)
            LIMIT 1";
    $params = array_merge([$code], array_map('strtolower', $allowedRoles));
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

/* -------------------------------------------------------------------------
   GRADE CALCULATION HELPERS (from old dashboard.php)
   Kept here so faculty encode + admin preview can share them.
   ------------------------------------------------------------------------- */
function compute_final_grade(float $attendance, float $quizzes, float $prelim, float $midterm, float $final): float {
    $final_score = ($attendance * 0.10) + ($quizzes * 0.20) + ($prelim * 0.20) + ($midterm * 0.25) + ($final * 0.25);

    // Grade-scale mode: every raw score is already on the 1.00–5.00 scale
    if ($attendance <= 5.0 && $quizzes <= 5.0 && $prelim <= 5.0 && $midterm <= 5.0 && $final <= 5.0) {
        return (float)$final_score;
    }

    if ($final_score >= 97) return 1.00;
    if ($final_score >= 94) return 1.25;
    if ($final_score >= 91) return 1.50;
    if ($final_score >= 88) return 1.75;
    if ($final_score >= 85) return 2.00;
    if ($final_score >= 82) return 2.25;
    if ($final_score >= 79) return 2.50;
    if ($final_score >= 76) return 2.75;
    if ($final_score >= 75) return 3.00;
    if ($final_score >= 70) return 4.00;
    return 5.00;
}

/* -------------------------------------------------------------------------
   CENTRALIZED FINANCIAL BALANCE
   -------------------------------------------------------------------------
   Every page that needs a student's balance calls this function.

   Rule (matches the existing StudentFLOW rule):
        balance = SUM(approved Charges) − SUM(approved Payments)

   - 'voided' rows are excluded.
   - If the workflow layer exists (status column), only 'approved' rows
     count. If it doesn't, the WHERE clause degrades to the original
     behaviour automatically.
   ------------------------------------------------------------------------- */
function calculateStudentBalance(PDO $pdo, int $studentUserId): array {
    $stmt = $pdo->prepare("
        SELECT
          COALESCE(SUM(CASE WHEN transaction_type='Charge'  THEN amount END), 0) AS c,
          COALESCE(SUM(CASE WHEN transaction_type='Payment' THEN amount END), 0) AS p
        FROM financial_ledgers
        WHERE student_id = ?
          AND voided = 0
          AND status  = 'approved'
    ");
    $stmt->execute([$studentUserId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $c = (float)($row['c'] ?? 0);
    $p = (float)($row['p'] ?? 0);
    return ['charges' => $c, 'payments' => $p, 'balance' => $c - $p];
}

/* Helper: get financial_ledgers columns present on this install. */
function ledger_has_workflow_columns(PDO $pdo): bool {
    static $has = null;
    if ($has !== null) return $has;
    try {
        $cols = $pdo->query("SHOW COLUMNS FROM financial_ledgers")->fetchAll(PDO::FETCH_COLUMN) ?: [];
        $has = in_array('status', $cols, true)
            && in_array('finance_id', $cols, true)
            && in_array('submitted_at', $cols, true);
    } catch (Throwable $e) {
        $has = false;
    }
    return $has;
}