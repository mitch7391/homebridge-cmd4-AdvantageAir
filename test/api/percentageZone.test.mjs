import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import http from 'node:http';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { normalizeZonePercentage, planZonePercentage, zonePercentage } from '../../dist/api/zonePercentage.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);
const identity = zone => JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', zone]);

function snapshot() {
  return {
    system: { mid: 'controller', hasAircons: true, noOfAircons: 1 },
    aircons: { ac1: {
      info: { uid: 'unit', name: 'Aircon', state: 'off', mode: 'cool', fan: 'auto', myZone: 0, constant1: 1, setTemp: 24 },
      zones: {
        z01: { name: 'Hall', number: 1, type: 0, state: 'open', value: 40,
          rssi: -50, measuredTemp: 23, error: 3, tempSensorClash: true },
        z02: { name: 'Office', number: 2, type: 1, state: 'open', value: 80, rssi: 0, measuredTemp: 22, error: 0 },
        z03: { name: 'Spare', number: 3, type: 0, state: 'close', value: 70 },
      },
    } },
  };
}

async function flush() {
  for (let i = 0; i < 70; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = snapshot();
  const model = { delay: 1000, busy: true, reject: false, ambiguous: false, never: false,
    failRead: false, readDelay: 0, beforeRead: undefined };
  const writes = [];
  const requests = [];
  let transition;
  let active = 0;
  let maximum = 0;
  t.mock.method(globalThis, 'fetch', async (url, { signal }) => {
    active++;
    maximum = Math.max(maximum, active);
    requests.push(url.pathname);
    try {
      if (url.pathname === '/setAircon') {
        const payload = JSON.parse(url.searchParams.get('json'));
        writes.push(payload);
        if (model.reject) {
          return { ok: true, text: async () => 'false' };
        }
        transition = { payload, due: Date.now() + model.delay };
        if (model.ambiguous) {
          throw new Error('Private transport details');
        }
        return { ok: true, text: async () => '{}' };
      }
      if (model.readDelay) {
        await new Promise((resolve, reject) => {
          let timer;
          const abort = () => {
            globalThis.clearTimeout(timer);
            reject(new Error('Aborted'));
          };
          timer = globalThis.setTimeout(() => {
            signal.removeEventListener('abort', abort);
            resolve();
          }, model.readDelay);
          signal.addEventListener('abort', abort, { once: true });
        });
      }
      if (model.failRead) {
        throw new Error('Private response content');
      }
      model.beforeRead?.();
      if (transition && !model.never && Date.now() >= transition.due) {
        for (const [aircon, patch] of Object.entries(transition.payload)) {
          if (patch.info) {
            Object.assign(data.aircons[aircon].info, patch.info);
          }
          for (const [zone, fields] of Object.entries(patch.zones ?? {})) {
            Object.assign(data.aircons[aircon].zones[zone], fields);
          }
        }
        transition = undefined;
      }
      return { ok: true, text: async () => JSON.stringify(transition && model.busy ? {} : data) };
    } finally {
      active--;
    }
  });
  const api = new HomebridgeAPI();
  const messages = { info: [], warn: [], error: [], debug: [] };
  const log = Object.fromEntries(Object.keys(messages).map(level => [level, (...args) => messages[level].push(args.join(' '))]));
  const registered = [];
  t.mock.method(api, 'registerPlatformAccessories', (plugin, platform, accessories) => registered.push(...accessories));
  const platform = new AdvantageAirPlatform(log, {
    platform: 'AdvantageAir', devices: [{ ipAddress: '192.0.2.1', name: 'Controller', debug: true }],
  }, api);
  t.after(() => api.emit('shutdown'));
  const uuid = (zone, kind = 'zone-percentage') => api.hap.uuid.generate(JSON.stringify([identity(zone), kind]));
  const light = (zone = 'z01', name = 'On') => platform.accessories.get(uuid(zone))
    .getService(api.hap.Service.Lightbulb).getCharacteristic(api.hap.Characteristic[name]);
  const advance = async ms => {
    for (let elapsed = 0; elapsed < ms; elapsed += 100) {
      t.mock.timers.tick(Math.min(100, ms - elapsed));
      await flush();
    }
  };
  if (!options.paused) {
    api.emit('didFinishLaunching');
    await flush();
  }
  return { api, data, model, platform, registered, messages, writes, requests, light, uuid, advance, max: () => maximum };
}

const failure = c => error => error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE;

test('percentage rounding accepts positive whole HomeKit values and returns only documented increments', () => {
  for (let value = 1; value <= 100; value++) {
    const result = normalizeZonePercentage(value);
    assert.ok(result >= 5 && result <= 100 && result % 5 === 0);
  }
  for (const [input, expected] of [[1, 5], [2, 5], [5, 5], [7, 5], [8, 10], [47, 45], [48, 50], [99, 100], [100, 100]]) {
    assert.equal(normalizeZonePercentage(input), expected);
  }
  for (const invalid of [0, -1, 101, 22.5, NaN, Infinity, '50', null]) {
    assert.throws(() => normalizeZonePercentage(invalid));
  }
});

test('percentage planner uses type, ignores sensor-health heuristics, and leaves data unchanged', () => {
  const aircon = snapshot().aircons.ac1;
  const before = globalThis.structuredClone(aircon);
  assert.deepEqual(planZonePercentage(aircon, 'z01', 42), { percentage: 40, unchanged: true });
  assert.deepEqual(planZonePercentage(aircon, 'z01', 48), { percentage: 50, unchanged: false });
  assert.throws(() => planZonePercentage(aircon, 'z02', 50));
  assert.throws(() => planZonePercentage(aircon, 'z99', 50));
  assert.deepEqual(aircon, before);
  for (const value of [0, 4, 42, 105, undefined, null, '40']) {
    assert.throws(() => zonePercentage({ type: 0, value }));
  }
});

test('percentage transport sends an encoded value-only HTTP command', async t => {
  const seen = [];
  const server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    seen.push({ method: request.method, path: url.pathname, json: JSON.parse(url.searchParams.get('json')) });
    response.end('{}');
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => {
    server.close(resolve); server.closeAllConnections();
  }));
  const client = new AdvantageAirClient({ ipAddress: '127.0.0.1', port: server.address().port });
  assert.deepEqual(await client.requestZonePercentage('ac2', 'z03', 55), {});
  assert.deepEqual(seen, [{ method: 'GET', path: '/setAircon', json: { ac2: { zones: { z03: { value: 55 } } } } }]);
});

test('percentage transport refuses invalid addresses, increments and cancellation before sending', async t => {
  const fetch = t.mock.method(globalThis, 'fetch', () => {
    throw new Error('Unexpected request');
  });
  const client = new AdvantageAirClient({ ipAddress: '192.0.2.1' });
  for (const value of [0, 1, 42, 101, 20.5, '50', NaN]) {
    await assert.rejects(client.requestZonePercentage('ac1', 'z01', value));
  }
  await assert.rejects(client.requestZonePercentage('other', 'z01', 50));
  await assert.rejects(client.requestZonePercentage('ac1', 'other', 50));
  const abort = new globalThis.AbortController();
  abort.abort();
  await assert.rejects(client.requestZonePercentage('ac1', 'z01', 50, abort.signal));
  assert.equal(fetch.mock.callCount(), 0);
});

test('mixed zone types create Lightbulbs or Switch plus sensor independently of RSSI and health', async t => {
  const c = await setup(t);
  assert.equal(c.platform.accessories.size, 7);
  assert.equal(await c.light().handleGetRequest(), true);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
  assert.equal(await c.light('z03').handleGetRequest(), false);
  assert.equal(await c.light('z03', 'Brightness').handleGetRequest(), 70);
  assert.equal(c.platform.accessories.get(c.uuid('z01')).displayName, 'Hall Zone');
  assert.equal(c.platform.accessories.has(c.uuid('z01', 'zone-switch')), false);
  assert.equal(c.platform.accessories.has(c.uuid('z01', 'temperature')), false);
  assert.equal(c.platform.accessories.has(c.uuid('z02')), false);
  assert.ok(c.platform.accessories.get(c.uuid('z02', 'zone-switch')).getService(c.api.hap.Service.Switch));
  assert.ok(c.platform.accessories.get(c.uuid('z02', 'temperature')).getService(c.api.hap.Service.TemperatureSensor));
});

test('Lightbulb On writes only close/open and preserves the stored percentage', async t => {
  const c = await setup(t);
  await c.light().handleSetRequest(false, {});
  assert.equal(await c.light().handleGetRequest(), false);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
  await c.advance(1100);
  await c.light().handleSetRequest(true, {});
  await c.advance(1100);
  assert.deepEqual(c.writes, [
    { ac1: { zones: { z01: { state: 'close' } } } }, { ac1: { zones: { z01: { state: 'open' } } } },
  ]);
  assert.equal(c.data.aircons.ac1.zones.z01.value, 40);
});

test('Brightness normalizes 1/48/100 and changes only value while the zone is closed', async t => {
  const c = await setup(t);
  const before = globalThis.structuredClone(c.data);
  for (const [input, expected] of [[1, 5], [48, 50], [100, 100]]) {
    const result = await c.light('z03', 'Brightness').handleSetRequest(input, {});
    assert.equal(result, expected);
    assert.equal(await c.light('z03', 'Brightness').handleGetRequest(), expected);
    assert.equal(await c.light('z03').handleGetRequest(), false);
    await c.advance(1100);
    assert.deepEqual(c.writes.at(-1), { ac1: { zones: { z03: { value: expected } } } });
  }
  before.aircons.ac1.zones.z03.value = 100;
  assert.deepEqual(c.data, before);
});

test('Brightness zero closes without a value write and returns the retained percentage', async t => {
  const c = await setup(t);
  assert.equal(await c.light('z01', 'Brightness').handleSetRequest(0, {}), 40);
  assert.equal(await c.light().handleGetRequest(), false);
  await c.advance(1100);
  assert.deepEqual(c.writes, [{ ac1: { zones: { z01: { state: 'close' } } } }]);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
  await c.light('z01', 'Brightness').handleSetRequest(0, {});
  await flush();
  assert.equal(c.writes.length, 1);
  await c.light().handleSetRequest(true, {});
  await c.advance(1100);
  assert.equal(c.data.aircons.ac1.zones.z01.value, 40);
});

test('zero brightness retains active-myZone refusal and sends nothing', async t => {
  const c = await setup(t);
  c.data.aircons.ac1.info.myZone = 1;
  await c.advance(30100);
  await assert.rejects(c.light('z01', 'Brightness').handleSetRequest(0, {}), failure(c));
  assert.equal(c.writes.length, 0);
  assert.match(c.messages.warn[0], /Select another myZone/);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
});

test('fresh no-op detection prevents redundant percentage writes', async t => {
  const c = await setup(t);
  await c.light('z01', 'Brightness').handleSetRequest(42, {});
  await flush();
  assert.equal(c.writes.length, 0);
  assert.equal(c.requests.length, 2);
  assert.ok(c.messages.info.filter(line => line.startsWith('[Debug]')).some(line => line.includes('Already in requested state: zone percentage 40%')));
  await c.light('z01', 'Brightness').handleSetRequest(55, {});
  c.data.aircons.ac1.zones.z01.value = 55;
  await flush();
  assert.equal(c.writes.length, 0);
});

test('rapid percentage changes retain only the latest unsent value', async t => {
  const c = await setup(t);
  await c.light('z01', 'Brightness').handleSetRequest(50, {});
  // First command may already be in flight; retain its latest successor only.
  await flush();
  await c.light('z01', 'Brightness').handleSetRequest(60, {});
  await c.light('z01', 'Brightness').handleSetRequest(80, {});
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 80);
  await c.advance(1100);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 80);
  await c.advance(1100);
  assert.deepEqual(c.writes, [{ ac1: { zones: { z01: { value: 50 } } } }, { ac1: { zones: { z01: { value: 80 } } } }]);
  assert.equal(c.max(), 1);
});

test('state and percentage have independent queue slots and do not affect another zone', async t => {
  const c = await setup(t);
  const initialInfo = globalThis.structuredClone(c.data.aircons.ac1.info);
  await c.light('z01', 'Brightness').handleSetRequest(50, {});
  await flush();
  await c.light().handleSetRequest(false, {});
  await c.light('z03', 'Brightness').handleSetRequest(90, {});
  await c.light('z01', 'Brightness').handleSetRequest(60, {});
  assert.equal(await c.light().handleGetRequest(), false);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 60);
  await c.advance(4500);
  assert.equal(c.data.aircons.ac1.zones.z01.state, 'close');
  assert.equal(c.data.aircons.ac1.zones.z01.value, 60);
  assert.equal(c.data.aircons.ac1.zones.z03.state, 'close');
  assert.equal(c.data.aircons.ac1.zones.z03.value, 90);
  assert.equal(c.data.aircons.ac1.zones.z02.state, 'open');
  assert.deepEqual(c.data.aircons.ac1.info, initialInfo);
  assert.equal(c.writes.length, 4);
});

test('controller rejection faults percentage only and does not resend', async t => {
  const c = await setup(t);
  c.model.reject = true;
  await c.light('z01', 'Brightness').handleSetRequest(60, {});
  await flush();
  assert.equal(c.writes.length, 1);
  await assert.rejects(c.light('z01', 'Brightness').handleGetRequest(), failure(c));
  assert.equal(await c.light().handleGetRequest(), true);
  assert.equal(await c.light('z03', 'Brightness').handleGetRequest(), 70);
  assert.match(c.messages.warn[0], /percentage 60%.*rejected/);
  await c.advance(30100);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
});

test('ambiguous percentage delivery reconciles by readback without retrying the write', async t => {
  const c = await setup(t);
  c.model.ambiguous = true;
  await c.light('z01', 'Brightness').handleSetRequest(60, {});
  await c.advance(1100);
  assert.equal(c.writes.length, 1);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 60);
  assert.deepEqual(c.messages.warn, []);
  assert.ok(c.messages.info.filter(line => line.startsWith('[Debug]')).some(line => line.includes('Controller confirmed: zone percentage 60%')));
  assert.equal(JSON.stringify(c.messages).includes('Private transport'), false);
});

test('old percentage readback times out and cancels dependent commands without resending', async t => {
  const c = await setup(t);
  c.model.never = true;
  c.model.busy = false;
  await c.light('z01', 'Brightness').handleSetRequest(60, {});
  await flush();
  await c.light('z03', 'Brightness').handleSetRequest(90, {});
  await c.advance(15100);
  assert.equal(c.writes.length, 1);
  assert.equal(c.messages.warn.length, 2);
  await assert.rejects(c.light('z01', 'Brightness').handleGetRequest(), failure(c));
  assert.equal(await c.light().handleGetRequest(), true);
});

test('stale controller data prevents percentage reads and writes and recovers on a valid poll', async t => {
  const c = await setup(t);
  c.model.failRead = true;
  await c.advance(90100);
  await assert.rejects(c.light().handleGetRequest(), failure(c));
  await assert.rejects(c.light('z01', 'Brightness').handleGetRequest(), failure(c));
  await assert.rejects(c.light('z01', 'Brightness').handleSetRequest(50, {}), failure(c));
  assert.equal(c.writes.length, 0);
  c.model.failRead = false;
  await c.advance(30100);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
});

test('preflight timeout and shutdown cannot send a late percentage write', async t => {
  const c = await setup(t);
  c.model.readDelay = 20000;
  await c.light('z01', 'Brightness').handleSetRequest(50, {});
  await c.advance(20100);
  assert.equal(c.writes.length, 0);
  c.api.emit('shutdown');
  await assert.rejects(c.light('z03', 'Brightness').handleSetRequest(50, {}), failure(c));
  await c.advance(30100);
  assert.equal(c.writes.length, 0);
});

test('fresh preflight follows aircon addressing and retained accessory names do not change UUIDs', async t => {
  const c = await setup(t);
  const accessory = c.platform.accessories.get(c.uuid('z01'));
  const aircon = c.data.aircons.ac1;
  await c.light('z01', 'Brightness').handleSetRequest(50, {});
  c.data.aircons = { ac2: aircon };
  aircon.zones.z01.name = 'Renamed';
  await c.advance(1100);
  assert.deepEqual(c.writes, [{ ac2: { zones: { z01: { value: 50 } } } }]);
  assert.equal(c.platform.accessories.get(c.uuid('z01')), accessory);
  assert.equal(c.registered.length, 7);
});

test('capability change before dispatch blocks both percentage and percentage-layout state writes', async t => {
  const c = await setup(t);
  c.model.beforeRead = () => {
    c.data.aircons.ac1.zones.z01.type = 1;
  };
  await c.light('z01', 'Brightness').handleSetRequest(50, {});
  await flush();
  assert.equal(c.writes.length, 0);
  await assert.rejects(c.light().handleGetRequest(), failure(c));
  assert.equal(c.platform.accessories.has(c.uuid('z01', 'zone-switch')), false);
  c.model.beforeRead = undefined;
  c.data.aircons.ac1.zones.z01.type = 0;
  await c.advance(30100);
  await c.light().handleSetRequest(false, {});
  c.data.aircons.ac1.zones.z01.type = 1;
  await flush();
  assert.equal(c.writes.length, 0);
});

test('missing zone faults its retained Lightbulb and recovers without recreating it', async t => {
  const c = await setup(t);
  const zone = c.data.aircons.ac1.zones.z01;
  const accessory = c.platform.accessories.get(c.uuid('z01'));
  delete c.data.aircons.ac1.zones.z01;
  await c.advance(30100);
  await assert.rejects(c.light().handleGetRequest(), failure(c));
  await assert.rejects(c.light('z01', 'Brightness').handleSetRequest(50, {}), failure(c));
  c.data.aircons.ac1.zones.z01 = zone;
  await c.advance(30100);
  assert.equal(c.platform.accessories.get(c.uuid('z01')), accessory);
  assert.equal(c.registered.length, 7);
  assert.equal(await c.light().handleGetRequest(), true);
});

test('cached Lightbulb waits for discovery and preserves its UUID and service on restart', async t => {
  const c = await setup(t, { paused: true });
  const accessory = new c.api.platformAccessory('My Hall Zone', c.uuid('z01'));
  accessory.context.advantageAirPercentageZone = true;
  accessory.addService(c.api.hap.Service.Lightbulb, accessory.displayName)
    .setCharacteristic(c.api.hap.Characteristic.Brightness, 95);
  c.platform.configureAccessory(accessory);
  await assert.rejects(c.light('z01', 'Brightness').handleGetRequest(), failure(c));
  await assert.rejects(c.light().handleSetRequest(false, {}), failure(c));
  c.api.emit('didFinishLaunching');
  await flush();
  assert.equal(c.platform.accessories.get(c.uuid('z01')), accessory);
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
  assert.equal(accessory.services.filter(s => s.UUID === c.api.hap.Service.Lightbulb.UUID).length, 1);
  assert.equal(c.registered.length, 6);
  assert.equal(c.messages.info.some(line => line.includes('Created accessory: My Hall Zone')), false);
});

test('cached Switch on a type-zero dropout zone is retained with no duplicate Lightbulb', async t => {
  const c = await setup(t, { paused: true });
  const accessory = new c.api.platformAccessory('Hall Zone', c.uuid('z01', 'zone-switch'));
  accessory.context.advantageAirZoneSwitch = true;
  c.platform.configureAccessory(accessory);
  c.api.emit('didFinishLaunching');
  await flush();
  assert.equal(c.platform.accessories.has(c.uuid('z01')), false);
  const on = accessory.getService(c.api.hap.Service.Switch).getCharacteristic(c.api.hap.Characteristic.On);
  assert.equal(await on.handleGetRequest(), true);
  await on.handleSetRequest(false, {});
  await c.advance(1100);
  assert.equal(c.data.aircons.ac1.zones.z01.value, 40);
});

test('cached Lightbulb with changed capability remains unavailable without a replacement Switch', async t => {
  const c = await setup(t, { paused: true });
  const accessory = new c.api.platformAccessory('Hall Zone', c.uuid('z01'));
  accessory.context.advantageAirPercentageZone = true;
  c.platform.configureAccessory(accessory);
  c.data.aircons.ac1.zones.z01.type = 1;
  c.api.emit('didFinishLaunching');
  await flush();
  await assert.rejects(c.light().handleGetRequest(), failure(c));
  assert.equal(c.platform.accessories.has(c.uuid('z01', 'zone-switch')), false);
  c.data.aircons.ac1.zones.z01.type = 0;
  await c.advance(30100);
  assert.equal(await c.light().handleGetRequest(), true);
  assert.equal(c.platform.accessories.get(c.uuid('z01')), accessory);
});

test('invalid percentage reading faults Brightness only while an invalid state faults On only', async t => {
  const c = await setup(t);
  c.data.aircons.ac1.zones.z01.value = 42;
  await c.advance(30100);
  await assert.rejects(c.light('z01', 'Brightness').handleGetRequest(), failure(c));
  assert.equal(await c.light().handleGetRequest(), true);
  await c.light().handleSetRequest(false, {});
  await c.advance(1100);
  assert.deepEqual(c.writes[0], { ac1: { zones: { z01: { state: 'close' } } } });
  c.data.aircons.ac1.zones.z01.value = 40;
  c.data.aircons.ac1.zones.z01.state = 'unknown';
  await c.advance(30100);
  await assert.rejects(c.light().handleGetRequest(), failure(c));
  assert.equal(await c.light('z01', 'Brightness').handleGetRequest(), 40);
});
