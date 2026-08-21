// Switch to your target database
db = db.getSiblingDB('StaySpot');

// 1. PropertyAmenities: Flexible catalog documents with nested arrays
db.PropertyAmenities.insertOne({
  property_id: 1, // References properties(id) from PostgreSQL
  amenities: ["WiFi", "Pool", "Air Conditioning"],
  house_rules: ["No smoking", "Quiet hours after 10 PM"],
  accessibility_features: ["Step-free path", "Wide doorway"],
  updated_at: new Date()
});

// 2. PropertyReviews: Structured reviews with ratings, location tags, and timestamps
db.PropertyReviews.insertOne({
  property_id: 1,
  guest_id: 5,
  rating: 4.8,
  review_text: "Amazing stay!",
  location_tags: ["beachfront", "quiet"],
  timestamp: new Date()
});

// 3. SearchSessions: Geospatial logs for dropped search pins
db.SearchSessions.insertOne({
  guest_id: 5,
  session_id: "sess_abc123",
  search_location: {
    type: "Point",
    coordinates: [-122.4194, 37.7749] // [longitude, latitude]
  },
  timestamp: new Date()
});

// Create the 2dsphere index for geospatial queries (Workflow 3)
db.SearchSessions.createIndex({ search_location: "2dsphere" });