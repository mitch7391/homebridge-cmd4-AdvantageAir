import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import process from 'node:process';
import { setTimeout as wait } from 'node:timers/promises';
import { fileURLToPath, pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);

test('grouped MyZone switches operate through the unchanged lab simulator over HTTP', async t => {
  const argv = process.argv;
  const port = process.env.PORT;
  let server;
  t.mock.method(globalThis.console, 'log', () => {});
  try {
    process.env.PORT = '0';
    process.argv = [process.execPath, fileURLToPath(new URL('../../dev/lab/AirConServer.cjs', import.meta.url))];
    server = await require('../../dev/lab/AirConServer.cjs');
  } finally {
    process.argv = argv;
    if (port === undefined) {
      delete process.env.PORT;
    } else {
      process.env.PORT = port;
    }
  }
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  });
  const address = server.address();
  const url = new URL(`http://127.0.0.1:${address.port}/`);
  url.searchParams.set('load', fileURLToPath(new URL('../../dev/lab/fixtures/myzone.json', import.meta.url)));
  const response = await globalThis.fetch(url);
  assert.equal(response.status, 200);
  await response.text();
  const client = new AdvantageAirClient({ ipAddress: '127.0.0.1', port: address.port });
  const baseline = await client.getSystemData();
  const api = new HomebridgeAPI();
  const messages = [];
  const log = Object.fromEntries(['info', 'warn', 'error', 'debug'].map(level => [level, (...args) => messages.push(args.join(' '))]));
  const platform = new AdvantageAirPlatform(log, {
    platform: 'AdvantageAir', devices: [{ ipAddress: '127.0.0.1', port: address.port, debug: true }],
  }, api);
  t.after(() => api.emit('shutdown'));
  const until = async predicate => {
    const end = Date.now() + 12000;
    while (!predicate()) {
      assert.ok(Date.now() < end, 'Simulator operation did not complete within 12 seconds.');
      await wait(25);
    }
  };
  api.emit('didFinishLaunching');
  const accessory = () => [...platform.accessories.values()].find(item => item.context.advantageAirMyZone);
  await until(() => accessory() !== undefined);
  const switches = accessory().services.filter(service => service.UUID === api.hap.Service.Switch.UUID);
  const on = name => switches.find(service => service.displayName === name).getCharacteristic(api.hap.Characteristic.On);
  const living = on('Living Reference MyZone');
  const bedroom = on('Bedroom Reference MyZone');
  assert.equal(await living.handleGetRequest(), true);
  await bedroom.handleSetRequest(true, {});
  assert.equal(await living.handleGetRequest(), false);
  await until(() => messages.some(line => line.includes('Controller confirmed: MyZone Bedroom Reference')));
  const selected = await client.getFreshSystemData();
  assert.equal(selected.aircons.ac1.info.myZone, 7);
  assert.equal(selected.aircons.ac1.info.setTemp, 22);
  assert.equal(selected.aircons.ac1.zones.z02.state, 'open');
  assert.deepEqual(selected.aircons.ac1.zones.z06, baseline.aircons.ac1.zones.z06);
  assert.equal(await bedroom.handleSetRequest(false, {}), true);
  await living.handleSetRequest(true, {});
  await until(() => messages.some(line => line.includes('Controller confirmed: MyZone Living Reference')));
  const restored = await client.getFreshSystemData();
  assert.equal(restored.aircons.ac1.info.myZone, 1);
  assert.equal(restored.aircons.ac1.info.setTemp, 24);
  assert.equal(restored.aircons.ac1.info.state, baseline.aircons.ac1.info.state);
  assert.equal(restored.aircons.ac1.info.mode, baseline.aircons.ac1.info.mode);
  assert.equal(restored.aircons.ac1.info.fan, baseline.aircons.ac1.info.fan);
});
