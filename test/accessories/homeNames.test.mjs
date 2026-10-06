import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { discoverDevices } from '../../dist/discovery/discoverDevices.js';
import { HomeNames, homeBaseName, detailedDebug } from '../../dist/discovery/homeNames.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))));
const fixture = JSON.parse(fs.readFileSync(new URL('../../dev/lab/fixtures/myzone.json', import.meta.url)));
const clone = value => globalThis.structuredClone(value);
function data(mid = 'first', keys = ['ac1']) {
  const result = clone(fixture);
  result.system.mid = mid;
  result.system.noOfAircons = keys.length;
  result.aircons = Object.fromEntries(keys.map(key => {
    const aircon = clone(fixture.aircons.ac1);
    aircon.info.uid = mid + '-' + key;
    aircon.info.name = 'Controller supplied ' + key;
    return [key, aircon];
  }));
  return result;
}
const identity = (snapshot, key) => discoverDevices(snapshot).find(d => d.kind === 'aircon' && d.airconKey === key).identity;
async function flush() {
  for (let i = 0; i < 120; i++) {
    await Promise.resolve();
  }
}
function setup(t, devices, snapshots, { debug = false, cached = [] } = {}) {
  const api = new HomebridgeAPI();
  const logs = { info: [], warn: [], error: [], debug: [] };
  const log = Object.fromEntries(Object.keys(logs).map(level => [level, (...args) => logs[level].push(args.join(' '))]));
  const registered = [];
  const updated = [];
  const reads = [];
  t.mock.method(api, 'registerPlatformAccessories', (_plugin, _platform, items) => registered.push(...items));
  t.mock.method(api, 'updatePlatformAccessories', items => updated.push(...items));
  t.mock.method(api, 'unregisterPlatformAccessories', () => assert.fail('Naming cannot remove accessories.'));
  t.mock.method(globalThis, 'fetch', async url => {
    assert.equal(url.pathname, '/getSystemData', 'Naming/debug must not send a controller write.');
    reads.push(url.hostname);
    const snapshot = snapshots[url.hostname];
    const value = typeof snapshot === 'function' ? await snapshot() : snapshot;
    return { ok: true, status: 200, text: async () => JSON.stringify(value) };
  });
  const config = { platform: 'AdvantageAir', name: 'Preserved platform label', debug, devices };
  const original = clone(config);
  const platform = new AdvantageAirPlatform(log, config, api);
  for (const accessory of cached) {
    platform.configureAccessory(accessory);
  }
  t.after(() => api.emit('shutdown'));
  return { api, platform, logs, registered, updated, reads, config, original,
    start: () => api.emit('didFinishLaunching'), stop: () => api.emit('shutdown') };
}
const accessories = c => [...c.platform.accessories.values()];
const thermostats = c => accessories(c).filter(a => a.context.advantageAirThermostat);

test('base names default only when missing/blank, trim explicit names, and debug uses strict OR', () => {
  for (const value of [undefined, '', '  \t ']) {
    assert.equal(homeBaseName(value), 'Aircon');
  }
  assert.equal(homeBaseName('  Downstairs Aircon  '), 'Downstairs Aircon');
  for (const global of [false, true]) {
    for (const individual of [false, true]) {
      assert.equal(detailedDebug(global, individual), global || individual);
    }
  }
  assert.equal(detailedDebug('true', 1), false);
});

test('natural aircon order, controller-local numbering and independent bases ignore arrival and JSON order', () => {
  const names = new HomeNames(assert.fail);
  names.configure(0, 'first', undefined);
  names.configure(1, 'second', ' Upstairs Aircon ');
  const a = data('first', ['ac10', 'ac2', 'ac1']);
  const b = data('second', ['ac2', 'ac1']);
  const before = clone([a, b]);
  assert.equal(names.update(1, b), false);
  assert.equal(names.resolve(identity(b, 'ac1')), undefined);
  assert.equal(names.update(0, a), true);
  assert.deepEqual(['ac1', 'ac2', 'ac10'].map(key => names.resolve(identity(a, key))), ['Aircon', 'Aircon 2', 'Aircon 3']);
  assert.deepEqual(['ac1', 'ac2'].map(key => names.resolve(identity(b, key))), ['Upstairs Aircon', 'Upstairs Aircon 2']);
  assert.deepEqual([a, b], before);
});

test('normalized configured and generated collisions reject the entire proposal with a useful diagnostic', () => {
  for (const [base1, base2, keys] of [[' Aircon ', 'airCON', ['ac1']], ['Aircon', 'aircon 2', ['ac2', 'ac1']]]) {
    const messages = [];
    const names = new HomeNames(message => messages.push(message));
    names.configure(0, 'Downstairs endpoint', base1);
    names.configure(1, 'Upstairs endpoint', base2);
    const a = data('first', keys);
    const b = data('second');
    names.update(0, a);
    assert.equal(names.update(1, b), false);
    assert.equal(names.resolve(identity(a, 'ac1')), undefined);
    assert.equal(names.resolve(identity(b, 'ac1')), undefined);
    assert.match(messages[0], /controller 1.*Downstairs endpoint/);
    assert.match(messages[0], /controller 2.*Upstairs endpoint/);
    names.update(1, b);
    assert.equal(messages.length, 1, 'Repeated polling must not repeat the same conflict warning.');
  }
});

test('later inventory collision retains all previously accepted names, then recovers when corrected', () => {
  const names = new HomeNames(() => {});
  names.configure(0, 'first', 'Aircon');
  names.configure(1, 'second', 'Aircon 2');
  const a = data('first', ['ac2']);
  const b = data('second');
  names.update(0, a);
  names.update(1, b);
  const expanded = data('first', ['ac2', 'ac1']);
  assert.equal(names.update(0, expanded), false);
  assert.equal(names.resolve(identity(a, 'ac2')), 'Aircon');
  assert.equal(names.resolve(identity(expanded, 'ac1')), undefined);
  assert.equal(names.resolve(identity(b, 'ac1')), 'Aircon 2');
  names.configure(1, 'second', 'Upstairs');
  assert.equal(names.update(1, b), true);
  assert.equal(names.resolve(identity(a, 'ac2')), 'Aircon 2');
  assert.equal(names.resolve(identity(expanded, 'ac1')), 'Aircon');
});

test('platform applies Aircon defaults and all existing derived names while leaving zones unchanged', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const c = setup(t, [{ ipAddress: '192.0.2.1', name: 'Legacy log label', homeName: '  ' }], { '192.0.2.1': data() });
  c.start();
  await flush();
  assert.equal(c.logs.error.length, 0);
  const all = accessories(c);
  for (const name of ['Aircon', 'Aircon Fan', 'Aircon Dry Mode', 'Aircon MyZone', 'Aircon Timer',
    'Living Reference Zone', 'Living Reference Temperature', 'Percentage Test Zone']) {
    assert.ok(all.some(a => a.displayName === name), name);
  }
  const thermostat = thermostats(c)[0];
  assert.equal(thermostat.getServiceById(c.api.hap.Service.Fan, 'fan-speed').displayName, 'Aircon FanSpeed');
  const myZone = all.find(a => a.context.advantageAirMyZone);
  assert.ok(myZone.services.some(s => s.displayName === 'Living Reference MyZone'));
  assert.deepEqual(c.config, c.original);
  assert.equal(c.reads.length, 1);
});

test('later controller arriving first cannot cause partial renames; cached controls remain readable', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const a = data('first');
  const b = data('second');
  const first = setup(t, [{ ipAddress: '192.0.2.1', homeName: 'Before downstairs' },
    { ipAddress: '192.0.2.2', homeName: 'Before upstairs' }], { '192.0.2.1': a, '192.0.2.2': b });
  first.start();
  await flush();
  first.stop();
  t.mock.restoreAll();
  const cached = accessories(first);
  const before = cached.map(a => a.displayName);
  let release;
  const gate = new Promise(resolve => {
    release = resolve;
  });
  const c = setup(t, [{ ipAddress: '192.0.2.1', homeName: 'New downstairs' },
    { ipAddress: '192.0.2.2', homeName: 'New upstairs' }], {
    '192.0.2.1': () => gate,
    '192.0.2.2': b,
  }, { cached });
  c.start();
  await flush();
  assert.deepEqual(cached.map(a => a.displayName), before);
  const upstairs = cached.find(a => a.displayName === 'Before upstairs');
  assert.equal(await upstairs.getService(c.api.hap.Service.Thermostat)
    .getCharacteristic(c.api.hap.Characteristic.TargetTemperature).handleGetRequest(), b.aircons.ac1.info.setTemp);
  release(a);
  await flush();
  assert.deepEqual(thermostats(c).map(a => a.displayName).sort(), ['New downstairs', 'New upstairs']);
  assert.equal(c.registered.length, 0);
  assert.equal(c.reads.length, 2);
});

test('cached rename retains accessory/service objects, UUIDs, serials, Timer duration and configuration', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const snapshots = { '192.0.2.1': data() };
  const first = setup(t, [{ ipAddress: '192.0.2.1', homeName: 'Before' }], snapshots);
  first.start();
  await flush();
  const cached = accessories(first);
  const timer = cached.find(a => a.context.advantageAirTimer);
  timer.context.advantageAirTimerDuration = 2700;
  const before = cached.map(a => ({ uuid: a.UUID, services: [...a.services], context: clone(a.context),
    name: a.displayName, serial: a.getService(first.api.hap.Service.AccessoryInformation)
      .getCharacteristic(first.api.hap.Characteristic.SerialNumber).value }));
  first.stop();
  t.mock.restoreAll();
  const c = setup(t, [{ ipAddress: '192.0.2.1', name: 'Retained label', homeName: ' After ' }], snapshots, { cached });
  c.start();
  await flush();
  assert.equal(c.registered.length, 0);
  assert.equal(c.platform.accessories.size, cached.length);
  for (let i = 0; i < cached.length; i++) {
    const a = cached[i];
    assert.equal(c.platform.accessories.get(before[i].uuid), a);
    assert.deepEqual(a.services, before[i].services);
    assert.deepEqual(a.context, before[i].context);
    assert.equal(a.getService(c.api.hap.Service.AccessoryInformation)
      .getCharacteristic(c.api.hap.Characteristic.SerialNumber).value, before[i].serial);
    assert.equal(a.displayName, before[i].name.startsWith('Before') ? before[i].name.replace('Before', 'After') : before[i].name);
  }
  assert.equal(await timer.getService(c.api.hap.Service.Valve)
    .getCharacteristic(c.api.hap.Characteristic.SetDuration).handleGetRequest(), 2700);
  assert.deepEqual(c.config, c.original);
});

test('runtime generated collision does not partially rename or disable existing accessories', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const snapshots = { '192.0.2.1': data('first', ['ac2']), '192.0.2.2': data('second') };
  const c = setup(t, [{ ipAddress: '192.0.2.1', homeName: 'Aircon' },
    { ipAddress: '192.0.2.2', homeName: 'Aircon 2' }], snapshots);
  c.start();
  await flush();
  const old = accessories(c).map(a => [a, a.displayName]);
  snapshots['192.0.2.1'] = data('first', ['ac2', 'ac1']);
  t.mock.timers.tick(30000);
  await flush();
  for (const [a, name] of old) {
    assert.equal(a.displayName, name);
  }
  assert.deepEqual(thermostats(c).map(a => a.displayName).sort(), ['Aircon', 'Aircon 2']);
  assert.equal(c.logs.error.length, 0);
  assert.ok(c.logs.warn.some(s => s.includes('Home accessory naming conflict')));
  for (const a of thermostats(c)) {
    assert.equal(await a.getService(c.api.hap.Service.Thermostat)
      .getCharacteristic(c.api.hap.Characteristic.TargetTemperature).handleGetRequest(), 24);
  }
});

test('global debug enables all controllers and turning it off restores preserved individual selections', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const devices = [{ ipAddress: '192.0.2.1', name: 'Downstairs log', homeName: 'Downstairs', debug: true },
    { ipAddress: '192.0.2.2', name: 'Upstairs log', homeName: 'Upstairs', debug: false }];
  const snapshots = { '192.0.2.1': data('first'), '192.0.2.2': data('second') };
  for (const debug of [false, true, false]) {
    const c = setup(t, devices, snapshots, { debug });
    c.start();
    await flush();
    for (const label of ['Downstairs log', 'Upstairs log']) {
      const enabled = label === 'Downstairs log' || debug;
      assert.equal(c.logs.debug.some(s => s.includes(label) && s.includes('AA timing:')), enabled);
      assert.equal(c.logs.debug.some(s => s.includes(label) && s.includes('Controller read:')), enabled);
    }
    assert.deepEqual(c.config, c.original);
    c.stop();
    t.mock.restoreAll();
  }
  assert.deepEqual(devices.map(d => d.debug), [true, false]);
});
