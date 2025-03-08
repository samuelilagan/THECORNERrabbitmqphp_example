<?php
// Include RabbitMQ PHP client files
require_once('/home/samilagan/git/rabbitmqphp_example/path.inc');
require_once('/home/samilagan/git/rabbitmqphp_example/get_host_info.inc');
require_once('/home/samilagan/git/rabbitmqphp_example/rabbitMQLib.inc');
// error_reporting(E_ALL);
// ini_set('display_errors', 1);

session_start();

function sendRequest($request) {
    $client = new rabbitMQClient('/home/samilagan/git/rabbitmqphp_example/localRabbitMQ.ini', 'testServer');
    try {
        $response = $client->send_request($request);

        // Log the raw response for debugging
        error_log("Raw Response: " . print_r($response, true));

        // Ensure the response is valid JSON
        if (json_last_error() !== JSON_ERROR_NONE) {
            return ["status" => "error", "message" => "Invalid JSON response from RabbitMQ"];
        }

        return $response;
    } catch (Exception $e) {
        return ["status" => "error", "message" => "Request failed: " . $e->getMessage()];
    }
}

// Handle incoming requests
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);

    if (!isset($data['type'])) {
        echo json_encode(["status" => "error", "message" => "Invalid request"]);
        exit();
    }

    switch ($data['type']) {
        case 'login':
            if (!isset($data['username']) || !isset($data['password'])) {
                echo json_encode(["status" => "error", "message" => "Missing username or password"]);
                exit();
            }

            // Ensure the user is not already logged in
            if (isset($_SESSION['sessionToken'])) {
                echo json_encode(["status" => "error", "message" => "Already logged in"]);
                exit();
            }

            $request = [
                "type" => "login",
                "username" => $data['username'],
                "password" => $data['password']
            ];
            $response = sendRequest($request);

            if ($response['status'] === "success") {
                $_SESSION['sessionToken'] = $response['sessionToken'];
                echo json_encode([
                    "status" => "success",
                    "sessionToken" => $response['sessionToken'],
                    "username" => $response['username'], // Forward the username
                    "redirect" => "home.html"  // Indicate the redirect target
                ]);
                exit();
            }

            echo json_encode($response);
            break;

        case 'logout':
            if (!isset($_SESSION['sessionToken'])) {
                echo json_encode(["status" => "error", "message" => "No active session"]);
                exit();
            }

            $request = [
                "type" => "logout",
                "sessionToken" => $_SESSION['sessionToken']
            ];
            $response = sendRequest($request);

            if ($response['status'] === "success") {
                session_unset();
                session_destroy();
            }

            echo json_encode($response);
            break;

        case 'register':
            if (!isset($data['username']) || !isset($data['password'])) {
                echo json_encode(["status" => "error", "message" => "Missing username or password"]);
                exit();
            }

            $request = [
                "type" => "register",
                "username" => $data['username'],
                "password" => $data['password']
            ];
            $response = sendRequest($request);

            echo json_encode($response);
            break;
        
        case 'fetch_user_info':
            $request = [
                "type" => "fetch_user_info"
            ];
            $response = sendRequest($request);
            echo json_encode($response);
            break;
        
        case 'submit_rating_review':
            if (!isset($data['user_id']) || !isset($data['table_id']) || !isset($data['rating']) || !isset($data['review'])) {
                echo json_encode(["status" => "error", "message" => "Missing required fields for rating and review"]);
                exit();
            }

            // Log the request data
            error_log("Submit rating review request: " . print_r($data, true));

            $request = [
                "type" => "submit_rating_review",
                "user_id" => $data['user_id'],
                "table_id" => $data['table_id'],
                "rating" => $data['rating'],
                "review" => $data['review']
            ];
            $response = sendRequest($request);
            echo json_encode($response);
            break;

        case 'fetch_ratings_reviews':
            if (!isset($data['table_id'])) {
                echo json_encode(["status" => "error", "message" => "Missing table_id for fetching ratings and reviews"]);
                exit();
            }

            $request = [
                "type" => "fetch_ratings_reviews",
                "table_id" => $data['table_id']
            ];
            $response = sendRequest($request);
            echo json_encode($response);
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid request type"]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Invalid request method"]);
}
?>