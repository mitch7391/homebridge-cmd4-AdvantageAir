import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';

import { AdvantageAirPlatform } from '../../dist/platform.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

const require = createRequire(import.meta.url);
const homebridgeEntry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', homebridgeEntry).href);

function snapshot(type = 0, controllerId = 'test-controller') {
  return {
    system: {
      mid: controllerId,
      hasAircons: true,
      noOfAircons: 1,
    },
    aircons: {
      ac1: {
        info: { uid: 'test-aircon', name: 'Aircon', myZone: 0 },
        zones: {
          z01: {
            name: 'Living',
            number: 1,
            state: 'open',
            type,
            error: 0,
            measuredTemp: 23.5,
          },
        },
      },
    },
  };
}

async function flushPromises() {
  await Promise.resolve();
  await Promise.resolve();
}

function setup(t, devices, read) {
  t.mock.timers.enable({
    apis: ['setTimeout', 'Date'],
    now: 1000,
  });

  t.mock.method(AdvantageAirClient.prototype, 'getSystemData', read);

  const messages = {
    info: [],
    warn: [],
    error: [],
    debug: [],
  };

  const log = Object.fromEntries(
    Object.keys(messages).map(level => [
      level,
      (...args) => messages[level].push(args.join(' ')),
    ]),
  );

  const api = new HomebridgeAPI();
  const registrations = [];
  const allRegistrations = [];
  const registerAccessories = api.registerPlatformAccessories.bind(api);

  t.mock.method(api, 'registerPlatformAccessories', (plugin, platform, accessories) => {
    registerAccessories(plugin, platform, accessories);
    allRegistrations.push(...accessories);
    // Keep the existing temperature tests focused on temperature accessories.
    registrations.push(...accessories.filter(item => item.context.advantageAirTemperature === true));
  });
  const platform = new AdvantageAirPlatform(
    log,
    { platform: 'AdvantageAir', name: 'Test', devices },
    api,
  );

  t.after(() => api.emit('shutdown'));

  return { api, platform, messages, registrations, allRegistrations };
}

test('starts each controller once and stops polling on shutdown', async (t) => {
  const clients = new Set();
  let reads = 0;

  const { api } = setup(t, [
    { ipAddress: '192.0.2.1' },
    { ipAddress: '192.0.2.2' },
  ], async function () {
    clients.add(this);
    reads++;
    return snapshot(0, `controller-${[...clients].indexOf(this)}`);
  });

  assert.equal(reads, 0);

  api.emit('didFinishLaunching');
  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(clients.size, 2);
  assert.equal(reads, 2);

  t.mock.timers.tick(30000);
  await flushPromises();
  assert.equal(reads, 4);

  api.emit('shutdown');
  t.mock.timers.tick(60000);
  await flushPromises();
  assert.equal(reads, 4);
});

async function flushCommands() {
  for (let i = 0; i < 30; i++) {
    await Promise.resolve();
  }
}

function switchOn(context) {
  const accessory = context.allRegistrations.find(item => item.context.advantageAirZoneSwitch === true);
  assert.ok(accessory);
  return accessory.getService(context.api.hap.Service.Switch)
    .getCharacteristic(context.api.hap.Characteristic.On);
}

test('platform discovers both a zone switch and its separate temperature sensor', async (t) => {
  const c = setup(t, [{ ipAddress: '192.0.2.1' }], async () => snapshot(1));
  c.api.emit('didFinishLaunching');
  await flushPromises();
  assert.equal(c.allRegistrations.length, 2);
  assert.equal(c.registrations.length, 1);
  assert.equal(await switchOn(c).handleGetRequest(), true);
  t.mock.timers.tick(30000);
  await flushPromises();
  assert.equal(c.allRegistrations.length, 2);
});

test('platform confirms a switch write and later reflects controller reopening', async (t) => {
  const data = snapshot(1);
  const c = setup(t, [{ ipAddress: '192.0.2.1' }], async () => data);
  let writes = 0;
  t.mock.method(AdvantageAirClient.prototype, 'requestZoneState', async (aircon, zone, state) => {
    writes++;
    assert.equal(aircon, 'ac1');
    assert.equal(zone, 'z01');
    data.aircons.ac1.zones.z01.state = state;
    return {};
  });
  c.api.emit('didFinishLaunching');
  await flushPromises();
  const on = switchOn(c);
  const write = on.handleSetRequest(false);
  const read = on.handleGetRequest();
  await flushCommands();
  assert.equal(writes, 1);
  t.mock.timers.tick(1000);
  await flushCommands();
  await write;
  assert.equal(await read, false);
  assert.equal(await on.handleGetRequest(), false);
  data.aircons.ac1.zones.z01.state = 'open';
  t.mock.timers.tick(30000);
  await flushCommands();
  assert.equal(await on.handleGetRequest(), true);
  assert.equal(writes, 1);
});

test('platform reports myZone refusal without sending a command', async (t) => {
  const data = snapshot(1);
  data.aircons.ac1.info.myZone = 1;
  const c = setup(t, [{ ipAddress: '192.0.2.1', name: 'Controller' }], async () => data);
  let writes = 0;
  t.mock.method(AdvantageAirClient.prototype, 'requestZoneState', async () => {
    writes++;
  });
  c.api.emit('didFinishLaunching');
  await flushPromises();
  await assert.rejects(switchOn(c).handleSetRequest(false), error =>
    error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  assert.equal(writes, 0);
  assert.equal(c.messages.warn.length, 1);
  assert.match(c.messages.warn[0], /Living Zone.*Select another myZone/);
  t.mock.timers.tick(30000);
  await flushPromises();
  assert.equal(c.messages.warn.length, 1);
});

test('platform restores a cached switch without exposing its saved state before discovery', async (t) => {
  const c = setup(t, [{ ipAddress: '192.0.2.1' }], async () => snapshot(1));
  const identity = JSON.stringify(['AdvantageAir', 'test-controller', 'test-aircon', 'zone', 'z01']);
  const uuid = c.api.hap.uuid.generate(JSON.stringify([identity, 'zone-switch']));
  const cached = new c.api.platformAccessory('Living Zone', uuid);
  cached.context.advantageAirZoneSwitch = true;
  const on = cached.addService(c.api.hap.Service.Switch, 'Living Zone')
    .getCharacteristic(c.api.hap.Characteristic.On);
  on.updateValue(false);
  c.platform.configureAccessory(cached);
  await assert.rejects(on.handleGetRequest(), error =>
    error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  c.api.emit('didFinishLaunching');
  await flushPromises();
  assert.equal(await on.handleGetRequest(), true);
  assert.equal(c.platform.accessories.get(uuid), cached);
  assert.equal(c.allRegistrations.length, 1);
  assert.equal(c.registrations.length, 1);
});

test('platform shutdown interrupts confirmation and prevents further zone writes', async (t) => {
  const c = setup(t, [{ ipAddress: '192.0.2.1' }], async () => snapshot(1));
  let writes = 0;
  t.mock.method(AdvantageAirClient.prototype, 'requestZoneState', async () => {
    writes++;
    return {};
  });
  c.api.emit('didFinishLaunching');
  await flushPromises();
  const on = switchOn(c);
  const write = assert.rejects(on.handleSetRequest(false), error =>
    error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  await flushCommands();
  assert.equal(writes, 1);
  c.api.emit('shutdown');
  await write;
  await assert.rejects(on.handleSetRequest(false), error =>
    error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  assert.equal(writes, 1);
});

test('invalid identity data makes both switch and temperature readings unavailable', async (t) => {
  const data = snapshot(1);
  const c = setup(t, [{ ipAddress: '192.0.2.1' }], async () => data);
  c.api.emit('didFinishLaunching');
  await flushPromises();
  const temperature = c.registrations[0].getService(c.api.hap.Service.TemperatureSensor)
    .getCharacteristic(c.api.hap.Characteristic.CurrentTemperature);
  assert.equal(await temperature.handleGetRequest(), 23.5);
  delete data.system.mid;
  t.mock.timers.tick(30000);
  await flushPromises();
  for (const characteristic of [temperature, switchOn(c)]) {
    await assert.rejects(characteristic.handleGetRequest(), error =>
      error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  }
  assert.equal(c.messages.error.length, 1);
  assert.equal(c.allRegistrations.length, 2);
});

test('skips invalid and duplicate controllers but starts valid ones', async (t) => {
  let reads = 0;
  const clients = new Set();

  const { api, messages } = setup(t, [
    { ipAddress: '192.0.2.1' },
    { ipAddress: '192.0.2.1', port: 2025 },
    { ipAddress: '192.0.2.1', port: 2026 },
    { ipAddress: 'invalid' },
    { ipAddress: '192.0.2.2', port: '2025' },
    null,
  ], async function () {
    clients.add(this);
    reads++;
    return snapshot(0, `controller-${[...clients].indexOf(this)}`);
  });

  assert.equal(messages.error.length, 4);

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(reads, 2);
});

test('logs one warning per failure period and reports recovery', async (t) => {
  let reads = 0;

  const { api, messages } = setup(t, [
    { ipAddress: '192.0.2.1', name: 'Controller' },
  ], async () => {
    reads++;

    if (reads === 2 || reads === 3) {
      throw new Error('Private response content');
    }

    return snapshot();
  });

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(
    messages.info.filter(line => line.includes('first valid')).length,
    1,
  );

  t.mock.timers.tick(30000);
  await flushPromises();
  t.mock.timers.tick(30000);
  await flushPromises();

  assert.equal(messages.warn.length, 1);
  assert.match(messages.warn[0], /Retaining previously received data/);

  t.mock.timers.tick(30000);
  await flushPromises();

  assert.equal(
    messages.info.filter(line => line.includes('recovered')).length,
    1,
  );
  assert.equal(JSON.stringify(messages).includes('Private response content'), false);
});

test('debug summaries are enabled per controller', async (t) => {
  const clients = new Set();
  const { api, messages } = setup(t, [
    { ipAddress: '192.0.2.1', name: 'Verbose', debug: true },
    { ipAddress: '192.0.2.2', name: 'Quiet', debug: false },
  ], async function () {
    clients.add(this);
    return snapshot(0, `controller-${[...clients].indexOf(this)}`);
  });

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(messages.debug.length, 1);
  assert.match(messages.debug[0], /Verbose/);
  assert.match(messages.debug[0], /1 air conditioner\(s\), 1 zone\(s\)/);
});

test('retains restored accessories without registering new ones', (t) => {
  const { api, platform, registrations } = setup(t, [], async () => snapshot());
  const accessory = new api.platformAccessory(
    'Existing zone',
    api.hap.uuid.generate('cached-accessory'),
  );

  platform.configureAccessory(accessory);

  assert.equal(platform.accessories.get(accessory.UUID), accessory);
  assert.equal(registrations.length, 0);
});

test('shutdown before launch prevents controller reads', async (t) => {
  let reads = 0;

  const { api } = setup(t, [
    { ipAddress: '192.0.2.1' },
  ], async () => {
    reads++;
    return snapshot();
  });

  api.emit('shutdown');
  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(reads, 0);
});

test('platform registers a temperature accessory after launch and updates it', async (t) => {
  const data = snapshot(1);
  const { api, registrations } = setup(t, [
    { ipAddress: '192.0.2.1' },
  ], async () => data);

  assert.equal(registrations.length, 0);

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(registrations.length, 1);
  assert.equal(registrations[0].displayName, 'Living Temperature');

  const temperature = registrations[0]
    .getService(api.hap.Service.TemperatureSensor)
    .getCharacteristic(api.hap.Characteristic.CurrentTemperature);

  assert.equal(await temperature.handleGetRequest(), 23.5);

  data.aircons.ac1.zones.z01.measuredTemp = 24.5;
  t.mock.timers.tick(30000);
  await flushPromises();

  assert.equal(temperature.value, 24.5);
  assert.equal(registrations.length, 1);
});

test('platform expires temperature data during failures and restores it on recovery', async (t) => {
  let fail = false;
  const data = snapshot(1);

  const { api, registrations } = setup(t, [
    { ipAddress: '192.0.2.1' },
  ], async () => {
    if (fail) {
      throw new Error('Simulated connection failure');
    }
    return data;
  });

  api.emit('didFinishLaunching');
  await flushPromises();

  const service = registrations[0].getService(api.hap.Service.TemperatureSensor);
  const temperature = service.getCharacteristic(api.hap.Characteristic.CurrentTemperature);
  const fault = service.getCharacteristic(api.hap.Characteristic.StatusFault);

  fail = true;

  t.mock.timers.tick(30000);
  await flushPromises();
  assert.equal(await temperature.handleGetRequest(), 23.5);

  t.mock.timers.tick(30000);
  await flushPromises();
  t.mock.timers.tick(30000);
  await flushPromises();

  await assert.rejects(
    () => temperature.handleGetRequest(),
    error => error === api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );
  assert.equal(fault.value, api.hap.Characteristic.StatusFault.GENERAL_FAULT);

  fail = false;
  data.aircons.ac1.zones.z01.measuredTemp = 22.5;
  t.mock.timers.tick(30000);
  await flushPromises();

  assert.equal(await temperature.handleGetRequest(), 22.5);
  assert.equal(fault.value, api.hap.Characteristic.StatusFault.NO_FAULT);
  assert.equal(registrations.length, 1);
});

test('platform reuses a cached temperature accessory when controller data arrives', async (t) => {
  const { api, platform, registrations } = setup(t, [
    { ipAddress: '192.0.2.1' },
  ], async () => snapshot(1));

  const identity = JSON.stringify([
    'AdvantageAir',
    'test-controller',
    'test-aircon',
    'zone',
    'z01',
  ]);

  const uuid = api.hap.uuid.generate(JSON.stringify([identity, 'temperature']));
  const cached = new api.platformAccessory('Living Temperature', uuid);
  const service = cached.addService(api.hap.Service.TemperatureSensor, 'Living Temperature');

  platform.configureAccessory(cached);
  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(registrations.length, 0);
  assert.equal(platform.accessories.get(uuid), cached);
  assert.equal(cached.getService(api.hap.Service.TemperatureSensor), service);
  assert.equal(
    await service.getCharacteristic(api.hap.Characteristic.CurrentTemperature).handleGetRequest(),
    23.5,
  );
});

test('restored temperature stays unavailable until the first successful controller read', async (t) => {
  let fail = true;

  const { api, platform, registrations } = setup(t, [
    { ipAddress: '192.0.2.1' },
  ], async () => {
    if (fail) {
      throw new Error('Simulated startup failure');
    }

    return snapshot(1);
  });

  const identity = JSON.stringify([
    'AdvantageAir',
    'test-controller',
    'test-aircon',
    'zone',
    'z01',
  ]);

  const uuid = api.hap.uuid.generate(JSON.stringify([identity, 'temperature']));
  const cached = new api.platformAccessory('Living Temperature', uuid);
  cached.context.advantageAirTemperature = true;

  const service = cached.addService(api.hap.Service.TemperatureSensor, 'Living Temperature');
  const temperature = service.getCharacteristic(api.hap.Characteristic.CurrentTemperature);
  temperature.updateValue(28.5);

  platform.configureAccessory(cached);

  // Even before polling starts, a saved temperature must not appear fresh.
  await assert.rejects(
    () => temperature.handleGetRequest(),
    error => error === api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );

  api.emit('didFinishLaunching');
  await flushPromises();

  await assert.rejects(
    () => temperature.handleGetRequest(),
    error => error === api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );
  assert.equal(registrations.length, 0);

  fail = false;
  t.mock.timers.tick(30000);
  await flushPromises();

  assert.equal(await temperature.handleGetRequest(), 23.5);
  assert.equal(platform.accessories.get(uuid), cached);
  assert.equal(registrations.length, 0);
  assert.equal(
    await service.getCharacteristic(api.hap.Characteristic.StatusFault).handleGetRequest(),
    api.hap.Characteristic.StatusFault.NO_FAULT,
  );
});

test('controllers with matching aircon and zone IDs keep separate temperature readings', async (t) => {
  const clients = new Map();
  const first = snapshot(1);
  const second = snapshot(1);

  first.system.mid = 'controller-one';
  second.system.mid = 'controller-two';
  first.aircons.ac1.zones.z01.measuredTemp = 21.5;
  second.aircons.ac1.zones.z01.measuredTemp = 26.5;

  let firstFails = false;

  const { api, registrations } = setup(t, [
    { ipAddress: '192.0.2.1' },
    { ipAddress: '192.0.2.2' },
  ], async function () {
    if (!clients.has(this)) {
      clients.set(this, clients.size);
    }

    const index = clients.get(this);

    if (index === 0 && firstFails) {
      throw new Error('First controller unavailable');
    }

    return index === 0 ? first : second;
  });

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(registrations.length, 2);
  assert.notEqual(registrations[0].UUID, registrations[1].UUID);
  assert.ok(
    registrations.every(accessory => accessory.context.advantageAirTemperature === true),
  );

  function temperatureFor(controllerId) {
    const identity = JSON.stringify([
      'AdvantageAir',
      controllerId,
      'test-aircon',
      'zone',
      'z01',
    ]);

    const uuid = api.hap.uuid.generate(JSON.stringify([identity, 'temperature']));
    const accessory = registrations.find(item => item.UUID === uuid);
    assert.ok(accessory);

    return accessory
      .getService(api.hap.Service.TemperatureSensor)
      .getCharacteristic(api.hap.Characteristic.CurrentTemperature);
  }

  const firstTemperature = temperatureFor('controller-one');
  const secondTemperature = temperatureFor('controller-two');

  assert.equal(await firstTemperature.handleGetRequest(), 21.5);
  assert.equal(await secondTemperature.handleGetRequest(), 26.5);

  firstFails = true;
  second.aircons.ac1.zones.z01.measuredTemp = 25.5;

  for (let attempt = 0; attempt < 3; attempt++) {
    t.mock.timers.tick(30000);
    await flushPromises();
  }

  await assert.rejects(
    () => firstTemperature.handleGetRequest(),
    error => error === api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE,
  );
  assert.equal(await secondTemperature.handleGetRequest(), 25.5);
  assert.equal(registrations.length, 2);
});

test('duplicate controller identities stop only the duplicate polling loop', async (t) => {
  const clients = new Map();
  const reads = [0, 0];

  const { api, registrations, messages } = setup(t, [
    { ipAddress: '192.0.2.1' },
    { ipAddress: '192.0.2.2' },
  ], async function () {
    if (!clients.has(this)) {
      clients.set(this, clients.size);
    }

    const index = clients.get(this);
    reads[index]++;
    const data = snapshot(1);
    data.aircons.ac1.zones.z01.measuredTemp = index === 0 ? 22.5 : 26.5;
    return data;
  });

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.deepEqual(reads, [1, 1]);
  assert.equal(registrations.length, 1);
  assert.equal(messages.error.length, 1);
  assert.match(messages.error[0], /Duplicate controller identity/);

  t.mock.timers.tick(30000);
  await flushPromises();

  assert.deepEqual(reads, [2, 1]);
  assert.equal(messages.error.length, 1);
  const temperature = registrations[0]
    .getService(api.hap.Service.TemperatureSensor)
    .getCharacteristic(api.hap.Characteristic.CurrentTemperature);
  assert.equal(await temperature.handleGetRequest(), 22.5);
});
