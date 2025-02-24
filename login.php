<?php
// Debugging: Output the incoming POST request data
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Read the raw POST data (useful for JSON requests)
$input = json_decode(file_get_contents('php://input'), true);

// Check if the type of the request is set (login, register, logout, validate_session)
if (!isset($input['type'])) {
    echo json_encode(["status" => "error", "message" => "Missing request type"]);
    exit(0);
}

$type = $input['type'];

// Include RabbitMQ PHP client files
echo "current user: ".get_current_user();
echo "script was executed under user: ".exec('whoami');
require_once('/home/dfc27vm/git/rabbitmqphp_example/path.inc');
require_once('/home/dfc27vm/git/rabbitmqphp_example/get_host_info.inc');
require_once('/home/dfc27vm/git/rabbitmqphp_example/rabbitMQLib.inc');

// Handle the different request types
switch ($type) {
    case "login":
        // Handle login request
        if (!isset($input['username']) || !isset($input['password'])) {
            echo json_encode(["status" => "error", "message" => "Missing username or password"]);
            exit(0);
        }

        $username = $input['username'];
        $password = $input['password'];

        // Create the message to send to RabbitMQ for login
        $msg = [
            "type" => "login",
            "username" => $username,
            "password" => $password
        ];

        // Connect to RabbitMQ server
        $client = new rabbitMQClient('/home/dfc27vm/git/rabbitmqphp_example/rabbitmq-server/localRabbitMQ.ini', 'testServer');
        // Send the request to RabbitMQ and get the response
        $response = $client->send_request($msg);

        // Log the raw response for debugging
        error_log("Raw Response from RabbitMQ: " . print_r($response, true));

        // Handle the response from RabbitMQ
        if (is_string($response)) {
            $response = json_decode($response, true);  // Decode the JSON response
        }

        if ($response && isset($response['status']) && $response['status'] == "success") {
            // If login is successful, set session cookie with the session token
            setcookie("sessionToken", $response['sessionToken'], time() + 3600, "/"); // Expires in 1 hour
            echo json_encode(["status" => "success", "message" => "Login successful", "sessionToken" => $response['sessionToken']]);
        } else {
            echo json_encode(["status" => "error", "message" => "Login failed"]);
        }
        break;

    case "register":
        // Handle registration request
        if (!isset($input['username']) || !isset($input['password'])) {
            echo json_encode(["status" => "error", "message" => "Missing username or password"]);
            exit(0);
        }

        $username = $input['username'];
        $password = $input['password'];

        // Create the message to send to RabbitMQ for registration
        $msg = [
            "type" => "register",
            "username" => $username,
            "password" => $password
        ];

        // Connect to RabbitMQ server
        $client = new rabbitMQClient('/home/dfc27vm/git/rabbitmqphp_example/rabbitmq-server/localRabbitMQ.ini', 'testServer');

        // Send the request to RabbitMQ and get the response
        $response = $client->send_request($msg);

        // Log the raw response for debugging
        error_log("Raw Response from RabbitMQ: " . print_r($response, true));

        // Handle the response from RabbitMQ
        if (is_string($response)) {
            $response = json_decode($response, true);  // Decode the JSON response
        }

        if ($response && isset($response['status']) && $response['status'] == "success") {
            echo json_encode(["status" => "success", "message" => "Registration successful"]);
        } else {
            echo json_encode(["status" => "error", "message" => "Registration failed"]);
        }
        break;

    case "logout":
        // Handle logout request
case "logout":
    if (isset($input['sessionToken'])) {
        // Send the logout request to RabbitMQ to clean the session token from the database
        $msg = [
            "type" => "logout",
            "sessionToken" => $input['sessionToken']
        ];

        // Connect to RabbitMQ server
        $client = new rabbitMQClient('/home/dfc27vm/git/rabbitmqphp_example/rabbitmq-server/localRabbitMQ.ini', 'testServer');

        // Send the request to RabbitMQ and get the response
        $response = $client->send_request($msg);

        // Check the response
        if ($response['status'] === 'success') {
            // Clear session token on the client side
            setcookie("sessionToken", "", time() - 3600, "/"); // Delete the session token cookie
            echo json_encode(["status" => "success", "message" => "Logout successful"]);
        } else {
            echo json_encode(["status" => "error", "message" => "Logout failed"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "Session token required"]);
    }
    break;

    case "validate_session":
        // Handle session validation
        if (isset($_COOKIE['sessionToken'])) {
            $sessionToken = $_COOKIE['sessionToken'];

            // Create the message to send to RabbitMQ for session validation
            $msg = [
                "type" => "validate_session",
                "sessionToken" => $sessionToken
            ];

            // Connect to RabbitMQ server
            $client = new rabbitMQClient('/home/dfc27vm/git/rabbitmqphp_example/rabbitmq-server/localRabbitMQ.ini', 'testServer');

            // Send the request to RabbitMQ and get the response
            $response = $client->send_request($msg);

            // Handle the response from RabbitMQ
            if ($response && isset($response['status']) && $response['status'] == "success") {
                echo json_encode(["status" => "success", "message" => "Valid session", "sessionToken" => $sessionToken]);
            } else {
                echo json_encode(["status" => "error", "message" => "Session expired or invalid"]);
            }
        } else {
            echo json_encode(["status" => "error", "message" => "No active session"]);
        }
        break;

    default:
        echo json_encode(["status" => "error", "message" => "Invalid request type"]);
        break;
}

exit(0);

/*
<?php


if (!isset($_POST))
{
	$msg = "NO POST MESSAGE SET, POLITELY FUCK OFF";
	echo json_encode($msg);
	exit(0);
}
$request = $_POST;
$response = "unsupported request type, politely FUCK OFF";
switch ($request["type"])
{
	case "login":
		$response = "login, yeah we can do that.";
	break;
}
echo json_encode($response);
exit(0);

?>
*/
