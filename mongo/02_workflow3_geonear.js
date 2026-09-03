db = db.getSiblingDB('StaySpot');

// Workflow 3: Trending Search Hotspots ($geoNear)
// Cluster recent SearchSessions within a 5km radius of specific coordinates

db.SearchSessions.aggregate([
  {
    $geoNear: {
      near: {
        type: "Point",
        coordinates: [-122.4194, 37.7749] // Target coordinates [longitude, latitude]
      },
      distanceField: "distance_meters",
      maxDistance: 5000, // 5km radius in meters
      spherical: true
    }
  },
  {
    $group: {
      _id: "$guest_id",
      total_searches: { $sum: 1 },
      avg_distance_meters: { $avg: "$distance_meters" },
      min_distance_meters: { $min: "$distance_meters" },
      last_search_time: { $max: "$created_at" }
    }
  },
  {
    $sort: { total_searches: -1 }
  },
  {
    $limit: 10
  },
  {
    $project: {
      _id: 0,
      guest_id: "$_id",
      total_searches: 1,
      avg_distance_km: { $divide: ["$avg_distance_meters", 1000] },
      min_distance_km: { $divide: ["$min_distance_meters", 1000] },
      last_search_time: 1
    }
  }
]);