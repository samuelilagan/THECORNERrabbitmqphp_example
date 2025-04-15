<?php
require __DIR__ . '/../vendor/autoload.php';

use PhpAmqpLib\Connection\AMQPStreamConnection;
use PhpAmqpLib\Message\AMQPMessage;

$connection = new AMQPStreamConnection('localhost', 5672, 'ace_p', 'goat', 'testHost');
$channel = $connection->channel();

// Declare both queues
$channel->queue_declare('incoming_tar_msg', false, true, false, false);
$channel->queue_declare('sent_tar_msg', false, true, false, false);

// Paths
$watchDirs = [
    'incoming_tar' => '/home/acepino/git/rabbitmqphp_example/it490/incoming_tar',
    'sent_tar' => '/home/acepino/git/rabbitmqphp_example/it490/sent_tar'
];

$knownFiles = [];

while (true) {
    foreach ($watchDirs as $type => $dir) {
        foreach (glob("$dir/*.tar.gz") as $file) {
            if (!isset($knownFiles[$file])) {
                $msg = new AMQPMessage(json_encode([
                    'file' => basename($file),
                    'path' => realpath($file),
                    'type' => $type,
                    'time' => date('c')
                ]));
                $queueName = $type === 'incoming_tar' ? 'incoming_tar_msg' : 'sent_tar_msg';
                $channel->basic_publish($msg, '', $queueName);
                echo "Queued file: $file to $queueName\n";
                $knownFiles[$file] = true;
            }
        }
    }
    sleep(5); // avoid busy loop
}


try {
    $connection = new AMQPStreamConnection('localhost', 5672, 'ace_p', 'goat', 'testHost');
    $channel = $connection->channel();
} catch (Exception $e) {
    echo "Error connecting to RabbitMQ: " . $e->getMessage();
    exit(1);
}


$channel->close();
$connection->close();
