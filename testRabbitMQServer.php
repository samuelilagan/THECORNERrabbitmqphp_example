#!/usr/bin/php
<?php
require_once('path.inc');
require_once('get_host_info.inc');
require_once('rabbitMQLib.inc');

// Function to process the incoming requests from RabbitMQ
function requestProcessor($request)
{
    echo "Received request: ".PHP_EOL;
    var_dump($request); // Log the request for debugging purposes

    if (!isset($request['type'])) {
        return ["status" => "error", "message" => "Unsupported message type"];
    }

    // Create a new RabbitMQ client to forward the request to the database processor
    $client = new rabbitMQClient("localRabbitMQ.ini", "testServer");

    // Forward the request to the database processor
    $response = $client->send_request($request);

    // Return the response from the database processor back to the client
    return $response;
}

// Create and start the RabbitMQ server to listen for incoming requests
$server = new rabbitMQServer("localRabbitMQ.ini", "testServer");
$server->process_requests('requestProcessor');
exit();
?>
