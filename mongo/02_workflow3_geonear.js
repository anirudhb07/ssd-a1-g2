// ============================================================================
// Project 3: StaySpot – Vacation Rental & Experiences
// Script: 02_workflow3_geonear.js
// Description: Workflow 3 - Trending Search Hotspots Proximity Analysis
// ============================================================================

db = db.getSiblingDB('StaySpot');

/**
 * Executes a geospatial aggregation pipeline on the SearchSessions collection
 * to cluster recent search telemetry within a 5 km radius of a target location.
 * 
 * @param {number} longitude - Longitude in decimal degrees (GeoJSON format)
 * @param {number} latitude - Latitude in decimal degrees (GeoJSON format)
 */
function getTrendingSearchHotspots(longitude, latitude) {
    const pipeline = [
        // --------------------------------------------------------------------
        // Stage 1: Geospatial Proximity Search
        // $geoNear MUST be the absolute first stage in the pipeline.
        // It utilizes the '2dsphere' spatial index to calculate precise spherical distances.
        // --------------------------------------------------------------------
        {
            $geoNear: {
                near: {
                    type: "Point",
                    coordinates: [longitude, latitude]
                },
                distanceField: "distance_meters",
                maxDistance: 5000, // 5,000 meters = 5 km radius
                spherical: true,
                query: {
                    // Filter to ensure we only look at active telemetry
                    // (TTL index cleans up records > 2 hours old, but we can enforce a sub-filter)
                    created_at: { $gte: new Date(Date.now() - 2 * 60 * 60 * 1000) }
                }
            }
        },

        // --------------------------------------------------------------------
        // Stage 2: Projected Metrics
        // Convert distances to kilometers and isolate target metrics.
        // --------------------------------------------------------------------
        {
            $project: {
                session_id: 1,
                distance_km: { $divide: ["$distance_meters", 1000] },
                "search_filters.guests_count": 1,
                "search_filters.max_price": 1,
                "search_filters.requires_pool": 1,
                created_at: 1
            }
        },

        // --------------------------------------------------------------------
        // Stage 3: Clustering and Aggregation (Facet/Bucket style)
        // Group search sessions into 1 km concentric rings to map hotspot density.
        // --------------------------------------------------------------------
        {
            $bucket: {
                groupBy: "$distance_km",
                boundaries: [0, 1, 2, 3, 4, 5], // Concentric 1km increments
                default: "beyond_5km",
                output: {
                    total_searches: { $sum: 1 },
                    average_requested_guests: { $avg: "$search_filters.guests_count" },
                    average_budget_limit: { $avg: "$search_filters.max_price" },
                    pool_requested_count: {
                        $sum: { $cond: [{ $eq: ["$search_filters.requires_pool", true] }, 1, 0] }
                    }
                }
            }
        },

        // --------------------------------------------------------------------
        // Stage 4: Order by Proximity (closest rings first)
        // --------------------------------------------------------------------
        {
            $sort: { _id: 1 }
        }
    ];

    return db.SearchSessions.aggregate(pipeline).toArray();
}

// Example execution centered near a popular tourist hotspot (e.g., Goa/San Francisco coordinates)
const defaultLongitude = -122.4194;
const defaultLatitude = 37.7749;

print(`Executing Geospatial Aggregation near [${defaultLongitude}, ${defaultLatitude}]...`);
const hotspots = getTrendingSearchHotspots(defaultLongitude, defaultLatitude);
printjson(hotspots);