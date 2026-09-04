db = db.getSiblingDB("app");

// recent window size
const REVIEW_WINDOW_DAYS = 30;

// frequency facet tag return count
const TOP_TAG_LIMIT = 10;

// ratings
const STAR_LEVELS = [1, 2, 3, 4, 5];

/**
 * @param {number} windowDays
 * @returns {MongoQuery[]}
 */
function buildReviewAnalyticsPipeline(windowDays) {
  const windowStart = new Date(Date.now() - windowDays * 24 * 60 * 60 * 1000);

  return [
    // filter events in last windowDays 
    { $match: { created_at: { $gte: windowStart } } },

    // multi aggregation (facet)
    {
      $facet: {
        // 1. Rating distribution 
        rating_distribution: [
          { $group: { _id: "$rating", count: { $sum: 1 } } },
          { $sort: { _id: 1 } }
        ],

        // 2. Most frequent tags
        top_tags: [
          { $unwind: "$location_tags" },
          { $group: { _id: "$location_tags", count: { $sum: 1 } } },
          { $sort: { count: -1, _id: 1 } },
          { $limit: TOP_TAG_LIMIT },
          { $project: { _id: 0, tag: "$_id", count: 1 } }
        ],

        // 3. Overall rating
        overall: [
          {
            $group: {
              _id: null,
              total_reviews: { $sum: 1 },
              average_rating: { $avg: "$rating" },
              lowest_rating: { $min: "$rating" },
              highest_rating: { $max: "$rating" }
            }
          },
          {
            $project: {
              _id: 0,
              total_reviews: 1,
              average_rating: { $round: ["$average_rating", 3] },
              lowest_rating: 1,
              highest_rating: 1
            }
          }
        ]
      }
    },

    // Stage 3: flatten `overall`
    {
      $set: {
        overall: {
          $ifNull: [
            { $first: "$overall" },
            {
              total_reviews: 0,
              average_rating: null,
              lowest_rating: null,
              highest_rating: null
            }
          ]
        }
      }
    },

    // densify the distribution to all 5 stars and add percentages
    {
      $set: {
        rating_distribution: {
          $let: {
            vars: {
              buckets: "$rating_distribution",
              total: "$overall.total_reviews"
            },
            in: {
              $map: {
                input: STAR_LEVELS,
                as: "star",
                in: {
                  $let: {
                    vars: {
                      hit: {
                        $first: {
                          $filter: {
                            input: "$$buckets",
                            as: "bucket",
                            cond: { $eq: ["$$bucket._id", "$$star"] }
                          }
                        }
                      }
                    },
                    in: {
                      rating: "$$star",
                      count: { $ifNull: ["$$hit.count", 0] },
                      percentage: {
                        $cond: [
                          { $gt: ["$$total", 0] },
                          {
                            $round: [
                              {
                                $multiply: [
                                  {
                                    $divide: [
                                      { $ifNull: ["$$hit.count", 0] },
                                      "$$total"
                                    ]
                                  },
                                  100
                                ]
                              },
                              2
                            ]
                          },
                          0
                        ]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    },

    // label the window
    {
      $set: {
        window: {
          days: windowDays,
          from: windowStart,
          to: "$$NOW"
        }
      }
    }
  ];
}

/**
 * @param {number} windowDays
 * @returns {MongoDocument[]}
 */
function getReviewAnalytics(windowDays) {
  return db.PropertyReviews.aggregate(
    buildReviewAnalyticsPipeline(windowDays),
    { allowDiskUse: true } // use disk when memory overflow
  ).toArray();
}

/**
 * @param {number} windowDays
 * @returns {MongoDocument}
 */
function explainReviewAnalytics(windowDays) {
  return db.PropertyReviews.explain("executionStats").aggregate(
    buildReviewAnalyticsPipeline(windowDays),
    { allowDiskUse: true } // use disk when memory overflow
  );
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

if (db.PropertyReviews.estimatedDocumentCount() === 0) {
  throw new Error(
    "PropertyReviews is empty."
  );
}

const reviewExplainRequested = typeof EXPLAIN !== "undefined" && EXPLAIN === true;

if (reviewExplainRequested) {
  printjson(explainReviewAnalytics(REVIEW_WINDOW_DAYS));
} else {
  print(
    "Workflow 4: review analytics over the last " +
    REVIEW_WINDOW_DAYS +
    " days"
  );
  printjson(getReviewAnalytics(REVIEW_WINDOW_DAYS));
}