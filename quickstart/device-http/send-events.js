#!/usr/bin/env node
// Quickstart HTTP sender — pushes temperature/humidity/battery readings
// to a MapexOS HTTP datasource every second.
//
// Requires Node.js 18+ (uses the native fetch API). No npm install
// needed.
//
// Usage:
//   node send-events.js --ds=<datasourceId> [--asset=<assetUUID>] [--count=<n>]
//
// Required flag:
//   --ds       MongoDB id of the HTTP datasource created in this folder.
//
// Optional flags:
//   --asset    assetUUID set when creating the asset. Default: weather-http-001
//   --count    number of events to send. Default: 60 (~ 1 minute at 1/s).
//   --gateway  base URL of the http_gateway. Default: http://localhost:5001
//   --apiKey   value of the X-API-Key header. Must match the datasource's
//              auth.apiKey.key. Default: quickstart-http-key-change-me

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, '').split('=');
    return [k, v.join('=') || true];
  })
);

if (!args.ds) {
  console.error('Missing required --ds=<datasourceId>');
  console.error('Usage: node send-events.js --ds=<datasourceId> [--asset=<uuid>] [--count=<n>]');
  process.exit(1);
}

const gateway = args.gateway || 'http://localhost:5001';
const apiKey  = args.apiKey  || 'quickstart-http-key-change-me';
const asset   = args.asset   || 'weather-http-001';
const count   = parseInt(args.count, 10) || 60;
const url     = `${gateway}/api/v1/events?ds=${args.ds}`;

function nextReading() {
  return {
    assetUUID: asset,
    temperature:  Math.round((20 + Math.random() * 10) * 10) / 10,
    humidity:     Math.round(50 + Math.random() * 30),
    batteryLevel: Math.round(70 + Math.random() * 30),
    timestamp:    new Date().toISOString(),
  };
}

async function sendOne(reading, idx) {
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': apiKey,
    },
    body: JSON.stringify(reading),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status}: ${body}`);
  }
  console.log(
    `[${String(idx + 1).padStart(3, '0')}/${count}] ` +
    `temp=${reading.temperature}°C humidity=${reading.humidity}% battery=${reading.batteryLevel}% → ${res.status}`
  );
}

async function main() {
  console.log(`Sending ${count} events to ${url}`);
  console.log(`Asset: ${asset}, API key header: X-API-Key`);
  console.log('---');
  for (let i = 0; i < count; i++) {
    try {
      await sendOne(nextReading(), i);
    } catch (err) {
      console.error(`[${String(i + 1).padStart(3, '0')}/${count}] FAILED: ${err.message}`);
    }
    if (i < count - 1) {
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
  console.log('---');
  console.log('Done.');
}

main();
