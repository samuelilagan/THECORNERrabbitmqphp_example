#!/usr/bin/php
<?php
require_once('path.inc');
require_once('get_host_info.inc');
require_once('rabbitMQLib.inc');
require_once('mysqlconnect.php');  // Include mysqlconnect.php for database operations

// Function to process the request (login, logout, etc.)
function requestProcessor($request)
{
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
        case "register":
            return doRegister($request['username'], $request['password']);
        case "fetch_user_info":
            return fetchUserInfo();
        
        case "submit_rating_review":
            return submitRatingReview($request['user_id'], $request['table_id'], $request['rating'], $request['review']);
        case "fetch_ratings_reviews":
            return fetchRatingsReviews($request['table_id']);

        default:
            return ["status" => "error", "message" => "Invalid request type"];
    }
}

// Start the RabbitMQ server to process requests
$server = new rabbitMQServer("localRabbitMQ.ini", "testServer");
$server->process_requests('requestProcessor');
exit();
?>