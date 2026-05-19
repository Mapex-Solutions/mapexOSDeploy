-- =============================================================================
-- Table: events_raw
-- Service: events
-- Version: v1
-- Description: Raw events from HTTP/MQTT gateways for debugging
-- Retention: 1-7 days (short, temporary data)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_raw;

CREATE TABLE events_raw (
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    event_tracker_id String DEFAULT '',
    thread_id String,
    org_id String,
    path_key String,
    source String,
    name String DEFAULT '',
    description String DEFAULT '',
    event String,
    metadata String,
    success UInt8,
    error String DEFAULT '',
    retention_days UInt16 DEFAULT 1
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, thread_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes
ALTER TABLE events_raw ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_raw ADD INDEX IF NOT EXISTS idx_source source TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_raw ADD INDEX IF NOT EXISTS idx_thread_id thread_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_raw ADD INDEX IF NOT EXISTS idx_success success TYPE minmax GRANULARITY 1;
ALTER TABLE events_raw ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
