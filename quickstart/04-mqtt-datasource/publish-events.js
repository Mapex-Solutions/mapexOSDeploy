#!/usr/bin/env node
// Quickstart MQTT publisher — publishes temperature/humidity/battery
// readings to the MapexOS MQTT broker every second.
//
// Requires the mqtt package:
//   npm install mqtt
//
// Usage:
//   node publish-events.js [--asset=<assetUUID>] [--count=<n>]
//
// Optional flags:
//   --asset     assetUUID set when creating the asset. Default: weather-mqtt-001
//   --count     number of events to publish. Default: 60 (~ 1 minute at 1/s).
//   --broker    MQTT broker URL. Default: mqtt://localhost:1883
//   --username  MQTT username. Default: weather-mqtt-001
//                  (must match asset.protocol.mqtt.username)
//   --password  MQTT password. Default: quickstart-mqtt-pass-change-me
//                  (must match asset.protocol.mqtt.password)
//   --topic     Topic to publish to. Default: mapexos/assets/<assetUUID>/data

let mqtt;
try {
  mqtt = require('mqtt');
} catch (e) {
  console.error('Missing "mqtt" package. Run: npm install mqtt');
  process.exit(1);
}

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...v] = a.replace(/^--/, '').split('=');
    return [k, v.join('=') || true];
  })
);

const asset    = args.asset    || 'weather-mqtt-001';
const count    = parseInt(args.count, 10) || 60;
const broker   = args.broker   || 'mqtt://localhost:1883';
const username = args.username || 'weather-mqtt-001';
const password = args.password || 'quickstart-mqtt-pass-change-me';
const topic    = args.topic    || `mapexos/assets/${asset}/data`;

function nextReading() {
  return {
    assetUUID: asset,
    temperature:  Math.round((20 + Math.random() * 10) * 10) / 10,
    humidity:     Math.round(50 + Math.random() * 30),
    batteryLevel: Math.round(70 + Math.random() * 30),
    timestamp:    new Date().toISOString(),
  };
}

function publishOne(client, idx) {
  return new Promise((resolve, reject) => {
    const reading = nextReading();
    client.publish(topic, JSON.stringify(reading), { qos: 1 }, (err) => {
      if (err) return reject(err);
      console.log(
        `[${String(idx + 1).padStart(3, '0')}/${count}] ` +
        `temp=${reading.temperature}°C humidity=${reading.humidity}% battery=${reading.batteryLevel}% → ${topic}`
      );
      resolve();
    });
  });
}

async function main() {
  console.log(`Connecting to ${broker} as "${username}"...`);
  const client = mqtt.connect(broker, {
    clientId: username,
    username,
    password,
    clean: true,
    reconnectPeriod: 0,
    connectTimeout: 5000,
  });

  await new Promise((resolve, reject) => {
    client.once('connect', () => {
      console.log('Connected.');
      console.log(`Publishing ${count} events to ${topic}`);
      console.log('---');
      resolve();
    });
    client.once('error', reject);
  });

  for (let i = 0; i < count; i++) {
    try {
      await publishOne(client, i);
    } catch (err) {
      console.error(`[${String(i + 1).padStart(3, '0')}/${count}] FAILED: ${err.message}`);
    }
    if (i < count - 1) {
      await new Promise((r) => setTimeout(r, 1000));
    }
  }

  console.log('---');
  console.log('Done.');
  client.end(true);
}

main().catch((err) => {
  console.error('Fatal:', err.message);
  process.exit(1);
});
