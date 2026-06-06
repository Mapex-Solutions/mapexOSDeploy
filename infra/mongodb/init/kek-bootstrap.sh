#!/bin/bash
# =============================================================================
# kek-bootstrap.sh: runs inside the mongodb-init container, sourced by seed.sh
# right after pki-bootstrap.sh.
# =============================================================================
#
# Seeds the platform key-encryption keys (KEKs) into
# ${DB_PREFIX}mapex_vault.encryptionKeys. Each KEK is a random 32-byte key,
# hex-encoded and envelope-encrypted with CREDENTIAL_MASTER_KEY (the same key
# the running mapexVault decrypts with), so the kek module can hand it out on
# GET /internal/kek/:context.
#
# Idempotent: skips when the collection already has docs, so
# `docker compose up` re-runs are safe.
#
# Required env (shared with seed.sh / pki-bootstrap.sh):
#   CREDENTIAL_MASTER_KEY   64-hex AES-256 master key (must match mapexVault).
#   MONGO_URL               mongo connection string.
#   DB_PREFIX               env prefix used by the platform (default dev-).
#
# =============================================================================

set -euo pipefail

DB_NAME="${DB_PREFIX:-dev-}mapex_vault"
KEK_COLLECTION="encryptionKeys"
KEK_WORK_DIR="/tmp/kek-bootstrap/seed"

echo ""
echo "=== KEK Bootstrap ==="

# Idempotency: per-collection check, independent from the PKI check above.
KEK_EXISTING=$(mongosh --quiet --norc "$MONGO_URL" --eval "
    print(db.getSiblingDB('${DB_NAME}').${KEK_COLLECTION}.countDocuments())
" 2>/dev/null | tr -d '[:space:]')

if [ "$KEK_EXISTING" != "0" ] && [ -n "$KEK_EXISTING" ]; then
    echo "  KEKs already seeded (${KEK_EXISTING} in ${DB_NAME}.${KEK_COLLECTION}). Skipping."
    return 0 2>/dev/null || exit 0
fi

if [ -z "${CREDENTIAL_MASTER_KEY:-}" ]; then
    echo "  ERROR: CREDENTIAL_MASTER_KEY not set, required for KEK generation."
    echo "         Set it via compose env (must match mapexVault config)."
    exit 1
fi

echo "  Generating platform KEKs..."
rm -rf "$(dirname "$KEK_WORK_DIR")"
mkdir -p "$KEK_WORK_DIR"

# seed-encryptor generates a random KEK per context and envelope-encrypts it
# with the master key, emitting one EJSON doc per context.
CREDENTIAL_MASTER_KEY="$CREDENTIAL_MASTER_KEY" \
    seed-encryptor --kek-out "$KEK_WORK_DIR" >/dev/null

for json in "$KEK_WORK_DIR"/*.json; do
    base="$(basename "$json")"
    mongosh --quiet --norc "$MONGO_URL" --eval "
        const fs = require('fs');
        const raw = fs.readFileSync('${json}', 'utf8');
        const data = EJSON.parse(raw);
        const target = db.getSiblingDB('${DB_NAME}');
        const result = target['${KEK_COLLECTION}'].insertMany(data);
        print('    + inserted ' + Object.keys(result.insertedIds).length + ' KEK doc from ${base}');
    "
done
