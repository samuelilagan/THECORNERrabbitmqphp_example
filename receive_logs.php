<?php
require_once __DIR__ . '/vendor/autoload.php';

use PhpAmqpLib\Connection\AMQPStreamConnection;

$rabbitmq_host = '172.28.80.118';  // backend node IP
$log_file = '/var/log/cluster_error.log';
$vhost = 'testHost';


$connection = new AMQPStreamConnection($rabbitmq_host, 5672, 'test', 'test', $vhost);
$channel = $connection->channel();

$channel->exchange_declare('cluster_logs', 'fanout', false, false, false);

// Create a uniquely-named queue that auto-deletes
list($queue_name, ,) = $channel->queue_declare('', false, false, true, false);
$channel->queue_bind($queue_name, 'cluster_logs');

// Message handler
$callback = function($msg) use ($log_file) {
    $data = json_decode($msg->body, true);
    $log = sprintf(
        "[%s] %s (%s): %s - %s\n",
        date('Y-m-d H:i:s'),
        $data['node'] ?? 'UNKNOWN',
        $data['ip'] ?? 'UNKNOWN',
        $data['type'] ?? 'UNKNOWN',
        $data['details'] ?? 'No details'
    );
    file_put_contents($log_file, $log, FILE_APPEND);
    echo " [x] Logged: $log";
};

echo " [*] Waiting for error logs. To exit press CTRL+C\n";
$channel->basic_consume($queue_name, '', false, true, false, false, $callback);

// Run the listener loop
while ($channel->is_consuming()) {
    $channel->wait();
}

