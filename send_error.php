<?php
require_once __DIR__ . '/vendor/autoload.php';

use PhpAmqpLib\Connection\AMQPStreamConnection;
use PhpAmqpLib\Message\AMQPMessage;

// RabbitMQ server (backend node IP)
$rabbitmq_host = '172.28.80.118';  // replace with backend IP

$connection = new AMQPStreamConnection($rabbitmq_host, 5672, 'guest', 'guest');
$channel = $connection->channel();

// Declare a fanout exchange
$channel->exchange_declare('cluster_logs', 'fanout', false, false, false);

// Create a JSON message
$hostname = gethostname();
$ip = gethostbyname($hostname);
$messageBody = json_encode([
    'node' => $hostname,
    'ip' => $ip,
    'type' => 'SERVICE_DOWN',
    'details' => 'Apache failed to start'
]);

$msg = new AMQPMessage($messageBody);
$channel->basic_publish($msg, 'cluster_logs');

echo " [x] Sent error log\n";

$channel->close();
$connection->close();

