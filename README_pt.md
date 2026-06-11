# MapexOS Stack

> **IoT-first, mas não se limita a IoT.**
> O MapexOS não vê dispositivos ou sensores — ele vê **Assets**.
> Qualquer fonte. Qualquer protocolo. Uma única abstração.
>
> **Connect. Automate. Scale.** — A plataforma aberta para integração de
> dados e automação inteligente.

```
   Fontes                        MapexOS                          Destinos
   ──────                        ───────                          ────────
   Devices ──┐                                              ┌── Webhooks / APIs
   Gateways ─┤   Ingest → Validate → Transform → Route →    ├── Slack / Teams / Email
   APIs ─────┼──        Store / Notify / Automate           ├── NATS / MQTT
   Apps ─────┤                                              └── Plugins customizados
   Terceiros ┘
```

Este repositório distribui a orquestração Docker Compose da plataforma
MapexOS — imagens multi-arch pré-construídas no Docker Hub, um único
comando para subir toda a stack. O código-fonte dos serviços vive no
repositório [mapexOS](https://github.com/Mapex-Solutions/mapexOS).

[English version](./README.md) · [Site de documentação](https://mapexos.io)

---

## Início rápido

```bash
git clone https://github.com/Mapex-Solutions/mapexOSDeploy.git
cd mapexOSDeploy
docker compose up -d
```

Aguarde ~2 minutos para tudo inicializar (replica-set do Mongo, streams
NATS, buckets MinIO, tabelas ClickHouse). Depois:

- **Frontend**: <http://localhost>
- **Login**: `admin@mapex.local` / `mapex@123` *(altere no primeiro login)*
- **Grafana**: <http://localhost:3001> (`admin` / `admin`)
- **Console MinIO**: <http://localhost:9001> (`mapex_admin` /
  `mapex_admin_secret_change_me`)

Para servir a UI para outras máquinas na sua rede:

```bash
MAPEXOS_PUBLIC_HOST=192.168.0.50 docker compose up -d
```

> Os logs mostrarão uma linha vermelha `[SECURITY WARNING]` por serviço.
> Isso é esperado para avaliação local — indica que você está rodando com
> valores padrão de desenvolvimento. Veja **Deploy em produção** abaixo
> para silenciá-los.

---

## Experimente a plataforma — quickstart

Quando a stack estiver no ar, a pasta [`quickstart/`](./quickstart/) te
leva pela conexão de um sensor de temperatura ponta a ponta: criar
asset template, route group, datasource HTTP ou MQTT, e aí mandar
leituras sintéticas com um pequeno script Node.js e ver chegando no
Grafana.

Cada passo traz payloads JSON prontos para colar nos formulários da UI.

Comece em [`quickstart/README_pt.md`](./quickstart/README_pt.md).

---

## O que está rodando

### Serviços da aplicação

| Serviço | Porta | Finalidade |
|---|---|---|
| Frontend | 80 | SPA Vue 3 + Quasar |
| mapex-iam | 5000 | Usuários, organizações, papéis, autenticação |
| http-gateway | 5001 | Ingestão de webhooks, registro de datasources |
| assets | 5002 | Ativos IoT, templates, campos EVA |
| router | 5003 | Roteamento de eventos, regras de match |
| events | 5004 | Armazenamento ClickHouse, 7 consumers NATS |
| triggers | 5006 | Executores de triggers (HTTP, MQTT, NATS, …) |
| workflow | 5007 | Engine de workflows DAG + plugins |
| mapex-vault | 5010 | Cofre de credenciais, autoridade PKI |
| js-executor | 8000 | Execução V8 de scripts para eventos IoT |
| js-wf-executor | 8001 | Execução V8 de nós de código de workflow |
| plugin-marketplace-mock | 3099 | CDN estática de manifests de plugins (workflow editor → aba Plugins) |

### Infraestrutura

| Serviço | Porta | Imagem |
|---|---|---|
| MongoDB | 27017 | `mongo:7.0.34` (replicaSet `rs0`) |
| MongoDB init | — | `thiagoanselmo/mongodb-init:1.0.0` (one-shot) |
| Redis | 6379 | `redis:7.4.9-alpine` |
| ClickHouse | 8123 / 9440 | `clickhouse/clickhouse-server:26.5.1.882` |
| MinIO | 9000 / 9001 | `minio/minio:RELEASE.2025-09-07T16-13-09Z` |
| NATS Core | 4222 / 8222 | `nats:2.14.1-alpine` |
| MQTT Broker | 1883 | `thiagoanselmo/mapex-broker-mqtt:1.0.0` |
| Prometheus | 9090 | `prom/prometheus:v3.11.3` |
| Grafana | 3001 | `grafana/grafana:13.0.1` (8 dashboards pré-carregados) |

---

## Limites de recursos

Todo serviço de longa duração traz um bloco `deploy.resources.limits`
(CPU + memória) nos compose files. Esses limites foram
**dimensionados de propósito para caber em uma única máquina local** —
mais ou menos um laptop de 4 cores / 8 GB — para você clonar o repo,
subir a stack inteira e simular alguns dispositivos sem sufocar o host.
A soma dos limites fica em torno de **10.5 vCPU / ~5 GB de RAM**.

Alguns pontos importantes:

- **São tetos, não reservas.** O Docker nunca *reserva* esses cores ou
  essa RAM — cada valor é apenas o máximo que um container pode usar.
  Por isso a soma dos limites de CPU dá mais vCPUs do que um laptop
  pequeno tem e mesmo assim a stack roda normalmente: o escalonador do
  kernel divide os cores reais no tempo, e containers ociosos não custam
  nada.
- **Dois engines também são ajustados internamente para casar com o
  teto.** O MongoDB recebe `--wiredTigerCacheSizeGB` e o ClickHouse
  recebe `max_server_memory_usage` / `mark_cache_size`, porque ambos
  dimensionam seus caches pela RAM do *host* por padrão e, sem isso,
  seriam mortos por OOM assim que um limite de container entra em cena.
- **Os init one-shot** (`mongodb-init`, `clickhouse-init`, …) ficam sem
  limite de propósito — rodam por pouco tempo durante o bootstrap e
  limitá-los só arriscaria atrasar ou quebrar o primeiro boot.

> **Produção: revise isso.** Os valores padrão existem para a stack
> caber em um laptop, **não** para ter performance sob carga real.
> Produção roda em um **cluster Kubernetes**, onde estes limites do
> compose não se aplicam — lá você define `resources.requests` /
> `resources.limits` por container (e HPA/VPA) dimensionados conforme a
> sua demanda e uso reais: número de dispositivos, volume de mensagens,
> volume de queries, retenção. Dê folga de verdade para
> MongoDB/ClickHouse/Prometheus e ajuste os serviços sob pressão.
> **Não dimensione pelo `docker stats`** — acompanhe as **métricas do
> seu cluster** (Prometheus / Grafana, `kubectl top pods`, Metrics
> Server) sob carga representativa e ajuste a partir daí.

---

## Parando e limpando

```bash
docker compose down              # para containers, mantém volumes
docker compose down -v           # para + remove volumes (reset completo)

# Reset total (apaga diretórios de dados montados também)
docker compose down -v
rm -rf infra/*/data/* broker-certs/
```

---

## Deploy em produção

A stack vem configurada para avaliação local. Para deploy com
credenciais reais:

### 1. Crie um arquivo env de produção

```bash
cp infra/envs/production.example.env infra/envs/production.env
$EDITOR infra/envs/production.env
```

Descomente todas as linhas e preencha com valores reais. O template
inclui comandos auxiliares para gerar cada segredo (ex: `openssl rand
-hex 32` para `AUTH_SECRET`).

### 2. Aponte o compose para o env de produção

Edite `services/docker-compose.yml` e `infra/docker-compose.yml` para
toda entrada de `env_file:` que hoje referencia `local.env` passar a
referenciar `production.env`. O mesmo para `${GO_ENV:-dev}` — exporte
`GO_ENV=prod` no shell, ou hardcode `prod` no YAML:

```bash
export GO_ENV=prod
export MAPEXOS_PUBLIC_HOST=mapex.exemplo.com
docker compose up -d
docker compose logs -f mapex-iam   # observe "[SECURITY] refusing to start"
```

Cada serviço Mapex possui um **security guard** que recusa iniciar
quando `GO_ENV` ou `NODE_ENV` não está em {`dev`, `development`, vazio}
e qualquer variável sensível (`AUTH_SECRET`, `INTERNAL_API_KEY`,
`NATS_PASSWORD`, …) está ausente ou ainda com o valor padrão de dev.
Esquecer de descomentar um valor em `production.env` gera um erro fatal
na inicialização — nunca um boot silencioso com credenciais vazadas.

> `infra/envs/production.env` está no `.gitignore`. Nunca faça commit dele.

---

## Visão geral da configuração

### Layout

| Arquivo | Papel | Commitado? |
|---|---|---|
| `services/docker-compose.yml` | Versões das imagens fixadas literalmente (ex.: `thiagoanselmo/mapex-iam:1.0.0`) | ✓ |
| `infra/docker-compose.yml` | Serviços de infra (mongo, redis, nats, ...) + imagens Mapex de init/broker | ✓ |
| `infra/envs/local.env` | Env de runtime compartilhada para avaliação local | ✓ |
| `infra/envs/production.example.env` | Template para segredos de produção | ✓ |
| `infra/envs/production.env` | Seus segredos reais de produção | ✗ (gitignored) |
| `services/<svc>/envs/<svc>.env` | Overrides por serviço (portas, nomes, URLs internas) | ✓ |

### Como as versões são fixadas

- **Mapex services** (`thiagoanselmo/*`): a versão é escrita
  diretamente em `services/docker-compose.yml` e
  `infra/docker-compose.yml`. Subir release significa editar esses
  arquivos. Sem var mágica, sem drift surpresa.
- **Imagens de infra** (`mongo`, `redis`, `nats`, ...): fixadas em
  tags concretas em `infra/docker-compose.yml`.
- **Knobs de runtime** (`GO_ENV`, `MAPEXOS_PUBLIC_HOST`) usam a
  sintaxe `${VAR:-default}` no compose, então a stack sobe sem
  nenhum `.env` na raiz. Override via shell:
  ```bash
  GO_ENV=prod MAPEXOS_PUBLIC_HOST=mapex.exemplo.com docker compose up -d
  ```

---

## Versionamento

Este repositório é versionado independentemente do código-fonte dos
serviços. Cada tag do `mapexOSDeploy` fixa uma versão específica de
imagem (literalmente nos compose files) e é testada em conjunto.
Trate a tag deste repo (ex: `v1.0.0`) como fonte da verdade: clonar a
tag correspondente e rodar `docker compose up -d` deve sempre funcionar.

Para atualizar:

```bash
git fetch --tags
git checkout v1.1.0
docker compose pull
docker compose up -d
```

---

## Repositórios fonte

| Projeto | Repo | Status |
|---|---|---|
| MapexOS core (serviços Go + JS + frontend) | `Mapex-Solutions/mapexOS` | privado |
| Plugin MQTT broker (Mosquitto + Go plugin) | `Mapex-Solutions/mapexMQTTBroker` | privado |
| Distribuição Docker Compose (este repo) | `Mapex-Solutions/mapexOSDeploy` | público |

As imagens dos serviços são publicadas em <https://hub.docker.com/u/thiagoanselmo>.

---

## Troubleshooting

**`[SECURITY] refusing to start in GO_ENV=prod`** — você exportou
`GO_ENV=prod` mas `infra/envs/production.env` não sobrescreveu toda
chave sensível. Releia o erro: ele nomeia as env vars ainda em
default de dev. Preencha no `production.env`.

**`unable to pull mapexos/…`** — referência antiga. Toda imagem está
sob `thiagoanselmo/…`. Puxe novamente após `git pull`.

**Frontend diz "network error"** — `MAPEXOS_PUBLIC_HOST` não bate
com a URL que você está usando. Sobrescreva via shell com o que o
navegador usa para chegar na máquina host (`localhost`, um IP, ou um
nome DNS) e recrie o container do frontend:
`MAPEXOS_PUBLIC_HOST=192.168.0.50 docker compose up -d --force-recreate frontend`.

**Containers saem `healthy` e voltam a subir** — normal nos primeiros
2 minutos. `mongodb-init`, `clickhouse-init`, `minio-init` e
`nats-init` são bootstrappers one-shot que saem `0` quando terminam.

**Replica set do Mongo não forma** — geralmente é problema de DNS do
Docker. `docker compose down && docker compose up -d` normalmente
resolve.

---

## Licença

Licenciado sob a [Business Source License 1.1](LICENSE). Consulte o
arquivo LICENSE para os termos completos.

## Suporte

Abra uma issue neste repositório. Para suporte comercial, entre em
contato com [Thiago Anselmo](mailto:thiagoo.anselmoo@gmail.com).
