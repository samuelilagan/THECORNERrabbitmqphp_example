<?php
// Include RabbitMQ PHP client files
require_once('path.inc');
require_once('get_host_info.inc');
require_once('rabbitMQLib.inc');


//NEED TO FIGURE OUT HOW TO SEND A SQL COMMAND THRU RABBIT MQ BASED ON FORM DATA


function sendRequest($request) {
    $client = new rabbitMQClient('testRabbitMQ.ini', 'testServer');
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

        case 'filter':
            if (!isset($data['city']) || !isset($data['keyword']) || !isset($data['rating'])) {
                echo json_encode(["status" => "error", "message" => "Missing filter information"]);
                exit();
            }

        $request = [
            "type" => "filter",
            "city" => $data['city'],
            "keyword" => $data['keyword'],
            "rating" => $data['rating']
        ];
        $response = sendRequest($request);

        if ($response['status'] === "success") {
            echo json_encode([
                "status" => "success"
            ]);
            exit();
        }

        echo json_encode($response);
        break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid request type"]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Invalid request method"]);
}
?>
