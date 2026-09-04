--
-- Step 2: Materialized views
--
DROP MATERIALIZED VIEW IF EXISTS mv_property_performance CASCADE;

-- Materialized View
CREATE MATERIALIZED VIEW
    mv_property_performance AS
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

-- UNIQUE index 
CREATE UNIQUE INDEX idx_mv_property_performance_id ON mv_property_performance (property_id);

-- Secondary index for "rank properties by revenue"
CREATE INDEX idx_mv_property_performance_revenue ON mv_property_performance (gross_revenue DESC);

-- Refresh function
DROP FUNCTION IF EXISTS refresh_property_performance_mv ();

CREATE
OR REPLACE FUNCTION refresh_property_performance_mv () RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_property_performance;
END;
$$ LANGUAGE plpgsql;