# Quickstart — MQTT device

Walk through the MapexOS UI to wire a temperature sensor that
publishes its readings to the bundled MQTT broker. By the end you'll
have:

1. A reusable **asset template** describing the sensor's data shape.
2. A **route group** that stores incoming events in ClickHouse.
3. An **asset** named `weather-mqtt-001` bound to the template, the
   route group and the MQTT protocol (with username + password
   credentials).
4. A small Node.js script (`publish-events.js`) that publishes fake
   readings to the broker so you can watch them land in Grafana.

**No datasource is needed for MQTT** — the broker (Mosquitto +
`mapex-broker` plugin) authenticates devices directly against the
asset record. The asset itself carries its MQTT credentials.

The whole flow is UI-driven. Open <http://localhost> (or your
`MAPEXOS_PUBLIC_HOST`) in a browser, log in as
`admin@mapex.local` / `mapex@123`, and follow each step in order.
Every value below is meant to be copied into the matching field
as-is.

> **Already did the HTTP quickstart?** The asset template and the
> route group are transport-agnostic — the template only describes
> the JSON shape and conversion logic, and the route group just sends
> events to ClickHouse. You can skip **Step 1** and **Step 2** and
> jump straight to **[Step 3 — Create the asset (MQTT)](#step-3--create-the-asset-mqtt)**,
> reusing the `Temperature Sensor` template and the `LakeHouse Storage`
> route group you already configured. Only redo them when you want a
> different payload shape (new template) or to route the event somewhere
> else (e.g., a trigger or fires a workflow).

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
incoming payload. The sample payloads we'll publish carry it as
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
  "assetUUID": "weather-mqtt-001",
  "temperature": 22.5,
  "humidity": 68,
  "batteryLevel": 92
}
```

### 1.7 Testing & review

The wizard auto-runs the preprocessor → validator → conversion chain
against the test payload. All three must report success before you
can move on. If they do, click **Next**.

> If you already created the same template during the HTTP
> quickstart, the wizard will offer to update it instead — keep
> going, all values are identical.

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

## Step 3 — Create the asset (MQTT)

The asset is the concrete device. It binds the template (step 1), the
route group (step 2) and carries the MQTT credentials the broker
will check on every CONNECT.

**UI path**: `Assets → Assets → Create new`

The form is a 6-step wizard.

### 3.1 Identification

| Field | Value |
|---|---|
| Name | `weather-mqtt-001` |
| Asset ID | `weather-mqtt-001` |
| Status | `Active` |
| Description | `Sample MQTT temperature sensor for the quickstart` |
| Debug Mode | *(on)* | Show logs

### 3.2 Asset Template

Pick **`Temperature Sensor`** from the dropdown (the template created
in step 1).

### 3.3 Route Groups

Pick **`Save Temperature Events`** from the multi-select (the route
group created in step 2).

### 3.4 Connectivity

| Field | Value |
|---|---|
| Protocol | `MQTT` |
| Client ID | *(auto-filled to `weather-mqtt-001` — read-only)* |
| Username | *(auto-filled to `weather-mqtt-001` — read-only)* |
| Authentication mode | `user / password` |
| Password | `quickstart-mqtt-pass-change-me` |
| Latitude | *(optional — e.g. `-23.55052` for São Paulo)* |
| Longitude | *(optional — e.g. `-46.633308`)* |

The **Client ID** and **Username** fields are read-only because the
broker derives them from the asset id. You only choose the
authentication mode and (for password auth) the password.

> If you pick **Authentication mode = certificate (mTLS)** instead,
> the form swaps the **Password** field for **Validity** + **Unit**
> (e.g. `1` + `year`) — the platform issues a device cert with that
> TTL. The bundled `publish-events.js` only handles
> username/password, so for the quickstart keep `user / password`.

### 3.5 Health monitoring

Leave **Enable Health Monitoring** toggled off for the quickstart.
(You can revisit later; with this off the asset stays in `unknown`
health state and that's fine.)

### 3.6 Review

Confirm the summary, click **Create Asset**.

---

## Step 4 — Publish some readings and watch them land

### 4.1 Install dependencies

The MQTT script needs the `mqtt` package. Run once in this folder:

```bash
npm install
```

### 4.2 Publish

```bash
npm start
# or, equivalently:
node publish-events.js
```

The script connects to `mqtt://localhost:1883` as
`weather-mqtt-001`, then publishes 60 readings to topic
`events/weather-mqtt-001/data`, one per second.

The broker plugin only accepts publishes on
`events/{assetUUID}/{eventType}` — every other topic shape is
rejected by the broker ACL, so the device must use that exact
prefix.

Other knobs:

```bash
# Publish 200 readings instead of 60
node publish-events.js --count=200

# Hit a remote stack (default is mqtt://localhost:1883)
node publish-events.js --broker=mqtt://192.168.15.6:1883

# Override credentials (must match step 3.4)
node publish-events.js --username=weather-mqtt-001 --password=quickstart-mqtt-pass-change-me

# Publish to a different event type (still under events/<assetUUID>/...)
node publish-events.js --topic=events/weather-mqtt-001/alert
```

### 4.3 See the readings

- Open Grafana: <http://localhost:3001> (`admin` / `admin`).
- Filter the events dashboard by `assetUUID = weather-mqtt-001` and
  the three numeric fields (`temperature`, `humidity`,
  `batteryLevel`) start charting.
- Or open the asset in the UI (`Assets → Assets → weather-mqtt-001`)
  and check its event timeline.

---

## Troubleshooting

**`Connection refused` from publish-events.js** — the broker isn't
listening on `1883`. Confirm the stack is up
(`docker compose ps mapex-broker-mqtt`). If running on a non-local
host, point at it: `--broker=mqtt://192.168.15.6:1883`.

**`Bad username or password`** — the credentials in the script don't
match the asset. Either update the asset's password (step 3.4) or
pass `--username=...` / `--password=...` to the script.

**Events publish OK but don't show up in Grafana** — confirm:
1. The datasource is `enabled` *(N/A for MQTT — there's no datasource)*.
2. The route group from step 2 is `enabled`.
3. The asset's `Asset ID` matches what the script publishes
   (`weather-mqtt-001` by default).
4. The broker plugin actually received the publish — check
   `docker logs mapex-broker-mqtt` and look for an `INGRESS` line.

**`Missing "mqtt" package`** — run `npm install` in this folder
first.
