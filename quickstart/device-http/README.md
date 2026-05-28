# Quickstart — HTTP device

Walk through the MapexOS UI to wire a temperature sensor that sends
its readings via an HTTP POST. By the end you'll have:

1. A reusable **asset template** describing the sensor's data shape.
2. A **route group** that stores incoming events in ClickHouse.
3. An **HTTP datasource** that exposes a webhook URL secured with an
   API key.
4. An **asset** named `weather-http-001` bound to the template, the
   route group and the datasource.
5. A small Node.js script (`send-events.js`) that pushes fake
   readings so you can watch them land in Grafana.

The whole flow is UI-driven — no JSON files, no `curl` invocations
until step 5. Open <http://localhost> (or your `MAPEXOS_PUBLIC_HOST`)
in a browser, log in as `admin@mapex.local` / `mapex@123`, and follow
each step in order. Every value below is meant to be copied into the
matching field as-is.

---

## Step 1 — Create the asset template

The template declares what fields a temperature sensor reports and
the JS scripts that validate / convert the incoming payload.

**UI path**: `Assets → Asset Templates → Create new`

The form is a 9-step wizard. Click **Next** between sub-steps.

### 1.1 Basic information

| Field | Value |
|---|---|
| Name | `Temperature Sensor` |
| Status | `Active` |
| Description | `Weather station with temperature, humidity and battery monitoring` |
| Category / Manufacturer / Model / Version | *(leave blank — optional)* |

### 1.2 Asset ID Path

| Field | Value |
|---|---|
| Asset ID Path | `assetUUID` |

The platform looks for the device identifier under this key in every
incoming payload. The sample payloads we'll send carry it as
`assetUUID`.

### 1.3 Preprocessor script

Paste in the code editor:

```javascript
// No preprocessing needed — pass the payload through untouched.
const result = payload;
```

### 1.4 Validation script

Paste in the code editor:

```javascript
// Accept anything that carries the three sensor fields as numbers.
const ok = typeof payload.temperature === 'number'
        && typeof payload.humidity === 'number'
        && typeof payload.batteryLevel === 'number';
if (!ok) throw new Error('Payload must contain temperature, humidity and batteryLevel as numbers');
const result = payload;
```

### 1.5 Conversion script

Paste in the code editor:

```javascript
// Reshape the raw payload into the platform's canonical event.
const result = {
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

In the **Test Input (JSON)** code editor, paste:

```json
{
  "assetUUID": "weather-http-001",
  "temperature": 22.5,
  "humidity": 68,
  "batteryLevel": 92
}
```

### 1.7 Testing & review

The wizard auto-runs the preprocessor → validator → conversion chain
against the test payload. All three must report success before you
can move on. If they do, click **Next**.

### 1.8 Dynamic fields

Click **+ Add field** three times and fill each row:

| Field Name | Type | Value Path |
|---|---|---|
| `temperature` | `number` | `payload.data.temperature` |
| `humidity` | `number` | `payload.data.humidity` |
| `batteryLevel` | `number` | `payload.data.batteryLevel` |

Dynamic fields tell the platform which keys to index in a typed
column so they're queryable from Grafana.

### 1.9 Review

Scroll through the summary, confirm everything reads as above, then
click **Create Asset Template**.

---

## Step 2 — Create the route group

The route group is the list of actions to run when an event arrives.
We use a single `save_event` router so each reading lands in
ClickHouse and shows up in Grafana.

**UI path**: `Routing → Route Groups → Create new`

The form is a 3-step wizard.

### 2.1 Basic information

| Field | Value |
|---|---|
| Name | `Save Temperature Events` |
| Status | `Active` |
| Description | `Persist every temperature reading to ClickHouse` |
| Shared Template | *(leave unchecked)* |

### 2.2 Routers

Click **+ Add Router** and fill the only row:

| Router Name | Kind | Workflow | Match Rules |
|---|---|---|---|
| `save` | `save_event` | — | *(leave empty — match every event)* |

### 2.3 Review

Confirm the summary, click **Create Route Group**.

---

## Step 3 — Create the HTTP datasource

The datasource exposes the webhook URL your device (or
`send-events.js`) will POST telemetry to.

**UI path**: `Data → HTTP Data Sources → Create new`

The form is a 6-step wizard.

### 3.1 Basic information

| Field | Value |
|---|---|
| Name | `Temperature HTTP Webhook` |
| Status | `Enabled` |
| Description | `HTTP endpoint that receives temperature readings via POST` |

### 3.2 Working hours & rate limit

Leave both toggles **off** (optional features).

### 3.3 Protocol config

Read-only info banner reading *"HTTP protocol, push mode only"*.
Click **Next**.

### 3.4 Authentication

| Field | Value |
|---|---|
| Authentication Type | `API Key` |
| Header Name | `X-API-Key` |
| API Key Value | `quickstart-http-key` *(or click **Generate** and copy the value)* |

### 3.5 Asset binding

| Field | Value |
|---|---|
| Binding Mode | `Dynamic UUID Field` |
| UUID JSON Path | `assetUUID` |

This makes the gateway resolve the asset from the `assetUUID` field
in every incoming POST body — the same key the template's
`assetIdPath` points at.

### 3.6 Review

The review screen shows the **endpoint URL** with a copy button.
Click **Create Data Source**.

> **Copy two things you'll need in step 5:**
> 1. The **Data Source ID** (the long hex id at the end of the URL on the detail page).
> 2. The **API key** you pasted in step 3.4 (`quickstart-http-key` or the value you generated).

---

## Step 4 — Create the asset

The asset is the concrete device. It binds the template (step 1), the
route group (step 2) and inherits the protocol from the datasource
(step 3).

**UI path**: `Assets → Assets → Create new`

The form is a 6-step wizard.

### 4.1 Identification

| Field | Value |
|---|---|
| Name | `weather-http-001` |
| Asset ID | `weather-http-001` |
| Status | `Active` |
| Description | `Sample HTTP temperature sensor for the quickstart` |
| Debug Mode | *(off)* |

### 4.2 Asset Template

Pick **`Temperature Sensor`** from the dropdown (the template created
in step 1).

### 4.3 Route Groups

Pick **`Save Temperature Events`** from the multi-select (the route
group created in step 2).

### 4.4 Connectivity

| Field | Value |
|---|---|
| Protocol | `HTTP` |
| Latitude | *(optional — e.g. `-23.55052` for São Paulo)* |
| Longitude | *(optional — e.g. `-46.633308`)* |

The form shows a banner reading *"For HTTP devices, create a Data
Source to receive data from this asset"* — which is the datasource
you already created in step 3.

### 4.5 Health monitoring

Leave **Enable Health Monitoring** toggled off for the quickstart.
(You can revisit later; with this off the asset stays in `unknown`
health state and that's fine.)

### 4.6 Review

Confirm the summary, click **Create Asset**.

---

## Step 5 — Push some readings and watch them land

Open a terminal in this folder and run:

```bash
node send-events.js --ds=<datasourceId>
```

Replace `<datasourceId>` with the id you copied in step 3.6. The
script pushes 60 readings, one per second, and prints `200` for each.

Other knobs:

```bash
# Send 200 readings instead of 60
node send-events.js --ds=<id> --count=200

# Hit a remote stack (default is http://localhost:5001)
node send-events.js --ds=<id> --gateway=http://192.168.15.6:5001

# Override the API key (must match what you set in step 3.4)
node send-events.js --ds=<id> --apiKey=<your-key>

# Use a different asset UUID (must match an existing asset)
node send-events.js --ds=<id> --asset=weather-http-002
```

### 5.1 See the readings

- Open Grafana: <http://localhost:3001> (`admin` / `admin`).
- Filter the events dashboard by `assetUUID = weather-http-001` and
  the three numeric fields (`temperature`, `humidity`,
  `batteryLevel`) start charting.
- Or open the asset in the UI (`Assets → Assets → weather-http-001`)
  and check its event timeline.

---

## Troubleshooting

**`401 Unauthorized` from send-events.js** — the `X-API-Key` value
doesn't match the datasource's API key. Fix the datasource (step 3.4)
or pass `--apiKey=<the right value>` to the script.

**`404 Not Found`** — the `ds=` query parameter doesn't match an
existing datasource id. Re-copy it from the datasource detail page.

**`400 Bad Request` with "asset not found"** — the `assetUUID` in
the payload doesn't match any asset bound to this datasource.
Confirm the asset was created with `Asset ID = weather-http-001`.

**Conversion / validation script errors at template creation** —
make sure each script is plain function body (no `function (...) {}`
wrapper); the editor wraps the body for you. Re-check that the test
payload in step 1.6 has all three numeric fields.

**Script crashes with `fetch is not defined`** — your Node is older
than 18. Upgrade Node 18+ or invoke the same POST with `curl`:

```bash
curl -X POST "http://localhost:5001/api/v1/events?ds=<datasourceId>" \
  -H "X-API-Key: quickstart-http-key" \
  -H "Content-Type: application/json" \
  -d '{"assetUUID":"weather-http-001","temperature":22.5,"humidity":68,"batteryLevel":92}'
```
