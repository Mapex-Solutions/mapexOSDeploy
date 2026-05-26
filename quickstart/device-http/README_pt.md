# Quickstart — Device HTTP

Caminhe pela UI do MapexOS pra conectar um sensor de temperatura que
envia leituras via POST HTTP. No fim você terá:

1. Um **asset template** reutilizável descrevendo a forma de dado do
   sensor.
2. Um **route group** que armazena cada evento no ClickHouse.
3. Um **datasource HTTP** que expõe uma URL de webhook protegida por
   API key.
4. Um **asset** chamado `weather-http-001` amarrado ao template, ao
   route group e ao datasource.
5. Um script Node.js (`send-events.js`) que empurra leituras
   sintéticas para você ver chegando no Grafana.

Todo o fluxo é guiado pela UI — sem arquivos JSON, sem `curl` até o
passo 5. Abra <http://localhost> (ou o seu `MAPEXOS_PUBLIC_HOST`) no
browser, logue como `admin@mapex.local` / `mapex@123`, e siga os
passos em ordem. Cada valor abaixo é pra colar como está no campo
correspondente.

---

## Passo 1 — Criar o asset template

O template declara quais campos um sensor de temperatura reporta e
os scripts JS que validam / convertem o payload recebido.

**Caminho UI**: `Assets → Asset Templates → Criar novo`

O formulário é um wizard de 9 sub-passos. Clique **Next** entre cada
sub-passo.

### 1.1 Informações básicas

| Campo | Valor |
|---|---|
| Name | `Temperature Sensor` |
| Status | `Active` |
| Description | `Estação meteorológica com temperatura, umidade e nível de bateria` |
| Category / Manufacturer / Model / Version | *(deixe em branco — opcionais)* |

### 1.2 Asset ID Path

| Campo | Valor |
|---|---|
| Asset ID Path | `assetUUID` |

A plataforma procura o identificador do device sob essa chave em
cada payload recebido. Os payloads de exemplo carregam ele como
`assetUUID`.

### 1.3 Preprocessor script

Cole no editor de código:

```javascript
// Sem pré-processamento — passa o payload adiante sem alterações.
return payload;
```

### 1.4 Validation script

Cole no editor de código:

```javascript
// Aceita qualquer payload que carregue os três campos como números.
return (
  typeof payload.temperature === 'number' &&
  typeof payload.humidity === 'number' &&
  typeof payload.batteryLevel === 'number'
);
```

### 1.5 Conversion script

Cole no editor de código:

```javascript
// Transforma o payload bruto no evento canônico da plataforma.
return {
  eventType: 'data',
  eventId: `${payload.assetUUID}-${Date.now()}`,
  created: new Date().toISOString(),
  data: {
    temperature:  payload.temperature,
    humidity:     payload.humidity,
    batteryLevel: payload.batteryLevel,
  },
};
```

### 1.6 Test payload

No editor **Test Input (JSON)**, cole:

```json
{
  "assetUUID": "weather-http-001",
  "temperature": 22.5,
  "humidity": 68,
  "batteryLevel": 92
}
```

### 1.7 Teste e revisão

O wizard roda automaticamente preprocessor → validator → conversion
contra o payload de teste. Os três precisam reportar sucesso antes
de você avançar. Quando rodar, clique **Next**.

### 1.8 Dynamic fields

Clique em **+ Add field** três vezes e preencha cada linha:

| Field Name | Type | Value Path |
|---|---|---|
| `temperature` | `number` | `payload.data.temperature` |
| `humidity` | `number` | `payload.data.humidity` |
| `batteryLevel` | `number` | `payload.data.batteryLevel` |

Dynamic fields dizem à plataforma quais chaves indexar em coluna
tipada — assim ficam consultáveis no Grafana.

### 1.9 Revisão

Role a tela de resumo, confirme que tudo está como acima, e clique
em **Create Asset Template**.

---

## Passo 2 — Criar o route group

O route group é a lista de ações que rodam quando um evento chega.
Usamos um único router `save_event` para que cada leitura caia no
ClickHouse e apareça no Grafana.

**Caminho UI**: `Routing → Route Groups → Criar novo`

O formulário é um wizard de 3 sub-passos.

### 2.1 Informações básicas

| Campo | Valor |
|---|---|
| Name | `Save Temperature Events` |
| Status | `Active` |
| Description | `Persiste cada leitura de temperatura no ClickHouse` |
| Shared Template | *(deixe desmarcado)* |

### 2.2 Routers

Clique em **+ Add Router** e preencha a única linha:

| Router Name | Kind | Workflow | Match Rules |
|---|---|---|---|
| `save` | `save_event` | — | *(deixe vazio — combina com todo evento)* |

### 2.3 Revisão

Confirme o resumo e clique em **Create Route Group**.

---

## Passo 3 — Criar o datasource HTTP

O datasource expõe a URL do webhook que seu device (ou o
`send-events.js`) vai usar para POSTar telemetria.

**Caminho UI**: `Data → HTTP Data Sources → Criar novo`

O formulário é um wizard de 6 sub-passos.

### 3.1 Informações básicas

| Campo | Valor |
|---|---|
| Name | `Temperature HTTP Webhook` |
| Status | `Enabled` |
| Description | `Endpoint HTTP que recebe leituras de temperatura via POST` |

### 3.2 Working hours & rate limit

Deixe os dois toggles **off** (features opcionais).

### 3.3 Protocol config

Banner read-only mostrando *"HTTP protocol, push mode only"*. Clique
em **Next**.

### 3.4 Autenticação

| Campo | Valor |
|---|---|
| Authentication Type | `API Key` |
| Header Name | `X-API-Key` |
| API Key Value | `quickstart-http-key` *(ou clique em **Generate** e copie o valor)* |

### 3.5 Asset binding

| Campo | Valor |
|---|---|
| Binding Mode | `Dynamic UUID Field` |
| UUID JSON Path | `assetUUID` |

Isto faz o gateway resolver o asset a partir do campo `assetUUID` no
body de cada POST que chega — a mesma chave que o template aponta
em `assetIdPath`.

### 3.6 Revisão

A tela de revisão mostra a **endpoint URL** com botão de copiar.
Clique em **Create Data Source**.

> **Copie duas coisas que você vai precisar no passo 5:**
> 1. O **Data Source ID** (o id hexadecimal longo no final da URL da página de detalhes).
> 2. A **API key** que você colou em 3.4 (`quickstart-http-key` ou o valor gerado).

---

## Passo 4 — Criar o asset

O asset é o device concreto. Ele amarra o template (passo 1), o
route group (passo 2) e herda o protocolo do datasource (passo 3).

**Caminho UI**: `Assets → Assets → Criar novo`

O formulário é um wizard de 6 sub-passos.

### 4.1 Identificação

| Campo | Valor |
|---|---|
| Name | `weather-http-001` |
| Asset ID | `weather-http-001` |
| Status | `Active` |
| Description | `Sensor HTTP de temperatura para o quickstart` |
| Debug Mode | *(off)* |

### 4.2 Asset Template

Escolha **`Temperature Sensor`** no dropdown (o template criado no
passo 1).

### 4.3 Route Groups

Escolha **`Save Temperature Events`** no multi-select (o route group
criado no passo 2).

### 4.4 Conectividade

| Campo | Valor |
|---|---|
| Protocol | `HTTP` |
| Latitude | *(opcional — ex.: `-23.55052` para São Paulo)* |
| Longitude | *(opcional — ex.: `-46.633308`)* |

O formulário mostra um banner *"For HTTP devices, create a Data
Source to receive data from this asset"* — que é exatamente o
datasource criado no passo 3.

### 4.5 Health monitoring

Deixe **Enable Health Monitoring** desligado para o quickstart. (Pode
revisitar depois; com ele off o asset fica em estado de saúde
`unknown`, sem problema.)

### 4.6 Revisão

Confirme o resumo e clique em **Create Asset**.

---

## Passo 5 — Enviar leituras e ver chegando

Abra um terminal nesta pasta e rode:

```bash
node send-events.js --ds=<datasourceId>
```

Substitua `<datasourceId>` pelo id copiado no passo 3.6. O script
empurra 60 leituras, uma por segundo, e imprime `200` em cada uma.

Outras opções:

```bash
# Mandar 200 leituras em vez de 60
node send-events.js --ds=<id> --count=200

# Bater em stack remota (default é http://localhost:5001)
node send-events.js --ds=<id> --gateway=http://192.168.15.6:5001

# Override da API key (precisa bater com o que setou em 3.4)
node send-events.js --ds=<id> --apiKey=<sua-key>

# Usar outro asset UUID (precisa existir)
node send-events.js --ds=<id> --asset=weather-http-002
```

### 5.1 Ver as leituras chegando

- Abra o Grafana: <http://localhost:3001> (`admin` / `admin`).
- Filtre o dashboard de eventos por `assetUUID = weather-http-001` e
  os três campos numéricos (`temperature`, `humidity`,
  `batteryLevel`) começam a gerar gráficos.
- Ou abra o asset na UI (`Assets → Assets → weather-http-001`) e
  veja a timeline de eventos.

---

## Troubleshooting

**`401 Unauthorized` do send-events.js** — o valor do header
`X-API-Key` não bate com a API key do datasource. Corrija o
datasource (passo 3.4) ou passe `--apiKey=<valor certo>` ao script.

**`404 Not Found`** — o query param `ds=` não bate com nenhum
datasource. Re-copie da página de detalhes do datasource.

**`400 Bad Request` com "asset not found"** — o `assetUUID` no
payload não bate com nenhum asset deste datasource. Confirme que o
asset foi criado com `Asset ID = weather-http-001`.

**Erros em scripts de conversão / validação na criação do template** —
verifique que cada script é só o corpo da função (sem `function (...) {}`
envolvendo); o editor já encapsula. Confirme que o payload de teste
em 1.6 tem os três campos numéricos.

**Script crasha com `fetch is not defined`** — seu Node é anterior
ao 18. Atualize para Node 18+ ou faça o mesmo POST com `curl`:

```bash
curl -X POST "http://localhost:5001/api/v1/events?ds=<datasourceId>" \
  -H "X-API-Key: quickstart-http-key" \
  -H "Content-Type: application/json" \
  -d '{"assetUUID":"weather-http-001","temperature":22.5,"humidity":68,"batteryLevel":92}'
```
