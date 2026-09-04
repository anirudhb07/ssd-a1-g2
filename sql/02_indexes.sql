--- ---------------------------
--- Step 2 Indexes
--- ---------------------------
-- Partial UNIQUE index: guests who are CHECKED_IN
DROP INDEX IF EXISTS idx_active_stay;

CREATE UNIQUE INDEX idx_active_stay ON bookings (guest_id)
WHERE
    status = 'CHECKED_IN';

-- Index for Workflow 2
DROP INDEX IF EXISTS idx_bookings_created_at_property;

CREATE INDEX idx_bookings_created_at_property ON bookings (created_at, property_id) INCLUDE (total_cost);

-- Partial index on realized revenue 
DROP INDEX IF EXISTS idx_bookings_completed_property;

CREATE INDEX idx_bookings_completed_property ON bookings (property_id) INCLUDE (total_cost, check_in_date, check_out_date)
WHERE
    status = 'COMPLETED';

-- Secondary index: per-property booking history, newest first
DROP INDEX IF EXISTS idx_bookings_property_created_at;

CREATE INDEX idx_bookings_property_created_at ON bookings (property_id, created_at DESC);

-- Secondary index: per-guest booking history, newest first
DROP INDEX IF EXISTS idx_bookings_guest_created_at;

CREATE INDEX idx_bookings_guest_created_at ON bookings (guest_id, created_at DESC);

-- Secondary index: a guest's wallet ledger, newest first
DROP INDEX IF EXISTS idx_wallet_audit_logs_guest_timestamp;

CREATE INDEX idx_wallet_audit_logs_guest_timestamp ON wallet_audit_logs (guest_id, "timestamp" DESC);