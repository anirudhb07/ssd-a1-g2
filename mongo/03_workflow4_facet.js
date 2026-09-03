db = db.getSiblingDB('StaySpot');

// Workflow 4: Multi-Faceted Analytics ($facet)
// Breakdown ratings and top tags across property reviews

db.PropertyReviews.aggregate([
  {
    $facet: {
      // Facet 1: Rating Distribution Breakdown
      "rating_breakdown": [
        {
          $group: {
            _id: "$rating",
            review_count: { $sum: 1 }
          }
        },
        { $sort: { _id: -1 } }
      ],

      // Facet 2: Most Popular Location Tags
      "top_location_tags": [
        { $unwind: "$location_tags" },
        {
          $group: {
            _id: "$location_tags",
            tag_count: { $sum: 1 }
          }
        },
        { $sort: { tag_count: -1 } },
        { $limit: 5 }
      ],

      // Facet 3: Overall Summary Statistics
      "summary_stats": [
        {
          $group: {
            _id: null,
            total_reviews: { $sum: 1 },
            average_rating: { $avg: "$rating" }
          }
        }
      ]
    }
  }
]);