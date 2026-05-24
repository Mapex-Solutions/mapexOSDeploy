# MapexOS Stack

> Self-hostable IoT platform for telemetry ingestion, rule-based routing,
> workflow execution, and asset management. Pre-built Docker Hub images;
> single command to boot the full stack.

This repository distributes the Docker Compose orchestration for the
MapexOS platform. The service source code lives in private Mapex
Solutions repositories — this repo pulls the published images from
Docker Hub.

---

## Quick start

```bash
git clone https://github.com/Mapex-Solutions/mapexOSDeploy.git
cd mapexOSDeploy
docker compose up -d
```

Wait ~2 minutes for everything to initialize (Mongo replica-set, NATS
streams, MinIO buckets, ClickHouse tables). Then:

- **Frontend**: <http://localhost>
- **Login**: `admin@mapex.local` / `mapex@123` *(change on first login)*
- **Grafana**: <http://localhost:3001> (`admin` / `admin`)
- **MinIO console**: <http://localhost:9001> (`mapex_admin` /
  `mapex_admin_secret_change_me`)

To serve the UI to other machines on your network:

```bash
MAPEXOS_PUBLIC_HOST=192.168.0.50 docker compose up -d
```

> The logs will show one big red `[SECURITY WARNING]` line per service.
> That's expected for local evaluation — it tells you you're running with
> dev defaults. See **Production deployment** below to silence it.

---

## Try the platform — quickstart

Once the stack is up, the [`quickstart/`](./quickstart/) folder walks
you through wiring a temperature sensor end to end: create an asset
template, a route group, an HTTP or MQTT datasource, then push fake
readings with a small Node.js script and watch them land in Grafana.

Every step ships ready-to-paste JSON payloads for the UI forms.

Start at [`quickstart/README.md`](./quickstart/README.md).

---

## What's running

### Application services

| Service | Port | Purpose |
|---|---|---|
| Frontend | 80 | Vue 3 + Quasar SPA |
| mapex-iam | 5000 | Users, organizations, roles, auth |
| http-gateway | 5001 | Webhook ingestion, datasource registry |
| assets | 5002 | IoT assets, templates, EVA fields |
| router | 5003 | Event routing, match rules |
| events | 5004 | ClickHouse storage, 7 NATS consumers |
| triggers | 5006 | Trigger executors (HTTP, MQTT, NATS, …) |
| workflow | 5007 | DAG workflow engine + plugins |
| mapex-vault | 5010 | Credential vault, PKI authority |
| js-executor | 8000 | V8 script execution for IoT events |
| js-wf-executor | 8001 | V8 execution of workflow code nodes |

### Infrastructure

| Service | Port | Image |
|---|---|---|
| MongoDB | 27017 | `mongo:7` (replicaSet `rs0`) |
| Redis | 6379 | `redis:7-alpine` |
| ClickHouse | 8123 / 9440 | `clickhouse/clickhouse-server` |
| MinIO | 9000 / 9001 | `minio/minio` |
| NATS Core | 4222 / 8222 | `nats:2.12-alpine` |
| MQTT Broker | 1883 | `thiagoanselmo/mapex-broker-mqtt` |
| Prometheus | 9090 | `prom/prometheus` |
| Grafana | 3001 | `grafana/grafana` (8 dashboards pre-loaded) |

---

## Stopping & cleaning up

```bash
docker compose down              # stop containers, keep volumes
docker compose down -v           # stop + drop volumes (full reset)

# Hard reset (wipes mounted data directories too)
docker compose down -v
rm -rf infra/*/data/* broker-certs/
```

---

## Production deployment

The stack defaults to local evaluation mode. To deploy with real
credentials:

### 1. Build a production env file

```bash
cp envs/production.example.env envs/production.env
$EDITOR envs/production.env
```

Uncomment every line and fill with real values. The template includes
helper commands for generating each secret (e.g. `openssl rand -hex 32`
for `AUTH_SECRET`).

### 2. Update the canonical `.env`

```diff
- ENV_PROFILE=local
- GO_ENV=dev
- NODE_ENV=dev
- IMAGE_TAG=1.0.0
- MAPEXOS_PUBLIC_HOST=localhost
+ ENV_PROFILE=production
+ GO_ENV=prod
+ NODE_ENV=prod
+ IMAGE_TAG=1.0.0          # or whatever release you want to pin
+ MAPEXOS_PUBLIC_HOST=mapex.example.com
```

### 3. Boot

```bash
docker compose up -d
docker compose logs -f mapex-iam   # watch for "[SECURITY] refusing to start"
```

Every Mapex service contains a **security guard** that refuses to boot
when `GO_ENV` or `NODE_ENV` is not in {`dev`, `development`, empty} and
any sensitive env var (`AUTH_SECRET`, `INTERNAL_API_KEY`,
`NATS_PASSWORD`, …) is missing or still equals its hardcoded dev
default. Forgetting to uncomment a value in `production.env` triggers a
loud fatal error at startup — never silent boot with a leaked default.

> `envs/production.env` is in `.gitignore`. Never commit it.

---

## Configuration overview

### Files

| File | Role | Committed? |
|---|---|---|
| `.env` | Canonical knobs (profile, env, image tag, public host) | ✓ |
| `envs/local.env` | Per-container env for local evaluation | ✓ |
| `envs/production.example.env` | Template for production secrets | ✓ |
| `envs/production.env` | Your actual production secrets | ✗ (gitignored) |
| `services/<svc>/envs/<svc>.env` | Per-service overrides (ports, internal URLs) | ✓ |

### How the four knobs flow

```
.env
 ├── ENV_PROFILE      → which envs/<profile>.env is loaded by every service
 ├── GO_ENV / NODE_ENV → injected at compose-substitution time into:
 │                       - DB_PREFIX                ("${GO_ENV}-mapex_vault", …)
 │                       - NATS subject prefix      ("${GO_ENV}.mapexos.…")
 │                       - NATS stream UPPER prefix ("${UPPER_ENV}-MAPEXOS-…")
 │                       - The service security guard
 ├── IMAGE_TAG        → tag of every thiagoanselmo/* image pulled
 └── MAPEXOS_PUBLIC_HOST → host the frontend uses to reach backend APIs
```

---

## Versioning

This repository is versioned independently from the service source. Each
tag of `mapexOSDeploy` pins a specific `IMAGE_TAG` and is tested
together. Treat the tag of this repo (e.g. `v1.0.0`) as the source of
truth: cloning the matching tag and running `docker compose up -d`
should always work.

To upgrade:

```bash
git fetch --tags
git checkout v1.1.0
$EDITOR .env            # bump IMAGE_TAG to 1.1.0
docker compose pull
docker compose up -d
```

---

## Source repositories

| Project | Repo | Status |
|---|---|---|
| MapexOS core (Go + JS services + frontend) | `Mapex-Solutions/mapexOS` | private |
| MQTT broker plugin (Mosquitto + Go plugin) | `Mapex-Solutions/mapexMQTTBroker` | private |
| Docker Compose distribution (this repo) | `Mapex-Solutions/mapexOSDeploy` | public |

Service images are published to <https://hub.docker.com/u/thiagoanselmo>.

---

## Troubleshooting

**`docker compose` complains about missing `.env`** — you cloned but
deleted the file. Restore it from git (`git checkout .env`).

**`[SECURITY] refusing to start in GO_ENV=prod`** — you set `GO_ENV=prod`
in `.env` but `envs/production.env` doesn't override every sensitive
key. Re-read the error: it names the env vars still on dev defaults.
Fill them in `production.env`.

**`unable to pull mapexos/…`** — old reference. Every image is under
`thiagoanselmo/…`. Pull again after `git pull`.

**Frontend says "network error"** — `MAPEXOS_PUBLIC_HOST` doesn't match
the URL you're using. Set it in `.env` to whatever the browser uses to
reach the host machine (`localhost`, an IP, or a DNS name) and recreate
the frontend container: `docker compose up -d --force-recreate frontend`.

**Containers exit healthy then come back up** — normal during the first
2 minutes. `mongodb-init`, `clickhouse-init`, `minio-init` and
`nats-init` are one-shot bootstrappers that exit `0` when done.

**Mongo replica set fails to form** — usually a Docker DNS issue.
`docker compose down && docker compose up -d` typically resolves it.

---

## License

Licensed under the [Business Source License 1.1](LICENSE). See the
LICENSE file for the full terms.

## Support

Open an issue on this repository. For commercial support, contact
[Thiago Anselmo](mailto:thiagoo.anselmoo@gmail.com).
