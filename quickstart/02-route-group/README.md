# 02 — Route group

A **route group** is the list of actions the platform takes when an
event arrives for an asset. Each entry inside the group is a router of
a specific `kind`: `save_event`, `trigger`, `workflow`, `lake_house`,
or `notification`.

Every asset must point at one or more route groups (1 to 3). The
quickstart uses a single route group with one router that simply
stores incoming events in ClickHouse, so you can query and chart them
from Grafana.

## Files in this folder

- [`save-temperature-events.json`](./save-temperature-events.json) —
  paste this into the route group creation form.

## Steps on the UI

1. From the side menu, open **Routes → Route Groups**.
2. Click **New Route Group**.
3. Open
   [`save-temperature-events.json`](./save-temperature-events.json)
   in your editor.
4. Fill the form:
   - **Name**: `Save Temperature Events`
   - **Version**: `1.0.0`
   - **Enabled**: on
5. Under **Routers**, click **Add Router** and pick **Save Event** as
   the kind. Leave the metadata as `{"source": "quickstart"}`.
6. Click **Save**.

You should see "Save Temperature Events" listed under Route Groups.

**Copy the ID**: open the route group you just created and copy its
id from the URL (or from the detail page). You'll paste it into the
`routeGroupIds` field of the asset in the next step.

## What each field does

| Field         | Why it's there                                                            |
|---------------|---------------------------------------------------------------------------|
| `version`     | Semver string. Route groups carry their own version so they can evolve independently of the assets that reference them. |
| `enabled`     | Disabled groups are still selectable but the router doesn't fire.         |
| `routers`     | The actions to run for each event. Use `save_event` for the quickstart. Other kinds (`trigger`, `workflow`, ...) plug downstream pipelines. |

## Next

Pick an ingestion path:

- HTTP webhook → [`03-http-datasource/`](../03-http-datasource/)
- MQTT broker → [`04-mqtt-datasource/`](../04-mqtt-datasource/)

Both folders are self-contained and reference the template + route
group you just created.
