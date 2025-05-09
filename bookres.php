<?php
require_once('/home/samilagan/git/rabbitmqphp_example/path.inc');
require_once('/home/samilagan/git/rabbitmqphp_example/get_host_info.inc');
require_once('/home/samilagan/git/rabbitmqphp_example/rabbitMQLib.inc');

// Clear any previous output
ob_clean();

// Set proper headers before any output
header('Content-Type: application/json');

// Handle CORS if needed
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

try {
    // Get raw POST data
    $input = file_get_contents('php://input');
    if (empty($input)) {
        throw new Exception("No input data received");
    }

    // Decode JSON input
    $data = json_decode($input, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("Invalid JSON input");
    }

    // Validate request type
    if (!isset($data['type'])) {
        throw new Exception("Missing request type");
    }

    // Add username if logged in
    session_start();
    if (isset($_SESSION['username'])) {
        $data['username'] = $_SESSION['username'];
    }

    // Initialize RabbitMQ client
    $client = new rabbitMQClient('/home/samilagan/git/rabbitmqphp_example/localRabbitMQ.ini', 'testServer');
    
    // Send request and get response
    $response = $client->send_request($data);
    
    // Ensure response is properly formatted
    if (!is_array($response)) {
        throw new Exception("Invalid response format from RabbitMQ");
    }

    // Output clean JSON
    echo json_encode($response);
    exit();

} catch (Exception $e) {
    // Output clean error JSON
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
    exit();
}
?>