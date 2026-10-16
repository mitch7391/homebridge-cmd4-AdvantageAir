import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';
import { pathToFileURL, URL } from 'node:url';

import { DuplicateControllerError, ZoneTemperatureManager } from '../../dist/accessories/zoneTemperatureManager.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../../dist/settings.js';

const require = createRequire(import.meta.url);
const homebridgeEntry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', homebridgeEntry).href);

function snapshot() {
  return {
    data: {
      system: { mid: 'test-controller' },
      aircons: {
        ac1: {
          info: { uid: 'test-aircon', name: 'Aircon' },
          zones: {
            z01: {
              name: 'Living',
              type: 1,
              error: 0,
              measuredTemp: 23.5,
            },
            z02: {
              name: 'Hall',
              type: 0,
              error: 0,
            },
          },
        },
      },
    },
    lastSuccessAt: 100000,
    lastAttemptAt: 100000,
    lastAttemptFailed: false,
  };
}

function setup(t) {
  t.mock.timers.enable({
    apis: ['Date'],
    now: 100000,
  });

  const api = new HomebridgeAPI();
  const registrations = [];
  const removals = [];

  const registerAccessories = api.registerPlatformAccessories.bind(api);

  t.mock.method(api, 'registerPlatformAccessories', (plugin, platform, accessories) => {
    registerAccessories(plugin, platform, accessories);
    registrations.push({ plugin, platform, accessories });
  });

  t.mock.method(api, 'unregisterPlatformAccessories', (...args) => {
    removals.push(args);
  });

  const accessories = new Map();
  const manager = new ZoneTemperatureManager(api, accessories);

  function temperature(accessory = [...accessories.values()][0]) {
    return accessory
      .getService(api.hap.Service.TemperatureSensor)
      .getCharacteristic(api.hap.Characteristic.CurrentTemperature);
  }

  return {
    api,
    accessories,
    manager,
    registrations,
    removals,
    temperature,
  };
}

test('manager registers temperature zones and skips percentage-only zones', (t) => {
  const context = setup(t);
  context.manager.update(snapshot());

  assert.equal(context.accessories.size, 1);
  assert.equal(context.registrations.length, 1);
  assert.equal(context.registrations[0].plugin, PLUGIN_NAME);
  assert.equal(context.registrations[0].platform, PLATFORM_NAME);
  assert.equal(
    context.registrations[0].accessories[0].displayName,
    'Living Temperature',
  );
  assert.equal(context.temperature().value, 23.5);
});

test('manager updates readings without registering duplicates', (t) => {
  const context = setup(t);
  const state = snapshot();
  context.manager.update(state);

  state.data.aircons.ac1.zones.z01.measuredTemp = 24.5;
  context.manager.update(state);

  assert.equal(context.registrations.length, 1);
  assert.equal(context.accessories.size, 1);
  assert.equal(context.temperature().value, 24.5);
});

test('manager reuses a restored accessory and its temperature service', (t) => {
  const context = setup(t);
  context.manager.update(snapshot());

  const accessory = [...context.accessories.values()][0];
  const restored = context.api.platformAccessory.deserialize(
    context.api.platformAccessory.serialize(accessory),
  );
  const service = restored.getService(context.api.hap.Service.TemperatureSensor);

  context.accessories.set(restored.UUID, restored);
  context.registrations.length = 0;

  const restartedApi = new HomebridgeAPI();
  t.mock.method(restartedApi, 'registerPlatformAccessories', (...args) => {
    context.registrations.push(args);
  });

  const restartedManager = new ZoneTemperatureManager(
    restartedApi,
    context.accessories,
  );
  restartedManager.update(snapshot());

  assert.equal(context.registrations.length, 0);
  assert.equal(context.accessories.get(restored.UUID), restored);
  assert.equal(
    restored.getService(context.api.hap.Service.TemperatureSensor),
    service,
  );
  assert.equal(context.temperature(restored).value, 23.5);
});

test('manager keeps accessory identity when names and aircon addressing change', async (t) => {
  const context = setup(t);
  const state = snapshot();
  context.manager.update(state);

  const accessory = [...context.accessories.values()][0];
  const aircon = state.data.aircons.ac1;
  delete state.data.aircons.ac1;
  state.data.aircons.ac2 = aircon;
  aircon.info.name = 'Renamed aircon';
  aircon.zones.z01.name = 'Renamed room';
  aircon.zones.z01.measuredTemp = 25.5;

  context.manager.update(state);

  assert.equal(context.registrations.length, 1);
  assert.equal(context.accessories.get(accessory.UUID), accessory);
  assert.equal(await context.temperature().handleGetRequest(), 25.5);
});

test('manager retains accessories through failed polls and expires old readings', async (t) => {
  const context = setup(t);
  const state = snapshot();
  context.manager.update(state);

  const failedState = { ...state, lastAttemptFailed: true };
  context.manager.update(failedState);
  assert.equal(await context.temperature().handleGetRequest(), 23.5);

  t.mock.timers.tick(90000);
  context.manager.update(failedState);

  await assert.rejects(
    () => context.temperature().handleGetRequest(),
    error => error === context.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );
  assert.equal(context.accessories.size, 1);
  assert.equal(context.removals.length, 0);
});

test('manager marks a missing zone unavailable and recovers without duplication', async (t) => {
  const context = setup(t);
  const state = snapshot();
  context.manager.update(state);

  const zone = state.data.aircons.ac1.zones.z01;
  delete state.data.aircons.ac1.zones.z01;
  context.manager.update(state);

  await assert.rejects(
    () => context.temperature().handleGetRequest(),
    error => error === context.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );
  assert.equal(context.accessories.size, 1);
  assert.equal(context.removals.length, 0);

  state.data.aircons.ac1.zones.z01 = zone;
  context.manager.update(state);

  assert.equal(await context.temperature().handleGetRequest(), 23.5);
  assert.equal(context.registrations.length, 1);
});

test('manager creates a faulty sensor accessory and recovers when the sensor does', async (t) => {
  const context = setup(t);
  const state = snapshot();
  state.data.aircons.ac1.zones.z01.error = 1;
  context.manager.update(state);

  assert.equal(context.accessories.size, 1);
  await assert.rejects(
    () => context.temperature().handleGetRequest(),
    error => error === context.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );

  state.data.aircons.ac1.zones.z01.error = 0;
  context.manager.update(state);

  assert.equal(await context.temperature().handleGetRequest(), 23.5);
  assert.equal(context.registrations.length, 1);
});

test('manager invalidates old addressing when discovery identities cannot be verified', async (t) => {
  const context = setup(t);
  const state = snapshot();
  context.manager.update(state);

  delete state.data.aircons.ac1.info.uid;

  assert.throws(
    () => context.manager.update(state),
    /air conditioner ID/,
  );

  await assert.rejects(
    () => context.temperature().handleGetRequest(),
    error => error === context.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );
  assert.equal(context.registrations.length, 1);
  assert.equal(context.removals.length, 0);

  state.data.aircons.ac1.info.uid = 'test-aircon';
  context.manager.update(state);

  assert.equal(await context.temperature().handleGetRequest(), 23.5);
  assert.equal(context.registrations.length, 1);
});

test('a duplicate controller manager cannot replace the original read handler', async (t) => {
  const context = setup(t);
  const original = snapshot();
  context.manager.update(original);

  const duplicate = new ZoneTemperatureManager(context.api, context.accessories);
  const otherState = snapshot();
  otherState.data.aircons.ac1.zones.z01.measuredTemp = 26.5;

  assert.throws(() => duplicate.update(otherState), DuplicateControllerError);

  original.data.aircons.ac1.zones.z01.measuredTemp = 22.5;
  context.manager.update(original);

  assert.equal(context.temperature().value, 22.5);
  assert.equal(await context.temperature().handleGetRequest(), 22.5);
  assert.equal(context.registrations.length, 1);
});
