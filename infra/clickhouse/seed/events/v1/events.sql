-- =============================================================================
-- Table: events
-- Service: events
-- Version: v2
-- Description: Processed events with EVA (Entity-Value-Attribute) MAP storage
-- Retention: 7-365 days (based on organization policy)
-- =============================================================================
--
-- EVA Storage Optimization:
-- - Uses MAP<UInt16, Type> instead of Array(Tuple(String, Type))
-- - FieldId (UInt16) from AssetTemplate.DynamicFields for 3-4x faster queries
-- - Better compression (no repeated field names)
-- - Query example: eva_number[1] > 25 (where 1 = temperature fieldId)
--
-- =============================================================================

USE mapexos;

-- Drop table if exists to allow schema changes
DROP TABLE IF EXISTS events;

CREATE TABLE events (
    -- Created and identification
    created DateTime64(3, 'UTC') DEFAULT now64(3, 'UTC'),
    event_tracker_id String DEFAULT '',  -- UUID for end-to-end event tracking across services
    thread_id String,                    -- Internal processing thread ID
    asset_id String,                     -- Asset that generated the event
    asset_template_id String,                  -- Template ID for EVA field resolution (AssetTemplate, BusinessRule, etc.)
    asset_template_org_id String,              -- Template owner org for cache lookup ("mapexos_public" or orgId)

    -- Human-readable names (denormalized at write-time by Router)
    asset_name String DEFAULT '',              -- Asset display name
    asset_description String DEFAULT '',       -- Asset description
    template_name String DEFAULT '',           -- Template display name
    template_description String DEFAULT '',    -- Template description

    -- Multi-tenant fields
    org_id String,
    path_key String,

    -- Event metadata
    event_type String,
    source String,
    payload String,                      -- Original JSON payload
    metadata String,                     -- Additional metadata JSON

    -- ==========================================================================
    -- EVA Fields: MAP<UInt16, Type>
    -- Key = fieldId from AssetTemplate.DynamicFields
    -- Value = typed value (not string!)
    -- ==========================================================================

    eva_number Map(UInt16, Float64),     -- Numeric fields (temperature, humidity, etc)
    eva_string Map(UInt16, String),      -- String fields (status, location, etc)
    eva_bool Map(UInt16, UInt8),         -- Boolean fields (is_online, alarm, etc)
    eva_date Map(UInt16, DateTime64(3)), -- Date/time fields (last_update, etc)

    -- Retention policy
    retention_days UInt16 DEFAULT 30
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(created)
ORDER BY (created, org_id, asset_id)
TTL created + toIntervalDay(retention_days)
SETTINGS index_granularity = 8192;

-- Indexes for common query patterns
ALTER TABLE events ADD INDEX IF NOT EXISTS idx_org_id org_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events ADD INDEX IF NOT EXISTS idx_event_type event_type TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events ADD INDEX IF NOT EXISTS idx_thread_id thread_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events ADD INDEX IF NOT EXISTS idx_event_tracker_id event_tracker_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events ADD INDEX IF NOT EXISTS idx_asset_id asset_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events ADD INDEX IF NOT EXISTS idx_asset_template_id asset_template_id TYPE bloom_filter GRANULARITY 1;
