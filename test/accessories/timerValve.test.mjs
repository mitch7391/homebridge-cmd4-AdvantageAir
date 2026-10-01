import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { TimerValveManager } from '../../dist/accessories/timerValveManager.js';
import { discoverDevices } from '../../dist/discovery/discoverDevices.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);
const fixture = JSON.parse(fs.readFileSync(new URL('../../dev/lab/fixtures/myzone.json', import.meta.url), 'utf8'));
async function flush() {
  for (let i = 0; i < 80; i++) {
    await Promise.resolve();
  }
}

async function setup(t, edit) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = globalThis.structuredClone(fixture);
  Object.assign(data.aircons.ac1.info, { state: 'on', countDownToOn: 0, countDownToOff: 0 });
  edit?.(data);
  const writes = [];
  const model = { failure: false };
  let patch;
  t.mock.method(globalThis, 'fetch', async url => {
    if (url.pathname === '/setAircon') {
      patch = JSON.parse(url.searchParams.get('json'));
      writes.push(patch);
      return { ok: true, status: 200, text: async () => '{}' };
    }
    if (model.failure) {
      throw new Error('private');
    }
    if (patch) {
      for (const [ac, fields] of Object.entries(patch)) {
        Object.assign(data.aircons[ac].info, fields.info);
      }
      patch = undefined;
    }
    return { ok: true, status: 200, text: async () => JSON.stringify(data) };
  });
  const api = new HomebridgeAPI();
  const registered = [];
  const updates = [];
  const removed = [];
  const messages = { info: [], warn: [], error: [], debug: [] };
  const register = api.registerPlatformAccessories.bind(api);
  t.mock.method(api, 'registerPlatformAccessories', (plugin, platform, accessories) => {
    register(plugin, platform, accessories);
    registered.push(...accessories);
  });
  t.mock.method(api, 'updatePlatformAccessories', accessories => updates.push(...accessories));
  t.mock.method(api, 'unregisterPlatformAccessories', (...args) => removed.push(args));
  const log = Object.fromEntries(Object.keys(messages).map(level => [level, (...args) => messages[level].push(args.join(' '))]));
  const platform = new AdvantageAirPlatform(log, { platform: 'AdvantageAir', devices: [{ ipAddress: '192.0.2.1', debug: true }] }, api);
  t.after(() => api.emit('shutdown'));
  const accessory = () => [...platform.accessories.values()].find(a => a.context.advantageAirTimer);
  const characteristic = name => accessory().getService(api.hap.Service.Valve).getCharacteristic(api.hap.Characteristic[name]);
  const advance = async ms => {
    for (let left = ms; left > 0;) {
      const step = Math.min(left, 100);
      t.mock.timers.tick(step);
      left -= step;
      await flush();
    }
  };
  api.emit('didFinishLaunching');
  await flush();
  return { api, platform, data, model, writes, registered, updates, removed, messages, accessory, characteristic, advance };
}

test('native Timer creates one Generic Valve alongside existing layouts with correct seconds bounds', async t => {
  const c = await setup(t);
  assert.equal(c.accessory().displayName, 'Simulator AC Timer');
  const identity = discoverDevices(c.data).find(device => device.kind === 'aircon').identity;
  assert.equal(c.accessory().UUID, c.api.hap.uuid.generate(JSON.stringify([identity, 'native-timer'])));
  const valve = c.accessory().getService(c.api.hap.Service.Valve);
  assert.equal(valve.displayName, 'Simulator AC Timer');
  assert.equal(valve.getCharacteristic(c.api.hap.Characteristic.Name).value, 'Simulator AC Timer');
  const information = c.accessory().getService(c.api.hap.Service.AccessoryInformation);
  assert.equal(information.getCharacteristic(c.api.hap.Characteristic.Name).value, 'Simulator AC Timer');
  assert.equal(c.accessory().services.filter(service => service.UUID === c.api.hap.Service.Valve.UUID).length, 1);
  assert.equal(c.characteristic('ValveType').value, c.api.hap.Characteristic.ValveType.GENERIC_VALVE);
  assert.equal(c.characteristic('IsConfigured').value, 1);
  assert.equal(await c.characteristic('Active').handleGetRequest(), 0);
  assert.equal(await c.characteristic('InUse').handleGetRequest(), 0);
  assert.equal(await c.characteristic('SetDuration').handleGetRequest(), 1800);
  assert.equal(c.characteristic('SetDuration').props.maxValue, 43200);
  assert.equal(c.characteristic('SetDuration').props.minValue, 60);
  assert.equal(c.characteristic('SetDuration').props.minStep, 60);
  assert.equal(c.characteristic('RemainingDuration').props.maxValue, 43200);
  for (const marker of ['advantageAirMyZone', 'advantageAirThermostat', 'advantageAirPercentageZone']) {
    assert.ok([...c.platform.accessories.values()].some(a => a.context[marker]));
  }
  assert.equal(c.messages.info.filter(line => line.includes('Created accessory: Simulator AC Timer')).length, 1);
});

test('inactive SetDuration only stores selection; activation and active duration changes use coordinator', async t => {
  const c = await setup(t);
  assert.equal(await c.characteristic('SetDuration').handleSetRequest(2700, {}), 2700);
  assert.deepEqual(c.writes, []);
  assert.equal(c.accessory().context.advantageAirTimerDuration, 2700);
  assert.ok(c.updates.includes(c.accessory()));
  assert.equal(await c.characteristic('Active').handleSetRequest(1, {}), 1);
  assert.equal(await c.characteristic('InUse').handleGetRequest(), 0);
  await c.advance(1500);
  assert.equal(await c.characteristic('InUse').handleGetRequest(), 1);
  assert.equal(await c.characteristic('RemainingDuration').handleGetRequest(), 2700);
  await c.characteristic('SetDuration').handleSetRequest(3600, {});
  await c.advance(1500);
  assert.deepEqual(c.writes, [{ ac1: { info: { countDownToOff: 45 } } }, { ac1: { info: { countDownToOff: 60 } } }]);
  assert.ok(c.messages.info.some(line => line.includes('Sending: timer 45 minutes')));
  assert.ok(c.messages.debug.some(line => line.includes('Controller confirmed: timer 60 minutes')));
});

test('duration and activation close together use the newest selection and cancellation preserves it', async t => {
  const c = await setup(t);
  const active = c.characteristic('Active').handleSetRequest(1, {});
  const duration = c.characteristic('SetDuration').handleSetRequest(7200, {});
  await Promise.all([active, duration]);
  await c.advance(2500);
  assert.equal(c.writes.at(-1).ac1.info.countDownToOff, 120);
  await c.characteristic('Active').handleSetRequest(0, {});
  await c.advance(1500);
  assert.equal(c.writes.at(-1).ac1.info.countDownToOff, 0);
  assert.equal(await c.characteristic('SetDuration').handleGetRequest(), 7200);
  assert.equal(c.data.aircons.ac1.info.state, 'on');
});

test('observed countdown ticks and native expiry do not shrink SetDuration or send client power writes', async t => {
  const c = await setup(t);
  await c.characteristic('SetDuration').handleSetRequest(3600, {});
  c.data.aircons.ac1.info.countDownToOff = 1;
  await c.advance(30100);
  assert.equal(await c.characteristic('RemainingDuration').handleGetRequest(), 60);
  assert.equal(await c.characteristic('SetDuration').handleGetRequest(), 3600);
  Object.assign(c.data.aircons.ac1.info, { state: 'off', countDownToOff: 0 });
  await c.advance(30100);
  assert.equal(await c.characteristic('Active').handleGetRequest(), 0);
  assert.equal(await c.characteristic('InUse').handleGetRequest(), 0);
  assert.equal(await c.characteristic('RemainingDuration').handleGetRequest(), 0);
  assert.deepEqual(c.writes, []);
});

test('cached Countdown becomes Timer while retaining context, duration, UUID and service without fresh registration', async t => {
  const c = await setup(t);
  await c.characteristic('SetDuration').handleSetRequest(43200, {});
  const old = c.accessory();
  old.displayName = 'Simulator AC Countdown';
  const oldValve = old.getService(c.api.hap.Service.Valve);
  oldValve.displayName = old.displayName;
  oldValve.setCharacteristic(c.api.hap.Characteristic.Name, old.displayName);
  old.getService(c.api.hap.Service.AccessoryInformation).setCharacteristic(c.api.hap.Characteristic.Name, old.displayName);
  old.context.unrelatedSentinel = 'preserve';
  const savedContext = globalThis.structuredClone(old.context);
  const restored = c.api.platformAccessory.deserialize(JSON.parse(JSON.stringify(c.api.platformAccessory.serialize(old))));
  const api = new HomebridgeAPI();
  const serviceCount = restored.services.length;
  const updates = [];
  t.mock.method(api, 'updatePlatformAccessories', accessories => updates.push(...accessories));
  TimerValveManager.prepareCachedAccessory(api, restored);
  const valve = restored.getService(api.hap.Service.Valve);
  await assert.rejects(valve.getCharacteristic(api.hap.Characteristic.Active).handleGetRequest());
  await assert.rejects(valve.getCharacteristic(api.hap.Characteristic.Active).handleSetRequest(1));
  assert.equal(await valve.getCharacteristic(api.hap.Characteristic.SetDuration).handleGetRequest(), 43200);
  const registered = [];
  t.mock.method(api, 'registerPlatformAccessories', (...args) => registered.push(args));
  const manager = new TimerValveManager(api, new Map([[restored.UUID, restored]]), {
    readTimer: () => ({ active: true, inUse: true, remaining: 60 }), requestTimer: () => {},
  }, () => {}, () => {});
  manager.update({ data: c.data, lastAttemptFailed: false });
  assert.equal(await valve.getCharacteristic(api.hap.Characteristic.Active).handleGetRequest(), 1);
  assert.equal(valve.getCharacteristic(api.hap.Characteristic.RemainingDuration).value, 60);
  assert.equal(valve.getCharacteristic(api.hap.Characteristic.SetDuration).value, 43200);
  assert.equal(restored.UUID, old.UUID);
  assert.equal(restored.displayName, 'Simulator AC Timer');
  assert.equal(restored.getService(api.hap.Service.Valve), valve);
  assert.equal(valve.displayName, 'Simulator AC Timer');
  assert.equal(valve.getCharacteristic(api.hap.Characteristic.Name).value, 'Simulator AC Timer');
  const information = restored.getService(api.hap.Service.AccessoryInformation);
  assert.equal(information.getCharacteristic(api.hap.Characteristic.Name).value, 'Simulator AC Timer');
  assert.deepEqual(restored.context, savedContext);
  assert.equal(restored.services.length, serviceCount);
  assert.deepEqual(updates, [restored]);
  manager.update({ data: c.data, lastAttemptFailed: false });
  assert.deepEqual(updates, [restored]);
  const saved = api.platformAccessory.serialize(restored);
  assert.equal(saved.displayName, 'Simulator AC Timer');
  const next = api.platformAccessory.deserialize(JSON.parse(JSON.stringify(saved)));
  assert.equal(next.displayName, 'Simulator AC Timer');
  assert.equal(next.UUID, old.UUID);
  assert.deepEqual(next.context, savedContext);
  assert.equal(next.getService(api.hap.Service.Valve).getCharacteristic(api.hap.Characteristic.SetDuration).value, 43200);
  assert.equal(restored.services.filter(s => s.UUID === api.hap.Service.Valve.UUID).length, 1);
  assert.deepEqual(registered, []);
  manager.stop();
  await assert.rejects(valve.getCharacteristic(api.hap.Characteristic.Active).handleGetRequest());
});

test('timer name/address changes preserve identity; missing fields retain unavailable accessory and recover', async t => {
  const c = await setup(t);
  const old = c.accessory();
  c.data.aircons.ac9 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  c.data.aircons.ac9.info.name = 'Renamed';
  await c.advance(30100);
  await c.characteristic('Active').handleSetRequest(1, {});
  await c.advance(1500);
  assert.deepEqual(c.writes, [{ ac9: { info: { countDownToOff: 30 } } }]);
  delete c.data.aircons.ac9.info.countDownToOn;
  await c.advance(30100);
  await assert.rejects(c.characteristic('Active').handleGetRequest());
  c.data.aircons.ac9.info.countDownToOn = 0;
  await c.advance(30100);
  assert.equal(await c.characteristic('Active').handleGetRequest(), 1);
  assert.equal(c.accessory(), old);
  assert.equal(c.registered.filter(a => a.context.advantageAirTimer).length, 1);
  assert.deepEqual(c.removed, []);
});

test('timer is not created from absent capability; stale reads and shutdown reject timer writes', async t => {
  const c = await setup(t, data => {
    delete data.aircons.ac1.info.countDownToOn;
  });
  assert.equal(c.accessory(), undefined);
  c.data.aircons.ac1.info.countDownToOn = 0;
  await c.advance(30100);
  c.model.failure = true;
  await c.advance(91000);
  await assert.rejects(c.characteristic('Active').handleGetRequest());
  await assert.rejects(c.characteristic('Active').handleSetRequest(1));
  c.api.emit('shutdown');
  await assert.rejects(c.characteristic('Active').handleSetRequest(1));
  assert.deepEqual(c.writes, []);
});

test('Valve accepts minute minimum and partial-minute ceiling; zero cannot cancel through SetDuration', async t => {
  const c = await setup(t);
  const duration = c.characteristic('SetDuration');
  assert.equal(await duration.handleSetRequest(60, {}), 60);
  assert.equal(await duration.handleSetRequest(61, {}), 120);
  await c.characteristic('Active').handleSetRequest(1, {});
  await c.advance(1500);
  assert.equal(c.writes.at(-1).ac1.info.countDownToOff, 2);
  const count = c.writes.length;
  await assert.rejects(duration.handleSetRequest(0, {}));
  assert.equal(c.writes.length, count);
  assert.equal(await c.characteristic('Active').handleGetRequest(), 1);
  assert.equal(await duration.handleGetRequest(), 120);
});
