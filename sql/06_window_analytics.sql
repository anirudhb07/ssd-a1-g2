-- Workflow 2: SQL window analytics.
-- 7-day moving average of booking revenue per property, ranked by DENSE_RANK.
--
-- THREE THINGS THIS QUERY IS CAREFUL ABOUT
--
-- 1. "7 days" means seven calendar days, not seven rows. Aggregating bookings
--    by day produces a *sparse* series -- a property with no booking on a
--    given day has no row for it. A ROWS BETWEEN 6 PRECEDING frame over that
--    series averages the last seven days *that had bookings*, which for a
--    quiet property can span months. Fixed two ways at once: a generated date
--    spine makes the series dense, and a RANGE ... INTERVAL frame measures the
--    window in time rather than in rows.
--
-- 2. Day boundaries are pinned to UTC. DATE(created_at) on a TIMESTAMPTZ is
--    resolved using the *client session's* TimeZone setting, so the same data
--    bucketed by two different sessions yields two different answers.
--
-- 3. The reported window is bounded and the bookings scan is index-driven.
--    An unbounded scan can only ever produce a Seq Scan; the WHERE clause
--    below is a contiguous range on created_at, served by
--    idx_bookings_created_at_property as an Index Only Scan.
--
-- Assumptions:
--   * Revenue is attributed to the day the booking was created, not the nights
--     stayed, and all statuses count (a CONFIRMED booking is committed money).
--   * DENSE_RANK partitions by day, so rank 1 is the top-earning property on
--     that date. Ties share a rank and consume no rank numbers.
--   * The report covers the trailing 30 days. Bookings are scanned from 36
--     days back so that the earliest reported day has a full 7-day lead-in
--     rather than a truncated average.
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
            b.created_at >= ((CURRENT_DATE - 36)::timestamp AT TIME ZONE 'UTC')
            AND b.created_at < ((CURRENT_DATE + 1)::timestamp AT TIME ZONE 'UTC')
        GROUP BY
            b.property_id,
            (b.created_at AT TIME ZONE 'UTC')::date
    ),
    active_properties AS (
        -- Only properties with activity in the window. Building a spine for
        -- every property in the table would inflate the join with rows that
        -- are all-zero and never reportable.
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
            generate_series(
                (CURRENT_DATE - 36)::timestamp,
                CURRENT_DATE::timestamp,
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
        -- RANGE + INTERVAL: the frame is "this day and the 6 calendar days
        -- before it". Over the dense series above, ROWS BETWEEN 6 PRECEDING
        -- would give the same answer -- but only because the series is dense,
        -- which is exactly the assumption that is easy to lose later.
        -- days_in_window is carried through as proof the frame is full.
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
                    booking_date RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
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
    -- Drop the lead-in days: their averages would be computed over fewer
    -- than 7 days and are not comparable to the rest.
    booking_date >= (CURRENT_DATE - 30)
ORDER BY
    booking_date DESC,
    rank_by_moving_avg ASC,
    property_id ASC;
