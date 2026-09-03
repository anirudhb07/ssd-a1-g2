DROP TRIGGER IF EXISTS trg_guest_wallet_audit ON guests;
DROP FUNCTION IF EXISTS log_wallet_balance_change();

CREATE OR REPLACE FUNCTION log_wallet_balance_change()
RETURNS TRIGGER AS $$
DECLARE
    delta DECIMAL(10, 2);
    action WALLET_ACTION;
BEGIN
    delta := NEW.wallet_balance - OLD.wallet_balance;

    IF delta <> 0 THEN
        IF delta > 0 THEN
            action := 'CREDIT';
        ELSE
            action := 'DEBIT';
            delta := ABS(delta);
        END IF;

        INSERT INTO wallet_audit_logs (
            guest_id,
            amount_changed,
            action_type,
            balance_after
        )
        VALUES (
            NEW.id,
            delta,
            action,
            NEW.wallet_balance
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guest_wallet_audit
AFTER UPDATE OF wallet_balance ON guests
FOR EACH ROW
EXECUTE FUNCTION log_wallet_balance_change();