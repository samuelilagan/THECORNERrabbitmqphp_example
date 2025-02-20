#!/usr/bin/php
<?php
require_once('path.inc');
require_once('get_host_info.inc');
require_once('rabbitMQLib.inc');

// Database connection settings
$dsn = 'mysql:host=127.0.0.1;dbname=users';
$dbUser = 'testUser';
$dbPassword = '12345';

try {
    $db = new PDO($dsn, $dbUser, $dbPassword);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo "Database connection failed: " . $e->getMessage();
    exit(0);
}

// Function to generate random session token
function generateSessionToken($length = 32) {
    return bin2hex(random_bytes($length / 2));
}

// Function to handle login
function doLogin($username, $password) {
    global $db;

    // Check if user exists
    $query = "SELECT * FROM user_info WHERE username = :username";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':username', $username);
    $stmt->execute();
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    // If user exists and password is correct
    if ($user && password_verify($password, $user['password'])) {
        // Check if user already has a valid session token
        if ($user['session_token'] && strtotime($user['token_expiry']) > time()) {
            // Return existing session token if already logged in
            return ["status" => "success", "message" => "Already logged in", "sessionToken" => $user['session_token']];
        }

        // Generate a new session token and set expiry time
        $sessionToken = generateSessionToken();
        $expiry = date('Y-m-d H:i:s', strtotime('+1 hour')); // TTL: 1 hour

        // Update session token and expiry in the database
        $updateQuery = "UPDATE user_info SET session_token = :sessionToken, token_expiry = :expiry WHERE username = :username";
        $updateStmt = $db->prepare($updateQuery);
        $updateStmt->bindParam(':sessionToken', $sessionToken);
        $updateStmt->bindParam(':expiry', $expiry);
        $updateStmt->bindParam(':username', $username);
        $updateStmt->execute();

        // Return success with session token
        return ["status" => "success", "message" => "Login successful", "sessionToken" => $sessionToken];
    } else {
        return ["status" => "error", "message" => "Login failed"];
    }
}

// Function to handle logout
function doLogout($sessionToken) {
    global $db;

    // Remove the session token from the database
    $updateQuery = "UPDATE user_info SET session_token = NULL, token_expiry = NULL WHERE session_token = :sessionToken";
    $updateStmt = $db->prepare($updateQuery);
    $updateStmt->bindParam(':sessionToken', $sessionToken);
    $updateStmt->execute();

    // Return success message
    return ["status" => "success", "message" => "Logout successful"];
}

// Function to validate session token
function validateSessionToken($sessionToken) {
    global $db;

    // Fetch the session token details from the database
    $query = "SELECT * FROM user_info WHERE session_token = :sessionToken";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':sessionToken', $sessionToken);
    $stmt->execute();
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        // Check if the session token is expired
        if (strtotime($user['token_expiry']) < time()) {
            return ["status" => "error", "message" => "Session expired"];
        }
        return ["status" => "success", "message" => "Session valid", "username" => $user['username']];
    } else {
        return ["status" => "error", "message" => "Invalid session token"];
    }
}

// Function to clean up expired sessions from the database
function cleanupExpiredSessions() {
    global $db;

    // Delete sessions that have expired
    $query = "DELETE FROM user_info WHERE token_expiry < NOW()";
    $stmt = $db->prepare($query);
    $stmt->execute();
}

// Function to handle registration
function doRegister($username, $password) {
    global $db;

    // Check if user already exists
    $query = "SELECT * FROM user_info WHERE username = :username";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':username', $username);
    $stmt->execute();
    $existingUser = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existingUser) {
        return ["status" => "error", "message" => "User already exists"];
    }

    // Hash the password before storing it in the database
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

    // Insert new user into the database
    $insertQuery = "INSERT INTO user_info (username, password) VALUES (:username, :password)";
    $insertStmt = $db->prepare($insertQuery);
    $insertStmt->bindParam(':username', $username);
    $insertStmt->bindParam(':password', $hashedPassword);

    try {
        $insertStmt->execute();
        return ["status" => "success", "message" => "Registration successful"];
    } catch (PDOException $e) {
        return ["status" => "error", "message" => "Registration failed: " . $e->getMessage()];
    }
}

// Function to process incoming requests
function requestProcessor($request) {
    echo "Received request" . PHP_EOL;
    var_dump($request);

    if (!isset($request['type'])) {
        return ["status" => "error", "message" => "Unsupported message type"];
    }

    switch ($request['type']) {
        case "login":
            return doLogin($request['username'], $request['password']);
        case "logout":
            return doLogout($request['sessionToken']);
        case "validate_session":
            return validateSessionToken($request['sessionToken']);
        case "register":
            return doRegister($request['username'], $request['password']);
        default:
            return ["status" => "error", "message" => "Invalid request type"];
    }
}

// Start the RabbitMQ server for database processing
$server = new rabbitMQServer("localRabbitMQ.ini", "testServer");
$server->process_requests('requestProcessor');
exit();
?>
