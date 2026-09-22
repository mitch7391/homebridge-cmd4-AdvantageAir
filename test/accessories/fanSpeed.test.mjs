import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { fanSetting } from '../../dist/api/fanCommand.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

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
      info: { uid: 'unit', name: 'Aircon', state: 'off', mode: 'cool', fan: 'low', myZone: 0, constant1: 1, setTemp: 24 },
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
        if (data.aircons[key].info.fan === 'autoAA') {
          data.aircons[key].info.fan = 'auto';
        }
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
  const fan = name => accessory().getServiceById(api.hap.Service.Fan, 'fan-speed').getCharacteristic(api.hap.Characteristic[name]);
  return { fan, api, data, model, writes, messages, registered, platform, cached, accessory, char, advance };
}

function unavailable(c) {
  return error => error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE;
}

test('legacy fan boundaries map to stable speed bands and reject invalid inputs', () => {
  for (const [value, fan, percentage] of [[0, 'low', 25], [33, 'low', 25], [34, 'medium', 50],
    [67, 'medium', 50], [68, 'high', 90], [99, 'high', 90], [100, 'autoAA', 100]]) {
    assert.deepEqual(fanSetting(value), { fan, percentage });
  }
  for (const value of [-1, 101, 24.5, NaN, Infinity, '50', null]) {
    assert.throws(() => fanSetting(value));
  }
});

test('linked speed reuses the thermostat accessory and never controls power through On', async t => {
  const c = await setup(t);
  const service = c.accessory().getServiceById(c.api.hap.Service.Fan, 'fan-speed');
  assert.ok(c.accessory().getService(c.api.hap.Service.Thermostat).linkedServices.includes(service));
  assert.equal(c.platform.accessories.size, 5);
  assert.equal(await c.fan('On').handleGetRequest(), true);
  assert.equal(await c.fan('RotationSpeed').handleGetRequest(), 25);
  await c.fan('On').handleSetRequest(false, {});
  assert.equal(c.fan('On').value, true);
  assert.equal(await c.fan('On').handleGetRequest(), true);
  await c.advance(1000);
  assert.equal(c.writes.length, 0);
  assert.equal(c.data.aircons.ac1.info.state, 'off');
});

test('fan write acknowledges immediately, snaps to its band, and confirms only fan without powering on', async t => {
  const c = await setup(t);
  const before = globalThis.structuredClone(c.data);
  await c.fan('RotationSpeed').handleSetRequest(60, {});
  assert.equal(c.fan('RotationSpeed').value, 50);
  assert.equal(await c.fan('RotationSpeed').handleGetRequest(), 50);
  assert.equal(c.data.aircons.ac1.info.fan, 'low');
  await c.advance(7200);
  assert.deepEqual(c.writes, [{ ac1: { info: { fan: 'medium' } } }]);
  before.aircons.ac1.info.fan = 'medium';
  assert.deepEqual(c.data, before);
  assert.ok(c.messages.info.includes('Controller Aircon Sending: fan speed medium'));
  assert.ok(c.messages.debug.includes('Controller Aircon Controller confirmed: fan speed medium'));
  assert.deepEqual(c.messages.warn, []);
});

test('Auto sends legacy autoAA, accepts auto readback, and does not resend an equivalent Auto', async t => {
  const c = await setup(t);
  await c.fan('RotationSpeed').handleSetRequest(100, {});
  await c.advance(7200);
  assert.deepEqual(c.writes, [{ ac1: { info: { fan: 'autoAA' } } }]);
  assert.equal(await c.fan('RotationSpeed').handleGetRequest(), 100);
  await c.fan('RotationSpeed').handleSetRequest(100, {});
  await flush();
  assert.equal(c.writes.length, 1);
  assert.ok(c.messages.debug.some(line => line.includes('Already in requested state: fan speed autoAA')));
});

test('fan replacement and queued temperature preserve newest speed and independent controls', async t => {
  const c = await setup(t);
  await c.fan('RotationSpeed').handleSetRequest(50, {});
  await flush();
  await c.char('TargetTemperature').handleSetRequest(25, {});
  await c.fan('RotationSpeed').handleSetRequest(90, {});
  await c.advance(7200);
  assert.equal(await c.fan('RotationSpeed').handleGetRequest(), 90);
  await c.advance(14500);
  assert.equal(c.writes.length, 3);
  assert.deepEqual(c.writes[0], { ac1: { info: { fan: 'medium' } } });
  assert.equal(c.writes[1].ac1.info.setTemp, 25);
  assert.deepEqual(c.writes[2], { ac1: { info: { fan: 'high' } } });
  assert.equal(await c.fan('RotationSpeed').handleGetRequest(), 90);
  assert.deepEqual(c.messages.warn, []);
});

test('cached thermostat gains one stable fan service and shutdown refuses speed changes', async t => {
  const c = await setup(t, { cached: true });
  const service = c.accessory().getServiceById(c.api.hap.Service.Fan, 'fan-speed');
  await c.advance(30100);
  assert.equal(c.accessory(), c.cached);
  assert.equal(c.accessory().services.filter(s => s.UUID === c.api.hap.Service.Fan.UUID).length, 1);
  assert.equal(c.accessory().getServiceById(c.api.hap.Service.Fan, 'fan-speed'), service);
  c.api.emit('shutdown');
  await assert.rejects(c.fan('RotationSpeed').handleGetRequest(), unavailable(c));
  await assert.rejects(c.fan('RotationSpeed').handleSetRequest(90, {}), unavailable(c));
  assert.equal(c.writes.length, 0);
});

test('rejected fan command warns with speed, faults that control, and leaves thermostat readings available', async t => {
  const c = await setup(t);
  c.model.reject = true;
  await c.fan('RotationSpeed').handleSetRequest(90, {});
  await flush();
  await assert.rejects(c.fan('RotationSpeed').handleGetRequest(), unavailable(c));
  assert.equal(await c.char('TargetTemperature').handleGetRequest(), 24);
  assert.equal(c.messages.warn.length, 1);
  assert.match(c.messages.warn[0], /Fan command failed.*fan speed high.*rejected/);
});

test('fan transport refuses unknown speed and malformed address before sending', async t => {
  const c = await setup(t);
  const client = new AdvantageAirClient({ ipAddress: '192.0.2.1' });
  await assert.rejects(client.requestFanSpeed('ac1?other', 'low'));
  await assert.rejects(client.requestFanSpeed('ac1', 'turbo'));
  assert.equal(c.writes.length, 0);
});
