--
-- Step 1. Schema & Constraints
--
DROP TABLE IF EXISTS bookings CASCADE;

DROP TABLE IF EXISTS wallet_audit_logs CASCADE;

DROP TABLE IF EXISTS properties CASCADE;

DROP TABLE IF EXISTS guests CASCADE;

DROP TYPE IF EXISTS WALLET_ACTION;

DROP TYPE IF EXISTS BOOKING_STATUS;

--
-- Guests Table
--
CREATE TABLE
    guests (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "name" VARCHAR(200) NOT NULL,
        "wallet_balance" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        CONSTRAINT guests_pkey PRIMARY KEY ("id"),
        CONSTRAINT guests_wallet_balance_check CHECK ("wallet_balance" >= 0.00),
        CONSTRAINT guests_name_check CHECK (LENGTH(TRIM("name")) > 0)
    );

--
-- Wallet Audit Logs Table
--
CREATE TYPE WALLET_ACTION AS ENUM('DEBIT', 'CREDIT');

CREATE TABLE
    wallet_audit_logs (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "guest_id" UUID NOT NULL,
        "amount_changed" DECIMAL(10, 2) NOT NULL,
        "action_type" WALLET_ACTION NOT NULL,
        "balance_after" DECIMAL(10, 2) NOT NULL,
        "timestamp" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT wallet_audit_logs_pkey PRIMARY KEY ("id"),
        CONSTRAINT wallet_audit_logs_amount_changed_check CHECK ("amount_changed" > 0.00), -- magnitude only
        CONSTRAINT wallet_audit_logs_balance_after_check CHECK ("balance_after" >= 0.00),
        CONSTRAINT wallet_audit_logs_guest_id_fkey FOREIGN KEY ("guest_id") REFERENCES guests ("id") ON UPDATE CASCADE ON DELETE RESTRICT
    );

--
-- Properties Table
--
CREATE TABLE
    properties (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "title" VARCHAR(300) NOT NULL,
        "base_price" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        "latitude" DOUBLE PRECISION NOT NULL,
        "longitude" DOUBLE PRECISION NOT NULL,
        CONSTRAINT properties_pkey PRIMARY KEY ("id"),
        CONSTRAINT properties_base_price_check CHECK ("base_price" >= 0.00),
        CONSTRAINT properties_latitude_check CHECK ("latitude" BETWEEN -90.0 AND 90.0),
        CONSTRAINT properties_longitude_check CHECK ("longitude" BETWEEN -180.0 AND 180.0)
    );

--
-- Bookings Table
--
CREATE TYPE BOOKING_STATUS AS ENUM('CONFIRMED', 'CHECKED_IN', 'COMPLETED');

CREATE TABLE
    bookings (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "guest_id" UUID NOT NULL,
        "property_id" UUID NOT NULL,
        "total_cost" DECIMAL(10, 2) NOT NULL,
        "status" BOOKING_STATUS NOT NULL,
        "check_in_date" DATE NOT NULL,
        "check_out_date" DATE NOT NULL,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT bookings_pkey PRIMARY KEY ("id"),
        CONSTRAINT bookings_total_cost_check CHECK ("total_cost" > 0.00),
        CONSTRAINT bookings_stay_window_check CHECK ("check_out_date" > "check_in_date"), -- stay is atleast 1 day
        CONSTRAINT bookings_guest_id_fkey FOREIGN KEY ("guest_id") REFERENCES guests ("id") ON UPDATE CASCADE ON DELETE CASCADE,
        CONSTRAINT bookings_property_id_fkey FOREIGN KEY ("property_id") REFERENCES properties ("id") ON UPDATE CASCADE ON DELETE CASCADE
    );