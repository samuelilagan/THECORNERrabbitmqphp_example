require('dotenv').config();
const { ApifyClient } = require('apify-client');
const mysql = require('mysql2/promise');

const apifyToken = process.env.APIFY_TOKEN;
const datasetId = "QubOQR8wBfoAMaEZQ"; // Replace with actual dataset ID

const dbConfig = {
    host: process.env.MYSQL_HOST || 'localhost',
    user: process.env.MYSQL_USER || 'testUser',
    password: process.env.MYSQL_PASSWORD || '12345',
    database: process.env.MYSQL_DATABASE || 'users'
};



(async () => {
    try {
        // Initialize Apify client
        const client = new ApifyClient({ token: apifyToken });

        // Fetch dataset records
        const { items } = await client.dataset(datasetId).listItems({limit:100});

        // Connect to MySQL
        const connection = await mysql.createConnection(dbConfig);

        // Insert data into MySQL table
        for (const reviews of items) {
          const placeName = reviews.placeName // || Unknown;
          const placeAddress = reviews.placeAddress // || Anonymous;
          const provider = reviews.provider // || No review text provided;
          const reviewText = reviews.reviewText // || No review text provided;
          const reviewDate = reviews.reviewDate // || No review text provided;
          const reviewRating = reviews.reviewRating   // Allow NULL for missing ratings
          const authorName = reviews.authorName // || new Date().toISOString().slice(0, 19).replace('T', ' '); // Default to current time
      
          console.log();


          // Check if the review already exists in the database (using a unique identifier such as 'reviewText' or 'placeName')
          const [rows] = await connection.execute('SELECT * FROM reviews WHERE reviewText = ?', [reviewText]);


          if (rows.length === 0) {
              // If not found, insert new data into MySQL
	                    const query = `INSERT INTO reviews (placeName, placeAddress, provider, reviewText, reviewDate, reviewRating, authorName) VALUES (?, ?, ?, ?, ?, ?, ?)`;
              await connection.execute(query, [placeName, placeAddress, provider, reviewText, reviewDate, reviewRating, authorName]);
              console.log();
          } else {
              console.log();
          }
      }


      console.log("Data processing complete!");
      await connection.end();
  } catch (error) {
      console.error("Error:", error);
  }
})
()
