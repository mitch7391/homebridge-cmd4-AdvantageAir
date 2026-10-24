import '../helpers/coordinatorClock.mjs';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { zoneLayout } from '../../dist/accessories/zoneLayout.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);
const types = ['switch-light', 'lights', 'fans'];
const snapshot = (mid = 'controller') => ({
  system: { mid },
  aircons: { ac1: {
    info: { uid: 'unit', name: 'Aircon', state: 'off', mode: 'cool', fan: 'auto', myZone: 1, setTemp: 23 },
    zones: {
      z01: { name: 'Living', number: 1, type: 1, state: 'open', value: 80, measuredTemp: 22, error: 0 },
      z02: { name: 'Hall', number: 2, type: 0, state: 'open', value: 40 },
    },
  } },
});
async function flush() {
  for (let i = 0; i < 100; i++) {
    await Promise.resolve();
  }
}
function environment(t) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const states = new Map([['192.0.2.1', snapshot()], ['192.0.2.2', snapshot('other')]]);
  const model = { unavailable: false, reject: false };
  const writes = [];
  t.mock.method(globalThis, 'fetch', async url => {
    if (model.unavailable) {
      throw new Error('Simulated controller outage');
    }
    const data = states.get(url.hostname);
    if (url.pathname === '/setAircon') {
      const payload = JSON.parse(url.searchParams.get('json'));
      writes.push({ host: url.hostname, payload });
      if (model.reject) {
        return { ok: true, text: async () => 'false' };
      }
      for (const [ac, patch] of Object.entries(payload)) {
        Object.assign(data.aircons[ac].info, patch.info ?? {});
        for (const [zone, values] of Object.entries(patch.zones ?? {})) {
          Object.assign(data.aircons[ac].zones[zone], values);
        }
      }
      return { ok: true, text: async () => '{}' };
    }
    return { ok: true, text: async () => JSON.stringify(data) };
  });
  const advance = async ms => {
    for (let i = 0; i < ms; i += 100) {
      t.mock.timers.tick(Math.min(100, ms - i));
      await flush();
    }
  };
  const start = async (settings = {}, cache = [], extra = []) => {
    const api = new HomebridgeAPI();
    const removed = [];
    const messages = [];
    // Keep Homebridge's plugin/platform ownership metadata for real cache serialization.
    t.mock.method(api, 'updatePlatformAccessories', () => {});
    t.mock.method(api, 'unregisterPlatformAccessories', (plugin, platform, items) => removed.push(...items));
    const log = Object.fromEntries(['info', 'warn', 'error', 'debug'].map(level => [level, (...args) => messages.push(args.join(' '))]));
    const platform = new AdvantageAirPlatform(log, {
      platform: 'AdvantageAir', devices: [{ ipAddress: '192.0.2.1', ...settings }, ...extra],
    }, api);
    for (const saved of cache) {
      platform.configureAccessory(api.platformAccessory.deserialize(saved));
    }
    t.after(() => api.emit('shutdown'));
    api.emit('didFinishLaunching');
    await flush();
    const id = (zone, role, mid = 'controller') => api.hap.uuid.generate(JSON.stringify([
      JSON.stringify(['AdvantageAir', mid, 'unit', 'zone', zone]), role,
    ]));
    const get = (zone, role, mid) => platform.accessories.get(id(zone, role, mid));
    const saved = () => [...platform.accessories.values()].map(a => api.platformAccessory.serialize(a));
    return { api, platform, removed, messages, id, get, saved };
  };
  return { start, advance, states, model, writes };
}

test('layout defaults and invalid settings are explicit', () => {
  assert.deepEqual(zoneLayout({}), { type: 'switch-light', linkTemperatures: false });
  for (const value of ['', 'Fan', 1, false, null]) {
    assert.throws(() => zoneLayout({ zoneControlType: value }));
  }
  for (const value of ['true', 1, null]) {
    assert.throws(() => zoneLayout({ linkZoneTemperatures: value }));
  }
});

for (const type of types) {
  for (const linked of [false, true]) {
    test(`${type}, temperatures ${linked ? 'linked' : 'separate'}: services, commands and MyZone refusal`, async t => {
      const e = environment(t);
      const c = await e.start({ zoneControlType: type, linkZoneTemperatures: linked });
      const { Service: S, Characteristic: C } = c.api.hap;
      const sensor = c.get('z01', 'zone-switch');
      const percentage = c.get('z02', 'zone-percentage');
      const sensorService = sensor.getService(type === 'fans' ? S.Fan : type === 'lights' ? S.Lightbulb : S.Switch);
      const percentService = percentage.getService(type === 'fans' ? S.Fan : S.Lightbulb);
      assert.ok(sensorService);
      assert.ok(percentService);
      assert.equal(sensorService.testCharacteristic(C.Brightness), false);
      assert.equal(sensorService.testCharacteristic(C.RotationSpeed), false);
      assert.equal(sensorService.testCharacteristic(C.RotationDirection), false);
      const tempHost = linked ? sensor : c.get('z01', 'temperature');
      const temp = tempHost.getService(S.TemperatureSensor);
      assert.equal(await temp.getCharacteristic(C.CurrentTemperature).handleGetRequest(), 22);
      assert.equal(!!c.get('z01', 'temperature'), !linked);
      assert.equal(!!sensor.getService(S.TemperatureSensor), linked);
      assert.equal(!!percentage.getService(S.TemperatureSensor), false);
      if (linked) {
        assert.ok(sensorService.linkedServices.includes(temp));
        assert.equal(sensorService.isPrimaryService, true);
      }
      // The selected MyZone cannot close, regardless of its presentation.
      await assert.rejects(sensorService.getCharacteristic(C.On).handleSetRequest(false));
      assert.equal(e.writes.length, 0);
      const control = percentService.getCharacteristic(type === 'fans' ? C.RotationSpeed : C.Brightness);
      for (const [requested, expected] of [[48, 50], [1, 5], [100, 100]]) {
        await control.handleSetRequest(requested);
        await e.advance(1500);
        assert.equal(e.states.get('192.0.2.1').aircons.ac1.zones.z02.value, expected);
        assert.deepEqual(e.writes.at(-1).payload, { ac1: { zones: { z02: { value: expected } } } });
      }
      await control.handleSetRequest(0);
      await e.advance(1500);
      assert.deepEqual(e.writes.at(-1).payload, { ac1: { zones: { z02: { state: 'close' } } } });
      assert.equal(await control.handleGetRequest(), 100);
      await percentService.getCharacteristic(C.On).handleSetRequest(true);
      await e.advance(1500);
      assert.deepEqual(e.writes.at(-1).payload, { ac1: { zones: { z02: { state: 'open' } } } });
      assert.equal(c.messages.some(m => m.includes('accessory update failed')), false);
    });
  }
}

test('default upgrade preserves Beta 2 UUIDs and service topology', async t => {
  const e = environment(t);
  const old = await e.start();
  const cache = old.saved();
  // Remove the new optional metadata to represent an existing Beta 2 cache.
  for (const a of cache) {
    delete a.context.advantageAirZoneControlType;
  }
  old.api.emit('shutdown');
  const c = await e.start({ zoneControlType: 'switch-light', linkZoneTemperatures: false }, cache);
  const topology = data => data.map(a => [a.UUID, a.services.map(s => [s.UUID, s.subtype, s.characteristics.map(c => c.UUID)])]);
  assert.deepEqual(topology(c.saved()), topology(cache));
  assert.equal(c.removed.length, 0);
});

test('restart transitions every layout and temperature grouping without stale services or duplicate accessories', async t => {
  const e = environment(t);
  let c = await e.start();
  const sensorId = c.get('z01', 'zone-switch').UUID;
  const percentageId = c.get('z02', 'zone-percentage').UUID;
  const temperatureId = c.get('z01', 'temperature').UUID;
  const unrelated = c.saved().filter(a => ![sensorId, percentageId, temperatureId].includes(a.UUID));
  const transitions = [
    ['fans', true], ['lights', true], ['switch-light', false], ['fans', false],
    ['lights', false], ['switch-light', true], ['switch-light', false],
  ];
  for (const [type, linked] of transitions) {
    const cache = c.saved();
    c.api.emit('shutdown');
    c = await e.start({ zoneControlType: type, linkZoneTemperatures: linked }, cache);
    const { Service: S } = c.api.hap;
    const sensor = c.get('z01', 'zone-switch');
    assert.equal(sensor.UUID, sensorId);
    assert.equal(c.get('z02', 'zone-percentage').UUID, percentageId);
    const controls = [S.Switch, S.Lightbulb, S.Fan];
    assert.equal(controls.filter(s => sensor.getService(s)).length, 1);
    assert.equal(controls.filter(s => c.get('z02', 'zone-percentage').getService(s)).length, 1);
    assert.equal([...c.platform.accessories.values()].filter(a => a.getService(S.TemperatureSensor)).length, 1);
    assert.equal(!!c.get('z01', 'temperature'), !linked);
    assert.deepEqual(c.saved().filter(a => ![sensorId, percentageId, temperatureId].includes(a.UUID)), unrelated);
    if (linked) {
      const service = sensor.getService(type === 'fans' ? S.Fan : type === 'lights' ? S.Lightbulb : S.Switch);
      assert.ok(service.linkedServices.includes(sensor.getService(S.TemperatureSensor)));
    }
  }
});

test('outage during restart preserves cached layout until valid discovery and does not rearrange on invalid identity', async t => {
  const e = environment(t);
  const old = await e.start({ zoneControlType: 'fans', linkZoneTemperatures: true });
  const cache = old.saved();
  old.api.emit('shutdown');
  e.model.unavailable = true;
  const c = await e.start({}, cache);
  const { Service: S, Characteristic: C } = c.api.hap;
  const zone = c.get('z01', 'zone-switch');
  assert.ok(zone.getService(S.Fan));
  assert.ok(zone.getService(S.TemperatureSensor));
  assert.equal(c.removed.length, 0);
  await assert.rejects(zone.getService(S.Fan).getCharacteristic(C.On).handleGetRequest());
  e.model.unavailable = false;
  delete e.states.get('192.0.2.1').system.mid;
  await e.advance(31000);
  assert.ok(zone.getService(S.Fan));
  e.states.get('192.0.2.1').system.mid = 'controller';
  await e.advance(31000);
  assert.ok(zone.getService(S.Switch));
  assert.equal(zone.getService(S.Fan), undefined);
  assert.equal(zone.getService(S.TemperatureSensor), undefined);
  assert.ok(c.get('z01', 'temperature'));
});

for (const linked of [false, true]) {
  test(`sensor dropout preserves fans and ${linked ? 'linked' : 'separate'} sensors across restart`, async t => {
    const e = environment(t);
    const old = await e.start({ zoneControlType: 'fans', linkZoneTemperatures: linked });
    const cache = old.saved();
    old.api.emit('shutdown');
    const data = e.states.get('192.0.2.1');
    data.aircons.ac1.zones.z01.type = 0;
    const c = await e.start({ zoneControlType: 'fans', linkZoneTemperatures: linked }, cache);
    const { Service: S, Characteristic: C } = c.api.hap;
    assert.equal(c.get('z01', 'zone-percentage'), undefined);
    const sensor = (linked ? c.get('z01', 'zone-switch') : c.get('z01', 'temperature')).getService(S.TemperatureSensor);
    await assert.rejects(sensor.getCharacteristic(C.CurrentTemperature).handleGetRequest());
    assert.equal(c.platform.accessories.size, cache.length);
    data.aircons.ac1.zones.z01.type = 1;
    await e.advance(31000);
    assert.equal(await sensor.getCharacteristic(C.CurrentTemperature).handleGetRequest(), 22);
    data.aircons.ac1.zones.z01.error = 3;
    await e.advance(31000);
    await assert.rejects(sensor.getCharacteristic(C.CurrentTemperature).handleGetRequest());
    assert.equal(c.platform.accessories.size, cache.length);
  });
}

test('controllers independently select layout/grouping and invalid settings do not start a controller', async t => {
  const e = environment(t);
  const c = await e.start({ zoneControlType: 'fans', linkZoneTemperatures: true }, [], [
    { ipAddress: '192.0.2.2', zoneControlType: 'lights', linkZoneTemperatures: false },
    { ipAddress: '192.0.2.3', zoneControlType: 'invalid' },
  ]);
  const { Service: S } = c.api.hap;
  assert.ok(c.get('z01', 'zone-switch').getService(S.Fan));
  assert.ok(c.get('z01', 'zone-switch').getService(S.TemperatureSensor));
  assert.ok(c.get('z01', 'zone-switch', 'other').getService(S.Lightbulb));
  assert.ok(c.get('z01', 'temperature', 'other'));
  assert.equal(c.get('z01', 'zone-switch', 'other').getService(S.TemperatureSensor), undefined);
  assert.ok(c.messages.some(m => m.includes('Controller entry 3 skipped')));
});

test('Fan percentage rejection faults speed without resending; stale data refuses writes', async t => {
  const e = environment(t);
  const c = await e.start({ zoneControlType: 'fans' });
  const speed = c.get('z02', 'zone-percentage').getService(c.api.hap.Service.Fan).getCharacteristic(c.api.hap.Characteristic.RotationSpeed);
  e.model.reject = true;
  await speed.handleSetRequest(65);
  await e.advance(2000);
  await assert.rejects(speed.handleGetRequest());
  assert.equal(e.writes.length, 1);
  e.model.unavailable = true;
  await e.advance(100000);
  await assert.rejects(speed.handleSetRequest(70));
  assert.equal(e.writes.length, 1);
});
