import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';
import { pathToFileURL, URL } from 'node:url';

import { ZoneTemperatureAccessory } from '../../dist/accessories/zoneTemperatureAccessory.js';

const require = createRequire(import.meta.url);
const homebridgeEntry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', homebridgeEntry).href);

function setup(t, restoreService = false) {
  t.mock.timers.enable({
    apis: ['Date'],
    now: 100000,
  });

  const api = new HomebridgeAPI();
  const { Characteristic, Service, uuid } = api.hap;
  const accessory = new api.platformAccessory(
    'Living Temperature',
    uuid.generate('test-living-temperature'),
  );

  const existingService = restoreService
    ? accessory.addService(Service.TemperatureSensor, 'Living Temperature')
    : undefined;

  const zone = {
    type: 1,
    error: 0,
    measuredTemp: 23.1,
  };

  const state = {
    data: {
      system: {},
      aircons: {
        ac1: {
          info: {},
          zones: { z01: zone },
        },
      },
    },
    lastSuccessAt: 100000,
    lastAttemptAt: 100000,
    lastAttemptFailed: false,
  };

  const handler = new ZoneTemperatureAccessory(api, accessory, {
    airconKey: 'ac1',
    zoneKey: 'z01',
    getState: () => state,
  });

  const service = accessory.getService(Service.TemperatureSensor);

  return {
    api,
    accessory,
    existingService,
    handler,
    service,
    state,
    zone,
    temperature: service.getCharacteristic(Characteristic.CurrentTemperature),
    fault: service.getCharacteristic(Characteristic.StatusFault),
  };
}

async function expectUnavailable(context) {
  await assert.rejects(
    () => context.temperature.handleGetRequest(),
    error => error === context.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );

  assert.equal(
    await context.fault.handleGetRequest(),
    context.api.hap.Characteristic.StatusFault.GENERAL_FAULT,
  );
}

test('temperature accessory reads cached values and publishes updates', async (t) => {
  const context = setup(t);

  assert.ok(
    Math.abs(await context.temperature.handleGetRequest() - 23.1) < 0.000001,
    'Temperature should match 23.1 within floating-point tolerance.',
  );
  assert.equal(
    await context.fault.handleGetRequest(),
    context.api.hap.Characteristic.StatusFault.NO_FAULT,
  );

  context.zone.measuredTemp = 24.5;
  context.handler.update();

  assert.equal(context.temperature.value, 24.5);
  assert.equal(await context.temperature.handleGetRequest(), 24.5);
});

test('temperature accessory preserves a valid zero-degree reading', async (t) => {
  const context = setup(t);
  context.zone.measuredTemp = 0;

  assert.equal(await context.temperature.handleGetRequest(), 0);
});

test('temperature accessory retains fresh data after a failed poll but expires it', async (t) => {
  const context = setup(t);
  context.state.lastAttemptFailed = true;

  t.mock.timers.tick(89999);
  assert.ok(
    Math.abs(await context.temperature.handleGetRequest() - 23.1) < 0.000001,
    'Temperature should match 23.1 within floating-point tolerance.',
  );

  t.mock.timers.tick(1);
  await expectUnavailable(context);
});

test('temperature accessory reports unavailable before its first valid reading', async (t) => {
  const context = setup(t);
  delete context.state.data;
  delete context.state.lastSuccessAt;

  await expectUnavailable(context);
});

test('temperature accessory rejects missing and faulty sensor data', async (t) => {
  const context = setup(t);
  const zones = context.state.data.aircons.ac1.zones;

  const invalidZones = [
    undefined,
    { type: 0, error: 0, measuredTemp: 23.1 },
    { type: 1, error: 1, measuredTemp: 23.1 },
    { type: 1, error: 0, measuredTemp: 23.1, tempSensorClash: true },
    { type: 1, error: 0 },
    { type: 1, error: 0, measuredTemp: '23.1' },
    { type: 1, error: 0, measuredTemp: NaN },
    { type: 1, error: 0, measuredTemp: 1000 },
  ];

  for (const zone of invalidZones) {
    zones.z01 = zone;
    await expectUnavailable(context);
  }
});

test('temperature accessory clears its fault after fresh valid data returns', async (t) => {
  const context = setup(t);

  t.mock.timers.tick(90000);
  context.handler.update();

  assert.equal(
    context.fault.value,
    context.api.hap.Characteristic.StatusFault.GENERAL_FAULT,
  );
  await expectUnavailable(context);

  context.state.lastSuccessAt = Date.now();
  context.state.lastAttemptFailed = false;
  context.zone.measuredTemp = 22.5;
  context.handler.update();

  assert.equal(context.temperature.value, 22.5);
  assert.equal(
    context.fault.value,
    context.api.hap.Characteristic.StatusFault.NO_FAULT,
  );
  assert.equal(await context.temperature.handleGetRequest(), 22.5);
});

test('temperature accessory reuses an existing temperature service', (t) => {
  const context = setup(t, true);

  assert.equal(context.service, context.existingService);
  assert.equal(
    context.accessory.services.filter(
      service => service.UUID === context.api.hap.Service.TemperatureSensor.UUID,
    ).length,
    1,
  );
});
