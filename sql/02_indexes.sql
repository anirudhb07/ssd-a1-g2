-- Step 2: partial indexes and secondary indexes.
-- Requires PostgreSQL 11+ for INCLUDE (covering) indexes.

-- ---------------------------------------------------------------------------
-- 1. Partial UNIQUE index (from the brief): a guest may hold at most one
--    CHECKED_IN stay at a time. Partial, so the uniqueness applies only to
--    the small set of live stays -- CONFIRMED and COMPLETED rows are not
--    indexed at all and a guest may have any number of them.
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_active_stay;

CREATE UNIQUE INDEX idx_active_stay ON bookings (guest_id)
WHERE
    status = 'CHECKED_IN';

-- ---------------------------------------------------------------------------
-- 2. Covering index for Workflow 2 (06_window_analytics.sql).
--    That query scans a bounded recent window of bookings and needs only
--    created_at, property_id and total_cost. Leading on created_at makes the
--    window a single contiguous range; INCLUDE-ing total_cost lets the
--    planner satisfy the whole aggregate from the index (Index Only Scan)
--    without touching the heap.
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_bookings_created_at_property;

CREATE INDEX idx_bookings_created_at_property ON bookings (created_at, property_id) INCLUDE (total_cost);

-- ---------------------------------------------------------------------------
-- 3. Partial index on realised revenue. The materialized view and any
--    "completed stays" report filter on status = 'COMPLETED'; indexing only
--    those rows keeps the index roughly half the size of the full table's.
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_bookings_completed_property;

CREATE INDEX idx_bookings_completed_property ON bookings (property_id) INCLUDE (total_cost, check_in_date, check_out_date)
WHERE
    status = 'COMPLETED';

-- ---------------------------------------------------------------------------
-- 4. Secondary index: per-property booking history, newest first.
--    Also serves the ON DELETE CASCADE referential check for properties,
--    which would otherwise seq-scan bookings on every property delete.
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_bookings_property_created_at;

CREATE INDEX idx_bookings_property_created_at ON bookings (property_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 5. Secondary index: per-guest booking history, newest first.
--    Serves the guests ON DELETE CASCADE check as well.
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_bookings_guest_created_at;

CREATE INDEX idx_bookings_guest_created_at ON bookings (guest_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 6. Secondary index: a guest's wallet ledger, newest first. PostgreSQL does
--    not index the referencing side of a FK automatically, so without this
--    the ON DELETE RESTRICT check on wallet_audit_logs.guest_id seq-scans
--    100k+ audit rows for every attempted guest delete.
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_wallet_audit_logs_guest_timestamp;

CREATE INDEX idx_wallet_audit_logs_guest_timestamp ON wallet_audit_logs (guest_id, "timestamp" DESC);
