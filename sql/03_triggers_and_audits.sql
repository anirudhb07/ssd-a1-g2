-- ============================================================================
-- Project 3: StaySpot – Vacation Rental & Experiences
-- Script: 03_triggers_and_audit.sql
-- Description: Trigger function and binding for automated wallet auditing.
-- ============================================================================

-- Create or replace the trigger function
CREATE OR REPLACE FUNCTION fn_audit_guest_wallet_update()
RETURNS TRIGGER AS $$
DECLARE
    v_amount_changed DECIMAL(10, 2);
    v_action_type WALLET_ACTION;
BEGIN
    -- Only execute audit insert if the wallet balance has actually changed
    IF NEW.wallet_balance IS DISTINCT FROM OLD.wallet_balance THEN
        -- Calculate difference
        v_amount_changed := NEW.wallet_balance - OLD.wallet_balance;
        
        -- Determine if it's a credit or a debit
        IF v_amount_changed > 0 THEN
            v_action_type := 'CREDIT'::WALLET_ACTION;
        ELSE
            v_action_type := 'DEBIT'::WALLET_ACTION;
            v_amount_changed := ABS(v_amount_changed); -- Ensure amount logged is positive
        END IF;

        -- Insert the immutable audit record
        INSERT INTO wallet_audit_logs (
            guest_id, 
            amount_changed, 
            action_type, 
            balance_after, 
            timestamp
        ) VALUES (
            NEW.id, 
            v_amount_changed, 
            v_action_type, 
            NEW.wallet_balance, 
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Bind the trigger to the guests table
DROP TRIGGER IF EXISTS trg_audit_wallet_balance ON guests;

CREATE TRIGGER trg_audit_wallet_balance
AFTER UPDATE OF wallet_balance ON guests
FOR EACH ROW
EXECUTE FUNCTION fn_audit_guest_wallet_update();