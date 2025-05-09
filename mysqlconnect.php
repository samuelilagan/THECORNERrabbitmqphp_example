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
            "sessionToken" => $_SESSION['sessionToken'],
            "username" => $_SESSION['username'] // Return the username
        ];
    }

    // User is not logged in, proceed with normal login
    $query = "SELECT * FROM user_info WHERE username = :username";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':username', $username);
    $stmt->execute();
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    // Debug: Print the user data fetched from the database
    echo "User data from database: ";
    var_dump($user);

    if ($user && password_verify($password, $user['password'])) {
        // Generate a new session token
        $sessionToken = generateSessionToken();
        $_SESSION['sessionToken'] = $sessionToken; // Store session token in session
        $_SESSION['username'] = $username; // Store username in session

        // Optionally update the session token in the database
        $expiry = date('Y-m-d H:i:s', strtotime('+1 hour'));
        $updateQuery = "UPDATE user_info SET session_token = :sessionToken, token_expiry = :expiry WHERE username = :username";
        $updateStmt = $db->prepare($updateQuery);
        $updateStmt->bindParam(':sessionToken', $sessionToken);
        $updateStmt->bindParam(':expiry', $expiry);
        $updateStmt->bindParam(':username', $username);
        $updateStmt->execute();

        return [
            "status" => "success",
            "message" => "Login successful",
            "sessionToken" => $sessionToken,
            "username" => $username // Return the username
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
function doRegister($username, $password, $phone) {
    global $db;

    // PHONE VALIDATION
    if (empty($phone)) {
        return ["status" => "error", "message" => "Phone number is required"];
    }

    // Check if user exists
    $query = "SELECT * FROM user_info WHERE username = :username";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':username', $username);
    $stmt->execute();
    $existingUser = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existingUser) {
        return ["status" => "error", "message" => "User already exists"];
    }

    // Hash password
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

    // Insert with PHONE
    $insertQuery = "INSERT INTO user_info (username, password, phone) VALUES (:username, :password, :phone)";
    $insertStmt = $db->prepare($insertQuery);
    $insertStmt->bindParam(':username', $username);
    $insertStmt->bindParam(':password', $hashedPassword);
    $insertStmt->bindParam(':phone', $phone);

    try {
        $insertStmt->execute();
        return ["status" => "success", "message" => "Registration successful"];
    } catch (PDOException $e) {
        error_log("Database error: " . $e->getMessage());
        return ["status" => "error", "message" => "Registration failed: " . $e->getMessage()];
    }
}

// Function to fetch all reviews
function fetchAllReviews() {
    global $db;

    try {
        // Fetch all reviews from the reviews table
        $query = "SELECT * FROM reviews";
        $stmt = $db->prepare($query);
        $stmt->execute();
        $reviews = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            "status" => "success",
            "reviews" => $reviews
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to fetch reviews: " . $e->getMessage()
        ];
    }
}

// Function to submit a rating and review
function submitRatingReview($username, $placeName, $rating, $review) {
    global $db;

    // Validate rating
    if ($rating < 1 || $rating > 5) {
        return ["status" => "error", "message" => "Rating must be between 1 and 5"];
    }

    try {
        // Insert the rating and review into the ratings_reviews table
        $query = "INSERT INTO ratings_reviews (username, placeName, rating, review) VALUES (:username, :placeName, :rating, :review)";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':username', $username);
        $stmt->bindParam(':placeName', $placeName);
        $stmt->bindParam(':rating', $rating);
        $stmt->bindParam(':review', $review);
        $stmt->execute();

        return [
            "status" => "success",
            "message" => "Rating and review submitted successfully"
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to submit rating and review: " . $e->getMessage()
        ];
    }
}

// Function to fetch ratings and reviews for a specific table
function fetchRatingsReviews($placeName) {
    global $db;

    try {
        // Fetch ratings and reviews for the specified placeName
        $query = "SELECT r.rating, r.review, r.created_at, u.username 
                  FROM ratings_reviews r 
                  JOIN user_info u ON r.username = u.username 
                  WHERE r.placeName = :placeName 
                  ORDER BY r.created_at DESC";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':placeName', $placeName);
        $stmt->execute();
        $reviews = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            "status" => "success",
            "reviews" => $reviews
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to fetch ratings and reviews: " . $e->getMessage()
        ];
    }
}

// Function to filter tables by restaurant
function fetchReviewsByRestaurant($placeName) {
    global $db;

    try {
        // Fetch reviews for the specified placeName
        $query = "SELECT * FROM reviews WHERE placeName = :placeName";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':placeName', $placeName);
        $stmt->execute();
        $reviews = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            "status" => "success",
            "tables" => $reviews // Ensure this matches the key used in the JavaScript
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to filter reviews: " . $e->getMessage()
        ];
    }
}

// Function for filter method
// Function to handle filtering
function doFilter($city, $keyword, $rating, $dietary, $cuisine) {
    global $db;
 
 
    try {
        // Initialize base query
        $query = "
            SELECT DISTINCT r.*
            FROM reviews r
            LEFT JOIN restaurant_dietary rd ON r.id = rd.restaurant_id
            LEFT JOIN dietary_options d ON rd.dietary_id = d.id
            LEFT JOIN restaurant_cuisine rc ON r.id = rc.restaurant_id
            LEFT JOIN cuisines c ON rc.cuisine_id = c.id
            WHERE 1=1
        ";
 
 
        // Initialize parameters array
        $params = [];
 
 
        // Add city filter if provided
        if (!empty($city)) {
            $query .= " AND r.placeAddress LIKE :city";
            $params[':city'] = '%' . $city . '%';
        }
 
 
        // Add keyword filter if provided
        if (!empty($keyword)) {
            $query .= " AND r.placeName LIKE :keyword";
            $params[':keyword'] = '%' . $keyword . '%';
        }
 
 
        // Add rating filter if provided
        if (!empty($rating)) {
            $query .= " AND r.reviewRating = :rating";
            $params[':rating'] = intval($rating);
        }
 
 
        // Add dietary filter if provided
        if (!empty($dietary)) {
            $query .= " AND d.option_name = :dietary";
            $params[':dietary'] = $dietary;
        }
 
 
        // Add cuisine filter if provided
        if (!empty($cuisine)) {
            $query .= " AND c.cuisine_name = :cuisine";
            $params[':cuisine'] = $cuisine;
        }
 
 
        // Prepare and execute the query
        $stmt = $db->prepare($query);
        foreach ($params as $key => $value) {
            $stmt->bindValue($key, $value);
        }
 
 
        $stmt->execute();
        $reviews = $stmt->fetchAll(PDO::FETCH_ASSOC);
 
 
        return [
            "status" => "success",
            "reviews" => $reviews
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to fetch filtered reviews: " . $e->getMessage()
        ];
    }
 }
 
 // Functions for bookres.php
 // Function to book a reservation
function bookReservation($restaurant, $date, $time, $username = null) {
    global $db;

    try {
        // Check if the time slot is available
        $checkQuery = "SELECT * FROM reservations 
                      WHERE restaurant = :restaurant 
                      AND date = :date 
                      AND time = :time";
        $checkStmt = $db->prepare($checkQuery);
        $checkStmt->bindParam(':restaurant', $restaurant);
        $checkStmt->bindParam(':date', $date);
        $checkStmt->bindParam(':time', $time);
        $checkStmt->execute();

        if ($checkStmt->rowCount() > 0) {
            return ["status" => "error", "message" => "This time slot is already booked"];
        }

        // Insert the new reservation
        $insertQuery = "INSERT INTO reservations (restaurant, date, time, username) 
                       VALUES (:restaurant, :date, :time, :username)";
        $insertStmt = $db->prepare($insertQuery);
        $insertStmt->bindParam(':restaurant', $restaurant);
        $insertStmt->bindParam(':date', $date);
        $insertStmt->bindParam(':time', $time);
        $insertStmt->bindParam(':username', $username);
        $insertStmt->execute();

        return [
            "status" => "success",
            "message" => "Reservation booked successfully",
            "reservation_id" => $db->lastInsertId()
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to book reservation: " . $e->getMessage()
        ];
    }
}

// Function to get user's reservations
function getReservations($username = null) {
    global $db;

    try {
        if ($username) {
            // Get reservations for specific user
            $query = "SELECT * FROM reservations 
                     WHERE username = :username 
                     ORDER BY date, time";
            $stmt = $db->prepare($query);
            $stmt->bindParam(':username', $username);
        } else {
            // Get all reservations (for admin view if needed)
            $query = "SELECT * FROM reservations ORDER BY date, time";
            $stmt = $db->prepare($query);
        }
        
        $stmt->execute();
        $reservations = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            "status" => "success",
            "reservations" => $reservations
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to fetch reservations: " . $e->getMessage()
        ];
    }
}

// Function to cancel a reservation
function cancelReservation($reservationId, $username = null) {
    global $db;

    try {
        // Check if reservation exists and belongs to user (if username provided)
        $checkQuery = "SELECT * FROM reservations 
                      WHERE id = :id" . 
                      ($username ? " AND username = :username" : "");
        $checkStmt = $db->prepare($checkQuery);
        $checkStmt->bindParam(':id', $reservationId);
        if ($username) {
            $checkStmt->bindParam(':username', $username);
        }
        $checkStmt->execute();

        if ($checkStmt->rowCount() === 0) {
            return ["status" => "error", "message" => "Reservation not found or not authorized"];
        }

        // Delete the reservation
        $deleteQuery = "DELETE FROM reservations WHERE id = :id";
        $deleteStmt = $db->prepare($deleteQuery);
        $deleteStmt->bindParam(':id', $reservationId);
        $deleteStmt->execute();

        return [
            "status" => "success",
            "message" => "Reservation canceled successfully"
        ];
    } catch (PDOException $e) {
        return [
            "status" => "error",
            "message" => "Failed to cancel reservation: " . $e->getMessage()
        ];
    }
}

?>