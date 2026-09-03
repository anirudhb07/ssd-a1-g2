DROP PROCEDURE IF EXISTS process_booking_payment(UUID, UUID, DECIMAL);

CREATE OR REPLACE PROCEDURE process_booking_payment(
    p_guest_id UUID,
    p_property_id UUID,
    p_total_cost DECIMAL(10, 2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_balance DECIMAL(10, 2);
BEGIN
    -- 1. Lock guest row for update to prevent race conditions & check balance
    SELECT wallet_balance INTO v_current_balance
    FROM guests
    WHERE id = p_guest_id
    FOR UPDATE;

    -- Validate guest existence
    IF v_current_balance IS NULL THEN
        RAISE EXCEPTION 'Guest ID % not found', p_guest_id;
    END IF;

    -- 2. Validate sufficient funds
    IF v_current_balance < p_total_cost THEN
        RAISE EXCEPTION 'Insufficient balance. Available: %, Required: %', 
            v_current_balance, p_total_cost;
    END IF;

    -- 3. Deduct total cost from guest's wallet balance
    -- (This automatically fires trg_guest_wallet_audit to log the debit entry)
    UPDATE guests
    SET wallet_balance = wallet_balance - p_total_cost
    WHERE id = p_guest_id;

    -- 4. Insert booking record with status 'CONFIRMED'
    INSERT INTO bookings (guest_id, property_id, total_cost, status)
    VALUES (p_guest_id, p_property_id, p_total_cost, 'CONFIRMED');

    -- PL/pgSQL implicitly commits when the block completes without errors.
    -- If any EXCEPTION occurs anywhere in this block, PL/pgSQL automatically
    -- rolls back the entire transaction.

EXCEPTION
    WHEN OTHERS THEN
        -- Explicit rollback on error to ensure atomicity
        RAISE NOTICE 'Transaction failed: %. Rolling back...', SQLERRM;
        RAISE;
END;
$$;