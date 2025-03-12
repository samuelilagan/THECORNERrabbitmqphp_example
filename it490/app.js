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
//serve static files from 'it490' folder
//app.use(express.static(path.join(__dirname, 'it490')));

//route to serve notiflanding.html
app.get("/notiflanding.html", (req, res) => {
  res.sendFile(path.join(__dirname, "/", "notiflanding.html"));
})

 
// Middleware to parse form data
app.use(bodyParser.urlencoded({ extended: true }));

// Serve the HTML form
app.get('/', (req, res) => {
    res.sendFile(__dirname + '/notiftest.html');
});

// Handle form submission
app.post('/submit', (req, res) => {
    // Get data from the form
    const email = req.body.email;
    const number = req.body.number;

    // Log the form data in the terminal
    console.log('User Data:');
    console.log('Number:', number);
    console.log('Email:', email);

    notificationapi.send({
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
})


    return email,number;
    module.exports = email;
    module.exports = number;

    // Respond back to the user
    res.send(`Thank you for your email, ${email}. We have received your information.`);
});

 



// Start the server
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
