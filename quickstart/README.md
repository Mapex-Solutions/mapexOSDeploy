# MapexOS Quickstart

Walk through the MapexOS UI to wire a temperature sensor end to end.
Two flavors, one per ingestion path:

```
quickstart/
├── device-http/    # sensor that posts telemetry to a webhook URL
└── device-mqtt/    # sensor that publishes telemetry to the MQTT broker  (coming next)
```

Each folder is **self-contained**: one README that walks every UI
form (asset template → route group → datasource → asset → test
data) field by field, plus a small Node.js script that pushes fake
readings once the setup is done.

## Prerequisites

The stack is up and you can log in to the frontend:

- Frontend: <http://localhost> (or your `MAPEXOS_PUBLIC_HOST`)
- Login: `admin@mapex.local` / `mapex@123`

If you don't have the stack running, see the
[top-level README](../README.md).

## Pick a path

| Path | Best for | Folder |
|---|---|---|
| **HTTP** | Devices that POST JSON to a webhook (REST endpoints, gateways, lambdas). | [`device-http/`](./device-http/) |
| **MQTT** | Devices that publish to an MQTT broker (most off-the-shelf IoT firmware). | [`device-mqtt/`](./device-mqtt/) |

## What you'll have at the end

- An **asset template** (`Temperature Sensor`) declaring the data
  shape and the preprocessor / validator / conversion scripts.
- A **route group** (`Save Temperature Events`) that persists every
  incoming reading to ClickHouse.
- For HTTP: a **datasource** with a webhook URL + API key.
- An **asset** (`weather-http-001` or `weather-mqtt-001`) bound to
  the template, the route group, and the chosen protocol.
- Live readings flowing into Grafana — open
  <http://localhost:3001> (`admin` / `admin`) and filter the events
  dashboard by `assetUUID`.

## Cleanup

Everything created by the quickstart is regular platform data —
delete from the UI (Assets, Datasources, Route Groups, Templates)
when you're done. No teardown script.

## Where to go next

The quickstart is intentionally narrow — one device, one route, one
test stream. For workflows, plugins, multi-tenancy, rule matching,
triggers and credential vault, see the platform documentation linked
from the top-level [README](../README.md).
