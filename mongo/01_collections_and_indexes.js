db = db.getSiblingDB("app");

// ---------------------------------------------------------------------------
// PropertyAmenities
// ---------------------------------------------------------------------------

const PropertyAmenitiesSchema = /** @type {const} */ ({
  bsonType: "object",
  title: "PropertyAmenities validation",
  required: ["property_id", "updated_at"],
  additionalProperties: true,
  properties: {
    property_id: { bsonType: "binData" },
    amenity_categories: {
      bsonType: "array",
      items: {
        bsonType: "object",
        required: ["category", "items"],
        properties: {
          category: { bsonType: "string" },
          items: { bsonType: "array", items: { bsonType: "string" } }
        }
      }
    },
    house_rules: { bsonType: "array", items: { bsonType: "string" } },
    accessibility_features: { bsonType: "array", items: { bsonType: "string" } },
    updated_at: { bsonType: "date" }
  }
});

db.PropertyAmenities.drop();

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

// ---------------------------------------------------------------------------
// SearchSessions
// ---------------------------------------------------------------------------

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
    search_filters: {
      bsonType: "object",
      properties: {
        guests_count: { bsonType: "int", minimum: 1, maximum: 16 },
        max_price: { bsonType: "number", minimum: 0 },
        min_bedrooms: { bsonType: "int", minimum: 0 },
        requires_pool: { bsonType: "bool" }
      }
    },
    created_at: { bsonType: "date" }
  }
});

db.SearchSessions.drop();

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

// geo sphere index

db.SearchSessions.createIndex(
  { location: "2dsphere", created_at: -1 },
  { name: "idx_sessions_geo_recent" }
);

// ttl index

db.SearchSessions.createIndex(
  { created_at: 1 },
  {
    name: "ttl_sessions_created_at",
    expireAfterSeconds: 7200 // 2h * 60m * 60s
  }
);

// ---------------------------------------------------------------------------
// PropertyReviews
// ---------------------------------------------------------------------------

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

db.PropertyReviews.drop();

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

// Per-property review history
db.PropertyReviews.createIndex(
  { property_id: 1, created_at: -1 },
  { name: "idx_reviews_property_recent" }
);

// review history
db.PropertyReviews.createIndex(
  { created_at: -1 },
  { name: "idx_reviews_recent" }
);

// Rating scoped history
db.PropertyReviews.createIndex(
  { rating: 1, created_at: -1 },
  { name: "idx_reviews_rating_recent" }
);

print("Collections and indexes created on database: " + db.getName());
