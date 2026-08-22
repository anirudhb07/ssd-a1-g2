DROP TABLE IF EXISTS bookings CASCADE;

DROP TABLE IF EXISTS wallet_audit_logs CASCADE;

DROP TABLE IF EXISTS properties CASCADE;

DROP TABLE IF EXISTS guests CASCADE;

-- Guest Table
CREATE TABLE IF NOT EXISTS
    guests (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "name" VARCHAR NOT NULL,
        "wallet_balance" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        CONSTRAINT guests_pkey PRIMARY KEY ("id"),
        CHECK ("wallet_balance" >= 0.00)
    );

-- Wallet Audit Logs Table
CREATE TYPE WALLET_ACTION AS ENUM('DEBIT', 'CREDIT');

CREATE TABLE IF NOT EXISTS
    wallet_audit_logs (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "guest_id" UUID NOT NULL,
        "amount_changed" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        "action_type" WALLET_ACTION NOT NULL,
        "balance_after" DECIMAL(10, 2) NOT NULL,
        "timestamp" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT wallet_audit_logs_pkey PRIMARY KEY ("id"),
        CONSTRAINT wallet_audit_logs_guest_id_fkey FOREIGN KEY ("guest_id") REFERENCES guests ("id") ON UPDATE CASCADE ON DELETE CASCADE
    );

-- Properties Table
CREATE TABLE IF NOT EXISTS
    properties (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "title" VARCHAR NOT NULL,
        "base_price" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        "latitude" DOUBLE PRECISION NOT NULL,
        "longitude" DOUBLE PRECISION NOT NULL,
        CONSTRAINT properties_pkey PRIMARY KEY ("id")
    );

-- Bookings Table
CREATE TYPE BOOKING_STATUS AS ENUM('CONFIRMED', 'CHECKED_IN', 'COMPLETED');

CREATE TABLE IF NOT EXISTS
    bookings (
        "id" UUID NOT NULL DEFAULT gen_random_uuid (),
        "guest_id" UUID NOT NULL,
        "property_id" UUID NOT NULL,
        "total_cost" DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        "status" BOOKING_STATUS NOT NULL,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT bookings_pkey PRIMARY KEY ("id"),
        CONSTRAINT bookings_guest_id_fkey FOREIGN KEY ("guest_id") REFERENCES guests ("id") ON UPDATE CASCADE ON DELETE CASCADE,
        CONSTRAINT bookings_property_id_fkey FOREIGN KEY ("property_id") REFERENCES properties ("id") ON UPDATE CASCADE ON DELETE CASCADE
    );