#!/bin/bash
# =============================================================================
# ClickHouse Seed Runner (Docker Init Container)
# =============================================================================
# Runs all SQL files against ClickHouse to create tables.
# Executed by the clickhouse-init container on startup.
#
# Waits for ClickHouse to be ready, then runs all .sql files
# in service/version order (e.g., events/v1/*.sql).
# =============================================================================

set -e

CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-clickhouse}"
CLICKHOUSE_PORT="${CLICKHOUSE_PORT:-9000}"
CLICKHOUSE_USER="${CLICKHOUSE_USER:-mapexos_user}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD:-mapexos_password}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Wait for ClickHouse
# =============================================================================
echo "=== ClickHouse Seed Runner ==="
echo "  Host: $CLICKHOUSE_HOST:$CLICKHOUSE_PORT"
echo "  User: $CLICKHOUSE_USER"

MAX_RETRIES=30
RETRY=0
echo "Waiting for ClickHouse to be ready..."
until clickhouse-client \
    --host "$CLICKHOUSE_HOST" \
    --port "$CLICKHOUSE_PORT" \
    --user "$CLICKHOUSE_USER" \
    --password "$CLICKHOUSE_PASSWORD" \
    --query "SELECT 1" >/dev/null 2>&1; do
    RETRY=$((RETRY + 1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
        echo "[ERROR] ClickHouse not ready after $MAX_RETRIES attempts. Aborting."
        exit 1
    fi
    echo "  Attempt $RETRY/$MAX_RETRIES - waiting 2s..."
    sleep 2
done
echo "ClickHouse is ready!"

# =============================================================================
# Run SQL files
# =============================================================================
run_sql_file() {
    local file="$1"
    local filename=$(basename "$file")
    echo "  Running: $filename"
    clickhouse-client \
        --host "$CLICKHOUSE_HOST" \
        --port "$CLICKHOUSE_PORT" \
        --user "$CLICKHOUSE_USER" \
        --password "$CLICKHOUSE_PASSWORD" \
        --multiquery < "$file"
    echo "  OK: $filename"
}

# Iterate over service directories (e.g., events/)
for service_dir in "$SCRIPT_DIR"/*/; do
    [ ! -d "$service_dir" ] && continue
    service=$(basename "$service_dir")

    # Skip if no version subdirectories
    if ! ls -d "$service_dir"/v* >/dev/null 2>&1; then
        continue
    fi

    echo ""
    echo "=========================================="
    echo "  Service: $service"
    echo "=========================================="

    # Iterate versions in order (v1, v2, ...)
    for version_dir in $(ls -d "$service_dir"/v* 2>/dev/null | sort -V); do
        ver=$(basename "$version_dir")
        echo "  Version: $ver"
        for file in "$version_dir"/*.sql; do
            [ -f "$file" ] && run_sql_file "$file"
        done
    done
done

echo ""
echo "=== All ClickHouse seeds completed successfully! ==="
