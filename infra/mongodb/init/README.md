# mongodb-init image source

Source for the `thiagoanselmo/mongodb-init` Docker image that the
infra docker-compose references as `mongodb-init`. On a fresh stack
this container:

1. Waits for MongoDB and initializes the `rs0` replica set.
2. Runs the PKI bootstrap (`pki-bootstrap.sh`) — generates the CA
   pair, writes broker server cert into `../../broker-certs`, and
   envelope-encrypts the CA private keys into
   `${DB_PREFIX}mapex_vault.pkiCertificateAuthorities`.
3. Seeds every JSON under [`../seed/`](../seed/) into the matching
   MongoDB collection.

## Files

| File | Role |
|---|---|
| `Dockerfile` | Builds on `mongo:7` + openssl + the `seed-encryptor` Go binary. |
| `seed.sh` | Entrypoint. Orchestrates wait → RS → PKI → seed. |
| `pki-bootstrap.sh` | PKI generation, encryption, and certificate output. Idempotent. |
| `seed-encryptor/` | Tiny Go program that envelope-encrypts CA private keys with `CREDENTIAL_MASTER_KEY` before they're inserted into mongo. |

## Idempotency

`seed.sh` upserts every seed document by `_id` (`bulkWrite` with
`replaceOne(_id, doc, {upsert: true})`). Re-running the container
never duplicates documents and restores any collection that was
wiped out of band — each collection reconciles independently.

## Build

The published image is the canonical artifact (`docker compose up`
pulls it). To build locally:

```bash
cd infra/mongodb/init
docker build -t thiagoanselmo/mongodb-init:dev .
```

Then point the compose at the local tag:

```bash
IMAGE_TAG=dev docker compose up -d mongodb-init --force-recreate
```
