#!/usr/bin/php
<?php
require_once('path.inc');
require_once('get_host_info.inc');
require_once('rabbitMQLib.inc');

// Database connection
$dsn = 'mysql:host=127.0.0.1;dbname=users';
$dbUser = 'testUser';
$dbPassword = '12345';

try {
    $db = new PDO($dsn, $dbUser, $dbPassword);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("DMZ Database connection failed: " . $e->getMessage());
}

function processReviewRequest($request) {
    global $db;
    
    if ($request['type'] === 'fetch_reviews_by_id') {
        try {
            $minId = (int)$request['min_id'];
            echo "Fetching reviews with ID > $minId\n";
            
            $stmt = $db->prepare("
                SELECT id, placeName, placeAddress, provider, 
                       reviewText, reviewDate, reviewRating, authorName
                FROM reviews
                WHERE id > :min_id
                ORDER BY id ASC
            ");
            $stmt->bindParam(':min_id', $minId, PDO::PARAM_INT);
            $stmt->execute();
            
            $reviews = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $count = count($reviews);
            
            echo "Found $count reviews to sync\n";
            return [
                'status' => 'success',
                'reviews' => $reviews,
                'count' => $count,
                'min_id_requested' => $minId,
                'max_id_returned' => $count ? max(array_column($reviews, 'id')) : $minId
            ];
            
        } catch (PDOException $e) {
            return [
                'status' => 'error',
                'message' => $e->getMessage()
            ];
        }
    }
    return ['status' => 'error', 'message' => 'Invalid request type'];
}

$server = new rabbitMQServer("dmzRabbitMQ.ini", "testServer");
echo "DMZ Review Server (ID-based sync) started.\n";
$server->process_requests('processReviewRequest');
?>
