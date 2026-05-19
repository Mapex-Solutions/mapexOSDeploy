-- =============================================================================
-- Table: events_businessrule
-- Service: events
-- Version: v1
-- Description: Business rule execution history for debugging and analytics
-- Retention: 1-30 days (configurable per org)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_businessrule;

CREATE TABLE events_businessrule (
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    event_tracker_id String DEFAULT '',
    thread_id String,
    org_id String,
    path_key String DEFAULT '',
    rule_id String,
    business_rule_id String,
    business_rule_name String DEFAULT '',
    business_rule_description String DEFAULT '',

    -- Execution result
    matched UInt8 DEFAULT 0,
    duration_ms Int64 DEFAULT 0,

    -- Evaluation metrics
    conditions_evaluated UInt16 DEFAULT 0,
    conditions_matched UInt16 DEFAULT 0,
    groups_evaluated UInt16 DEFAULT 0,
    max_depth_reached UInt16 DEFAULT 0,

    -- State data (JSON strings)
    final_state String DEFAULT '',
    state_changes String DEFAULT '',

    -- Detailed logs (JSON strings)
    evaluation_tree String DEFAULT '',
    condition_logs String DEFAULT '',

    -- Actions (JSON string)
    actions_to_dispatch String DEFAULT '',

    retention_days UInt16 DEFAULT 7
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, business_rule_id, thread_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes for common query patterns
ALTER TABLE events_businessrule ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_businessrule ADD INDEX IF NOT EXISTS idx_rule_id rule_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_businessrule ADD INDEX IF NOT EXISTS idx_business_rule_id business_rule_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_businessrule ADD INDEX IF NOT EXISTS idx_thread_id thread_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_businessrule ADD INDEX IF NOT EXISTS idx_matched matched TYPE minmax GRANULARITY 1;
ALTER TABLE events_businessrule ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
