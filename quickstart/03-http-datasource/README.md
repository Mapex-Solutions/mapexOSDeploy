# 03 — HTTP datasource

The HTTP path: a webhook URL that accepts POSTs from any HTTP client
(curl, Postman, your firmware, the bundled Node.js script).

You will create:
1. A **datasource** that exposes the webhook URL and protects it with
   an API key.
2. An **asset** bound to the datasource via its `assetUUID`.
3. Then run **`send-events.js`** to push a stream of fake readings.

## Files in this folder

- [`datasource.json`](./datasource.json) — payload for the datasource
  creation form.
- [`asset.json`](./asset.json) — payload for the asset creation form
  (you fill the template id and route group id placeholders before
  pasting).
- [`send-events.js`](./send-events.js) — Node.js 18+ script that POSTs
  events to the webhook. No npm install needed.

## Steps on the UI

### 3.1 Create the datasource

1. From the side menu, open **Gateway → Data Sources**.
2. Click **New Data Source**.
3. Open [`datasource.json`](./datasource.json). Fill the form:
   - **Name**: `Quickstart HTTP Webhook`
   - **Mode**: `push`
   - **Protocol**: `http`
   - **Auth → Type**: `apiKey`
   - **Auth → Header name**: `X-API-Key`
   - **Auth → Key value**: `quickstart-http-key-change-me`
     (change it to anything you want, just remember it — you'll pass
     it to the script via `--apiKey=...`).
   - **Asset bind → Type**: `uuidField`
   - **Asset bind → UUID fields**: `assetUUID`
4. Click **Save**.
5. Open the datasource you just created and **copy its id** from the
   URL or the detail page — this is the `ds` query param the webhook
   expects.

### 3.2 Create the asset

1. From the side menu, open **Assets → Assets**.
2. Click **New Asset**.
3. Open [`asset.json`](./asset.json). Fill the form:
   - **Name**: `Weather Station HTTP`
   - **Asset UUID**: `weather-http-001`
   - **Asset Template**: pick "Temperature Sensor" from the dropdown
     (the template you created in step 01).
   - **Route Groups**: pick "Save Temperature Events" from the
     dropdown (the route group from step 02).
   - **Protocol → Type**: `http`
4. Click **Save**.

### 3.3 Send some data

Open a terminal in this folder and run:

```bash
node send-events.js --ds=<datasourceId>
```

Replace `<datasourceId>` with the id you copied in step 3.1. The
script pushes 60 readings, one per second, and prints `200` for each.

Other options:

```bash
# Send 200 readings instead of 60
node send-events.js --ds=<id> --count=200

# Use a different gateway URL (e.g. you're hitting a remote stack)
node send-events.js --ds=<id> --gateway=http://mapex.example.com:5001

# Override the asset UUID (must match an existing asset)
node send-events.js --ds=<id> --asset=weather-http-002

# Override the API key (must match the datasource's auth.apiKey.key)
node send-events.js --ds=<id> --apiKey=my-custom-secret
```

### 3.4 See the data land

- Open Grafana: <http://localhost:3001> (`admin` / `admin`).
- The pre-loaded dashboards include an events view. Filter by the
  asset's UUID (`weather-http-001`) to watch the values arrive.
- Or query directly: open the Assets page, pick the
  "Weather Station HTTP" asset, and inspect its event timeline.

## Troubleshooting

**`401 Unauthorized`** — the `X-API-Key` header value doesn't match
the datasource's `auth.apiKey.key`. Either fix the datasource or pass
`--apiKey=<the right value>` to the script.

**`404 Not Found`** — the `ds=` query parameter doesn't match an
existing datasource id. Re-copy the id from the UI.

**`400 Bad Request` with "asset not found"** — the `assetUUID` in
the payload isn't bound to any asset under this datasource. Confirm
the asset was created with `assetUUID: "weather-http-001"` (or
whatever value you used).

**Script crashes with `fetch is not defined`** — your Node is older
than 18. Upgrade Node or use `curl` to send one event manually:
```bash
curl -X POST "http://localhost:5001/api/v1/events?ds=<id>" \
  -H "X-API-Key: quickstart-http-key-change-me" \
  -H "Content-Type: application/json" \
  -d '{"assetUUID":"weather-http-001","temperature":22.5,"humidity":68,"batteryLevel":92}'
```
