#!/bin/sh
# =============================================================================
# MapexOS Frontend — Docker Entrypoint
# =============================================================================
#
# Replaces __PLACEHOLDER__ strings in the built JS files with runtime env vars.
# This allows configuring API URLs at container start without rebuilding.
#
# =============================================================================

set -e

HTML_DIR="/usr/share/nginx/html"

# Map of placeholder → env var name
VARS="
MAPEXOS_API_BASE_URL
HTTP_GATEWAY_API_BASE_URL
ASSETS_API_BASE_URL
ROUTER_API_BASE_URL
EVENTS_API_BASE_URL
RULE_ENGINE_API_BASE_URL
TRIGGERS_API_BASE_URL
JS_EXECUTOR_API_BASE_URL
"

for VAR in $VARS; do
    VALUE=$(eval echo "\$$VAR")

    if [ -n "$VALUE" ]; then
        PLACEHOLDER="__${VAR}__"
        echo "  env: ${VAR} = ${VALUE}"

        # Replace in all JS files (Vite bundles the placeholders as string literals)
        find "$HTML_DIR" -name '*.js' -exec sed -i "s|${PLACEHOLDER}|${VALUE}|g" {} +
    fi
done

echo "  Frontend ready"

# Execute CMD (nginx)
exec "$@"
