db = db.getSiblingDB('StaySpot');

// 1. PropertyAmenities
var PropertyAmenitiesSchema = /** @type {const} */ ({
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

db.PropertyAmenities.createIndex(
  { property_id: 1 },
  { name: "idx_amenities_property", unique: true }
);

// 2. SearchSessions
var SearchSessionsSchema = /** @type {const} */ ({
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

// 3. PropertyReviews
var PropertyReviewsSchema = /** @type {const} */ ({
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

db.PropertyReviews.createIndex(
  { property_id: 1, created_at: -1 },
  { name: "idx_reviews_property_recent" }
);