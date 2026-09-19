import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';
import { pathToFileURL, URL } from 'node:url';

import { ZoneSwitchManager } from '../../dist/accessories/zoneSwitchManager.js';
import { ZoneCommandError } from '../../dist/api/zoneCommand.js';
import { ZoneCommandExecutor } from '../../dist/api/zoneCommandExecutor.js';
import { DuplicateControllerError } from '../../dist/accessories/zoneTemperatureManager.js';

const require = createRequire(import.meta.url);
const entry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', entry).href);

function snapshot(open = true, key = 'ac1') {
  return {
    data: {
      system: { mid: 'controller' },
      aircons: {
        [key]: {
          info: { uid: 'unit', myZone: 0 },
          zones: {
            z01: {
              name: 'Living',
              number: 1,
              type: 1,
              state: open ? 'open' : 'close',
            },
            z02: {
              name: 'Hall',
              number: 2,
              type: 0,
              state: 'open',
              value: 50,
            },
          },
        },
      },
    },
    lastSuccessAt: Date.now(),
    lastAttemptAt: Date.now(),
    lastAttemptFailed: false,
  };
}

function setup(t) {
  t.mock.timers.enable({ apis: ['Date'], now: 100000 });
  const api = new HomebridgeAPI();
  const accessories = new Map();
  const registrations = [];
  const warnings = [];
  t.mock.method(api, 'registerPlatformAccessories', (...args) => registrations.push(args));
  const executor = {
    async setZone(identity, on) {
      return { outcome: 'confirmed', data: snapshot(on).data };
    },
    stop() {},
  };
  const manager = new ZoneSwitchManager(
    api,
    accessories,
    executor,
    message => warnings.push(message),
  );
  const on = () => [...accessories.values()][0]
    .getService(api.hap.Service.Switch)
    .getCharacteristic(api.hap.Characteristic.On);
  const unavailable = error => error === api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE;
  return {
    api, accessories, registrations, warnings, executor, manager, on, unavailable,
  };
}

test('switch manager discovers sensor-zone switches and keeps percentage zones for their own layout', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  assert.equal(c.accessories.size, 1);
  assert.equal([...c.accessories.values()][0].displayName, 'Living Zone');
  assert.equal(await c.on().handleGetRequest(), true);
  c.manager.update(snapshot(false));
  assert.equal(c.registrations.length, 1);
  assert.equal(await c.on().handleGetRequest(), false);
});

test('confirmed switch state survives an older poll and later reflects a controller override', async (t) => {
  const c = setup(t);
  const old = snapshot();
  c.manager.update(old);
  t.mock.timers.tick(10);
  await c.on().handleSetRequest(false);
  assert.equal(await c.on().handleGetRequest(), false);
  old.lastSuccessAt = Date.now();
  c.manager.update(old);
  assert.equal(await c.on().handleGetRequest(), false);
  t.mock.timers.tick(1);
  c.manager.update(snapshot());
  assert.equal(await c.on().handleGetRequest(), true);
});

test('failed polls cannot restore cached data from before a confirmed write', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  await c.on().handleSetRequest(false);
  t.mock.timers.tick(1);
  c.manager.update({ ...snapshot(), lastAttemptFailed: true });
  assert.equal(await c.on().handleGetRequest(), false);
  t.mock.timers.tick(90000);
  await assert.rejects(c.on().handleGetRequest(), c.unavailable);
});

test('failed commands require a new poll and log their reason', async (t) => {
  const c = setup(t);
  const old = snapshot();
  c.manager.update(old);
  c.executor.setZone = async () => {
    throw new ZoneCommandError('Select another myZone before closing this zone.');
  };
  await assert.rejects(c.on().handleSetRequest(false), c.unavailable);
  assert.match(c.warnings[0], /Living Zone.*Select another myZone/);
  c.manager.update(old);
  await assert.rejects(c.on().handleGetRequest(), c.unavailable);
  t.mock.timers.tick(1);
  c.manager.update(snapshot());
  assert.equal(await c.on().handleGetRequest(), true);
  assert.equal(c.warnings.length, 1);
});

test('switch identity survives name and aircon-key changes', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  const initial = [...c.accessories.values()][0];
  const changed = snapshot(false, 'ac2');
  changed.data.aircons.ac2.zones.z01.name = 'Renamed';
  c.manager.update(changed);
  assert.equal([...c.accessories.values()][0], initial);
  assert.equal(c.registrations.length, 1);
  assert.equal(await c.on().handleGetRequest(), false);
});

test('missing zones remain registered but unavailable and can recover', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  const missing = snapshot();
  delete missing.data.aircons.ac1.zones.z01;
  c.manager.update(missing);
  assert.equal(c.accessories.size, 1);
  await assert.rejects(c.on().handleGetRequest(), c.unavailable);
  c.manager.update(snapshot());
  assert.equal(await c.on().handleGetRequest(), true);
});

test('invalid discovery identities invalidate switch readings', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  const invalid = snapshot();
  delete invalid.data.system.mid;
  assert.throws(() => c.manager.update(invalid));
  await assert.rejects(c.on().handleGetRequest(), c.unavailable);
});

test('another configured address cannot replace an existing switch owner', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  const duplicate = new ZoneSwitchManager(
    c.api, c.accessories, c.executor, () => {},
  );
  assert.throws(() => duplicate.update(snapshot(false)), DuplicateControllerError);
  assert.equal(await c.on().handleGetRequest(), true);
  assert.equal(c.registrations.length, 1);
});

test('restored switches stay unavailable until discovery reattaches their handlers', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  const accessory = [...c.accessories.values()][0];
  ZoneSwitchManager.prepareCachedAccessory(c.api, accessory);
  await assert.rejects(c.on().handleGetRequest(), c.unavailable);
  await assert.rejects(c.on().handleSetRequest(false), c.unavailable);
  const newApi = new HomebridgeAPI();
  const next = new ZoneSwitchManager(
    newApi, c.accessories, c.executor, () => {},
  );
  next.update(snapshot(false));
  assert.equal(await c.on().handleGetRequest(), false);
  assert.equal(c.accessories.size, 1);
});

test('stopping the manager prevents further reads and commands', async (t) => {
  const c = setup(t);
  c.manager.update(snapshot());
  let stopped = 0;
  c.executor.stop = () => {
    stopped++;
  };
  c.manager.stop();
  c.manager.update(snapshot());
  await assert.rejects(c.on().handleGetRequest(), c.unavailable);
  await assert.rejects(c.on().handleSetRequest(false), c.unavailable);
  assert.equal(stopped, 1);
});

test('switch manager, handler and executor confirm a command together', async (t) => {
  const c = setup(t);
  let writes = 0;
  let reads = 0;
  const executor = new ZoneCommandExecutor({
    async getFreshSystemData() {
      reads++;
      return snapshot(writes === 0).data;
    },
    async requestZoneState() {
      writes++;
      return {};
    },
  }, 2, 1);
  const manager = new ZoneSwitchManager(
    c.api, c.accessories, executor, () => {},
  );
  manager.update(snapshot());
  await c.on().handleSetRequest(false);
  assert.equal(await c.on().handleGetRequest(), false);
  assert.equal(reads, 2);
  assert.equal(writes, 1);
});
