<?php
header('Content-Type: application/json');

// Database Connection
$conn = new mysqli("localhost", "root", "", "student_portal_db");

if ($conn->connect_error) {
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed.'
    ]);
    exit();
}

// Read student_id from GET query parameter
$student_id = trim($_GET['student_id'] ?? '');

if (empty($student_id)) {
    echo json_encode([
        'success' => false,
        'message' => 'Student ID is required.'
    ]);
    exit();
}

// 1. Check if Student ID exists in the Admin Master List
$stmt = $conn->prepare("SELECT first_name, last_name, department, course, status FROM student_masterlist WHERE student_id = ?");
$stmt->bind_param("s", $student_id);
$stmt->execute();
$res = $stmt->get_result();

if ($res->num_rows === 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Student ID not found in Master List. Please contact Admin.'
    ]);
    $stmt->close();
    $conn->close();
    exit();
}

$master_data = $res->fetch_assoc();
$stmt->close();

// 2. Check if Student ID has already registered an active account in users table
$user_stmt = $conn->prepare("SELECT id FROM users WHERE student_id = ?");
$user_stmt->bind_param("s", $student_id);
$user_stmt->execute();
$user_res = $user_stmt->get_result();

if ($user_res->num_rows > 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Student ID Number (' . htmlspecialchars($student_id) . ') already has an active portal account.'
    ]);
    $user_stmt->close();
    $conn->close();
    exit();
}

$user_stmt->close();

// 3. Return verified status, name, department, and course details
echo json_encode([
    'success' => true,
    'message' => 'Student ID verified in Master List.',
    'data' => [
        'first_name' => $master_data['first_name'],
        'last_name'  => $master_data['last_name'],
        'department' => $master_data['department'],
        'course'     => $master_data['course'],
        'status'     => $master_data['status']
    ]
]);

$conn->close();
?>