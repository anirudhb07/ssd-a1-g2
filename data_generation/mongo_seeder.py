import os
import random
import uuid
from datetime import datetime, timedelta, timezone
from bson.binary import Binary, UUID_SUBTYPE
from faker import Faker
from pymongo import MongoClient, InsertOne

# Configuration
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = "StaySpot"

# Target counts
NUM_SEARCH_SESSIONS = 500_000  # Required: at least 500,000 geospatial pings
NUM_AMENITIES = 2_000
NUM_REVIEWS = 20_000

BATCH_SIZE = 10_000

fake = Faker()

def uuid_to_binary(u: uuid.UUID) -> Binary:
    """Convert a Python UUID to BSON Binary subtype 4 (16 bytes)."""
    return Binary(u.bytes, subtype=UUID_SUBTYPE)

def get_mongo_client():
    return MongoClient(MONGO_URI)

def seed_mongo():
    client = get_mongo_client()
    db = client[DB_NAME]
    print(f"🚀 Connected to MongoDB ('{DB_NAME}'). Starting data seeding...")

    try:
        # Generate shared pool of guest and property UUIDs
        guest_uuids = [uuid.uuid4() for _ in range(5_000)]
        property_uuids = [uuid.uuid4() for _ in range(2_000)]

        # 1. Seed PropertyAmenities
        print(f"Generating {NUM_AMENITIES:,} PropertyAmenities documents...")
        amenities_collection = db["PropertyAmenities"]
        amenity_ops = []
        
        sample_amenities = ["WiFi", "Pool", "Air Conditioning", "Free Parking", "Kitchen", "Hot Tub", "Gym", "EV Charger"]
        sample_rules = ["No smoking", "Quiet hours after 10 PM", "No pets", "No parties or events"]
        sample_accessibility = ["Step-free path", "Wide doorway", "Accessible bathroom", "Single-level home"]

        for pid in property_uuids[:NUM_AMENITIES]:
            doc = {
                "property_id": uuid_to_binary(pid),
                "amenities": random.sample(sample_amenities, k=random.randint(2, 6)),
                "house_rules": random.sample(sample_rules, k=random.randint(1, 3)),
                "accessibility_features": random.sample(sample_accessibility, k=random.randint(1, 3)),
                "updated_at": datetime.now(timezone.utc)
            }
            amenity_ops.append(InsertOne(doc))

            if len(amenity_ops) >= BATCH_SIZE:
                amenities_collection.bulk_write(amenity_ops)
                amenity_ops = []

        if amenity_ops:
            amenities_collection.bulk_write(amenity_ops)
        print("  -> PropertyAmenities complete.")

        # 2. Seed SearchSessions (500,000 geospatial pings)
        print(f"Generating {NUM_SEARCH_SESSIONS:,} SearchSessions geospatial pings...")
        sessions_collection = db["SearchSessions"]
        session_ops = []

        # Coordinate bounding box for simulation (e.g., California area)
        MIN_LAT, MAX_LAT = 32.5, 42.0
        MIN_LON, MAX_LON = -124.4, -114.1
        now = datetime.now(timezone.utc)

        for i in range(1, NUM_SEARCH_SESSIONS + 1):
            gid = random.choice(guest_uuids)
            sid = uuid.uuid4()

            # GeoJSON Point: [longitude, latitude]
            lon = round(random.uniform(MIN_LON, MAX_LON), 6)
            lat = round(random.uniform(MIN_LAT, MAX_LAT), 6)

            # Random timestamp within last 1 hour (within 2-hour TTL window)
            created_at = now - timedelta(seconds=random.randint(0, 3600))

            doc = {
                "guest_id": uuid_to_binary(gid),
                "session_id": uuid_to_binary(sid),
                "location": {
                    "type": "Point",
                    "coordinates": [lon, lat]
                },
                "created_at": created_at
            }
            session_ops.append(InsertOne(doc))

            if len(session_ops) >= BATCH_SIZE:
                sessions_collection.bulk_write(session_ops, ordered=False)
                session_ops = []
                print(f"  -> Inserted {i:,} / {NUM_SEARCH_SESSIONS:,} search pings")

        if session_ops:
            sessions_collection.bulk_write(session_ops, ordered=False)
        print("  -> SearchSessions complete.")

        # 3. Seed PropertyReviews
        print(f"Generating {NUM_REVIEWS:,} PropertyReviews documents...")
        reviews_collection = db["PropertyReviews"]
        review_ops = []
        tags_pool = ["beachfront", "quiet", "clean", "spacious", "scenic", "central", "cozy"]

        for _ in range(NUM_REVIEWS):
            doc = {
                "property_id": uuid_to_binary(random.choice(property_uuids)),
                "guest_id": uuid_to_binary(random.choice(guest_uuids)),
                "rating": random.randint(1, 5),
                "review_text": fake.paragraph(nb_sentences=2),
                "location_tags": random.sample(tags_pool, k=random.randint(1, 3)),
                "created_at": fake.date_time_between(start_date="-1y", end_date="now")
            }
            review_ops.append(InsertOne(doc))

            if len(review_ops) >= BATCH_SIZE:
                reviews_collection.bulk_write(review_ops)
                review_ops = []

        if review_ops:
            reviews_collection.bulk_write(review_ops)
        print("  -> PropertyReviews complete.")

        print("✅ MongoDB data seeding successfully completed!")

    except Exception as e:
        print(f"❌ Error during MongoDB seeding: {e}")
        raise e
    finally:
        client.close()

if __name__ == "__main__":
    seed_mongo()