<?php

error_reporting(E_ALL);
ini_set('display_errors', 1);

include 'rabbitMQLib.inc'; // Connection
header('Content-Type: application/json');

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $restaurant = $_POST["restaurant"] ?? '';
    $date = $_POST["date"] ?? '';
    $time = $_POST["time"] ?? '';

    if (empty($restaurant) || empty($date) || empty($time)) {
        echo json_encode(["status" => "error", "message" => "All fields are required!"]);
        exit;
    }

    // The invite link
    $inviteLink = "http://localhost/invite.php?restaurant=" . urlencode($restaurant) . "&date=" . urlencode($date) . "&time=" . urlencode($time);

    // RabbitMQ client
    $client = new rabbitMQClient("testRabbitMQ.ini", "rabbitMQ");

    // Reservation data
    $request = [
        "type" => "book_reservation",
        "restaurant" => $restaurant,
        "date" => $date,
        "time" => $time
    ];

    // Sends to RabbitMQ
    $response = $client->send_request($request);

    if ($response === "success") {
        echo json_encode(["status" => "success", "message" => "Reservation booked!", "invite_link" => $inviteLink]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to book reservation."]);
    }
}
?>
