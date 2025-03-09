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

    // Print the request data received
    echo "Received login request: ";
    var_dump(['username' => $username, 'password' => $password]);

    // Check if session token already exists in the session
    if (isset($_SESSION['sessionToken']) && $_SESSION['sessionToken'] != "") {
        // User is already logged in, no need to create a new token
        return [
            "status" => "success",
            "message" => "Already logged in",
            "sessionToken" => $_SESSION['sessionToken']
        ];
    }

    // User is not logged in, proceed with normal login
    $query = "SELECT * FROM user_info WHERE username = :username";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':username', $username);
    $stmt->execute();
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user && password_verify($password, $user['password'])) {
        // Generate a new session token
        $sessionToken = generateSessionToken();
        $_SESSION['sessionToken'] = $sessionToken; // Store session token in session
        
        // Optionally update the session token in the database
        $expiry = time() + (60 * 60); // expiration is 1 hour, can change based on needs
        $updateQuery = "UPDATE user_info SET session_token = :sessionToken, token_expiry = :expiry WHERE username = :username";
        $updateStmt = $db->prepare($updateQuery);
        $updateStmt->bindParam(':sessionToken', $sessionToken);
        $updateStmt->bindParam(':expiry', $expiry);
        $updateStmt->bindParam(':username', $username);
        $updateStmt->execute();

        return [
            "status" => "success",
            "message" => "Login successful",
            "sessionToken" => $sessionToken
        ];
    } else {
        return [
            "status" => "error",
            "message" => "Login failed"
        ];
    }
}

// Function to handle logout
function doLogout($sessionToken) {
    global $db;

    // Print the request data received
    echo "Received logout request: ";
    var_dump(['sessionToken' => $sessionToken]);

    // Clear the session token from the session
    unset($_SESSION['sessionToken']); // Remove from session storage

    // Optionally update the session token in the database to NULL
    $updateQuery = "UPDATE user_info SET session_token = NULL, token_expiry = NULL WHERE session_token = :sessionToken";
    $updateStmt = $db->prepare($updateQuery);
    $updateStmt->bindParam(':sessionToken', $sessionToken);
    $updateStmt->execute();

    return [
        "status" => "success",
        "message" => "Logout successful"
    ];
}

// Function to handle registration
function doRegister($username, $password) {
    global $db;

    // Print the request data received
    echo "Received registration request: ";
    var_dump(['username' => $username, 'password' => $password]);

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

// Function to handle filtering
function doFilter($city, $keyword, $rating) {
    global $db;

    try{
        // Print the request data received
        echo "Received filter request: ";
        var_dump(['city' => $city, 'keyword' => $keyword, 'rating' => $rating]);

        $intrating = intval($rating);
        $regexcity = '%'.$city.'%';
        $regexkeyword = '%'.$keyword.'%';

        // Query the review DB
        $query = "SELECT * FROM reviews WHERE reviewRating >= :rating AND placeName LIKE :keyword AND placeAddress LIKE :city";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':city', $regexcity);
        $stmt->bindParam(':keyword', $regexkeyword);
        $stmt->bindParam(':rating', $intrating);
        $stmt->execute();

        return [
            "status" => "success",
            "reviews" => $reviews
        ];
    }
    catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to fetch ratings and reviews: " . $e->getMessage()
        ];
    }

}

?>
