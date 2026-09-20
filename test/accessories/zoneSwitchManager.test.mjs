import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';
import { pathToFileURL, URL } from 'node:url';
import { ZoneSwitchManager } from '../../dist/accessories/zoneSwitchManager.js';
import { DuplicateControllerError } from '../../dist/accessories/zoneTemperatureManager.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);
function snapshot(name = 'Living', key = 'ac1') {
  return {
    data: {
      system: { mid: 'controller' },
      aircons: { [key]: {
        info: { uid: 'unit' },
        zones: {
          z01: { name, number: 1, type: 1, state: 'open' },
          z02: { name: 'Hall', number: 2, type: 0, state: 'open' },
        },
      } },
    }, lastSuccessAt: Date.now(), lastAttemptAt: Date.now(), lastAttemptFailed: false,
  };
}
function setup(t) {
  const api = new HomebridgeAPI();
  const accessories = new Map();
  const registrations = [];
  t.mock.method(api, 'registerPlatformAccessories', (...args) => registrations.push(args));
  const model = { on: true, stopped: false };
  const coordinator = {
    readZone() {
      if (model.stopped) {
        throw new Error('stopped');
      }
      return model.on;
    },
    requestZone(identity, on) {
      if (model.stopped) {
        throw new Error('stopped');
      }
      model.on = on;
    },
    stop() {
      model.stopped = true;
    },
  };
  const manager = new ZoneSwitchManager(api, accessories, coordinator, () => {});
  const on = () => [...accessories.values()][0].getService(api.hap.Service.Switch)
    .getCharacteristic(api.hap.Characteristic.On);
  return { api, accessories, registrations, model, coordinator, manager, on };
}

test('manager discovers only sensor-zone switches and uses coordinator state', async t => {
  const c = setup(t);
  c.manager.update(snapshot());
  assert.equal(c.accessories.size, 1);
  assert.equal(await c.on().handleGetRequest(), true);
  await c.on().handleSetRequest(false);
  c.manager.update(snapshot());
  assert.equal(await c.on().handleGetRequest(), false);
  assert.equal(c.on().value, false);
  assert.equal(c.registrations.length, 1);
});

test('manager keeps accessory UUID through controller addressing and zone name changes', t => {
  const c = setup(t);
  c.manager.update(snapshot());
  const accessory = [...c.accessories.values()][0];
  c.manager.update(snapshot('Renamed', 'ac2'));
  assert.equal([...c.accessories.values()][0], accessory);
  assert.equal(c.registrations.length, 1);
});

test('manager invalidates handlers when discovery identities are malformed', async t => {
  const c = setup(t);
  c.manager.update(snapshot());
  const invalid = snapshot();
  delete invalid.data.system.mid;
  assert.throws(() => c.manager.update(invalid));
  await assert.rejects(c.on().handleGetRequest());
  c.manager.update(snapshot());
  assert.equal(await c.on().handleGetRequest(), true);
});

test('duplicate controller manager cannot replace registered switch handlers', async t => {
  const c = setup(t);
  c.manager.update(snapshot());
  const duplicate = new ZoneSwitchManager(c.api, c.accessories, c.coordinator, () => {});
  assert.throws(() => duplicate.update(snapshot()), DuplicateControllerError);
  assert.equal(await c.on().handleGetRequest(), true);
  assert.equal(c.registrations.length, 1);
});

test('restored switch rejects reads and writes until attached to its coordinator', async t => {
  const c = setup(t);
  c.manager.update(snapshot());
  const accessory = [...c.accessories.values()][0];
  ZoneSwitchManager.prepareCachedAccessory(c.api, accessory);
  await assert.rejects(c.on().handleGetRequest());
  await assert.rejects(c.on().handleSetRequest(false));
  const next = new ZoneSwitchManager(new HomebridgeAPI(), c.accessories, c.coordinator, () => {});
  next.update(snapshot());
  assert.equal(await c.on().handleGetRequest(), true);
  assert.equal(c.accessories.size, 1);
});

test('manager shutdown stops its coordinator and makes cached handlers unavailable', async t => {
  const c = setup(t);
  c.manager.update(snapshot());
  c.manager.stop();
  c.manager.update(snapshot());
  assert.equal(c.model.stopped, true);
  await assert.rejects(c.on().handleGetRequest());
  await assert.rejects(c.on().handleSetRequest(false));
});
