-- =============================================================================
-- Table: asset_status_history
-- Service: events
-- Version: v1
-- Description: Asset connectivity transitions (offline/online) for timeline UI.
-- Retention: configurable via retention policy (default 7 days, min 1, max 90).
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;
USE mapexos;

DROP TABLE IF EXISTS asset_status_history;

CREATE TABLE asset_status_history (
    created           DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    org_id            String,
    path_key          String,
    asset_uuid        String,
    asset_name        String DEFAULT '',
    event_id          String,
    event_type        LowCardinality(String),
    last_seen_at      Nullable(DateTime64(3, 'UTC')),
    threshold_minutes UInt16 DEFAULT 0,
    miss_count        UInt16 DEFAULT 0
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (org_id, asset_uuid, created)
TTL created + toIntervalDay(7)
SETTINGS index_granularity = 8192;

ALTER TABLE asset_status_history ADD INDEX IF NOT EXISTS idx_event_type event_type TYPE bloom_filter GRANULARITY 1;
ALTER TABLE asset_status_history ADD INDEX IF NOT EXISTS idx_asset_uuid asset_uuid TYPE bloom_filter GRANULARITY 1;
ALTER TABLE asset_status_history ADD INDEX IF NOT EXISTS idx_path_key path_key TYPE bloom_filter GRANULARITY 1;
