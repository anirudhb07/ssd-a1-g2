WITH daily_property_revenue AS (
    -- Step 1: Aggregate daily revenue per property
    SELECT 
        property_id,
        DATE(created_at) AS booking_date,
        SUM(total_cost) AS daily_revenue
    FROM bookings
    GROUP BY property_id, DATE(created_at)
),
moving_average_calc AS (
    -- Step 2: Compute 7-day moving average (current day + 6 days preceding)
    SELECT 
        property_id,
        booking_date,
        daily_revenue,
        AVG(daily_revenue) OVER (
            PARTITION BY property_id 
            ORDER BY booking_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS moving_avg_7d
    FROM daily_property_revenue
)
-- Step 3: Rank properties per day based on their 7-day moving average
SELECT 
    booking_date,
    property_id,
    daily_revenue,
    ROUND(moving_avg_7d, 2) AS moving_avg_7d,
    DENSE_RANK() OVER (
        PARTITION BY booking_date 
        ORDER BY moving_avg_7d DESC
    ) AS rank_by_moving_avg
FROM moving_average_calc
ORDER BY booking_date DESC, rank_by_moving_avg ASC;