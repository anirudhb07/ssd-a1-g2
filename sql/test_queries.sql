-- Select an existing guest and property ID from your database
DO $$
DECLARE
    v_guest_id UUID;
    v_property_id UUID;
BEGIN
    SELECT id INTO v_guest_id FROM guests LIMIT 1;
    SELECT id INTO v_property_id FROM properties LIMIT 1;

    -- Ensure guest has sufficient balance for test
    UPDATE guests SET wallet_balance = 500.00 WHERE id = v_guest_id;

    -- Execute stored procedure
    CALL process_booking_payment(v_guest_id, v_property_id, 150.00);
END $$;

-- Verify that the new booking was inserted and wallet balance was deducted
SELECT * FROM bookings ORDER BY created_at DESC LIMIT 1;
SELECT * FROM wallet_audit_logs ORDER BY timestamp DESC LIMIT 1;