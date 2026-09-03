DROP MATERIALIZED VIEW IF EXISTS mv_property_performance CASCADE;

-- 1. Create Materialized View
CREATE MATERIALIZED VIEW mv_property_performance AS
SELECT 
    p.id AS property_id,
    p.title,
    COUNT(b.id) AS total_nights_booked, -- or SUM(b.nights) if a nights column is added later
    COALESCE(SUM(b.total_cost), 0.00) AS gross_revenue
FROM properties p
LEFT JOIN bookings b ON p.id = b.property_id
GROUP BY p.id, p.title;

-- 2. Create Unique Index (Required for REFRESH CONCURRENTLY)
CREATE UNIQUE INDEX idx_mv_property_performance_id 
ON mv_property_performance (property_id);

-- 3. Create Function to Refresh the View Concurrently
CREATE OR REPLACE FUNCTION refresh_property_performance_mv()
RETURNS VOID AS $$
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_property_performance;
$$ LANGUAGE sql;