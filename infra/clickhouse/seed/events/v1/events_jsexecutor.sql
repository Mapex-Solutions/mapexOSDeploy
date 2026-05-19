-- =============================================================================
-- Table: events_jsexecutor
-- Service: events
-- Version: v2
-- Description: JS Executor debug logs for script execution tracking
-- Retention: 1-7 days (short, temporary data)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_jsexecutor;

CREATE TABLE events_jsexecutor (
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    event_tracker_id String DEFAULT '',
    thread_id String,
    org_id String,
    path_key String DEFAULT '',
    name String DEFAULT '',
    description String DEFAULT '',
    event String,
    success UInt8,
    failed_at String DEFAULT '',
    total_execution_time UInt32,
    error String DEFAULT '',
    retention_days UInt16 DEFAULT 1
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, path_key, thread_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes
ALTER TABLE events_jsexecutor ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_jsexecutor ADD INDEX IF NOT EXISTS idx_path_key path_key TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_jsexecutor ADD INDEX IF NOT EXISTS idx_thread_id thread_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_jsexecutor ADD INDEX IF NOT EXISTS idx_success success TYPE minmax GRANULARITY 1;
ALTER TABLE events_jsexecutor ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
