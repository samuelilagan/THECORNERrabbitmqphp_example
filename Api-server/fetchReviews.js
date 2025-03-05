const { ApifyClient } = require('apify-client'); 

// Initialize the Apify client with your API token 
const client = new ApifyClient({ 
token: 'apify_api_IXZmdm4hEGcpg3bB1mYIWibqMFm0zh4AmTY7', 
}); 

(async () => { 
try { 
// Define input parameters for the API 
const input = { 
"restaurantUrls": ["https://www.yelp.com/biz/jollibee-jersey-city-7?osq=Jollibee&limit=10"], 
"maxReviews": 10
};

 // Run the Restaurant Review Aggregator actor 
const run = await client.actor("tri_angle/restaurant-review-aggregator").call(input); 

// Fetch the results from the dataset 
const { items } = await client.dataset(run.defaultDatasetId).listItems(); 

// Print the extracted reviews 
console.log('Extracted Reviews:', items); 
} catch (error) {
     console.error("Error fetching reviews:", error); 
} 
})();

