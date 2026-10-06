import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { MyZoneManager } from '../../dist/accessories/myZoneManager.js';
import { DuplicateControllerError } from '../../dist/accessories/zoneTemperatureManager.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);
const fixture = JSON.parse(fs.readFileSync(new URL('../../dev/lab/fixtures/myzone.json', import.meta.url), 'utf8'));
const identity = key => JSON.stringify(['AdvantageAir', fixture.system.mid, fixture.aircons.ac1.info.uid, 'zone', key]);

async function flush() {
  for (let i = 0; i < 80; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = globalThis.structuredClone(fixture);
  options.edit?.(data);
  const model = { failure: false, reject: '', ambiguous: false, delay: 100, ...options.model };
  const writes = [];
  let transition;
  t.mock.method(globalThis, 'fetch', async url => {
    if (url.pathname === '/setAircon') {
      const patch = JSON.parse(url.searchParams.get('json'));
      writes.push(patch);
      const fields = Object.values(patch)[0];
      const step = fields.zones ? 'open' : Object.hasOwn(fields.info, 'myZone') ? 'select' : 'target';
      if (model.reject === step) {
        return { ok: true, status: 200, text: async () => 'false' };
      }
      transition = { patch, due: Date.now() + model.delay };
      if (model.ambiguous) {
        throw new Error('Delivery unknown');
      }
      return { ok: true, status: 200, text: async () => '{}' };
    }
    assert.equal(url.pathname, '/getSystemData');
    if (model.failure) {
      throw new Error('Read unavailable');
    }
    if (transition && Date.now() >= transition.due) {
      for (const [ac, fields] of Object.entries(transition.patch)) {
        Object.assign(data.aircons[ac].info, fields.info);
        for (const [zone, values] of Object.entries(fields.zones ?? {})) {
          Object.assign(data.aircons[ac].zones[zone], values);
        }
      }
      transition = undefined;
    }
    return { ok: true, status: 200, text: async () => JSON.stringify(transition ? {} : data) };
  });
  const api = new HomebridgeAPI();
  const registered = [];
  const updates = [];
  const removals = [];
  const register = api.registerPlatformAccessories.bind(api);
  t.mock.method(api, 'registerPlatformAccessories', (plugin, platform, accessories) => {
    register(plugin, platform, accessories);
    registered.push(...accessories);
  });
  t.mock.method(api, 'updatePlatformAccessories', accessories => updates.push(...accessories));
  t.mock.method(api, 'unregisterPlatformAccessories', (...args) => removals.push(args));
  const messages = { info: [], warn: [], error: [], debug: [] };
  const log = Object.fromEntries(Object.keys(messages).map(level => [level, (...args) => messages[level].push(args.join(' '))]));
  const platform = new AdvantageAirPlatform(log,
    { platform: 'AdvantageAir', devices: [{ ipAddress: '192.0.2.1', debug: true }] }, api);
  t.after(() => api.emit('shutdown'));
  const accessory = () => [...platform.accessories.values()].find(item => item.context.advantageAirMyZone === true);
  const on = key => accessory().getServiceById(api.hap.Service.Switch,
    api.hap.uuid.generate(JSON.stringify([identity(key), 'myzone-selection']))).getCharacteristic(api.hap.Characteristic.On);
  const advance = async ms => {
    for (let left = ms; left > 0;) {
      const step = Math.min(left, 100);
      t.mock.timers.tick(step);
      left -= step;
      await flush();
    }
  };
  const start = async () => {
    api.emit('didFinishLaunching');
    await flush();
  };
  if (!options.paused) {
    await start();
  }
  return { api, data, model, writes, messages, platform, registered, updates, removals, accessory, on, advance, start };
}

test('MyZone creates one accessory with distinct named switches alongside the existing layouts', async t => {
  const c = await setup(t);
  const accessory = c.accessory();
  assert.equal(accessory.displayName, 'Aircon MyZone');
  const switches = accessory.services.filter(service => service.UUID === c.api.hap.Service.Switch.UUID);
  assert.equal(switches.length, 2);
  assert.equal(new Set(switches.map(service => service.subtype)).size, 2);
  assert.deepEqual(switches.map(service => service.getCharacteristic(c.api.hap.Characteristic.ConfiguredName).value),
    ['Living Reference MyZone', 'Bedroom Reference MyZone']);
  assert.equal(await c.on('z01').handleGetRequest(), true);
  assert.equal(await c.on('z02').handleGetRequest(), false);
  const all = [...c.platform.accessories.values()];
  assert.equal(all.filter(a => a.context.advantageAirMyZone).length, 1);
  assert.equal(all.filter(a => a.context.advantageAirZoneSwitch).length, 2);
  assert.equal(all.filter(a => a.context.advantageAirTemperature).length, 2);
  assert.equal(all.filter(a => a.context.advantageAirPercentageZone).length, 1);
  assert.equal(all.filter(a => a.context.advantageAirThermostat).length, 1);
  assert.equal(all.filter(a => a.context.advantageAirModeFan).length, 2);
  assert.equal(c.messages.info.filter(line => line.includes('Created accessory: Aircon MyZone')).length, 1);
});

test('MyZone HAP selection immediately updates every switch and dispatches the existing ordered backend', async t => {
  const c = await setup(t);
  const info = { ...c.data.aircons.ac1.info };
  const percentage = { ...c.data.aircons.ac1.zones.z06 };
  assert.equal(await c.on('z02').handleSetRequest(true, {}), true);
  assert.equal(c.on('z01').value, false);
  assert.equal(c.on('z02').value, true);
  assert.equal(await c.on('z02').handleGetRequest(), true);
  await c.advance(3500);
  assert.deepEqual(c.writes, [
    { ac1: { zones: { z02: { state: 'open' } } } },
    { ac1: { info: { myZone: 7 } } },
    { ac1: { info: { setTemp: 22 } } },
  ]);
  assert.deepEqual(c.data.aircons.ac1.info, { ...info, myZone: 7, setTemp: 22 });
  assert.deepEqual(c.data.aircons.ac1.zones.z06, percentage);
  assert.equal(c.data.aircons.ac1.zones.z01.state, 'open');
  assert.deepEqual(c.messages.warn, []);
});

test('selected MyZone Off returns true, explains refusal and sends nothing', async t => {
  const c = await setup(t);
  assert.equal(await c.on('z01').handleSetRequest(false, {}), true);
  await flush();
  assert.equal(c.on('z01').value, true);
  assert.deepEqual(c.writes, []);
  assert.match(c.messages.warn.join('\n'), /Living Reference MyZone cannot be turned off; select another MyZone instead\./);
  assert.equal(c.data.aircons.ac1.info.myZone, 1);
});

test('unselected MyZone Off is a silent no-op; selecting an already-satisfied zone sends nothing', async t => {
  const c = await setup(t);
  assert.equal(await c.on('z02').handleSetRequest(false, {}), false);
  await c.on('z01').handleSetRequest(true, {});
  await flush();
  assert.deepEqual(c.writes, []);
  assert.deepEqual(c.messages.warn, []);
  assert.ok(c.messages.debug.some(line => line.includes('Already in requested state: MyZone')));
});

test('rapid unsent MyZone switch selections resolve to the latest selection without a redundant physical write', async t => {
  const c = await setup(t);
  const b = c.on('z02').handleSetRequest(true, {});
  const a = c.on('z01').handleSetRequest(true, {});
  await Promise.all([b, a]);
  await c.advance(3500);
  assert.deepEqual(c.writes, []);
  assert.equal(await c.on('z01').handleGetRequest(), true);
  assert.equal(await c.on('z02').handleGetRequest(), false);
});

test('selected pending switch Off does not cancel or disable a MyZone selection', async t => {
  const c = await setup(t);
  await c.on('z02').handleSetRequest(true, {});
  assert.equal(await c.on('z02').handleSetRequest(false, {}), true);
  await c.advance(3500);
  assert.equal(c.data.aircons.ac1.info.myZone, 7);
  assert.equal(c.writes.length, 3);
});

test('HomeKit MyZone reflects observed selection after partial target rejection', async t => {
  const c = await setup(t, { model: { reject: 'target' } });
  await c.on('z02').handleSetRequest(true, {});
  await c.advance(3500);
  assert.equal(c.data.aircons.ac1.info.myZone, 7);
  assert.equal(c.data.aircons.ac1.info.setTemp, 24);
  assert.equal(await c.on('z02').handleGetRequest(), true);
  assert.equal(await c.on('z01').handleGetRequest(), false);
  assert.ok(c.messages.warn.some(line => /target/.test(line)));
  assert.equal(c.writes.length, 3);
});

test('HomeKit MyZone reverts optimistic selection after selection rejection, retaining the opened zone', async t => {
  const c = await setup(t, { model: { reject: 'select' } });
  await c.on('z02').handleSetRequest(true, {});
  await c.advance(2500);
  assert.equal(c.data.aircons.ac1.zones.z02.state, 'open');
  assert.equal(await c.on('z01').handleGetRequest(), true);
  assert.equal(await c.on('z02').handleGetRequest(), false);
  assert.equal(c.writes.length, 2);
});

test('HomeKit MyZone ambiguous writes reconcile through the existing backend without resend', async t => {
  const c = await setup(t, { model: { ambiguous: true } });
  await c.on('z02').handleSetRequest(true, {});
  await c.advance(3500);
  assert.equal(await c.on('z02').handleGetRequest(), true);
  assert.equal(c.writes.length, 3);
  assert.deepEqual(c.messages.warn, []);
});

test('MyZone is not exposed on installer-disabled or ambiguous systems', async t => {
  const c = await setup(t, { edit: d => {
    d.aircons.ac1.info.myZone = 0;
  } });
  assert.equal(c.accessory(), undefined);
  c.data.aircons.ac1.info.myZone = 1;
  c.data.aircons.ac1.zones.z02.number = 1;
  await c.advance(30100);
  assert.equal(c.accessory(), undefined);
  assert.deepEqual(c.writes, []);
});

test('new MyZone services exclude invalid targets and use type instead of sensor-health fields', async t => {
  const c = await setup(t, { edit: d => {
    d.aircons.ac1.zones.z02.setTemp = '22';
    d.aircons.ac1.zones.z01.error = 2;
    d.aircons.ac1.zones.z01.measuredTemp = 0;
    d.aircons.ac1.zones.z01.rssi = 0;
  } });
  assert.equal(c.accessory().services.filter(s => s.UUID === c.api.hap.Service.Switch.UUID).length, 1);
  assert.equal(await c.on('z01').handleGetRequest(), true);
});

test('cached MyZone services retain identity, user naming and handlers through serialization and fresh attachment', async t => {
  const c = await setup(t);
  const old = c.accessory();
  const service = old.services.find(s => s.UUID === c.api.hap.Service.Switch.UUID);
  service.setCharacteristic(c.api.hap.Characteristic.ConfiguredName, 'Custom reference');
  const serialized = c.api.platformAccessory.serialize(old);
  const restored = c.api.platformAccessory.deserialize(JSON.parse(JSON.stringify(serialized)));
  const api = new HomebridgeAPI();
  MyZoneManager.prepareCachedAccessory(api, restored);
  const on = restored.getServiceById(api.hap.Service.Switch, service.subtype).getCharacteristic(api.hap.Characteristic.On);
  await assert.rejects(on.handleGetRequest());
  await assert.rejects(on.handleSetRequest(true));
  const registrations = [];
  t.mock.method(api, 'registerPlatformAccessories', (...args) => registrations.push(args));
  t.mock.method(api, 'updatePlatformAccessories', () => {});
  const manager = new MyZoneManager(api, new Map([[restored.UUID, restored]]), {
    readMyZoneSelection: () => identity('z01'), requestMyZoneSelection: () => {},
  }, () => {}, () => {});
  manager.update({ data: c.data, lastAttemptFailed: false });
  assert.equal(await on.handleGetRequest(), true);
  assert.equal(restored.UUID, old.UUID);
  assert.deepEqual(restored.services.map(s => s.subtype), old.services.map(s => s.subtype));
  assert.equal(restored.getServiceById(api.hap.Service.Switch, service.subtype)
    .getCharacteristic(api.hap.Characteristic.ConfiguredName).value, 'Custom reference');
  assert.deepEqual(registrations, []);
});

test('MyZone names, zone numbers and aircon addressing changes do not duplicate services', async t => {
  const c = await setup(t);
  const accessory = c.accessory();
  const serviceIds = accessory.services.map(s => s.subtype);
  c.data.aircons.ac2 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  c.data.aircons.ac2.info.name = 'Renamed AC';
  c.data.aircons.ac2.zones.z02.name = 'Renamed zone';
  c.data.aircons.ac2.zones.z02.number = 9;
  await c.advance(30100);
  assert.equal(c.accessory(), accessory);
  assert.deepEqual(accessory.services.map(s => s.subtype), serviceIds);
  await c.on('z02').handleSetRequest(true, {});
  await c.advance(3500);
  assert.deepEqual(c.writes[1], { ac2: { info: { myZone: 9 } } });
  assert.equal(c.registered.filter(a => a.context.advantageAirMyZone).length, 1);
});

test('lost MyZone capability retains the accessory and faults its switches until recovery', async t => {
  const c = await setup(t);
  const accessory = c.accessory();
  c.data.aircons.ac1.info.myZone = 0;
  await c.advance(30100);
  await assert.rejects(c.on('z01').handleGetRequest());
  await assert.rejects(c.on('z02').handleSetRequest(true));
  assert.equal(c.accessory(), accessory);
  c.data.aircons.ac1.info.myZone = 1;
  await c.advance(30100);
  assert.equal(await c.on('z01').handleGetRequest(), true);
  assert.deepEqual(c.removals, []);
  assert.deepEqual(c.writes, []);
});

test('a MyZone service whose zone changes type is retained unavailable and recovers without duplication', async t => {
  const c = await setup(t);
  const on = c.on('z02');
  c.data.aircons.ac1.zones.z02.type = 0;
  await c.advance(30100);
  await assert.rejects(on.handleGetRequest());
  assert.equal(await c.on('z01').handleGetRequest(), true);
  c.data.aircons.ac1.zones.z02.type = 1;
  await c.advance(30100);
  assert.equal(c.on('z02'), on);
  assert.equal(await on.handleGetRequest(), false);
  assert.deepEqual(c.removals, []);
});

test('missing controller data retains MyZone services; stale reads and shutdown reject operations', async t => {
  const c = await setup(t);
  const accessory = c.accessory();
  c.model.failure = true;
  await c.advance(30100);
  assert.equal(await c.on('z01').handleGetRequest(), true);
  await c.advance(61000);
  await assert.rejects(c.on('z01').handleGetRequest());
  await assert.rejects(c.on('z02').handleSetRequest(true));
  assert.equal(c.accessory(), accessory);
  c.model.failure = false;
  await c.advance(30100);
  assert.equal(await c.on('z01').handleGetRequest(), true);
  c.api.emit('shutdown');
  await assert.rejects(c.on('z01').handleGetRequest());
  await assert.rejects(c.on('z02').handleSetRequest(true));
  assert.deepEqual(c.writes, []);
});

test('duplicate MyZone managers cannot replace the owner callbacks', async t => {
  const c = await setup(t);
  const manager = new MyZoneManager(c.api, c.platform.accessories, {
    readMyZoneSelection: () => identity('z02'), requestMyZoneSelection: () => {},
  }, () => {}, () => {});
  assert.throws(() => manager.update({ data: c.data, lastAttemptFailed: false }), DuplicateControllerError);
  assert.equal(await c.on('z01').handleGetRequest(), true);
});

test('a newly eligible MyZone service is persisted once without recreating the accessory', async t => {
  const c = await setup(t, { edit: d => {
    d.aircons.ac1.zones.z02.type = 0;
  } });
  const accessory = c.accessory();
  c.data.aircons.ac1.zones.z02.type = 1;
  await c.advance(30100);
  assert.equal(c.accessory(), accessory);
  assert.equal(await c.on('z02').handleGetRequest(), false);
  assert.equal(c.updates.filter(a => a === accessory).length, 1);
  await c.advance(30100);
  assert.equal(c.updates.filter(a => a === accessory).length, 1);
});

test('invalid discovery makes MyZone unavailable and restores the same services after recovery', async t => {
  const c = await setup(t);
  const mid = c.data.system.mid;
  delete c.data.system.mid;
  await c.advance(30100);
  await assert.rejects(c.on('z01').handleGetRequest());
  c.data.system.mid = mid;
  await c.advance(30100);
  assert.equal(await c.on('z01').handleGetRequest(), true);
});

test('the MyZone simulator fixture preserves the percentage zone and uses a reported number different from its key', () => {
  const percentage = JSON.parse(fs.readFileSync(new URL('../../dev/lab/fixtures/percentage.json', import.meta.url), 'utf8'));
  assert.equal(fixture.system.mid, percentage.system.mid);
  assert.equal(fixture.aircons.ac1.info.uid, percentage.aircons.ac1.info.uid);
  assert.deepEqual(fixture.aircons.ac1.zones.z06, percentage.aircons.ac1.zones.z06);
  assert.equal(fixture.aircons.ac1.info.myZone, 1);
  assert.equal(fixture.aircons.ac1.zones.z02.number, 7);
});
