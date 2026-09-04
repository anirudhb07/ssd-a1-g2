--
-- Step 3
-- Workflow 2: SQL window analytics.
--
WITH
    daily_property_revenue AS (
        -- Sparse: one row per (property, day) that actually had a booking.
        SELECT
            b.property_id,
            (b.created_at AT TIME ZONE 'UTC')::date AS booking_date,
            SUM(b.total_cost) AS daily_revenue
        FROM
            bookings b
        WHERE
            b.created_at >= ((CURRENT_DATE - 36)::TIMESTAMP AT TIME ZONE 'UTC')
            AND b.created_at < ((CURRENT_DATE + 1)::TIMESTAMP AT TIME ZONE 'UTC')
        GROUP BY
            b.property_id,
            (b.created_at AT TIME ZONE 'UTC')::date
    ),
    active_properties AS (
        -- Only properties with activity in the window
        SELECT DISTINCT
            property_id
        FROM
            daily_property_revenue
    ),
    calendar AS (
        -- The date spine, including the 6-day lead-in.
        SELECT
            g.d::date AS booking_date
        FROM
            GENERATE_SERIES(
                (CURRENT_DATE - 36)::TIMESTAMP,
                CURRENT_DATE::TIMESTAMP,
                INTERVAL '1 day'
            ) AS g (d)
    ),
    dense_daily_revenue AS (
        -- Dense: every (property, day) pair in the window, zero-filled.
        SELECT
            ap.property_id,
            c.booking_date,
            COALESCE(dpr.daily_revenue, 0.00) AS daily_revenue
        FROM
            active_properties ap
            CROSS JOIN calendar c
            LEFT JOIN daily_property_revenue dpr ON dpr.property_id = ap.property_id
            AND dpr.booking_date = c.booking_date
    ),
    moving_average_calc AS (
        -- RANGE + INTERVAL
        SELECT
            property_id,
            booking_date,
            daily_revenue,
            AVG(daily_revenue) OVER w AS moving_avg_7d,
            SUM(daily_revenue) OVER w AS trailing_7d_revenue,
            COUNT(*) OVER w AS days_in_window
        FROM
            dense_daily_revenue
        WINDOW
            w AS (
                PARTITION BY
                    property_id
                ORDER BY
                    booking_date RANGE BETWEEN INTERVAL '6 days' PRECEDING
                    AND CURRENT ROW
            )
    )
SELECT
    booking_date,
    property_id,
    daily_revenue,
    ROUND(moving_avg_7d, 2) AS moving_avg_7d,
    trailing_7d_revenue,
    days_in_window,
    DENSE_RANK() OVER (
        PARTITION BY
            booking_date
        ORDER BY
            moving_avg_7d DESC
    ) AS rank_by_moving_avg
FROM
    moving_average_calc
WHERE
    -- Drop the lead-in days
    booking_date >= (CURRENT_DATE - 30)
ORDER BY
    booking_date DESC,
    rank_by_moving_avg ASC,
    property_id ASC;