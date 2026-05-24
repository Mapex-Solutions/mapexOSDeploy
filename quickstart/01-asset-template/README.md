# 01 — Asset template

An **asset template** is the blueprint for a kind of device. It
declares the data fields the device reports, the path to extract the
device's unique id from incoming payloads, and any conversion script
that runs before routing.

In this quickstart the template describes a generic temperature
sensor that reports `temperature`, `humidity`, and `batteryLevel`.

## Files in this folder

- [`temperature-sensor-template.json`](./temperature-sensor-template.json)
  — paste this into the template creation form.

## Steps on the UI

1. From the side menu, open **Admin → Asset Templates**.
2. Click **New Template** (top right).
3. Open [`temperature-sensor-template.json`](./temperature-sensor-template.json)
   in your editor.
4. Copy the values into the form fields — or use the JSON view if the
   page exposes one.
5. Click **Save**.

You should now see "Temperature Sensor" listed under Asset Templates.

## What each field does

| Field             | Why it's there                                                            |
|-------------------|---------------------------------------------------------------------------|
| `name`            | Display name shown in the UI and in lists.                                |
| `enabled`         | Keep `true` — disabled templates can't be picked when creating an asset.  |
| `assetIdPath`     | JSON path used to find the asset's unique id in incoming payloads. The quickstart payloads carry it under `assetUUID`, so the path is just `assetUUID`. |
| `scriptConversion`| A JS expression that transforms the incoming payload before routing. The quickstart returns the payload unchanged. |
| `availableFields` | Names exposed to the rule autocomplete in the UI (so you can build rules that reference these fields). |
| `dynamicFields`   | The fields that get indexed and stored in typed columns. The quickstart declares 3 number fields; the platform stores them in dedicated columns for efficient queries. |

## Next

Continue to [`02-route-group/`](../02-route-group/) — every asset
needs at least one route group to point at, so the platform knows
what to do with events that arrive.
