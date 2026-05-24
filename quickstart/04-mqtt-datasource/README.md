# 04 — MQTT datasource

The MQTT path: the platform's bundled MQTT broker accepts publishes
from any MQTT client authenticated with the asset's credentials. Once
you create the asset with `protocol.type=mqtt`, the platform
provisions a username/password pair you set in the asset payload.

You will create:
1. An **MQTT datasource** so the platform expects ingress on the MQTT
   protocol.
2. An **asset** with `protocol.type=mqtt` carrying its MQTT
   credentials.
3. Then run **`publish-events.js`** to publish a stream of fake
   readings.

## Files in this folder

- [`datasource.json`](./datasource.json) — payload for the datasource
  creation form.
- [`asset.json`](./asset.json) — payload for the asset creation form.
- [`publish-events.js`](./publish-events.js) — Node.js MQTT publisher.
- [`package.json`](./package.json) — declares the `mqtt` dependency
  and the `npm start` script.

## Steps on the UI

### 4.1 Create the datasource

1. From the side menu, open **Gateway → Data Sources**.
2. Click **New Data Source**.
3. Fill the form from [`datasource.json`](./datasource.json):
   - **Name**: `Quickstart MQTT Gateway`
   - **Mode**: `push`
   - **Protocol**: `mqtt`
   - **Auth → Type**: `none` (auth lives on the asset, not the
     datasource, for MQTT)
   - **Asset bind → Type**: `uuidField`
   - **Asset bind → UUID fields**: `assetUUID`
4. Click **Save**.

### 4.2 Create the asset

1. From the side menu, open **Assets → Assets**.
2. Click **New Asset**.
3. Fill the form from [`asset.json`](./asset.json):
   - **Name**: `Weather Station MQTT`
   - **Asset UUID**: `weather-mqtt-001`
   - **Asset Template**: pick "Temperature Sensor" (from step 01).
   - **Route Groups**: pick "Save Temperature Events" (from step 02).
   - **Protocol → Type**: `mqtt`
   - **Protocol → MQTT → Client ID**: `weather-mqtt-001`
   - **Protocol → MQTT → Username**: `weather-mqtt-001`
   - **Protocol → MQTT → Auth type**: `password`
   - **Protocol → MQTT → Password**: `quickstart-mqtt-pass-change-me`
     (change it to anything, just remember it — you'll pass it to the
     script via `--password=...`).
4. Click **Save**.

### 4.3 Publish some data

Install dependencies once (one-shot):

```bash
npm install
```

Then run:

```bash
npm start
# or, equivalently:
node publish-events.js
```

The script publishes 60 readings, one per second, to topic
`mapexos/assets/weather-mqtt-001/data`.

Other options:

```bash
# Publish 200 readings instead of 60
node publish-events.js --count=200

# Use a different broker URL (e.g. a remote stack)
node publish-events.js --broker=mqtt://mapex.example.com:1883

# Override credentials (must match the asset)
node publish-events.js --username=weather-mqtt-001 --password=my-custom-pass

# Publish to a different topic
node publish-events.js --topic=mapexos/custom/weather-mqtt-001
```

### 4.4 See the data land

- Open Grafana: <http://localhost:3001> (`admin` / `admin`).
- Filter the events dashboard by `assetUUID = weather-mqtt-001`.
- Or open the asset page in the UI and check its event timeline.

## Troubleshooting

**`Connection refused`** — the broker isn't listening on `1883`.
Confirm the stack is up (`docker compose ps mapex-broker-mqtt`) and
adjust `--broker=` if you bound to a different port.

**`Bad username or password`** — the credentials in the script don't
match the ones in the asset. Either update the asset's
`protocol.mqtt.password` to match the script default, or pass
`--username=` / `--password=` flags to match the asset.

**Events publish OK but don't show up in Grafana** — confirm the
datasource is `enabled` and the asset's `assetUUID` exactly matches
what the script publishes (`weather-mqtt-001` by default). Also
confirm the route group from step 02 is `enabled`.

**`Missing "mqtt" package`** — run `npm install` in this folder
first.
