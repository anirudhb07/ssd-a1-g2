db = db.getSiblingDB('StaySpot');

db.PropertyAmenities.insertOne({
  property_id: 1, 
  amenities: ["WiFi", "Pool", "Air Conditioning"],
  house_rules: ["No smoking", "Quiet hours after 10 PM"],
  accessibility_features: ["Step-free path", "Wide doorway"],
  updated_at: new Date()
});

db.PropertyReviews.insertOne({
  property_id: 1,
  guest_id: 5,
  rating: 4.8,
  review_text: "Amazing stay!",
  location_tags: ["beachfront", "quiet"],
  timestamp: new Date()
});


db.SearchSessions.insertOne({
  guest_id: 5,
  session_id: "sess_abc123",
  search_location: {
    type: "Point",
    coordinates: [-122.4194, 37.7749] // [longitude, latitude]
  },
  timestamp: new Date()
});
