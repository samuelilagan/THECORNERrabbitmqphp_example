?php
require_once('/path/to/vendor/autoload.php'); // Adjust if you're using Composer/php-amqplib

use PhpAmqpLib\Connection\AMQPStreamConnection;
use PhpAmqpLib\Message\AMQPMessage;

function log_error($message, $file = null, $line = null) {
    $host = gethostname();
    $timestamp = date('Y-m-d H:i:s');

    $log = json_encode([
        'host' => $host,
        'file' => $file ?? basename(__FILE__),
        'line' => $line ?? __LINE__,
        'message' => $message,
        'timestamp' => $timestamp
    ]);
// replace with ace's IP?
    $connection = new AMQPStreamConnection('REPLACE_WITH_RABBITMQ_IP', 5672, 'guest', 'guest');
    $channel = $connection->channel();
    $channel->queue_declare('logQueue', false, true, false, false);

    $msg = new AMQPMessage($log);
    $channel->basic_publish($msg, '', 'logQueue');

    $channel->close();
    $connection->close();
}
?>
