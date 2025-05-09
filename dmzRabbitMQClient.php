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
    die("Database connection failed: " . $e->getMessage());
}

function syncReviewsById() {
    global $db;
    
    // Get max ID from local database
    $localMaxId = $db->query("SELECT MAX(id) FROM reviews")->fetchColumn() ?? 0;
    
    $client = new rabbitMQClient("localRabbitMQ.ini", "dmzServer");
    $request = [
        'type' => 'fetch_reviews_by_id',
        'min_id' => $localMaxId
    ];
    
    try {
        echo "Requesting reviews with ID > $localMaxId from DMZ...\n";
        $response = $client->send_request($request, 'api_routing_key');
        
        if ($response['status'] === 'success' && !empty($response['reviews'])) {
            $insertCount = 0;
            $db->beginTransaction();
            
            foreach ($response['reviews'] as $review) {
                try {
                    $stmt = $db->prepare("
                        INSERT INTO reviews 
                        (id, placeName, placeAddress, provider, reviewText, reviewDate, reviewRating, authorName) 
                        VALUES 
                        (:id, :placeName, :placeAddress, :provider, :reviewText, :reviewDate, :reviewRating, :authorName)
                    ");
                    
                    $stmt->execute([
                        ':id' => $review['id'],
                        ':placeName' => $review['placeName'],
                        ':placeAddress' => $review['placeAddress'],
                        ':provider' => $review['provider'],
                        ':reviewText' => $review['reviewText'],
                        ':reviewDate' => $review['reviewDate'],
                        ':reviewRating' => $review['reviewRating'],
                        ':authorName' => $review['authorName']
                    ]);
                    $insertCount++;
                } catch (PDOException $e) {
                    // Continue if duplicate ID, fail otherwise
                    if ($e->errorInfo[1] != 1062) { // 1062 = Duplicate entry
                        throw $e;
                    }
                }
            }
            
            $db->commit();
            return [
                'status' => 'success',
                'message' => "Inserted $insertCount new reviews",
                'count' => $insertCount,
                'new_max_id' => $db->query("SELECT MAX(id) FROM reviews")->fetchColumn()
            ];
        }
        return $response;
    } catch (Exception $e) {
        $db->rollBack();
        return [
            'status' => 'error',
            'message' => $e->getMessage()
        ];
    }
}

$result = syncReviewsById();
print_r($result);
?>