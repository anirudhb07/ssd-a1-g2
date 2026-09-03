-- Step 2: materialized view definition & concurrent refresh.
--
-- Summarises each property by total nights booked and gross revenue.
--
-- Assumptions:
--   * "Nights" is check_out_date - check_in_date summed over bookings. This is
--     why 01_schema_ddl.sql carries an explicit stay window; counting booking
--     rows would answer a different question.
--   * gross_revenue counts every booking regardless of status, since a
--     CONFIRMED stay is money already committed. realised_* is the
--     COMPLETED-only subset, for the stricter reading of "revenue".
--   * Properties with no bookings are retained (LEFT JOIN) with zeroes, so the
--     view is a complete property roster rather than only the booked ones.

DROP MATERIALIZED VIEW IF EXISTS mv_property_performance CASCADE;

-- ---------------------------------------------------------------------------
-- 1. The view
-- ---------------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_property_performance AS
SELECT
    p.id AS property_id,
    p.title,
    COUNT(b.id) AS total_bookings,
    COALESCE(SUM(b.check_out_date - b.check_in_date), 0) AS total_nights_booked,
    COALESCE(SUM(b.total_cost), 0.00) AS gross_revenue,
    COUNT(b.id) FILTER (
        WHERE
            b.status = 'COMPLETED'
    ) AS realised_bookings,
    COALESCE(
        SUM(b.check_out_date - b.check_in_date) FILTER (
            WHERE
                b.status = 'COMPLETED'
        ),
        0
    ) AS realised_nights,
    COALESCE(
        SUM(b.total_cost) FILTER (
            WHERE
                b.status = 'COMPLETED'
        ),
        0.00
    ) AS realised_revenue
FROM
    properties p
    LEFT JOIN bookings b ON p.id = b.property_id
GROUP BY
    p.id,
    p.title;

-- ---------------------------------------------------------------------------
-- 2. UNIQUE index -- mandatory for REFRESH ... CONCURRENTLY, which needs a key
--    to diff the old and new snapshots row by row.
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX idx_mv_property_performance_id ON mv_property_performance (property_id);

-- Secondary index for the common "rank properties by revenue" read.
CREATE INDEX idx_mv_property_performance_revenue ON mv_property_performance (gross_revenue DESC);

-- ---------------------------------------------------------------------------
-- 3. Refresh function.
--    plpgsql, not sql: a LANGUAGE sql body is planned as a single unit up
--    front, which makes utility statements like REFRESH awkward at best.
--
--    CONCURRENTLY takes only an EXCLUSIVE lock instead of ACCESS EXCLUSIVE, so
--    readers keep querying the old snapshot throughout the rebuild. It is
--    slower than a plain refresh and requires the view to be already
--    populated -- it is, because CREATE MATERIALIZED VIEW defaults to
--    WITH DATA.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS refresh_property_performance_mv ();

CREATE
OR REPLACE FUNCTION refresh_property_performance_mv () RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_property_performance;
END;
$$ LANGUAGE plpgsql;
