-- =============================================================================
-- Table: events_workflow
-- Service: events
-- Version: v1
-- Description: Workflow execution history for debugging and analytics
-- Retention: 1-365 days (configurable per org, default 7)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS mapexos;

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events_workflow;

CREATE TABLE events_workflow (
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    finished DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    execution_id String DEFAULT '',
    event_tracker_id String DEFAULT '',
    org_id String,
    path_key String DEFAULT '',
    workflow_uuid String DEFAULT '',
    instance_id String,
    definition_id String,
    workflow_name String DEFAULT '',
    instance_name String DEFAULT '',
    definition_name String DEFAULT '',
    status String DEFAULT '',
    success Bool DEFAULT false,
    duration_ms Int64 DEFAULT 0,
    error_message String DEFAULT '',
    execution_path String DEFAULT '',
    node_outputs String DEFAULT '',
    error_info String DEFAULT '',
    event_payload String DEFAULT '',
    trigger_source String DEFAULT '',
    parent_execution_id String DEFAULT '',
    depth UInt8 DEFAULT 0,
    retention_days UInt16 DEFAULT 7,
    state String DEFAULT '',
    external_inputs String DEFAULT ''
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, instance_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes for common query patterns
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_execution_id execution_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_instance_id instance_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_definition_id definition_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_workflow_uuid workflow_uuid TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_status status TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_success success TYPE minmax GRANULARITY 1;
ALTER TABLE events_workflow ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
