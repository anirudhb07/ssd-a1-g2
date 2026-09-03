DROP INDEX IF EXISTS idx_active_stay;

-- Partial Index: Prevents multiple overlapping check-ins for the same guest
CREATE UNIQUE INDEX idx_active_stay 
ON bookings (guest_id) 
WHERE status = 'CHECKED_IN';