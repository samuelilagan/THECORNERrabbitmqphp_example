<?php
require_once(__DIR__ . '/vendor/autoload.php');

use PhpAmqpLib\Connection\AMQPStreamConnection;

// ACE'S IP under localhost
$connection = new AMQPStreamConnection('localhost', 5672, 'guest', 'guest');
$channel = $connection->channel();
$channel->queue_declare('logQueue', false, true, false, false);

echo "Listening for logs...\n";

$callback = function ($msg) {
    $log = $msg->body;

    // Save to log file
    file_put_contents("/var/log/distributed.log", $log . PHP_EOL, FILE_APPEND);
};

$channel->basic_consume('logQueue', '', false, true, false, false, $callback);

while (true) {
    $channel->wait();
}