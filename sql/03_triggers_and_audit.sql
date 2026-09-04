--
-- Step 2. Triggers
--
-- Audit logging
--
DROP TRIGGER IF EXISTS trg_guest_wallet_audit ON guests;

DROP FUNCTION IF EXISTS log_wallet_balance_change ();

CREATE
OR REPLACE FUNCTION log_wallet_balance_change () RETURNS TRIGGER AS $$
DECLARE
    v_delta  DECIMAL(10, 2);
    v_action WALLET_ACTION;
BEGIN
    -- delta != 0 guaranteed by trigger
    v_delta := NEW.wallet_balance - OLD.wallet_balance; 

    IF v_delta > 0 THEN
        v_action := 'CREDIT';
    ELSE
        v_action := 'DEBIT';
        v_delta := ABS(v_delta);
    END IF;

    INSERT INTO wallet_audit_logs (
        guest_id,
        amount_changed,
        action_type,
        balance_after
    )
    VALUES (
        NEW.id,
        v_delta,
        v_action,
        NEW.wallet_balance
    );

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guest_wallet_audit
AFTER
UPDATE OF wallet_balance ON guests FOR EACH ROW WHEN (
    OLD.wallet_balance IS DISTINCT
    FROM
        NEW.wallet_balance
        -- trigger only when wallet balance changes 
)
EXECUTE FUNCTION log_wallet_balance_change ();

--
-- Make audit log append-only
--
DROP TRIGGER IF EXISTS trg_wallet_audit_immutable_row ON wallet_audit_logs;

DROP TRIGGER IF EXISTS trg_wallet_audit_immutable_truncate ON wallet_audit_logs;

DROP FUNCTION IF EXISTS prevent_wallet_audit_mutation ();

CREATE
OR REPLACE FUNCTION prevent_wallet_audit_mutation () RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION
        'wallet_audit_logs is append-only: % is not permitted', TG_OP
        USING ERRCODE = 'insufficient_privilege',
              HINT = 'Correct a bad ledger entry by inserting a compensating row.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_wallet_audit_immutable_row BEFORE
UPDATE
OR DELETE ON wallet_audit_logs FOR EACH ROW
EXECUTE FUNCTION prevent_wallet_audit_mutation ();

-- TRUNCATE triggers
CREATE TRIGGER trg_wallet_audit_immutable_truncate BEFORE
TRUNCATE ON wallet_audit_logs FOR EACH STATEMENT
EXECUTE FUNCTION prevent_wallet_audit_mutation ();