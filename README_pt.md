# MapexOS Stack

> Plataforma IoT auto-hospedável para ingestão de telemetria, roteamento
> baseado em regras, execução de workflows e gestão de ativos. Imagens
> pré-compiladas no Docker Hub; um único comando para subir toda a stack.

Este repositório distribui a orquestração Docker Compose da plataforma
MapexOS. O código-fonte dos serviços está em repositórios privados da
Mapex Solutions — este repo puxa as imagens publicadas no Docker Hub.

---

## Início rápido

```bash
git clone https://github.com/thiagoanselmo/mapexos-stack.git
cd mapexos-stack
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

### Infraestrutura

| Serviço | Porta | Imagem |
|---|---|---|
| MongoDB | 27017 | `mongo:7` (replicaSet `rs0`) |
| Redis | 6379 | `redis:7-alpine` |
| ClickHouse | 8123 / 9440 | `clickhouse/clickhouse-server` |
| MinIO | 9000 / 9001 | `minio/minio` |
| NATS Core | 4222 / 8222 | `nats:2.12-alpine` |
| MQTT Broker | 1883 | `thiagoanselmo/mapex-broker-mqtt` |
| Prometheus | 9090 | `prom/prometheus` |
| Grafana | 3001 | `grafana/grafana` (8 dashboards pré-carregados) |

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
cp envs/production.example.env envs/production.env
$EDITOR envs/production.env
```

Descomente todas as linhas e preencha com valores reais. O template
inclui comandos auxiliares para gerar cada segredo (ex: `openssl rand
-hex 32` para `AUTH_SECRET`).

### 2. Atualize o `.env` canônico

```diff
- ENV_PROFILE=local
- GO_ENV=dev
- NODE_ENV=dev
- IMAGE_TAG=1.0.0
- MAPEXOS_PUBLIC_HOST=localhost
+ ENV_PROFILE=production
+ GO_ENV=prod
+ NODE_ENV=prod
+ IMAGE_TAG=1.0.0          # ou a release que quiser fixar
+ MAPEXOS_PUBLIC_HOST=mapex.exemplo.com
```

### 3. Suba a stack

```bash
docker compose up -d
docker compose logs -f mapex-iam   # observe "[SECURITY] refusing to start"
```

Cada serviço Mapex possui um **security guard** que recusa iniciar
quando `GO_ENV` ou `NODE_ENV` não está em {`dev`, `development`, vazio}
e qualquer variável sensível (`AUTH_SECRET`, `INTERNAL_API_KEY`,
`NATS_PASSWORD`, …) está ausente ou ainda com o valor padrão de dev.
Esquecer de descomentar um valor em `production.env` gera um erro fatal
na inicialização — nunca um boot silencioso com credenciais vazadas.

> `envs/production.env` está no `.gitignore`. Nunca faça commit dele.

---

## Visão geral da configuração

### Arquivos

| Arquivo | Papel | Commitado? |
|---|---|---|
| `.env` | Knobs canônicos (perfil, env, tag da imagem, host público) | ✓ |
| `envs/local.env` | Env por container para avaliação local | ✓ |
| `envs/production.example.env` | Template para segredos de produção | ✓ |
| `envs/production.env` | Seus segredos reais de produção | ✗ (gitignored) |
| `services/<svc>/envs/<svc>.env` | Overrides por serviço (portas, URLs internas) | ✓ |

### Como os quatro knobs fluem

```
.env
 ├── ENV_PROFILE      → qual envs/<profile>.env é carregado por cada serviço
 ├── GO_ENV / NODE_ENV → injetados no compose-substitution em:
 │                       - DB_PREFIX                ("${GO_ENV}-mapex_vault", …)
 │                       - Prefixo de subjects NATS ("${GO_ENV}.mapexos.…")
 │                       - Prefixo UPPER de streams  ("${UPPER_ENV}-MAPEXOS-…")
 │                       - O security guard do serviço
 ├── IMAGE_TAG        → tag de toda imagem thiagoanselmo/* puxada
 └── MAPEXOS_PUBLIC_HOST → host que o frontend usa para alcançar as APIs
```

---

## Versionamento

Este repositório é versionado independentemente do código-fonte dos
serviços. Cada tag do `mapexos-stack` fixa um `IMAGE_TAG` específico e é
testada em conjunto. Trate a tag deste repo (ex: `v1.0.0`) como fonte da
verdade: clonar a tag correspondente e rodar `docker compose up -d` deve
sempre funcionar.

Para atualizar:

```bash
git fetch --tags
git checkout v1.1.0
$EDITOR .env            # atualize IMAGE_TAG para 1.1.0
docker compose pull
docker compose up -d
```

---

## Repositórios fonte

| Projeto | Repo | Status |
|---|---|---|
| MapexOS core (serviços Go + JS + frontend) | `Mapex-Solutions/mapexOS` | privado |
| Plugin MQTT broker (Mosquitto + Go plugin) | `Mapex-Solutions/mapexMQTTBroker` | privado |
| Distribuição Docker Compose (este repo) | `thiagoanselmo/mapexos-stack` | público |

As imagens dos serviços são publicadas em <https://hub.docker.com/u/thiagoanselmo>.

---

## Licença

Licenciado sob a [Business Source License 1.1](LICENSE). Consulte o
arquivo LICENSE para os termos completos.

## Suporte

Abra uma issue neste repositório. Para suporte comercial, entre em
contato com [Thiago Anselmo](mailto:thiagoo.anselmoo@gmail.com).
