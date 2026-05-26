# Quickstart — Device MQTT

Caminhe pela UI do MapexOS pra conectar um sensor de temperatura
que publica suas leituras no broker MQTT incluso na stack. No fim
você terá:

1. Um **asset template** reutilizável descrevendo a forma de dado do
   sensor.
2. Um **route group** que armazena cada evento no ClickHouse.
3. Um **asset** chamado `weather-mqtt-001` amarrado ao template, ao
   route group e ao protocolo MQTT (com credenciais username +
   password).
4. Um script Node.js (`publish-events.js`) que publica leituras
   sintéticas no broker pra você ver chegando no Grafana.

**Não precisa de datasource pra MQTT** — o broker (Mosquitto +
plugin `mapex-broker`) autentica devices direto contra o registro do
asset. O próprio asset carrega as credenciais MQTT.

Todo o fluxo é guiado pela UI. Abra <http://localhost> (ou o seu
`MAPEXOS_PUBLIC_HOST`) no browser, logue como
`admin@mapex.local` / `mapex@123`, e siga os passos em ordem. Cada
valor abaixo é pra colar como está no campo correspondente.

---

## Passo 1 — Criar o asset template

O template declara quais campos um sensor de temperatura reporta e
os scripts JS que validam / convertem o payload recebido.

**Caminho UI**: `Assets → Asset Templates → Criar novo`

O formulário é um wizard de 9 sub-passos. Clique em **Next** entre
cada sub-passo.

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
  "assetUUID": "weather-mqtt-001",
  "temperature": 22.5,
  "humidity": 68,
  "batteryLevel": 92
}
```

### 1.7 Teste e revisão

O wizard roda automaticamente preprocessor → validator → conversion
contra o payload de teste. Os três precisam reportar sucesso antes
de você avançar. Quando rodar, clique **Next**.

> Se você já criou o mesmo template no quickstart HTTP, o wizard vai
> oferecer atualizá-lo em vez de criar — siga em frente, todos os
> valores são idênticos.

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

## Passo 3 — Criar o asset (MQTT)

O asset é o device concreto. Ele amarra o template (passo 1), o
route group (passo 2) e carrega as credenciais MQTT que o broker
vai checar em cada CONNECT.

**Caminho UI**: `Assets → Assets → Criar novo`

O formulário é um wizard de 6 sub-passos.

### 3.1 Identificação

| Campo | Valor |
|---|---|
| Name | `weather-mqtt-001` |
| Asset ID | `weather-mqtt-001` |
| Status | `Active` |
| Description | `Sensor MQTT de temperatura para o quickstart` |
| Debug Mode | *(off)* |

### 3.2 Asset Template

Escolha **`Temperature Sensor`** no dropdown (o template criado no
passo 1).

### 3.3 Route Groups

Escolha **`Save Temperature Events`** no multi-select (o route group
criado no passo 2).

### 3.4 Conectividade

| Campo | Valor |
|---|---|
| Protocol | `MQTT` |
| Client ID | *(auto-preenchido como `weather-mqtt-001` — read-only)* |
| Username | *(auto-preenchido como `weather-mqtt-001` — read-only)* |
| Authentication mode | `user / password` |
| Password | `quickstart-mqtt-pass-change-me` |
| Latitude | *(opcional — ex.: `-23.55052` para São Paulo)* |
| Longitude | *(opcional — ex.: `-46.633308`)* |

Os campos **Client ID** e **Username** são read-only porque o broker
deriva eles do id do asset. Você só escolhe o modo de autenticação
e (para auth de password) a senha.

> Se você escolher **Authentication mode = certificate (mTLS)** ao
> invés, o formulário troca o campo **Password** por **Validity** +
> **Unit** (ex.: `1` + `year`) — a plataforma emite um cert de
> device com esse TTL. O `publish-events.js` incluso só lida com
> username/password, então mantenha `user / password` para o
> quickstart.

### 3.5 Health monitoring

Deixe **Enable Health Monitoring** desligado para o quickstart.
(Pode revisitar depois; com ele off o asset fica em estado de saúde
`unknown`, sem problema.)

### 3.6 Revisão

Confirme o resumo e clique em **Create Asset**.

---

## Passo 4 — Publicar leituras e ver chegando

### 4.1 Instalar dependências

O script MQTT precisa do pacote `mqtt`. Rode uma vez nesta pasta:

```bash
npm install
```

### 4.2 Publicar

```bash
npm start
# ou, equivalente:
node publish-events.js
```

O script conecta em `mqtt://localhost:1883` como
`weather-mqtt-001`, depois publica 60 leituras no tópico
`mapexos/assets/weather-mqtt-001/data`, uma por segundo.

Outras opções:

```bash
# Publicar 200 leituras em vez de 60
node publish-events.js --count=200

# Bater em stack remota (default é mqtt://localhost:1883)
node publish-events.js --broker=mqtt://192.168.15.6:1883

# Override de credenciais (precisa bater com o passo 3.4)
node publish-events.js --username=weather-mqtt-001 --password=quickstart-mqtt-pass-change-me

# Publicar em outro tópico
node publish-events.js --topic=mapexos/custom/weather-mqtt-001
```

### 4.3 Ver as leituras chegando

- Abra o Grafana: <http://localhost:3001> (`admin` / `admin`).
- Filtre o dashboard de eventos por `assetUUID = weather-mqtt-001`
  e os três campos numéricos (`temperature`, `humidity`,
  `batteryLevel`) começam a gerar gráficos.
- Ou abra o asset na UI (`Assets → Assets → weather-mqtt-001`) e
  veja a timeline de eventos.

---

## Troubleshooting

**`Connection refused` do publish-events.js** — o broker não está
escutando em `1883`. Confirme que a stack está no ar
(`docker compose ps mapex-broker-mqtt`). Se está rodando num host
não-local, aponte: `--broker=mqtt://192.168.15.6:1883`.

**`Bad username or password`** — as credenciais no script não batem
com o asset. Atualize a senha do asset (passo 3.4) ou passe
`--username=...` / `--password=...` ao script.

**Eventos publicam OK mas não aparecem no Grafana** — confirme:
1. O datasource está `enabled` *(N/A para MQTT — não existe
   datasource)*.
2. O route group do passo 2 está `enabled`.
3. O `Asset ID` do asset bate com o que o script publica
   (`weather-mqtt-001` por default).
4. O plugin do broker realmente recebeu o publish — veja
   `docker logs mapex-broker-mqtt` procurando linha `INGRESS`.

**`Missing "mqtt" package`** — rode `npm install` nesta pasta.
