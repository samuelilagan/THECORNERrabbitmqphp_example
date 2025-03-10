<?php
require_once('/home/samilagan/git/rabbitmqphp_example/path.inc');
require_once('/home/samilagan/git/rabbitmqphp_example/get_host_info.inc');
require_once('/home/samilagan/git/rabbitmqphp_example/rabbitMQLib.inc');


function sendRequest($request) {
   $client = new rabbitMQClient('/home/samilagan/git/rabbitmqphp_example/localRabbitMQ.ini', 'testServer');
   try {
       $response = $client->send_request($request);
       error_log("Raw Response: " . print_r($response, true));
       return $response;
   } catch (Exception $e) {
       return ["status" => "error", "message" => "Request failed: " . $e->getMessage()];
   }
}


if ($_SERVER['REQUEST_METHOD'] === 'POST') {
   $data = json_decode(file_get_contents('php://input'), true);


   if (!isset($data['type'])) {
       echo json_encode(["status" => "error", "message" => "Invalid request"]);
       exit();
   }


   switch ($data['type']) {
       case 'filter':
           if (!isset($data['city']) || !isset($data['keyword'])) {
               echo json_encode(["status" => "error", "message" => "Missing filter information"]);
               exit();
           }


           $request = [
               "type" => "filter",
               "city" => $data['city'],
               "keyword" => $data['keyword'],
               "rating" => $data['rating'],
               "dietary" => $data['dietary'],
               "cuisine" => $data['cuisine']
           ];
           $response = sendRequest($request);


           if ($response['status'] === "success") {
               echo json_encode([
                   "status" => "success",
                   "reviews" => $response['reviews']
               ]);
               exit();
           }


           echo json_encode($response);
           break;


       default:
           echo json_encode(["status" => "error", "message" => "Invalid request type"]);
   }
} else {
   echo json_encode(["status" => "error", "message" => "Invalid request method"]);
}
?>
