# 03 — Datasource HTTP

O caminho HTTP: uma URL de webhook que aceita POSTs de qualquer cliente
HTTP (curl, Postman, seu firmware, o script Node.js incluso).

Você vai criar:
1. Um **datasource** que expõe a URL do webhook e protege com API key.
2. Um **asset** amarrado ao datasource via `assetUUID`.
3. Aí rodar o **`send-events.js`** para mandar uma stream de leituras
   sintéticas.

## Arquivos nesta pasta

- [`datasource.json`](./datasource.json) — payload para o formulário
  de criação do datasource.
- [`asset.json`](./asset.json) — payload para o formulário de
  criação do asset (você substitui os placeholders de template id e
  route group id antes de colar).
- [`send-events.js`](./send-events.js) — script Node.js 18+ que faz
  POSTs no webhook. Sem npm install.

## Passo a passo na UI

### 3.1 Criar o datasource

1. No menu lateral, abra **Gateway → Data Sources**.
2. Clique em **Novo Data Source**.
3. Abra o [`datasource.json`](./datasource.json). Preencha o formulário:
   - **Nome**: `Quickstart HTTP Webhook`
   - **Mode**: `push`
   - **Protocolo**: `http`
   - **Auth → Tipo**: `apiKey`
   - **Auth → Nome do header**: `X-API-Key`
   - **Auth → Valor da chave**: `quickstart-http-key-change-me`
     (mude para o que quiser, só lembre — você passa para o script via
     `--apiKey=...`).
   - **Asset bind → Tipo**: `uuidField`
   - **Asset bind → Campos UUID**: `assetUUID`
4. Clique em **Salvar**.
5. Abra o datasource que você acabou de criar e **copie o id** dele da
   URL ou da página de detalhes — esse é o query param `ds` que o
   webhook espera.

### 3.2 Criar o asset

1. No menu lateral, abra **Assets → Assets**.
2. Clique em **Novo Asset**.
3. Abra o [`asset.json`](./asset.json). Preencha o formulário:
   - **Nome**: `Weather Station HTTP`
   - **Asset UUID**: `weather-http-001`
   - **Asset Template**: escolha "Temperature Sensor" no dropdown
     (o template do passo 01).
   - **Route Groups**: escolha "Save Temperature Events" no dropdown
     (o route group do passo 02).
   - **Protocolo → Tipo**: `http`
4. Clique em **Salvar**.

### 3.3 Mandar dados

Abra um terminal nesta pasta e rode:

```bash
node send-events.js --ds=<datasourceId>
```

Substitua `<datasourceId>` pelo id que você copiou no passo 3.1. O
script empurra 60 leituras, uma por segundo, e imprime `200` para
cada uma.

Outras opções:

```bash
# Mandar 200 leituras em vez de 60
node send-events.js --ds=<id> --count=200

# Usar outra URL de gateway (ex.: stack remota)
node send-events.js --ds=<id> --gateway=http://mapex.exemplo.com:5001

# Override do asset UUID (precisa bater com um asset existente)
node send-events.js --ds=<id> --asset=weather-http-002

# Override da API key (precisa bater com auth.apiKey.key do datasource)
node send-events.js --ds=<id> --apiKey=meu-segredo
```

### 3.4 Ver os dados chegando

- Abra o Grafana: <http://localhost:3001> (`admin` / `admin`).
- Os dashboards pré-carregados incluem uma visão de eventos. Filtre
  pelo UUID do asset (`weather-http-001`) para ver os valores chegando.
- Ou consulte direto: abra a página de Assets, escolha o asset
  "Weather Station HTTP", e inspecione a timeline de eventos dele.

## Troubleshooting

**`401 Unauthorized`** — o valor do header `X-API-Key` não bate com
o `auth.apiKey.key` do datasource. Corrija o datasource ou passe
`--apiKey=<o valor certo>` para o script.

**`404 Not Found`** — o query param `ds=` não bate com nenhum
datasource. Re-copie o id da UI.

**`400 Bad Request` com "asset not found"** — o `assetUUID` no
payload não está amarrado a nenhum asset deste datasource. Confirme
que o asset foi criado com `assetUUID: "weather-http-001"` (ou o
valor que você usou).

**Script falha com `fetch is not defined`** — seu Node é anterior
ao 18. Atualize o Node ou use `curl` para mandar um evento manual:
```bash
curl -X POST "http://localhost:5001/api/v1/events?ds=<id>" \
  -H "X-API-Key: quickstart-http-key-change-me" \
  -H "Content-Type: application/json" \
  -d '{"assetUUID":"weather-http-001","temperature":22.5,"humidity":68,"batteryLevel":92}'
```
