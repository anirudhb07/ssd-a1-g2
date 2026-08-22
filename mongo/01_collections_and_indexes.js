db = db.getSiblingDB('StaySpot')

// PropertyAmenities

const PropertyAmenitiesSchema = /** @type {const} */ ({
  bsonType: "object",
  title: "PropertyAmenities validation",
  required: ["property_id", "updated_at"],
  properties: {
    property_id: { bsonType: "binData" },
    amenities: { bsonType: "array", items: { bsonType: "string" } },
    house_rules: { bsonType: "array", items: { bsonType: "string" } },
    accessibility_features: { bsonType: "array", items: { bsonType: "string" } },
    updated_at: { bsonType: "date" }
  }
});

db.createCollection("PropertyAmenities", {
  validator: {
    $and: [
      { $jsonSchema: PropertyAmenitiesSchema },
      { $expr: { $eq: [{ $binarySize: "$property_id" }, 16] } }
    ]
  },
  validationLevel: "strict",
  validationAction: "error"
});


// PropertyAmenities Index

db.PropertyAmenities.createIndex(
  { property_id: 1 },
  { name: "idx_amenities_property", unique: true }
);

// Dummy data

// db.PropertyAmenities.insertOne({
//   property_id: UUID("12-34"),
//   amenities: ["WiFi", "Pool", "Air Conditioning"],
//   house_rules: ["No smoking", "Quiet hours after 10 PM"],
//   accessibility_features: ["Step-free path", "Wide doorway"],
//   updated_at: new Date()
// });

// SearchSessions

const SearchSessionsSchema = /** @type {const} */ ({
  bsonType: "object",
  title: "SearchSessions validation",
  required: ["guest_id", "session_id", "location", "created_at"],
  properties: {
    guest_id: { bsonType: "binData" },
    session_id: { bsonType: "binData" },
    location: {
      bsonType: "object",
      required: ["type", "coordinates"],
      properties: {
        type: { enum: ["Point"] },
        coordinates: {
          bsonType: "array",
          minItems: 2,
          maxItems: 2,
          items: { bsonType: "number" }
        }
      }
    },
    created_at: { bsonType: "date" }
  }
});

db.createCollection("SearchSessions", {
  validator: {
    $and: [
      { $jsonSchema: SearchSessionsSchema },
      { $expr: { $eq: [{ $binarySize: "$guest_id" }, 16] } },
      { $expr: { $eq: [{ $binarySize: "$session_id" }, 16] } }
    ]
  },
  validationLevel: "strict",
  validationAction: "error"
});

db.SearchSessions.createIndex(
  { location: "2dsphere", created_at: -1 },
  { name: "idx_sessions_geo_recent" }
);

db.SearchSessions.createIndex(
  { created_at: 1 },
  { name: "ttl_sessions_created_at", expireAfterSeconds: 7200 }
);

// Dummy data

// db.SearchSessions.insertOne({
//   guest_id: UUID(""),
//   session_id: UUID(""),
//   location: {
//     type: "Point",
//     coordinates: [-122.4194, 37.7749] // [longitude, latitude]
//   },
//   created_at: new Date()
// });

// PropertyReviews

const PropertyReviewsSchema = /** @type {const} */ ({
  bsonType: "object",
  title: "PropertyReviews validation",
  required: ["property_id", "guest_id", "rating", "created_at"],
  properties: {
    property_id: { bsonType: "binData" },
    guest_id: { bsonType: "binData" },
    rating: { bsonType: "int", minimum: 1, maximum: 5 },
    review_text: { bsonType: "string" },
    location_tags: { bsonType: "array", items: { bsonType: "string" } },
    created_at: { bsonType: "date" }
  }
});

db.createCollection("PropertyReviews", {
  validator: {
    $and: [
      { $jsonSchema: PropertyReviewsSchema },
      { $expr: { $eq: [{ $binarySize: "$property_id" }, 16] } },
      { $expr: { $eq: [{ $binarySize: "$guest_id" }, 16] } }
    ]
  },
  validationLevel: "strict",
  validationAction: "error"
});

// PropertyReviews index

db.PropertyReviews.createIndex(
  { property_id: 1, created_at: -1 },
  { name: "idx_reviews_property_recent" }
);

// Dummy data

// db.PropertyReviews.insertOne({
//   property_id: UUID(""),
//   guest_id: UUID(""),
//   rating: 4.8,
//   review_text: "Amazing stay!",
//   location_tags: ["beachfront", "quiet"],
//   timestamp: new Date()
// });


