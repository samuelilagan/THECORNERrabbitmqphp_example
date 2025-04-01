<?php
require_once('/path/to/vendor/autoload.php'); // Adjust if using Composer

use PhpAmqpLib\Connection\AMQPStreamConnection;

// ACE'S IP?
$connection = new AMQPStreamConnection('REPLACE_WITH_RABBITMQ_IP', 5672, 'guest', 'guest');
$channel = $connection->channel();
$channel->queue_declare('logQueue', false, true, false, false);

echo "Listening for logs...\n";

$callback = function ($msg) {
    $log = $msg->body;

    // Save to log file
    file_put_contents("/var/log/distributed.log", $log . PHP_EOL, FILE_APPEND);
};

$channel->basic_consume('logQueue', '', false, true, false, false, $callback);

// Keep the script running
while ($channel->is_consuming()) {
    $channel->wait();
}
