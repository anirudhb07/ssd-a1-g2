-- Workflow 1: Atomic Booking (stored procedure).
--
-- Deducts the guest's balance, inserts the booking (which fires the wallet
-- audit trigger), and COMMITs. Rolls back gracefully on CHECK constraint
-- failure -- notably the guests.wallet_balance >= 0 constraint, which is what
-- rejects an over-spend.
--
-- IMPORTANT CALLING CONVENTION
--   This procedure performs its own transaction control, so it must be CALLed
--   at the top level of a session (psql autocommit). PostgreSQL raises
--   2D000 "invalid_transaction_termination" if a procedure that COMMITs is
--   invoked from inside an explicit BEGIN ... END block, a DO block, or
--   another function. See test_queries.sql for the correct invocation.
--
-- WHY THE WORK SITS IN A NESTED BLOCK
--   PL/pgSQL cannot COMMIT inside a block that carries an EXCEPTION clause --
--   the handler opens an implicit subtransaction and the commit fails with
--   2D000 "cannot commit while a subtransaction is active". So the outer
--   block owns the transaction control (it has no EXCEPTION clause) and a
--   nested block owns the error handling. Once the nested handler returns,
--   the subtransaction is closed and the outer block is free to COMMIT or
--   ROLLBACK.

DROP PROCEDURE IF EXISTS process_booking_payment (UUID, UUID, DECIMAL);

DROP PROCEDURE IF EXISTS process_booking_payment (UUID, UUID, DECIMAL, DATE, INTEGER);

CREATE
OR REPLACE PROCEDURE process_booking_payment (
    p_guest_id UUID,
    p_property_id UUID,
    p_total_cost DECIMAL(10, 2),
    p_check_in DATE DEFAULT CURRENT_DATE,
    p_nights INTEGER DEFAULT 1
) LANGUAGE plpgsql AS $$
DECLARE
    v_balance    DECIMAL(10, 2);
    v_booking_id UUID;
    v_failed     BOOLEAN;
    v_errmsg     TEXT;
    v_errstate   TEXT;
BEGIN
    -- CALL runs inside an implicit transaction that already holds a snapshot.
    -- End it so the work below runs in a transaction whose isolation level we
    -- choose. SET TRANSACTION must be the first statement of the new
    -- transaction, so nothing may come between these two lines.
    COMMIT;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    v_failed := FALSE;

    BEGIN
        -- Reject a non-positive charge before touching the wallet: a negative
        -- p_total_cost would otherwise *credit* the balance. The
        -- bookings_total_cost_check constraint is the backstop, this is the
        -- readable error.
        IF p_total_cost IS NULL OR p_total_cost <= 0 THEN
            RAISE EXCEPTION 'total_cost must be positive, got %', p_total_cost
                USING ERRCODE = 'check_violation';
        END IF;

        IF p_nights IS NULL OR p_nights < 1 THEN
            RAISE EXCEPTION 'a stay must be at least 1 night, got %', p_nights
                USING ERRCODE = 'check_violation';
        END IF;

        -- Lock the guest row. Under REPEATABLE READ this both serialises
        -- concurrent checkouts for the same guest and surfaces a concurrent
        -- writer as a 40001 serialization_failure, handled below.
        SELECT wallet_balance INTO v_balance
        FROM guests
        WHERE id = p_guest_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Guest % not found', p_guest_id
                USING ERRCODE = 'foreign_key_violation';
        END IF;

        -- Deduct. Deliberately NOT pre-tested against p_total_cost: the
        -- guests_wallet_balance_check CHECK constraint is the single authority
        -- on solvency, and its violation is what the handler below catches.
        -- A pre-flight IF would make that constraint unreachable dead weight.
        UPDATE guests
        SET wallet_balance = wallet_balance - p_total_cost
        WHERE id = p_guest_id;

        -- Fires trg_guest_wallet_audit, writing the immutable DEBIT record.
        INSERT INTO bookings (
            guest_id,
            property_id,
            total_cost,
            status,
            check_in_date,
            check_out_date
        )
        VALUES (
            p_guest_id,
            p_property_id,
            p_total_cost,
            'CONFIRMED',
            p_check_in,
            p_check_in + p_nights
        )
        RETURNING id INTO v_booking_id;

    EXCEPTION
        WHEN check_violation THEN
            -- Insufficient funds lands here, via guests_wallet_balance_check.
            v_failed   := TRUE;
            v_errstate := SQLSTATE;
            v_errmsg   := SQLERRM;
        WHEN serialization_failure THEN
            -- Another transaction touched this guest first. Safe to retry.
            v_failed   := TRUE;
            v_errstate := SQLSTATE;
            v_errmsg   := SQLERRM;
        WHEN unique_violation THEN
            -- e.g. idx_active_stay, if this booking were created CHECKED_IN.
            v_failed   := TRUE;
            v_errstate := SQLSTATE;
            v_errmsg   := SQLERRM;
        WHEN foreign_key_violation THEN
            -- Unknown guest or property.
            v_failed   := TRUE;
            v_errstate := SQLSTATE;
            v_errmsg   := SQLERRM;
    END;

    IF v_failed THEN
        -- Discards the wallet deduction, the booking, and the audit row the
        -- trigger wrote -- all three, or none.
        ROLLBACK;
        RAISE WARNING 'Booking rejected [%]: %', v_errstate, v_errmsg;
    ELSE
        COMMIT;
        RAISE NOTICE 'Booking % committed for guest %', v_booking_id, p_guest_id;
    END IF;
END;
$$;
