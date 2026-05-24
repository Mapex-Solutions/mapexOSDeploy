#!/bin/bash
# =============================================================================
# pki-bootstrap.sh — runs inside the mongodb-init container.
# =============================================================================
#
# Flow (matches the operator's mental model):
#   1. Generate root + intermediate + broker server certs (openssl) in WORK_DIR.
#   2. Copy broker server.crt/server.key/ca-chain.pem into BROKER_DIR mount.
#   3. Envelope-encrypt each CA private key and insertMany into
#      ${DB_PREFIX}mapex_vault.pkiCertificateAuthorities (same shape the
#      service would produce if it persisted via its repository).
#
# Idempotent: skips everything when the collection already has docs, so
# `docker compose up` re-runs are safe.
#
# Required env:
#   CREDENTIAL_MASTER_KEY   64-hex AES-256 master key (must match the
#                           mapexVault config value so the running
#                           service can decrypt what we seed).
#   MONGO_URL               mongo connection string (typically passed by
#                           seed.sh).
#   DB_PREFIX               env prefix used by the platform (default dev-).
#   BROKER_CERTS_DIR        host-mounted dir where the broker reads its
#                           TLS material from (default /broker-certs).
#
# Optional env:
#   PKI_BROKER_CN           CN for the broker server cert (default
#                           mapex-mqtt-broker).
#   PKI_BROKER_SAN          CSV of SANs for the broker server cert
#                           (default mapex-mqtt-broker,localhost,127.0.0.1).
#   PKI_CA_TTL_DAYS         days both CAs are valid for (default 3650).
#   PKI_BROKER_TTL_DAYS     days the broker server cert is valid for
#                           (default 3650).
#
# =============================================================================

set -euo pipefail

MONGO_URL="${MONGO_URL:?MONGO_URL required}"
DB_PREFIX="${DB_PREFIX:-dev-}"
DB_NAME="${DB_PREFIX}mapex_vault"
COLLECTION="pkiCertificateAuthorities"
BROKER_DIR="${BROKER_CERTS_DIR:-/broker-certs}"
WORK_DIR="/tmp/pki-bootstrap"

PKI_BROKER_CN="${PKI_BROKER_CN:-mapex-mqtt-broker}"
PKI_BROKER_SAN="${PKI_BROKER_SAN:-mapex-mqtt-broker,localhost,127.0.0.1}"
PKI_CA_TTL_DAYS="${PKI_CA_TTL_DAYS:-3650}"
PKI_BROKER_TTL_DAYS="${PKI_BROKER_TTL_DAYS:-3650}"

echo ""
echo "=== PKI Bootstrap ==="

# Idempotency: per-collection check so this stays independent from the
# global IAM-org check seed.sh uses.
EXISTING=$(mongosh --quiet --norc "$MONGO_URL" --eval "
    print(db.getSiblingDB('${DB_NAME}').${COLLECTION}.countDocuments())
" 2>/dev/null | tr -d '[:space:]')

if [ "$EXISTING" != "0" ] && [ -n "$EXISTING" ]; then
    echo "  PKI already seeded (${EXISTING} CAs in ${DB_NAME}.${COLLECTION}). Skipping."
    return 0 2>/dev/null || exit 0
fi

if [ -z "${CREDENTIAL_MASTER_KEY:-}" ]; then
    echo "  ERROR: CREDENTIAL_MASTER_KEY not set — required for PKI generation."
    echo "         Set it via compose env (must match mapexVault config)."
    exit 1
fi

echo "  Generating fresh platform PKI..."

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/ca" "$WORK_DIR/broker" "$WORK_DIR/seed" "$BROKER_DIR"

# Step 1a: Root CA
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK_DIR/ca/root_ca.key" 2>/dev/null
chmod 0600 "$WORK_DIR/ca/root_ca.key"

ROOT_EXT_FILE="$(mktemp)"
cat > "$ROOT_EXT_FILE" <<EOF
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
EOF
openssl req -new -x509 \
    -key "$WORK_DIR/ca/root_ca.key" \
    -out "$WORK_DIR/ca/root_ca.crt" \
    -days "$PKI_CA_TTL_DAYS" \
    -sha256 \
    -subj "/CN=Mapex Root CA/O=Mapex Solutions" \
    -extensions v3_ca \
    -config <(printf "[req]\ndistinguished_name=dn\n[dn]\n[v3_ca]\n%s\n" "$(cat "$ROOT_EXT_FILE")") \
    2>/dev/null
rm -f "$ROOT_EXT_FILE"
echo "    + root_ca generated"

# Step 1b: Intermediate CA — signed by root, pathlen:0
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK_DIR/ca/intermediate_ca.key" 2>/dev/null
chmod 0600 "$WORK_DIR/ca/intermediate_ca.key"

INT_CSR="$(mktemp)"
INT_EXT_FILE="$(mktemp)"
INT_SERIAL_FILE="$(mktemp)"
openssl rand -hex 16 > "$INT_SERIAL_FILE"

openssl req -new \
    -key "$WORK_DIR/ca/intermediate_ca.key" \
    -out "$INT_CSR" \
    -subj "/CN=Mapex Intermediate CA/O=Mapex Solutions" \
    2>/dev/null

cat > "$INT_EXT_FILE" <<EOF
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF

openssl x509 -req \
    -in "$INT_CSR" \
    -CA "$WORK_DIR/ca/root_ca.crt" \
    -CAkey "$WORK_DIR/ca/root_ca.key" \
    -CAserial "$INT_SERIAL_FILE" \
    -days "$PKI_CA_TTL_DAYS" \
    -sha256 \
    -extfile "$INT_EXT_FILE" \
    -out "$WORK_DIR/ca/intermediate_ca.crt" \
    2>/dev/null

rm -f "$INT_CSR" "$INT_EXT_FILE" "$INT_SERIAL_FILE"
echo "    + intermediate_ca generated"

# Step 1c: Broker server cert — signed by intermediate, with SANs
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK_DIR/broker/server.key" 2>/dev/null
chmod 0600 "$WORK_DIR/broker/server.key"

SRV_CSR="$(mktemp)"
SRV_EXT_FILE="$(mktemp)"
SRV_SERIAL_FILE="$(mktemp)"
openssl rand -hex 16 > "$SRV_SERIAL_FILE"

# Build SAN extension lines from the CSV (DNS for non-IP, IP otherwise).
SAN_LINES=""
DNS_IDX=1
IP_IDX=1
IFS=',' read -ra SAN_ENTRIES <<< "$PKI_BROKER_SAN"
for entry in "${SAN_ENTRIES[@]}"; do
    e="$(echo "$entry" | xargs)"
    [ -z "$e" ] && continue
    if [[ "$e" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        SAN_LINES+="IP.${IP_IDX} = $e"$'\n'
        IP_IDX=$((IP_IDX + 1))
    else
        SAN_LINES+="DNS.${DNS_IDX} = $e"$'\n'
        DNS_IDX=$((DNS_IDX + 1))
    fi
done

openssl req -new \
    -key "$WORK_DIR/broker/server.key" \
    -out "$SRV_CSR" \
    -subj "/CN=${PKI_BROKER_CN}/O=Mapex Solutions" \
    2>/dev/null

cat > "$SRV_EXT_FILE" <<EOF
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
subjectAltName=@alt_names

[alt_names]
${SAN_LINES}
EOF

openssl x509 -req \
    -in "$SRV_CSR" \
    -CA "$WORK_DIR/ca/intermediate_ca.crt" \
    -CAkey "$WORK_DIR/ca/intermediate_ca.key" \
    -CAserial "$SRV_SERIAL_FILE" \
    -days "$PKI_BROKER_TTL_DAYS" \
    -sha256 \
    -extfile "$SRV_EXT_FILE" \
    -out "$WORK_DIR/broker/server.crt" \
    2>/dev/null

rm -f "$SRV_CSR" "$SRV_EXT_FILE" "$SRV_SERIAL_FILE"

cat "$WORK_DIR/ca/root_ca.crt" "$WORK_DIR/ca/intermediate_ca.crt" > "$WORK_DIR/broker/ca-chain.pem"
echo "    + broker server cert generated"

# Step 2: copy broker pieces to the broker volume
cp "$WORK_DIR/broker/server.crt" "$BROKER_DIR/server.crt"
cp "$WORK_DIR/broker/server.key" "$BROKER_DIR/server.key"
cp "$WORK_DIR/broker/ca-chain.pem" "$BROKER_DIR/ca-chain.pem"
# 0644 across the board: this script runs as root (mongo:7) but
# mosquitto reads the files as a non-root user, and the broker mounts
# the dir read-only so write-side hardening lives on the host (broker
# certs dir should be owned/perms-restricted by the operator's deploy
# tooling, not by us mid-bootstrap).
chmod 0644 "$BROKER_DIR/server.crt" "$BROKER_DIR/server.key" "$BROKER_DIR/ca-chain.pem"
echo "  Broker certs written to ${BROKER_DIR}"

# Step 3a: envelope-encrypt + emit per-CA EJSON docs
CREDENTIAL_MASTER_KEY="$CREDENTIAL_MASTER_KEY" \
    seed-encryptor --in "$WORK_DIR/ca" --out "$WORK_DIR/seed" >/dev/null

# Step 3b: insertMany into mapex_vault.pkiCertificateAuthorities
for json in "$WORK_DIR/seed"/*.json; do
    base="$(basename "$json")"
    mongosh --quiet --norc "$MONGO_URL" --eval "
        const fs = require('fs');
        const raw = fs.readFileSync('${json}', 'utf8');
        const data = EJSON.parse(raw);
        const target = db.getSiblingDB('${DB_NAME}');
        const result = target['${COLLECTION}'].insertMany(data);
        print('    + inserted ' + Object.keys(result.insertedIds).length + ' doc from ${base}');
    "
done

# Wipe plaintext key material from the container fs.
rm -rf "$WORK_DIR"

echo "  PKI bootstrap complete."
