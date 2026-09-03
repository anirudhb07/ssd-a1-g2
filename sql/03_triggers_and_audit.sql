-- Step 2: audit log triggers.

-- ---------------------------------------------------------------------------
-- 1. Audit logging: every change to guests.wallet_balance is recorded.
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_guest_wallet_audit ON guests;

DROP FUNCTION IF EXISTS log_wallet_balance_change ();

CREATE
OR REPLACE FUNCTION log_wallet_balance_change () RETURNS TRIGGER AS $$
DECLARE
    v_delta  DECIMAL(10, 2);
    v_action WALLET_ACTION;
BEGIN
    -- The trigger's WHEN clause guarantees a real change, so v_delta <> 0.
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

    -- Return value is ignored for AFTER triggers.
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- AFTER UPDATE OF wallet_balance fires whenever the column appears in the
-- SET list, even when the value is unchanged. The WHEN clause filters those
-- no-op updates out in the executor, so the function body is never entered
-- for them -- cheaper than testing the delta inside the function once the
-- table holds 100k+ rows.
CREATE TRIGGER trg_guest_wallet_audit
AFTER
UPDATE OF wallet_balance ON guests FOR EACH ROW
WHEN (
    OLD.wallet_balance IS DISTINCT FROM NEW.wallet_balance
)
EXECUTE FUNCTION log_wallet_balance_change ();

-- ---------------------------------------------------------------------------
-- 2. Immutability: the brief calls for an "immutable record", so the audit
--    table must reject every write except INSERT. Without this, the ledger
--    is only as trustworthy as the last person to hold write access.
--
--    The FK from wallet_audit_logs to guests is ON DELETE RESTRICT
--    (01_schema_ddl.sql), so deleting a guest cannot silently cascade the
--    ledger away either.
--
--    Note that DROP TABLE is unaffected -- DDL does not fire DML triggers.
--    These guard the data, not the schema.
-- ---------------------------------------------------------------------------
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

-- TRUNCATE triggers must be FOR EACH STATEMENT, hence the second trigger.
CREATE TRIGGER trg_wallet_audit_immutable_truncate BEFORE TRUNCATE ON wallet_audit_logs FOR EACH STATEMENT
EXECUTE FUNCTION prevent_wallet_audit_mutation ();
