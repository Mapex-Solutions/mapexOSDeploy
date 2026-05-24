# MapexOS Quickstart

This guide walks you through wiring a temperature sensor end to end on a
fresh MapexOS stack — using the UI for setup and a tiny Node.js script
to push data once everything is in place.

Pick **one** ingestion path (HTTP or MQTT), or do both. The first two
steps are shared.

```
quickstart/
├── 01-asset-template/    # define what a temperature sensor looks like
├── 02-route-group/       # define what to do with the events (save them)
├── 03-http-datasource/   # HTTP path: webhook URL + send-events.js
└── 04-mqtt-datasource/   # MQTT path: broker creds + publish-events.js
```

## Prerequisites

The stack is up and you can log in to the frontend:

- Frontend: <http://localhost>
- Login: `admin@mapex.local` / `mapex@123`

If you don't have the stack running, see the [top-level README](../README.md).

## Use case

A weather station that reports three values:

| Field          | Type   | Example  |
|----------------|--------|----------|
| `temperature`  | number | `22.5`   |
| `humidity`     | number | `68`     |
| `batteryLevel` | number | `92`     |

Every folder ships ready-to-paste JSON payloads for the UI forms.
After setup, the `send-events.js` (HTTP) or `publish-events.js` (MQTT)
script in the matching folder pushes a stream of fake readings so you
can watch them land in Grafana.

## The flow

1. **Asset template** (`01-asset-template/`) — describes the device:
   what fields it carries, how to extract its identifier from incoming
   payloads, and any conversion script.
2. **Route group** (`02-route-group/`) — describes what to do with
   incoming events. The quickstart group does the simplest thing:
   stores events to ClickHouse so you can query them from Grafana.
3. **Datasource + Asset** (`03-` or `04-`) — registers the ingestion
   path (HTTP webhook URL or MQTT broker access) and binds it to a
   concrete asset built from the template.
4. **Send data** — run the bundled Node.js script. It pushes a few
   readings every second.
5. **Watch** — open Grafana (<http://localhost:3001>, `admin` /
   `admin`) and visualize what just landed.

## Order

Do the folders in numeric order. The HTTP and MQTT folders are
independent of each other — you can do one, the other, or both.

```
01-asset-template
   │
   ▼
02-route-group
   │
   ├─► 03-http-datasource   (pick one or both)
   │
   └─► 04-mqtt-datasource
```

## Cleanup

Everything created in this quickstart is regular platform data. Delete
the entries from the UI (Assets, Datasources, Route Groups, Templates)
when you're done. There is no separate teardown script.

## Need a deeper tour?

The quickstart is intentionally narrow — one device, one route, one
script. For the full picture (workflows, triggers, multi-tenancy,
rules, plugins), see the platform documentation linked from the
top-level [README](../README.md).
