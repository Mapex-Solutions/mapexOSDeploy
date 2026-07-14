# MapexOS stack helpers. The canonical flow is full-docker (`make up`), which
# mirrors production/K8s. `make up-hybrid` layers a dev-only overlay that lets
# the app services run from source (go run) on the host while infra and the edge
# brokers stay in Docker — see docker-compose.hostbridge.yml.
#
# Set COMPOSE_PROJECT_NAME to target an existing stack under a specific project.

COMPOSE := docker compose

# Full stack in Docker (production-like). Default flow, matches the README.
up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

# Hybrid dev: infra + edge brokers in Docker, app services from source on the
# host. Bridges the edge containers to the host-side services (assets, vault).
up-hybrid:
	$(COMPOSE) -f docker-compose.yml -f docker-compose.hostbridge.yml up -d

down-hybrid:
	$(COMPOSE) -f docker-compose.yml -f docker-compose.hostbridge.yml down

.PHONY: up down logs up-hybrid down-hybrid
