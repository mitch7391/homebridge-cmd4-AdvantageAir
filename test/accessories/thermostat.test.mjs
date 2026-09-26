import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { ThermostatAccessory } from '../../dist/accessories/thermostatAccessory.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);

async function flush() {
  for (let i = 0; i < 70; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = {
    system: { mid: 'controller', hasAircons: true, noOfAircons: 1 },
    aircons: { ac1: {
      info: { uid: 'unit', name: 'Aircon', state: 'off', mode: 'cool', myZone: 0, constant1: 1, setTemp: 24 },
      zones: {
        z01: { name: 'Living', number: 1, type: 1, state: 'open', setTemp: 24, measuredTemp: 23.1, error: 0 },
        z02: { name: 'Bedroom', number: 7, type: 1, state: 'close', setTemp: 24, measuredTemp: 21.2, error: 0 },
      },
    } },
  };
  const model = { delay: 6500, reject: false, failRead: false };
  const writes = [];
  let transition;
  t.mock.method(globalThis, 'fetch', async url => {
    if (url.pathname === '/setAircon') {
      const payload = JSON.parse(url.searchParams.get('json'));
      writes.push(payload);
      if (model.reject) {
        return { ok: true, status: 200, text: async () => 'false' };
      }
      transition = { payload, due: Date.now() + model.delay };
      return { ok: true, status: 200, text: async () => '{}' };
    }
    assert.equal(url.pathname, '/getSystemData');
    if (model.failRead) {
      throw new Error('private network failure');
    }
    if (transition && Date.now() >= transition.due) {
      for (const [key, patch] of Object.entries(transition.payload)) {
        Object.assign(data.aircons[key].info, patch.info);
        for (const [zone, fields] of Object.entries(patch.zones ?? {})) {
          Object.assign(data.aircons[key].zones[zone], fields);
        }
      }
      transition = undefined;
    }
    return { ok: true, status: 200, text: async () => JSON.stringify(transition ? {} : data) };
  });
  const api = new HomebridgeAPI();
  const messages = { info: [], warn: [], error: [], debug: [] };
  const log = Object.fromEntries(Object.keys(messages).map(level => [level, (...args) => messages[level].push(args.join(' '))]));
  const registered = [];
  t.mock.method(api, 'registerPlatformAccessories', (plugin, platform, accessories) => registered.push(...accessories));
  const platform = new AdvantageAirPlatform(log,
    { platform: 'AdvantageAir', devices: [{ ipAddress: '192.0.2.1', name: 'Controller', debug: true }] }, api);
  t.after(() => api.emit('shutdown'));
  const uuid = api.hap.uuid.generate(JSON.stringify([JSON.stringify(['AdvantageAir', 'controller', 'unit', 'aircon']), 'thermostat']));
  let cached;
  if (options.cached) {
    cached = new api.platformAccessory('Aircon', uuid);
    cached.context.advantageAirThermostat = true;
    cached.addService(api.hap.Service.Thermostat, 'Aircon')
      .setCharacteristic(api.hap.Characteristic.TargetTemperature, 30);
    platform.configureAccessory(cached);
  }
  const accessory = () => platform.accessories.get(uuid);
  const char = name => accessory().getService(api.hap.Service.Thermostat).getCharacteristic(api.hap.Characteristic[name]);
  const advance = async ms => {
    for (let remaining = ms; remaining > 0;) {
      const step = Math.min(remaining, 100);
      t.mock.timers.tick(step);
      remaining -= step;
      await flush();
    }
  };
  if (!options.paused) {
    api.emit('didFinishLaunching');
    await flush();
  }
  return { api, data, model, writes, messages, registered, platform, cached, accessory, char, advance };
}

function unavailable(c) {
  return error => error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE;
}

test('platform creates one Celsius thermostat with only Off Heat Cool, alongside existing zone accessories', async t => {
  const c = await setup(t);
  assert.equal(c.platform.accessories.size, 7);
  assert.equal(c.registered.filter(a => a.context.advantageAirThermostat).length, 1);
  assert.deepEqual(c.char('TargetHeatingCoolingState').props.validValues, [0, 1, 2]);
  assert.equal(c.char('TargetTemperature').props.minValue, 16);
  assert.equal(c.char('TargetTemperature').props.maxValue, 32);
  assert.equal(c.char('TargetTemperature').props.minStep, 1);
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 0);
  assert.equal(await c.char('TargetHeatingCoolingState').handleGetRequest(), 0);
  assert.ok(Math.abs(await c.char('CurrentTemperature').handleGetRequest() - 23.1) < 1e-8);
  assert.equal(await c.char('TargetTemperature').handleGetRequest(), 24);
  assert.equal(await c.char('TemperatureDisplayUnits').handleGetRequest(), 0);
  await c.char('TemperatureDisplayUnits').handleSetRequest(0);
  await c.advance(30000);
  assert.equal(c.writes.length, 0);
  assert.equal(c.messages.info.filter(line => line === 'Controller Created accessory: Aircon').length, 1);
  assert.equal(c.registered.length, 7);
  assert.deepEqual(c.messages.error, []);
});

test('a HomeKit mode write completes while busy and current mode changes only on confirmation', async t => {
  const c = await setup(t);
  const hap = c.accessory()._associatedHAPAccessory;
  hap.aid = 1;
  c.char('TargetHeatingCoolingState').iid = 10;
  const warnings = [];
  hap.on('characteristic-warning', warning => warnings.push(warning));
  let reply;
  hap.handleSetCharacteristics({}, { characteristics: [{ aid: 1, iid: 10, value: 1 }] }, (error, response) => {
    assert.equal(error, undefined);
    reply = response;
  });
  await flush();
  assert.equal(reply.characteristics[0].status, 0);
  assert.equal(Date.now(), 1000);
  assert.equal(await c.char('TargetHeatingCoolingState').handleGetRequest(), 1);
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 0);
  await c.advance(6100);
  assert.equal(c.data.aircons.ac1.info.state, 'off');
  assert.equal(c.char('CurrentHeatingCoolingState').value, 0);
  assert.equal(c.char('TargetHeatingCoolingState').value, 1);
  await c.advance(1100);
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 1);
  assert.deepEqual(c.writes, [{ ac1: { info: { state: 'on', mode: 'heat' } } }]);
  assert.equal(c.messages.debug.filter(line => line.includes('Controller confirmed: heat')).length, 1);
  assert.deepEqual(c.messages.warn, []);
  assert.deepEqual(warnings, []);
});

test('HomeKit temperature writes preserve measured readings and confirm main plus closed-zone targets', async t => {
  const c = await setup(t);
  await c.char('TargetTemperature').handleSetRequest(25);
  assert.equal(await c.char('TargetTemperature').handleGetRequest(), 25);
  assert.ok(Math.abs(await c.char('CurrentTemperature').handleGetRequest() - 23.1) < 1e-8);
  await c.advance(7200);
  assert.deepEqual(c.writes, [{ ac1: { info: { setTemp: 25 }, zones: { z01: { setTemp: 25 }, z02: { setTemp: 25 } } } }]);
  assert.equal(c.data.aircons.ac1.info.state, 'off');
  assert.ok(Math.abs(await c.char('CurrentTemperature').handleGetRequest() - 23.1) < 1e-8);
  assert.equal(c.char('TargetTemperature').value, 25);
});

test('rapid HomeKit mode reversals preserve the newest target while confirming both physical changes', async t => {
  const c = await setup(t);
  await c.char('TargetHeatingCoolingState').handleSetRequest(1);
  await flush();
  assert.equal(c.writes.length, 1);
  await c.char('TargetHeatingCoolingState').handleSetRequest(0);
  await c.advance(7200);
  assert.equal(await c.char('TargetHeatingCoolingState').handleGetRequest(), 0);
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 1);
  await c.advance(7200);
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 0);
  assert.equal(c.writes.length, 2);
  assert.equal(c.messages.debug.filter(line => line.includes('Controller confirmed: heat')).length, 0);
  assert.equal(c.messages.debug.filter(line => line.includes('Controller confirmed: off')).length, 1);
});

test('thermostat observes tablet changes and selects myZone temperature by its reported number', async t => {
  const c = await setup(t);
  Object.assign(c.data.aircons.ac1.info, { state: 'on', mode: 'cool', myZone: 7 });
  c.data.aircons.ac1.zones.z02.setTemp = 26;
  await c.advance(30100);
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 2);
  assert.equal(await c.char('TargetHeatingCoolingState').handleGetRequest(), 2);
  assert.ok(Math.abs(await c.char('CurrentTemperature').handleGetRequest() - 21.2) < 1e-8);
  assert.equal(await c.char('TargetTemperature').handleGetRequest(), 26);
  await c.char('TargetTemperature').handleSetRequest(27);
  await c.advance(7200);
  assert.deepEqual(c.writes[0], { ac1: { info: { setTemp: 27 }, zones: { z02: { setTemp: 27 } } } });
  assert.equal(c.data.aircons.ac1.zones.z01.setTemp, 24);
});

for (const mode of ['dry', 'vent']) {
  test(`observed ${mode} never publishes Auto or invalid current state, and explicit Off stops power`, async t => {
    const c = await setup(t);
    Object.assign(c.data.aircons.ac1.info, { state: 'on', mode });
    await c.advance(30100);
    assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 0);
    assert.equal(await c.char('TargetHeatingCoolingState').handleGetRequest(), 0);
    assert.equal(c.writes.length, 0);
    await c.char('TargetHeatingCoolingState').handleSetRequest(0);
    await c.advance(7200);
    assert.deepEqual(c.writes, [{ ac1: { info: { state: 'off' } } }]);
    assert.equal(c.data.aircons.ac1.info.mode, mode);
  });
}

test('sensor failure faults measured temperature independently of valid thermostat targets', async t => {
  const c = await setup(t);
  c.data.aircons.ac1.zones.z01.error = 1;
  await c.advance(30100);
  await assert.rejects(c.char('CurrentTemperature').handleGetRequest(), unavailable(c));
  assert.equal(await c.char('TargetTemperature').handleGetRequest(), 24);
  assert.equal(await c.char('TargetHeatingCoolingState').handleGetRequest(), 0);
  assert.equal(c.writes.length, 0);
  c.data.aircons.ac1.zones.z01.error = 0;
  await c.advance(30100);
  assert.ok(Math.abs(await c.char('CurrentTemperature').handleGetRequest() - 23.1) < 1e-8);
});

test('cached thermostat is unavailable before discovery, restores once, and retains its service', async t => {
  const c = await setup(t, { cached: true, paused: true });
  const service = c.accessory().getService(c.api.hap.Service.Thermostat);
  await assert.rejects(c.char('TargetTemperature').handleGetRequest(), unavailable(c));
  await assert.rejects(c.char('TargetHeatingCoolingState').handleSetRequest(1), unavailable(c));
  assert.equal(c.writes.length, 0);
  c.api.emit('didFinishLaunching');
  await flush();
  assert.equal(c.accessory(), c.cached);
  assert.equal(c.accessory().getService(c.api.hap.Service.Thermostat), service);
  assert.equal(await c.char('TargetTemperature').handleGetRequest(), 24);
  assert.equal(c.registered.length, 6);
  assert.equal(c.messages.info.filter(line => line === 'Controller Created accessory: Aircon').length, 0);
});

test('thermostat identity survives renamed and readdressed aircon without registering again', async t => {
  const c = await setup(t);
  const accessory = c.accessory();
  c.data.aircons.ac2 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  c.data.aircons.ac2.info.name = 'New name';
  await c.advance(30100);
  await c.char('TargetHeatingCoolingState').handleSetRequest(2);
  await c.advance(7200);
  assert.equal(c.accessory(), accessory);
  assert.equal(c.registered.length, 7);
  assert.deepEqual(c.writes, [{ ac2: { info: { state: 'on', mode: 'cool' } } }]);
});

test('missing aircon is retained but cannot read or accept thermostat writes', async t => {
  const c = await setup(t);
  c.data.aircons = {};
  Object.assign(c.data.system, { hasAircons: false, noOfAircons: 0 });
  await c.advance(30100);
  await assert.rejects(c.char('TargetTemperature').handleGetRequest(), unavailable(c));
  await assert.rejects(c.char('TargetHeatingCoolingState').handleSetRequest(1), unavailable(c));
  assert.equal(c.platform.accessories.size, 7);
  assert.equal(c.writes.length, 0);
});

test('stale controller data faults all thermostat readings and refuses new commands', async t => {
  const c = await setup(t);
  c.model.failRead = true;
  await c.advance(90100);
  for (const name of ['CurrentTemperature', 'TargetTemperature', 'CurrentHeatingCoolingState', 'TargetHeatingCoolingState']) {
    await assert.rejects(c.char(name).handleGetRequest(), unavailable(c));
  }
  await assert.rejects(c.char('TargetTemperature').handleSetRequest(25), unavailable(c));
  assert.equal(c.writes.length, 0);
});

test('multiple aircons get distinct thermostat identities and commands affect only the selected unit', async t => {
  const c = await setup(t, { paused: true });
  c.data.aircons.ac2 = globalThis.structuredClone(c.data.aircons.ac1);
  Object.assign(c.data.aircons.ac2.info, { uid: 'second-unit', name: 'Upstairs' });
  c.data.system.noOfAircons = 2;
  c.api.emit('didFinishLaunching');
  await flush();
  const thermostats = c.registered.filter(a => a.context.advantageAirThermostat);
  assert.equal(thermostats.length, 2);
  assert.notEqual(thermostats[0].UUID, thermostats[1].UUID);
  const upstairs = thermostats.find(a => a.displayName === 'Upstairs').getService(c.api.hap.Service.Thermostat);
  await upstairs.getCharacteristic(c.api.hap.Characteristic.TargetHeatingCoolingState).handleSetRequest(2);
  await c.advance(7200);
  assert.deepEqual(c.writes, [{ ac2: { info: { state: 'on', mode: 'cool' } } }]);
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 0);
});

test('invalid discovery faults the retained thermostat until valid identity data returns', async t => {
  const c = await setup(t);
  delete c.data.system.mid;
  await c.advance(30100);
  await assert.rejects(c.char('CurrentTemperature').handleGetRequest(), unavailable(c));
  await assert.rejects(c.char('TargetHeatingCoolingState').handleSetRequest(1), unavailable(c));
  assert.equal(c.writes.length, 0);
  assert.equal(c.messages.error.length, 1);
  c.data.system.mid = 'controller';
  await c.advance(30100);
  assert.equal(await c.char('TargetTemperature').handleGetRequest(), 24);
  assert.equal(c.registered.length, 7);
});

test('a rejected command faults its target without replacing observed readings and later recovers', async t => {
  const c = await setup(t);
  c.model.reject = true;
  await c.char('TargetHeatingCoolingState').handleSetRequest(1);
  await flush();
  await assert.rejects(c.char('TargetHeatingCoolingState').handleGetRequest(), unavailable(c));
  assert.equal(await c.char('CurrentHeatingCoolingState').handleGetRequest(), 0);
  assert.ok(Math.abs(await c.char('CurrentTemperature').handleGetRequest() - 23.1) < 1e-8);
  assert.equal(c.messages.warn.length, 1);
  await c.advance(30100);
  assert.equal(await c.char('TargetHeatingCoolingState').handleGetRequest(), 0);
});

test('shutdown makes thermostat controls unavailable and stops pending physical commands', async t => {
  const c = await setup(t);
  await c.char('TargetHeatingCoolingState').handleSetRequest(1);
  await flush();
  c.api.emit('shutdown');
  await c.advance(40000);
  await assert.rejects(c.char('TargetHeatingCoolingState').handleGetRequest(), unavailable(c));
  await assert.rejects(c.char('TargetTemperature').handleSetRequest(25), unavailable(c));
  assert.equal(c.writes.length, 1);
  assert.equal(c.messages.debug.filter(line => line.includes('Controller confirmed:')).length, 0);
});

test('HomeKit rejects unsupported modes and out-of-range temperatures before any controller write', async t => {
  const c = await setup(t);
  for (const [name, values] of [
    ['TargetHeatingCoolingState', [-1, 3, 4]],
    ['TargetTemperature', [15, 24.5, 33]],
    ['TemperatureDisplayUnits', [1]],
  ]) {
    for (const value of values) {
      await assert.rejects(c.char(name).handleSetRequest(value, {}), error => error === c.api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
    }
  }
  assert.equal(c.writes.length, 0);
});

test('live regression: integer write repairs fractional zone targets even when the main target already matches', async t => {
  const c = await setup(t, { paused: true });
  c.data.aircons.ac1.zones.z01.setTemp = 24.5;
  c.data.aircons.ac1.zones.z02.setTemp = 24.5;
  c.api.emit('didFinishLaunching');
  await flush();
  await c.char('TargetTemperature').handleSetRequest(24, {});
  await c.advance(7200);
  assert.deepEqual(c.writes, [{ ac1: { info: { setTemp: 24 }, zones: { z01: { setTemp: 24 }, z02: { setTemp: 24 } } } }]);
  assert.ok(c.messages.info.includes('Controller Aircon Sending: target temperature 24 °C'));
  assert.ok(c.messages.debug.includes('Controller Aircon Controller confirmed: 24 °C'));
  assert.equal(c.messages.info.some(line => line.includes('Controller confirmed:')), false);
  assert.deepEqual(c.messages.warn, []);
  assert.ok(Math.abs(await c.char('CurrentTemperature').handleGetRequest() - 23.1) < 1e-8);
});

test('dispatch logs only the latest unsent target, and failure names that target', async t => {
  const c = await setup(t);
  c.model.reject = true;
  const first = c.char('TargetTemperature').handleSetRequest(25, {});
  const second = c.char('TargetTemperature').handleSetRequest(26, {});
  await Promise.all([first, second]);
  await flush();
  assert.equal(c.writes.length, 1);
  assert.equal(c.writes[0].ac1.info.setTemp, 26);
  assert.deepEqual(c.messages.info.filter(line => line.includes('Sending:')),
    ['Controller Aircon Sending: target temperature 26 °C']);
  assert.equal(c.messages.warn.length, 1);
  assert.match(c.messages.warn[0], /Aircon.*target temperature 26 °C.*rejected/);
});

test('accessory isolates invalid readings and sanitises unexpected admission errors', async () => {
  const api = new HomebridgeAPI();
  const accessory = new api.platformAccessory('Aircon', api.hap.uuid.generate('isolated-thermostat'));
  const warnings = [];
  const options = {
    getCurrentMode: () => 'dry', getTargetMode: () => 'cool',
    getCurrentTemperature: () => NaN, getTargetTemperature: () => 24,
    setTargetMode: () => {
      throw new Error('private payload');
    },
    setTargetTemperature: () => {}, warn: message => warnings.push(message),
  };
  const handler = new ThermostatAccessory(api, accessory, options);
  handler.update();
  const char = name => accessory.getService(api.hap.Service.Thermostat).getCharacteristic(api.hap.Characteristic[name]);
  await assert.rejects(char('CurrentTemperature').handleGetRequest(), unavailable({ api }));
  await assert.rejects(char('CurrentHeatingCoolingState').handleGetRequest(), unavailable({ api }));
  assert.equal(await char('TargetTemperature').handleGetRequest(), 24);
  await assert.rejects(char('TargetHeatingCoolingState').handleSetRequest(1), unavailable({ api }));
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /Aircon.*could not be accepted/);
  assert.equal(warnings[0].includes('private'), false);
  options.warn = () => {
    throw new Error('logger failed');
  };
  await assert.rejects(char('TargetHeatingCoolingState').handleSetRequest(1), unavailable({ api }));
});
