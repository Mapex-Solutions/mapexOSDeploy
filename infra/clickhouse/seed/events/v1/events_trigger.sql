-- =============================================================================
-- Table: events_trigger
-- Service: events
-- Version: v1
-- Description: Trigger execution history for debugging and analytics
-- Retention: 1-30 days (configurable per org)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_trigger;

CREATE TABLE events_trigger (
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    event_tracker_id String DEFAULT '',
    org_id String,
    path_key String DEFAULT '',
    trigger_id String,
    trigger_name String DEFAULT '',
    trigger_type String DEFAULT '',
    category String DEFAULT '',
    source String DEFAULT '',
    success UInt8 DEFAULT 0,
    duration_ms Int64 DEFAULT 0,
    error String DEFAULT '',
    request_data String DEFAULT '',
    response_data String DEFAULT '',
    retention_days UInt16 DEFAULT 7
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, trigger_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes for common query patterns
ALTER TABLE events_trigger ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_trigger ADD INDEX IF NOT EXISTS idx_trigger_id trigger_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_trigger ADD INDEX IF NOT EXISTS idx_trigger_type trigger_type TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_trigger ADD INDEX IF NOT EXISTS idx_source source TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_trigger ADD INDEX IF NOT EXISTS idx_success success TYPE minmax GRANULARITY 1;
ALTER TABLE events_trigger ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
