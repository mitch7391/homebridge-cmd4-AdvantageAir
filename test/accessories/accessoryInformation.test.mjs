import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { updateAccessoryInformation } from '../../dist/accessories/accessoryInformation.js';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);
const version = require('../../package.json').version;
const fixture = JSON.parse(fs.readFileSync(new URL('../../dev/lab/fixtures/myzone.json', import.meta.url), 'utf8'));
const clone = value => globalThis.structuredClone(value);
const noop = () => undefined;
const log = { info: noop, warn: noop, error: noop, debug: noop };
const field = (api, accessory, name) => accessory.getService(api.hap.Service.AccessoryInformation)
  .getCharacteristic(api.hap.Characteristic[name]);

async function flush() {
  for (let i = 0; i < 100; i++) {
    await Promise.resolve();
  }
}

function platform(t, data, cached = [], devices = [{ ipAddress: '192.0.2.1' }]) {
  const api = new HomebridgeAPI();
  const registered = [];
  const updated = [];
  const register = api.registerPlatformAccessories.bind(api);
  t.mock.method(api, 'registerPlatformAccessories', (plugin, name, accessories) => {
    register(plugin, name, accessories);
    registered.push(...accessories);
  });
  t.mock.method(api, 'updatePlatformAccessories', accessories => updated.push(...accessories));
  t.mock.method(api, 'unregisterPlatformAccessories', () => assert.fail('Metadata must not remove accessories.'));
  const state = { fail: false, reads: 0 };
  t.mock.method(AdvantageAirClient.prototype, 'getSystemData', async () => {
    state.reads++;
    if (state.fail) {
      throw new Error('Offline');
    }
    return clone(typeof data === 'function' ? data() : data);
  });
  t.mock.method(globalThis, 'fetch', () => assert.fail('Metadata must not make controller requests.'));
  const instance = new AdvantageAirPlatform(log, { platform: 'AdvantageAir', devices }, api);
  cached.forEach(accessory => instance.configureAccessory(accessory));
  t.after(() => api.emit('shutdown'));
  return { api, instance, registered, updated, state, start: () => api.emit('didFinishLaunching') };
}

test('information uses exact family, existing UUID/name and package version with one information service', () => {
  const api = new HomebridgeAPI();
  const accessory = new api.platformAccessory('Existing Home Name', api.hap.uuid.generate('stable identity'));
  const services = [...accessory.services];
  accessory.context.saved = 123;
  for (const family of ['e-zone', 'MyAir5', ' MyPlace ']) {
    assert.equal(updateAccessoryInformation(api, accessory, family), true);
    assert.equal(field(api, accessory, 'Manufacturer').value, 'Advantage Air');
    assert.equal(field(api, accessory, 'Model').value, family);
    assert.equal(field(api, accessory, 'SerialNumber').value, 'AA-' + accessory.UUID.replace(/-/g, ''));
    assert.equal(field(api, accessory, 'FirmwareRevision').value, version);
    assert.equal(field(api, accessory, 'Name').value, 'Existing Home Name');
    assert.deepEqual(accessory.services, services);
    assert.deepEqual(accessory.context, { saved: 123 });
  }
});

test('invalid or absent model retains defaults or last good metadata without truncation', () => {
  const api = new HomebridgeAPI();
  const accessory = new api.platformAccessory('AC', api.hap.uuid.generate('invalid-model'));
  const initial = field(api, accessory, 'Model').value;
  for (const previous of [initial, 'e-zone']) {
    if (previous === 'e-zone') {
      updateAccessoryInformation(api, accessory, previous);
    }
    for (const invalid of [undefined, null, 7, {}, [], '', '  ', 'a\nb', 'a'.repeat(65), 'é'.repeat(33)]) {
      updateAccessoryInformation(api, accessory, invalid);
      assert.equal(field(api, accessory, 'Model').value, previous);
    }
  }
});

test('metadata persistence is idempotent and names cannot change serial identity', t => {
  const api = new HomebridgeAPI();
  const accessory = new api.platformAccessory('Old Name', api.hap.uuid.generate('persisted identity'));
  const updates = [];
  t.mock.method(api, 'updatePlatformAccessories', items => updates.push(...items));
  updateAccessoryInformation(api, accessory, 'e-zone', true);
  const serial = field(api, accessory, 'SerialNumber').value;
  assert.equal(updateAccessoryInformation(api, accessory, 'e-zone', true), false);
  assert.equal(updates.length, 1);
  accessory.displayName = 'New Name';
  assert.equal(updateAccessoryInformation(api, accessory, 'e-zone', true), true);
  assert.equal(field(api, accessory, 'SerialNumber').value, serial);
  assert.equal(field(api, accessory, 'Name').value, 'New Name');
  assert.equal(updates.length, 2);
});

test('fresh platform gives every layout parent metadata and no extra identities or controller reads', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = clone(fixture);
  data.system.sysType = 'MyAir5';
  const c = platform(t, data);
  c.start();
  await flush();
  const accessories = [...c.instance.accessories.values()];
  for (const marker of ['advantageAirTemperature', 'advantageAirZoneSwitch', 'advantageAirThermostat',
    'advantageAirModeFan', 'advantageAirPercentageZone', 'advantageAirMyZone', 'advantageAirTimer']) {
    assert.ok(accessories.some(a => a.context[marker]), marker);
  }
  const serials = new Set();
  for (const accessory of accessories) {
    assert.equal(field(c.api, accessory, 'Model').value, 'MyAir5');
    assert.equal(field(c.api, accessory, 'Manufacturer').value, 'Advantage Air');
    assert.equal(field(c.api, accessory, 'FirmwareRevision').value, version);
    const serial = field(c.api, accessory, 'SerialNumber').value;
    assert.equal(serial, 'AA-' + accessory.UUID.replace(/-/g, ''));
    serials.add(serial);
    assert.equal(accessory.services.filter(s => s.UUID === c.api.hap.Service.AccessoryInformation.UUID).length, 1);
  }
  assert.equal(serials.size, accessories.length);
  const thermostat = accessories.find(a => a.context.advantageAirThermostat);
  assert.ok(thermostat.getServiceById(c.api.hap.Service.Fan, 'fan-speed'));
  const myZone = accessories.find(a => a.context.advantageAirMyZone);
  assert.ok(myZone.services.filter(s => s.UUID === c.api.hap.Service.Switch.UUID).length > 1);
  assert.equal(c.registered.length, accessories.length);
  assert.equal(c.state.reads, 1);
});

test('cached upgrade retains UUIDs, actual services, context and selected Timer duration', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = clone(fixture);
  const first = platform(t, data);
  first.start();
  await flush();
  first.api.emit('shutdown');
  t.mock.restoreAll();
  const cached = [...first.instance.accessories.values()];
  const timer = cached.find(a => a.context.advantageAirTimer);
  timer.context.advantageAirTimerDuration = 2700;
  for (const accessory of cached) {
    field(first.api, accessory, 'Manufacturer').updateValue('Old Manufacturer');
    field(first.api, accessory, 'FirmwareRevision').updateValue('0.0.1');
  }
  const previous = cached.map(a => ({ uuid: a.UUID, services: [...a.services], context: clone(a.context), name: a.displayName }));
  const c = platform(t, data, cached);
  assert.equal(field(c.api, timer, 'Manufacturer').value, 'Old Manufacturer');
  c.start();
  await flush();
  assert.equal(c.registered.length, 0);
  assert.equal(c.instance.accessories.size, cached.length);
  for (let i = 0; i < cached.length; i++) {
    const a = cached[i];
    assert.equal(c.instance.accessories.get(previous[i].uuid), a);
    assert.deepEqual(a.services, previous[i].services);
    assert.deepEqual(a.context, previous[i].context);
    assert.equal(a.displayName, previous[i].name);
    assert.equal(field(c.api, a, 'Manufacturer').value, 'Advantage Air');
    assert.equal(field(c.api, a, 'FirmwareRevision').value, version);
    assert.equal(field(c.api, a, 'Model').value, data.system.sysType);
    assert.ok(c.updated.includes(a));
  }
  const duration = timer.getService(c.api.hap.Service.Valve).getCharacteristic(c.api.hap.Characteristic.SetDuration);
  assert.equal(await duration.handleGetRequest(), 2700);
});

test('later valid model updates every existing binding; failed reads preserve it', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = clone(fixture);
  delete data.system.sysType;
  const c = platform(t, data);
  c.start();
  await flush();
  const accessories = [...c.instance.accessories.values()];
  data.system.sysType = 'MyAir5';
  t.mock.timers.tick(30000);
  await flush();
  assert.ok(c.state.reads >= 2);
  for (const accessory of accessories) {
    assert.equal(field(c.api, accessory, 'Model').value, 'MyAir5');
  }
  const count = c.updated.length;
  t.mock.timers.tick(30000);
  await flush();
  assert.equal(c.updated.length, count, 'Unchanged metadata must not churn the cache.');
  c.state.fail = true;
  data.system.sysType = 'Wrong stale model';
  t.mock.timers.tick(30000);
  await flush();
  for (const accessory of accessories) {
    assert.equal(field(c.api, accessory, 'Model').value, 'MyAir5');
  }
});

test('separate controllers retain their own models and distinct accessory serials', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const first = clone(fixture);
  const second = clone(fixture);
  first.system.sysType = 'e-zone';
  second.system.sysType = 'MyAir5';
  second.system.mid = 'another controller';
  let reads = 0;
  const c = platform(t, () => ++reads === 1 ? first : second, [], [{ ipAddress: '192.0.2.1' }, { ipAddress: '192.0.2.2' }]);
  c.start();
  await flush();
  const models = c.registered.map(a => field(c.api, a, 'Model').value);
  assert.ok(models.includes('e-zone'));
  assert.ok(models.includes('MyAir5'));
  assert.equal(models.filter(x => x === 'e-zone').length, models.filter(x => x === 'MyAir5').length);
  const serials = c.registered.map(a => field(c.api, a, 'SerialNumber').value);
  assert.equal(new Set(serials).size, c.registered.length);
});
