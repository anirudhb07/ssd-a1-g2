-- Project 3: StaySpot - Vacation Rental & Experiences
-- Step 1: schema, data types, PK/FKs, CHECK constraints.
--
-- Assumptions documented here (the brief leaves these open):
--   * Surrogate keys are UUIDs generated server-side. gen_random_uuid() is
--     core from PostgreSQL 13 onward; no pgcrypto extension is needed.
--   * A booking carries an explicit stay window (check_in_date/check_out_date)
--     so that "total nights booked" is derivable. The brief lists neither
--     column, but its materialized view requires nights, which cannot be
--     recovered from a single created_at timestamp.
--   * wallet_audit_logs is append-only. Its rows must outlive the guest they
--     describe, so the FK is ON DELETE RESTRICT rather than CASCADE -- an
--     audit trail that a DELETE can erase is not an audit trail. Immutability
--     against UPDATE/DELETE/TRUNCATE is enforced in 03_triggers_and_audit.sql.
--
-- Idempotent: drops precede creates, so this file can be re-run as-is.

DROP TABLE IF EXISTS bookings CASCADE;

DROP TABLE IF EXISTS wallet_audit_logs CASCADE;

DROP TABLE IF EXISTS properties CASCADE;

DROP TABLE IF EXISTS guests CASCADE;

DROP TYPE IF EXISTS WALLET_ACTION;

DROP TYPE IF EXISTS BOOKING_STATUS;

-- Guests Table
CREATE TABLE guests (
    "id" UUID NOT NULL DEFAULT gen_random_uuid (),
    "name" VARCHAR(200) NOT NULL,
    "wallet_balance" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    CONSTRAINT guests_pkey PRIMARY KEY ("id"),
    CONSTRAINT guests_wallet_balance_check CHECK ("wallet_balance" >= 0.00),
    CONSTRAINT guests_name_check CHECK (LENGTH(TRIM("name")) > 0)
);

-- Wallet Audit Logs Table (append-only; see 03_triggers_and_audit.sql)
CREATE TYPE WALLET_ACTION AS ENUM('DEBIT', 'CREDIT');

CREATE TABLE wallet_audit_logs (
    "id" UUID NOT NULL DEFAULT gen_random_uuid (),
    "guest_id" UUID NOT NULL,
    "amount_changed" DECIMAL(10, 2) NOT NULL,
    "action_type" WALLET_ACTION NOT NULL,
    "balance_after" DECIMAL(10, 2) NOT NULL,
    "timestamp" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT wallet_audit_logs_pkey PRIMARY KEY ("id"),
    -- amount_changed is stored as a magnitude; action_type carries the sign.
    CONSTRAINT wallet_audit_logs_amount_changed_check CHECK ("amount_changed" > 0.00),
    CONSTRAINT wallet_audit_logs_balance_after_check CHECK ("balance_after" >= 0.00),
    CONSTRAINT wallet_audit_logs_guest_id_fkey FOREIGN KEY ("guest_id") REFERENCES guests ("id") ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Properties Table
CREATE TABLE properties (
    "id" UUID NOT NULL DEFAULT gen_random_uuid (),
    "title" VARCHAR(300) NOT NULL,
    "base_price" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    CONSTRAINT properties_pkey PRIMARY KEY ("id"),
    CONSTRAINT properties_base_price_check CHECK ("base_price" >= 0.00),
    -- Coordinates feed the MongoDB 2dsphere workflows; reject out-of-range
    -- values at the source rather than at query time.
    CONSTRAINT properties_latitude_check CHECK ("latitude" BETWEEN -90.0 AND 90.0),
    CONSTRAINT properties_longitude_check CHECK ("longitude" BETWEEN -180.0 AND 180.0)
);

-- Bookings Table
CREATE TYPE BOOKING_STATUS AS ENUM('CONFIRMED', 'CHECKED_IN', 'COMPLETED');

CREATE TABLE bookings (
    "id" UUID NOT NULL DEFAULT gen_random_uuid (),
    "guest_id" UUID NOT NULL,
    "property_id" UUID NOT NULL,
    "total_cost" DECIMAL(10, 2) NOT NULL,
    "status" BOOKING_STATUS NOT NULL,
    "check_in_date" DATE NOT NULL,
    "check_out_date" DATE NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT bookings_pkey PRIMARY KEY ("id"),
    -- A booking must cost something: this is what stops a negative total_cost
    -- from being used to credit a wallet via the checkout procedure.
    CONSTRAINT bookings_total_cost_check CHECK ("total_cost" > 0.00),
    -- A stay is at least one night.
    CONSTRAINT bookings_stay_window_check CHECK ("check_out_date" > "check_in_date"),
    CONSTRAINT bookings_guest_id_fkey FOREIGN KEY ("guest_id") REFERENCES guests ("id") ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT bookings_property_id_fkey FOREIGN KEY ("property_id") REFERENCES properties ("id") ON UPDATE CASCADE ON DELETE CASCADE
);
