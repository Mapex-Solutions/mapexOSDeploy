-- =============================================================================
-- Table: events_router
-- Service: events
-- Version: v1
-- Description: Router execution history for debugging and UI visualization
-- Retention: 1-30 days (configurable per org)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_router;

CREATE TABLE events_router (
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    event_tracker_id String DEFAULT '',
    thread_id String,
    org_id String,
    path_key String DEFAULT '',
    asset_id String DEFAULT '',
    router_id String,
    name String DEFAULT '',
    description String DEFAULT '',

    -- Counters (agregados by Events service)
    total_routers UInt8 DEFAULT 0,
    matched_count UInt8 DEFAULT 0,
    published_count UInt8 DEFAULT 0,

    -- Routers array as JSON string
    event String,

    success UInt8,
    error String DEFAULT '',
    retention_days UInt16 DEFAULT 1
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, router_id, thread_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes for common query patterns
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_router_id router_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_thread_id thread_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_asset_id asset_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_success success TYPE minmax GRANULARITY 1;
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_matched_count matched_count TYPE minmax GRANULARITY 1;
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_published_count published_count TYPE minmax GRANULARITY 1;
ALTER TABLE events_router ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
