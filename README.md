# MapexOS Stack

> **IoT-first, but not limited to IoT.**
> MapexOS doesn't see devices or sensors — it sees **Assets**.
> Any source. Any protocol. One abstraction.
>
> **Connect. Automate. Scale.** — The open platform for data integration
> and intelligent automation.

```
   Sources                       MapexOS                         Destinations
   ───────                       ───────                         ────────────
   Devices ──┐                                              ┌── Webhooks / APIs
   Gateways ─┤   Ingest → Validate → Transform → Route →    ├── Slack / Teams / Email
   APIs ─────┼──        Store / Notify / Automate           ├── NATS / MQTT
   Apps ─────┤                                              └── Custom plugins
   3rd-party ┘
```

This repository distributes the Docker Compose orchestration for the
MapexOS platform — pre-built multi-arch images on Docker Hub, a single
command to boot the full stack. The service source code lives in the
[mapexOS](https://github.com/Mapex-Solutions/mapexOS) repository.

[Versão em português](./README_pt.md) · [Documentation site](https://mapexos.io)

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
| MongoDB | 27017 | `mongo:7.0.34` (replicaSet `rs0`) |
| MongoDB init | — | `thiagoanselmo/mongodb-init:1.0.0` (one-shot) |
| Redis | 6379 | `redis:7.4.9-alpine` |
| ClickHouse | 8123 / 9440 | `clickhouse/clickhouse-server:26.5.1.882` |
| MinIO | 9000 / 9001 | `minio/minio:RELEASE.2025-09-07T16-13-09Z` |
| NATS Core | 4222 / 8222 | `nats:2.14.1-alpine` |
| MQTT Broker | 1883 | `thiagoanselmo/mapex-broker-mqtt:1.0.0` |
| Prometheus | 9090 | `prom/prometheus:v3.11.3` |
| Grafana | 3001 | `grafana/grafana:13.0.1` (8 dashboards pre-loaded) |

---

## Resource limits

Every long-running service ships with a `deploy.resources.limits`
(CPU + memory) block in the compose files. These are deliberately
**sized to fit a single local machine** — roughly a 4-core / 8 GB
laptop — so you can clone the repo, boot the whole stack and simulate a
few devices without it eating the host. The sum of the limits is about
**10.5 vCPU / ~5 GB RAM**.

A couple of things worth knowing:

- **They are ceilings, not reservations.** Docker never *reserves* those
  cores or that RAM — each value is just the most a container is allowed
  to use. That's why the CPU limits sum to more vCPUs than a small laptop
  has and the stack still runs fine: the kernel scheduler time-shares the
  real cores, and idle containers cost nothing.
- **Two engines are also tuned internally to match their cap.** MongoDB
  gets `--wiredTigerCacheSizeGB` and ClickHouse gets
  `max_server_memory_usage` / `mark_cache_size`, because both size their
  caches off *host* RAM by default and would otherwise be OOM-killed once
  a container limit is in place.
- **Init one-shots** (`mongodb-init`, `clickhouse-init`, …) are left
  uncapped on purpose — they run briefly during bootstrap and capping
  them only risks slowing or failing the first boot.

> **Production: revisit these.** The defaults exist so the stack fits a
> laptop, **not** so it performs under real load. Production runs on a
> **Kubernetes cluster**, where these compose limits don't apply — there
> you set per-container `resources.requests` / `resources.limits` (and
> HPA/VPA) sized to your actual demand and usage: number of devices,
> message throughput, query volume, retention. Give
> MongoDB/ClickHouse/Prometheus real headroom and right-size the services
> under pressure. **Don't size from `docker stats`** — monitor your
> **cluster's metrics** (Prometheus / Grafana, `kubectl top pods`,
> Metrics Server) under representative load and tune from there.

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
cp infra/envs/production.example.env infra/envs/production.env
$EDITOR infra/envs/production.env
```

Uncomment every line and fill with real values. The template includes
helper commands for generating each secret (e.g. `openssl rand -hex 32`
for `AUTH_SECRET`).

### 2. Point the compose at the production env

Edit `services/docker-compose.yml` and `infra/docker-compose.yml` so
every `env_file:` entry that today references `local.env` references
`production.env` instead. Same for `${GO_ENV:-dev}` → set
`GO_ENV=prod` in your shell, or hardcode `prod` in the YAML:

```bash
export GO_ENV=prod
export MAPEXOS_PUBLIC_HOST=mapex.example.com
docker compose up -d
docker compose logs -f mapex-iam   # watch for "[SECURITY] refusing to start"
```

Every Mapex service contains a **security guard** that refuses to boot
when `GO_ENV` or `NODE_ENV` is not in {`dev`, `development`, empty} and
any sensitive env var (`AUTH_SECRET`, `INTERNAL_API_KEY`,
`NATS_PASSWORD`, …) is missing or still equals its hardcoded dev
default. Forgetting to uncomment a value in `production.env` triggers a
loud fatal error at startup — never silent boot with a leaked default.

> `infra/envs/production.env` is in `.gitignore`. Never commit it.

---

## Configuration overview

### Layout

| File | Role | Committed? |
|---|---|---|
| `services/docker-compose.yml` | Image versions pinned literally (e.g. `thiagoanselmo/mapex-iam:1.0.0`) | ✓ |
| `infra/docker-compose.yml` | Infra services (mongo, redis, nats, ...) + Mapex init/broker images | ✓ |
| `infra/envs/local.env` | Shared runtime env for local evaluation | ✓ |
| `infra/envs/production.example.env` | Template for production secrets | ✓ |
| `infra/envs/production.env` | Your actual production secrets | ✗ (gitignored) |
| `services/<svc>/envs/<svc>.env` | Per-service overrides (ports, names, internal URLs) | ✓ |

### How versions are pinned

- **Mapex services** (`thiagoanselmo/*`): the version is written
  directly in `services/docker-compose.yml` and
  `infra/docker-compose.yml`. Bumping a release means editing those
  files. No magic env var, no surprise drift.
- **Infra images** (`mongo`, `redis`, `nats`, ...): pinned to fixed
  tags in `infra/docker-compose.yml`.
- **Runtime knobs** (`GO_ENV`, `MAPEXOS_PUBLIC_HOST`) use the
  `${VAR:-default}` syntax in the compose, so the stack boots without
  any `.env` file in the repo root. Override via shell:
  ```bash
  GO_ENV=prod MAPEXOS_PUBLIC_HOST=mapex.example.com docker compose up -d
  ```

---

## Versioning

This repository is versioned independently from the service source. Each
tag of `mapexOSDeploy` pins a specific image version (literally in the
compose files) and is tested together. Treat the tag of this repo (e.g.
`v1.0.0`) as the source of truth: cloning the matching tag and running
`docker compose up -d` should always work.

To upgrade:

```bash
git fetch --tags
git checkout v1.1.0
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

**`[SECURITY] refusing to start in GO_ENV=prod`** — you exported
`GO_ENV=prod` but `infra/envs/production.env` doesn't override every
sensitive key. Re-read the error: it names the env vars still on dev
defaults. Fill them in `production.env`.

**`unable to pull mapexos/…`** — old reference. Every image is under
`thiagoanselmo/…`. Pull again after `git pull`.

**Frontend says "network error"** — `MAPEXOS_PUBLIC_HOST` doesn't match
the URL you're using. Override it via shell to whatever the browser
uses to reach the host machine (`localhost`, an IP, or a DNS name) and
recreate the frontend container:
`MAPEXOS_PUBLIC_HOST=192.168.0.50 docker compose up -d --force-recreate frontend`.

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
