
-- 1. Required Partial Unique Index
-- This index enforces the business rule that a guest can only have at most
-- ONE active 'CHECKED_IN' booking at any given time.
CREATE UNIQUE INDEX idx_active_stay 
ON bookings (guest_id) 
WHERE status = 'CHECKED_IN';

-- 2. Foreign Key Performance Indexes
-- PostgreSQL does not automatically index foreign keys. We index them here to
-- prevent full table scans when joining tables or performing cascades.
CREATE INDEX IF NOT EXISTS idx_bookings_guest_id ON bookings (guest_id);
CREATE INDEX IF NOT EXISTS idx_bookings_property_id ON bookings (property_id);
CREATE INDEX IF NOT EXISTS idx_wallet_audit_logs_guest_id ON wallet_audit_logs (guest_id);

-- 3. Query Performance & Analytical Indexes
-- These support fast sorting and filtering in analytics (Workflow 2 and 3)
CREATE INDEX IF NOT EXISTS idx_bookings_status_created ON bookings (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_audit_timestamp ON wallet_audit_logs ("timestamp" DESC);