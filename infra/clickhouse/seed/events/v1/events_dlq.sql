-- =============================================================================
-- Table: events_dlq
-- Service: events
-- Version: v1
-- Description: Dead Letter Queue events from all services
-- Retention: 30 days (configurable per message)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_dlq;

CREATE TABLE events_dlq (
    -- Created when message was sent to DLQ
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),

    -- Event tracking (for correlation across pipeline)
    event_tracker_id String DEFAULT '',

    -- Unique identifier
    id String,

    -- Tenant context (MANDATORY for multi-tenant filtering)
    org_id String,
    path_key String,

    -- Service context (for filtering)
    service_name String,
    service_type String,
    event_type String,

    -- Original message information
    original_subject String,
    original_stream String,
    original_data String,
    original_headers String,

    -- Error information
    last_error String,
    error_count UInt32,

    -- Delivery tracking
    first_delivery DateTime64(3, 'UTC'),
    last_delivery DateTime64(3, 'UTC'),
    total_deliveries UInt32,

    -- Consumer context
    consumer_name String,

    -- Retention
    retention_days UInt16 DEFAULT 30
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, service_name)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes for efficient querying
ALTER TABLE events_dlq ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_dlq ADD INDEX IF NOT EXISTS idx_service_name service_name TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_dlq ADD INDEX IF NOT EXISTS idx_service_type service_type TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_dlq ADD INDEX IF NOT EXISTS idx_event_type event_type TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_dlq ADD INDEX IF NOT EXISTS idx_id id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_dlq ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
