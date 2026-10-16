import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import fs from 'node:fs';
import http from 'node:http';
import { setTimeout as wait } from 'node:timers/promises';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);

test('native Timer Valve uses real HTTP with an evidence-based test controller, including transient empty readback', async t => {
  // The legacy lab server's countdown setter crashes when reassigning a const.
  // This test-only model exercises transport/HAP without modifying that separate tool.
  const data = JSON.parse(fs.readFileSync(new URL('../../dev/lab/fixtures/myzone.json', import.meta.url), 'utf8'));
  const writes = [];
  let busy = 0;
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://127.0.0.1');
    response.setHeader('Content-Type', 'application/json');
    if (url.pathname === '/getSystemData') {
      response.end(JSON.stringify(busy-- > 0 ? {} : data));
      return;
    }
    if (url.pathname === '/setAircon') {
      const patch = JSON.parse(url.searchParams.get('json'));
      writes.push(patch);
      for (const [ac, value] of Object.entries(patch)) {
        Object.assign(data.aircons[ac].info, value.info);
      }
      busy = 1;
      response.end('{}');
      return;
    }
    response.statusCode = 404;
    response.end('false');
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  });
  const address = server.address();
  const client = new AdvantageAirClient({ ipAddress: '127.0.0.1', port: address.port });
  const baseline = await client.getFreshSystemData();
  assert.equal(baseline.aircons.ac1.info.countDownToOn, 0);
  assert.equal(baseline.aircons.ac1.info.countDownToOff, 0);
  const api = new HomebridgeAPI();
  const events = [];
  const log = Object.fromEntries(['info', 'warn', 'error', 'debug'].map(level => [level, (...args) => events.push(args.join(' '))]));
  const platform = new AdvantageAirPlatform(log, {
    platform: 'AdvantageAir', devices: [{ ipAddress: '127.0.0.1', port: address.port, debug: true }],
  }, api);
  t.after(() => api.emit('shutdown'));
  const until = async predicate => {
    const deadline = Date.now() + 12000;
    while (!predicate()) {
      assert.ok(Date.now() < deadline, 'Timer simulator operation exceeded 12 seconds');
      await wait(25);
    }
  };
  api.emit('didFinishLaunching');
  const accessory = () => [...platform.accessories.values()].find(a => a.context.advantageAirTimer);
  await until(() => accessory());
  const valve = accessory().getService(api.hap.Service.Valve);
  const active = valve.getCharacteristic(api.hap.Characteristic.Active);
  const duration = valve.getCharacteristic(api.hap.Characteristic.SetDuration);
  const remaining = valve.getCharacteristic(api.hap.Characteristic.RemainingDuration);
  await active.handleSetRequest(1, {});
  await until(() => events.some(line => line.includes('Controller confirmed: timer 30 minutes')));
  assert.equal(await remaining.handleGetRequest(), 1800);
  await duration.handleSetRequest(2700, {});
  await until(() => events.some(line => line.includes('Controller confirmed: timer 45 minutes')));
  const running = await client.getFreshSystemData();
  const field = baseline.aircons.ac1.info.state === 'on' ? 'countDownToOff' : 'countDownToOn';
  assert.equal(running.aircons.ac1.info[field], 45);
  await active.handleSetRequest(0, {});
  await until(() => events.some(line => line.includes('Controller confirmed: timer cancelled')));
  const cancelled = await client.getFreshSystemData();
  assert.equal(cancelled.aircons.ac1.info.countDownToOn, 0);
  assert.equal(cancelled.aircons.ac1.info.countDownToOff, 0);
  for (const key of ['state', 'mode', 'fan', 'setTemp', 'myZone']) {
    assert.equal(cancelled.aircons.ac1.info[key], baseline.aircons.ac1.info[key]);
  }
  assert.deepEqual(cancelled.aircons.ac1.zones, baseline.aircons.ac1.zones);
  assert.equal(await duration.handleGetRequest(), 2700);
  assert.equal(await remaining.handleGetRequest(), 0);
  assert.equal(events.some(line => line.includes('command failed')), false);
  assert.deepEqual(writes, [
    { ac1: { info: { [field]: 30 } } },
    { ac1: { info: { [field]: 45 } } },
    { ac1: { info: { [field]: 0 } } },
  ]);
});
