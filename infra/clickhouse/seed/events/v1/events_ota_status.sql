-- =============================================================================
-- Table: events_ota_status
-- Service: events
-- Version: v1
-- Description: Per-device OTA (firmware update) status history. One row per
--              device status transition (downloading -> ... -> updated/failed)
--              published by the Asset MS on each device progress report.
-- Retention: default 90 days (configurable per org via retention_days)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_ota_status;

CREATE TABLE events_ota_status (
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    org_id String,
    asset_uuid String DEFAULT '',
    plan_id String DEFAULT '',
    ota_execution_id String DEFAULT '',
    status String DEFAULT '',
    progress Int32 DEFAULT 0,
    error String DEFAULT '',
    message String DEFAULT '',
    retention_days UInt16 DEFAULT 90
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, ota_execution_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes for common query patterns (per-org, per-plan, per-execution timelines)
ALTER TABLE events_ota_status ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_ota_status ADD INDEX IF NOT EXISTS idx_plan_id plan_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_ota_status ADD INDEX IF NOT EXISTS idx_ota_execution_id ota_execution_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_ota_status ADD INDEX IF NOT EXISTS idx_asset_uuid asset_uuid TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_ota_status ADD INDEX IF NOT EXISTS idx_status status TYPE bloom_filter GRANULARITY 1;
