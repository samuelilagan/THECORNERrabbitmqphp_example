<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);


if ($_SERVER["REQUEST_METHOD"] == "POST") {
   $restaurant = $_POST["restaurant"];
   $date = $_POST["date"];
   $time = $_POST["time"];


   if (!empty($restaurant) && !empty($date) && !empty($time)) {
       // Format reservation entry
       $reservationEntry = "$restaurant | $date | $time\n";


       // Save to file
       file_put_contents("reservations.txt", $reservationEntry, FILE_APPEND);
       echo "Reservation booked successfully!";
       exit;
   } else {
       echo "All fields are required!";
       exit;
   }
}


// Display existing reservations
if (file_exists("reservations.txt")) {
   $reservations = file("reservations.txt", FILE_IGNORE_NEW_LINES);
   foreach ($reservations as $res) {
       echo "<li>$res</li>";
   }
} else {
   echo "<li>No reservations yet.</li>";
}
?>

