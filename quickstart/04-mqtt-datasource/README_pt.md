# 04 — Datasource MQTT

O caminho MQTT: o broker MQTT incluso na plataforma aceita publishes
de qualquer cliente MQTT autenticado com as credenciais do asset. Ao
criar o asset com `protocol.type=mqtt`, a plataforma usa o par
username/password que você definiu no payload do asset.

Você vai criar:
1. Um **datasource MQTT** para a plataforma esperar ingresso no
   protocolo MQTT.
2. Um **asset** com `protocol.type=mqtt` carregando as credenciais
   MQTT.
3. Aí rodar o **`publish-events.js`** para publicar uma stream de
   leituras sintéticas.

## Arquivos nesta pasta

- [`datasource.json`](./datasource.json) — payload para o formulário
  de criação do datasource.
- [`asset.json`](./asset.json) — payload para o formulário de
  criação do asset.
- [`publish-events.js`](./publish-events.js) — publisher MQTT em
  Node.js.
- [`package.json`](./package.json) — declara a dependência `mqtt` e o
  script `npm start`.

## Passo a passo na UI

### 4.1 Criar o datasource

1. No menu lateral, abra **Gateway → Data Sources**.
2. Clique em **Novo Data Source**.
3. Preencha o formulário a partir do
   [`datasource.json`](./datasource.json):
   - **Nome**: `Quickstart MQTT Gateway`
   - **Mode**: `push`
   - **Protocolo**: `mqtt`
   - **Auth → Tipo**: `none` (para MQTT, a auth fica no asset, não no
     datasource)
   - **Asset bind → Tipo**: `uuidField`
   - **Asset bind → Campos UUID**: `assetUUID`
4. Clique em **Salvar**.

### 4.2 Criar o asset

1. No menu lateral, abra **Assets → Assets**.
2. Clique em **Novo Asset**.
3. Preencha a partir do [`asset.json`](./asset.json):
   - **Nome**: `Weather Station MQTT`
   - **Asset UUID**: `weather-mqtt-001`
   - **Asset Template**: escolha "Temperature Sensor" (do passo 01).
   - **Route Groups**: escolha "Save Temperature Events" (do passo 02).
   - **Protocolo → Tipo**: `mqtt`
   - **Protocolo → MQTT → Client ID**: `weather-mqtt-001`
   - **Protocolo → MQTT → Username**: `weather-mqtt-001`
   - **Protocolo → MQTT → Tipo de auth**: `password`
   - **Protocolo → MQTT → Password**: `quickstart-mqtt-pass-change-me`
     (mude para o que quiser, só lembre — você passa para o script
     via `--password=...`).
4. Clique em **Salvar**.

### 4.3 Publicar dados

Instale as dependências uma vez (one-shot):

```bash
npm install
```

Depois rode:

```bash
npm start
# ou, equivalente:
node publish-events.js
```

O script publica 60 leituras, uma por segundo, no tópico
`mapexos/assets/weather-mqtt-001/data`.

Outras opções:

```bash
# Publicar 200 leituras em vez de 60
node publish-events.js --count=200

# Usar outra URL de broker (ex.: stack remota)
node publish-events.js --broker=mqtt://mapex.exemplo.com:1883

# Override de credenciais (precisam bater com o asset)
node publish-events.js --username=weather-mqtt-001 --password=meu-pass

# Publicar em outro tópico
node publish-events.js --topic=mapexos/custom/weather-mqtt-001
```

### 4.4 Ver os dados chegando

- Abra o Grafana: <http://localhost:3001> (`admin` / `admin`).
- Filtre o dashboard de eventos por `assetUUID = weather-mqtt-001`.
- Ou abra a página do asset na UI e veja a timeline de eventos.

## Troubleshooting

**`Connection refused`** — o broker não está escutando em `1883`.
Confirme que a stack está no ar (`docker compose ps mapex-broker-mqtt`)
e ajuste `--broker=` se você usou outra porta.

**`Bad username or password`** — as credenciais no script não batem
com as do asset. Atualize `protocol.mqtt.password` do asset para
bater com o default do script, ou passe os flags `--username=` /
`--password=` batendo com o asset.

**Eventos publicam OK mas não aparecem no Grafana** — confirme que o
datasource está `enabled` e que o `assetUUID` do asset bate
exatamente com o que o script publica (`weather-mqtt-001` por
default). Confirme também que o route group do passo 02 está
`enabled`.

**`Missing "mqtt" package`** — rode `npm install` nesta pasta.
