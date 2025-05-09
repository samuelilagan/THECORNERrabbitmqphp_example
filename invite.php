<?php
// Reservation details from the URL parameters
$restaurant = $_GET["restaurant"] ?? "Unknown Restaurant";
$date = $_GET["date"] ?? "Unknown Date";
$time = $_GET["time"] ?? "Unknown Time";

// Format the event for Google Calendar
$startDateTime = date("Ymd\THis", strtotime("$date $time"));
$endDateTime = date("Ymd\THis", strtotime("$date $time +1 hour")); 

// Google Calendar event link
$googleCalendarLink = "https://www.google.com/calendar/render?action=TEMPLATE" .
    "&text=" . urlencode("Dinner at $restaurant") .
    "&dates=" . urlencode("$startDateTime/$endDateTime") .
    "&details=" . urlencode("You're invited to dinner at $restaurant!") .
    "&location=" . urlencode($restaurant) .
    "&sf=true&output=xml";
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>You're Invited</title>
</head>
<body>
    <h2>You're Invited</h2>
    <p>Join us at <strong><?php echo htmlspecialchars($restaurant); ?></strong> on <strong><?php echo htmlspecialchars($date); ?></strong> at <strong><?php echo htmlspecialchars($time); ?></strong>.</p>
    
    <h3>Invite Friends</h3>
    <p>Send this link to invite your friends:</p>
    <input type="text" value="<?php echo htmlspecialchars("http://localhost/invite.php?restaurant=" . urlencode($restaurant) . "&date=" . urlencode($date) . "&time=" . urlencode($time)); ?>" readonly>
    
    <h3>Add to Calendar</h3>
    <p><a href="<?php echo $googleCalendarLink; ?>" target="_blank">➕ Add to Google Calendar</a></p>
</body>
</html>
