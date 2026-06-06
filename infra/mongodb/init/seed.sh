#!/bin/bash
# =============================================================================
# MapexOS MongoDB Init — ReplicaSet + PKI bootstrap + Seed Data
# =============================================================================
#
# This script runs inside the mongodb-init container:
#   1. Waits for MongoDB to accept connections
#   2. Initializes the ReplicaSet (idempotent)
#   3. Waits for a PRIMARY to be elected
#   4. Bootstraps the platform PKI (idempotent, see pki-bootstrap.sh):
#      generates CA pair + broker server cert, copies broker certs to
#      the broker volume, encrypts the CA keys and inserts them into
#      mapex_vault.pkiCertificateAuthorities.
#   5. Seeds the static JSON data for mapex_iam + assets (idempotent)
#
# Environment:
#   MONGO_HOST        - MongoDB hostname for connection (default: mongodb)
#   RS_HOST           - Hostname for ReplicaSet member (default: mongodb)
#                       Use "localhost" for services_required (services
#                       run outside Docker), "mongodb" for standalone.
#   DB_PREFIX         - Database name prefix (default: dev-)
#   CREDENTIAL_MASTER_KEY  - 64-hex AES-256 key shared with mapexVault
#   BROKER_CERTS_DIR  - Path to broker volume mount (default: /broker-certs)
#   PKI_BROKER_CN     - CN for broker server cert (default: mapex-mqtt-broker)
#   PKI_BROKER_SAN    - CSV SANs for broker server cert
#
# =============================================================================

MONGO_HOST="${MONGO_HOST:-mongodb}"
RS_HOST="${RS_HOST:-mongodb}"
DB_PREFIX="${DB_PREFIX:-dev-}"
MONGO_URL="mongodb://${MONGO_HOST}:27017/?directConnection=true"
SEED_DIR="/seed"

export MONGO_URL DB_PREFIX

# -----------------------------------------------------------------------------
# wait_for_mongo - Waits until MongoDB accepts connections
# -----------------------------------------------------------------------------
wait_for_mongo() {
    echo "Waiting for MongoDB at ${MONGO_HOST}:27017..."
    for i in $(seq 1 30); do
        if mongosh --quiet --norc "$MONGO_URL" --eval "db.runCommand({ping:1}).ok" 2>/dev/null | grep -q 1; then
            echo "  MongoDB is accepting connections"
            return 0
        fi
        sleep 2
    done
    echo "  TIMEOUT: MongoDB not available after 60s"
    exit 1
}

# -----------------------------------------------------------------------------
# init_replicaset - Initializes RS if not already configured
# -----------------------------------------------------------------------------
init_replicaset() {
    echo ""
    echo "=== ReplicaSet Initialization ==="

    mongosh --quiet --norc "$MONGO_URL" --eval "
        try {
            const status = rs.status();
            print('  ReplicaSet already initialized (state: ' + status.myState + ')');
        } catch(e) {
            print('  Initializing ReplicaSet rs0...');
            rs.initiate({ _id: 'rs0', members: [{ _id: 0, host: '${RS_HOST}:27017' }] });
            print('  ReplicaSet rs0 initiated');
        }
    "
}

# -----------------------------------------------------------------------------
# wait_for_primary - Waits until this node becomes PRIMARY
# -----------------------------------------------------------------------------
wait_for_primary() {
    echo "  Waiting for PRIMARY election..."
    for i in $(seq 1 30); do
        IS_PRIMARY=$(mongosh --quiet --norc "$MONGO_URL" --eval "
            try { print(rs.isMaster().ismaster) } catch(e) { print('false') }
        " 2>/dev/null)

        if [ "$IS_PRIMARY" = "true" ]; then
            echo "  PRIMARY elected"
            return 0
        fi
        sleep 2
    done
    echo "  TIMEOUT: No PRIMARY after 60s"
    exit 1
}

# -----------------------------------------------------------------------------
# seed_collection - Upserts documents from a JSON file into a collection.
#
# Idempotent at the document level: each seed doc carries an explicit
# _id, so we bulkWrite replaceOne({_id}, doc, {upsert:true}). Re-runs
# never duplicate and always restore docs that were wiped out of a
# partially-populated collection.
#
# Args:
#   $1 - Database name (e.g., "mapex_iam", "assets")
#   $2 - Collection name (e.g., "users", "organizations")
#   $3 - Path to JSON file containing an array of documents
# -----------------------------------------------------------------------------
seed_collection() {
    local db="$1" collection="$2" file="$3"

    if [ ! -f "$file" ]; then
        echo "    SKIP: $(basename "$file") not found"
        return
    fi

    echo "    Seeding ${db}.${collection}..."

    mongosh --quiet --norc "$MONGO_URL" --eval "
        const fs = require('fs');
        const raw = fs.readFileSync('${file}', 'utf8');
        const data = EJSON.parse(raw);
        const targetDb = db.getSiblingDB('${db}');
        const ops = data.map(doc => ({
            replaceOne: { filter: { _id: doc._id }, replacement: doc, upsert: true }
        }));
        const result = targetDb['${collection}'].bulkWrite(ops, { ordered: false });
        const upserted = result.upsertedCount || 0;
        const modified = result.modifiedCount || 0;
        print('      -> ' + upserted + ' inserted, ' + modified + ' updated, ' + (data.length - upserted - modified) + ' unchanged');
    "

    if [ $? -eq 0 ]; then
        echo "      OK"
    else
        echo "      FAILED"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo "============================================="
echo "  MapexOS MongoDB Init (prefix: ${DB_PREFIX})"
echo "============================================="

# Step 1: Wait for MongoDB
wait_for_mongo

# Step 2: Init ReplicaSet
init_replicaset

# Step 3: Wait for PRIMARY
wait_for_primary

# Step 4: PKI bootstrap (per-collection idempotency inside).
# Sourced so it can `return 0` to skip without exiting this script when
# the CA collection is already populated.
# shellcheck disable=SC1091
source /usr/local/bin/pki-bootstrap.sh

# Step 4b: KEK bootstrap (per-collection idempotency inside). Sourced for the
# same `return 0` skip behaviour as the PKI bootstrap.
# shellcheck disable=SC1091
source /usr/local/bin/kek-bootstrap.sh

# Step 5: Static JSON seed (idempotent at the document level via upserts
# in seed_collection — each collection is reconciled independently, so a
# partially-wiped collection is restored without touching the others).
echo ""
echo "=== Seed Data ==="
echo ""

# --- mapex_iam database ---
echo "  [${DB_PREFIX}mapex_iam]"
seed_collection "${DB_PREFIX}mapex_iam" "organizations" "$SEED_DIR/mapex_iam/organizations.json"
seed_collection "${DB_PREFIX}mapex_iam" "roles"         "$SEED_DIR/mapex_iam/roles.json"
seed_collection "${DB_PREFIX}mapex_iam" "users"         "$SEED_DIR/mapex_iam/users.json"
seed_collection "${DB_PREFIX}mapex_iam" "memberships"   "$SEED_DIR/mapex_iam/memberships.json"
seed_collection "${DB_PREFIX}mapex_iam" "groups"        "$SEED_DIR/mapex_iam/groups.json"
seed_collection "${DB_PREFIX}mapex_iam" "lists"         "$SEED_DIR/mapex_iam/lists.json"
echo ""

# --- assets database ---
echo "  [${DB_PREFIX}assets]"
seed_collection "${DB_PREFIX}assets" "assets_templates" "$SEED_DIR/assets/assets_templates.json"
echo ""

echo "============================================="
echo "  MapexOS MongoDB Init Complete"
echo "============================================="
echo ""
echo "  Login: admin@mapex.local / mapex@123"
echo ""
