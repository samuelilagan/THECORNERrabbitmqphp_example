const express = require('express');
const path = require('path');
const bodyParser = require('body-parser');
const app = express();
const port = 3000;

//connects to notificationAPI
const notificationapi = require('notificationapi-node-server-sdk').default
notificationapi.init(
    'nysaalf6rdm6jyg8pla5si4cju', // clientId
    'xvsjcir9jktvmud6vtlpxnon8j217eh3uufighc0gcjlaw8uh9rdw815i9'// clientSecret
  )

// enables the ability to load otificaitonAPI asyncronously
function loadScript(scriptUrl) {
    let script = document.createElement("script");
    script.src = scriptUrl;
    script.type = "text/javascript";
    script.async = true;  // Load asynchronously
    document.body.appendChild(script);
}
app.get('/notiflanding', (req, res) => {
  res.sendFile(path.join(__dirname, 'notiflanding.html'));
});


 
// Middleware to parse form data
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json()); // <--this line SHOULD parse JSON input from frontend

// Serve the HTML form
app.get('/', (req, res) => {
    res.sendFile(__dirname + '/notiftest.html');
});

// Serve notiflanding.html explicitly
app.get('/notiflanding.html', (req, res) => {
  res.sendFile(path.join(__dirname, 'notiflanding.html'));
});


// Handle form submission
app.post('/submit', async (req, res) => {
  try {
    const email = req.body.email;
    const number = req.body.number;

    console.log('User Data Received:');
    console.log('Email:', email);
    console.log('Number:', number);

    await notificationapi.send({
      notificationId: 'test',
      user: {
      id: "'" + email +"'",
      email: "'" + email +"'",
      number: "'+1'" + number +'"' // Replace with your phone number, use format [+][country code][area code][local number]
      },
      mergeTags: {
        "comment": "You will have an upcoming reservation!",
        "commentId": "testCommentId"
      }
    });

    res.status(200).json({ status: "success", message: `Notification sent to ${email}` });

  } catch (err) {
    console.error("Error in /submit:", err);
    res.status(500).json({ status: "error", message: "Internal Server Error" });
  }
});


 



// Start the server
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
