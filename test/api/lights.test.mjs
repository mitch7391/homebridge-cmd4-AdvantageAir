import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { createRequire } from 'node:module';
import { pathToFileURL, URL, URLSearchParams } from 'node:url';
import { lightPayload, observeLights } from '../../dist/api/lightCommand.js';
import { validateSystemData } from '../../dist/api/systemData.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { AdvantageAirPlatform } from '../../dist/platform.js';

const require = createRequire(import.meta.url);
const { HomebridgeAPI } = await import(new URL('./api.js', pathToFileURL(require.resolve('homebridge'))).href);
const fixture = file => JSON.parse(fs.readFileSync(new URL(`../../dev/lab/fixtures/${file}`, import.meta.url)));
const small = () => fixture('lights-small.json');
const identity = id => JSON.stringify(['AdvantageAir', 'fixture-controller', 'light', id]);
async function flush() {
  for (let i = 0; i < 90; i++) {
    await Promise.resolve();
  }
}

test('historical-derived fixtures preserve four dimmers and the 98-output 49/49 mixture', () => {
  assert.equal(observeLights(validateSystemData(small())).length, 4);
  const lights = observeLights(validateSystemData(fixture('lights-large.json')));
  assert.equal(lights.length, 98);
  assert.equal(lights.filter(l => l.capability === 'dimmer').length, 49);
  assert.equal(lights.filter(l => l.capability === 'relay').length, 49);
  assert.equal(new Set(lights.map(l => l.identity)).size, 98);
  assert.ok(lights.some(l => !l.on && l.brightness > 0));
});

test('light parser isolates malformed entries, identity mismatches and capability contradictions', () => {
  const d = small();
  Object.assign(d.myLights.lights, {
    bad: { id: 'different', state: 'on' }, duplicate: { id: 'l000001', state: 'on' },
    invalid: { id: 'invalid', state: 'unknown' },
    conflict: { id: 'conflict', state: 'on', relay: true, value: 50 },
    wrong: { id: 'wrong', state: 'off', value: '50' },
    malformed: null,
  });
  const warnings = [];
  assert.equal(observeLights(d, m => warnings.push(m)).length, 4);
  assert.equal(warnings.length, 6);
  d.myLights.lights.l000001.name = '';
  assert.equal(observeLights(d)[0].name, 'Light l000001');
  delete d.myLights;
  assert.deepEqual(observeLights(d), []);
  assert.throws(() => validateSystemData({}));
  assert.throws(() => validateSystemData({ system: { hasAircons: false, noOfAircons: 0 } }));
});

test('historical light wire contract and exact URL encoding, independent On and brightness', async t => {
  const urls = [];
  t.mock.method(globalThis, 'fetch', async url => {
    urls.push(url.href); return { ok: true, text: async () => '{}' };
  });
  const client = new AdvantageAirClient({ ipAddress: '127.0.0.1' });
  for (const [field, value, payload] of [
    ['state', true, '{id:"l000001",state:on}'], ['state', false, '{id:"l000001",state:off}'],
    ['value', 80, '{id:"l000001",value:80}'], ['value', 0, '{id:"l000001",value:0}'],
  ]) {
    assert.equal(lightPayload('l000001', field, value), payload);
    await client.requestLight('l000001', field, value);
    assert.equal(urls.at(-1), `http://127.0.0.1:2025/setLight?json=${new URLSearchParams({ json: payload }).toString().slice(5)}`);
  }
  assert.equal(urls[0], 'http://127.0.0.1:2025/setLight?json=%7Bid%3A%22l000001%22%2Cstate%3Aon%7D');
  for (const id of ['a"b', '../x', '', 'a,b']) {
    assert.throws(() => lightPayload(id, 'state', true));
  }
  for (const n of [-1, 101, NaN, 1.5, '20']) {
    assert.throws(() => lightPayload('a', 'value', n));
  }
});

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = options.data ?? small();
  const model = { reject: false, ambiguous: false, never: false, busy: false, fail: false, readHook: undefined };
  let pending;
  const writes = [];
  let active = 0; let maximum = 0;
  t.mock.method(globalThis, 'fetch', async url => {
    active++; maximum = Math.max(maximum, active);
    try {
      if (url.pathname === '/setAircon') {
        const patch = JSON.parse(url.searchParams.get('json'));
        writes.push({ aircon: patch });
        for (const [id, body] of Object.entries(patch)) {
          Object.assign(data.aircons[id].info, body.info ?? {});
          for (const [zoneId, values] of Object.entries(body.zones ?? {})) {
            Object.assign(data.aircons[id].zones[zoneId], values);
          }
        }
        return { ok: true, text: async () => '{}' };
      }
      if (url.pathname === '/setLight') {
        const raw = url.searchParams.get('json');
        const match = /^\{id:"([a-zA-Z0-9_-]+)",(state|value):(on|off|\d+)\}$/.exec(raw);
        assert.ok(match, raw);
        const [, id, field, value] = match;
        writes.push({ id, field, value });
        if (model.reject) {
          return { ok: true, text: async () => 'false' };
        }
        pending = { id, field, value, due: Date.now() + 500 };
        if (model.ambiguous) {
          throw new Error('Ambiguous delivery');
        }
        return { ok: true, text: async () => '{}' };
      }
      model.readHook?.();
      if (model.fail) {
        throw new Error('Read failed');
      }
      if (pending && Date.now() >= pending.due && !model.never) {
        const l = data.myLights.lights[pending.id];
        l[pending.field] = pending.field === 'value' ? Number(pending.value) : pending.value;
        pending = undefined;
      }
      return { ok: true, text: async () => JSON.stringify(model.busy ? {} : data) };
    } finally {
      active--;
    }
  });
  const api = new HomebridgeAPI();
  const messages = [];
  const log = Object.fromEntries(['info', 'warn', 'error', 'debug'].map(k => [k, (...v) => messages.push(v.join(' '))]));
  const registered = []; const removed = [];
  t.mock.method(api, 'registerPlatformAccessories', (p, n, a) => registered.push(...a));
  t.mock.method(api, 'unregisterPlatformAccessories', (p, n, a) => removed.push(...a));
  const platform = new AdvantageAirPlatform(log, { platform: 'AdvantageAir', devices: options.devices ?? [
    { ipAddress: '192.0.2.1', excludedLightIds: options.exclude ?? [] },
  ] }, api);
  for (const a of options.cached ?? []) {
    platform.configureAccessory(a);
  }
  t.after(() => api.emit('shutdown'));
  const advance = async ms => {
    for (let elapsed = 0; elapsed < ms; elapsed += 100) {
      t.mock.timers.tick(100); await flush();
    }
  };
  api.emit('didFinishLaunching'); await flush();
  const accessory = id => platform.accessories.get(api.hap.uuid.generate(identity(id)));
  const characteristic = (id, key) => accessory(id).getService(api.hap.Service.Lightbulb).getCharacteristic(api.hap.Characteristic[key]);
  return { api, platform, data, model, writes, registered, removed, messages, advance, accessory, characteristic, maximum: () => maximum };
}

test('automatic lights-only discovery, exclusions, initial state and stable naming', async t => {
  const c = await setup(t, { exclude: ['l000002'] });
  assert.equal(c.registered.length, 3);
  assert.equal(c.accessory('l000002'), undefined);
  const a = c.accessory('l000001'); const service = a.getService(c.api.hap.Service.Lightbulb);
  assert.equal(await c.characteristic('l000001', 'On').handleGetRequest(), false);
  assert.equal(await c.characteristic('l000001', 'Brightness').handleGetRequest(), 50);
  c.data.myLights.lights.l000001.name = 'Renamed';
  c.data.myLights.lights.l000001.state = 'on';
  await c.advance(30100);
  assert.equal(c.accessory('l000001'), a);
  assert.equal(a.getService(c.api.hap.Service.Lightbulb), service);
  assert.equal(a.displayName, 'Renamed');
  assert.equal(await c.characteristic('l000001', 'On').handleGetRequest(), true);
});

test('On, Off and Brightness use separate ordered intentions; repeated unsent values coalesce', async t => {
  const c = await setup(t);
  const on = c.characteristic('l000001', 'On'); const brightness = c.characteristic('l000001', 'Brightness');
  await brightness.handleSetRequest(80, {});
  await brightness.handleSetRequest(80, {});
  await on.handleSetRequest(true, {});
  await c.advance(2500);
  assert.deepEqual(c.writes, [{ id: 'l000001', field: 'value', value: '80' }, { id: 'l000001', field: 'state', value: 'on' }]);
  await on.handleSetRequest(false, {}); await c.advance(1200);
  assert.equal(c.data.myLights.lights.l000001.value, 80);
  assert.equal(c.data.myLights.lights.l000001.state, 'off');
  await brightness.handleSetRequest(0, {}); await c.advance(1200);
  assert.equal(c.data.myLights.lights.l000001.state, 'off');
  assert.equal(c.maximum(), 1);
});

test('capability and identity persist through missing value, missing collection and contradictions', async t => {
  const c = await setup(t); const a = c.accessory('l000001');
  delete c.data.myLights.lights.l000001.value;
  await c.advance(30100);
  assert.equal(a.context.lightDimmer, true);
  await assert.rejects(c.characteristic('l000001', 'Brightness').handleGetRequest());
  assert.equal(await c.characteristic('l000001', 'On').handleGetRequest(), false);
  c.data.myLights.lights.l000001.relay = true;
  await c.advance(30100);
  await assert.rejects(c.characteristic('l000001', 'On').handleGetRequest());
  delete c.data.myLights.lights.l000001.relay;
  c.data.myLights.lights.l000001.value = 60;
  await c.advance(30100);
  assert.equal(await c.characteristic('l000001', 'Brightness').handleGetRequest(), 60);
  const saved = c.data.myLights; delete c.data.myLights;
  await c.advance(30100);
  await assert.rejects(c.characteristic('l000001', 'On').handleGetRequest());
  c.data.myLights = saved;
  await c.advance(30100);
  assert.equal(c.accessory('l000001'), a);
  assert.equal(c.removed.length, 0);
});

for (const mode of ['reject', 'ambiguous', 'never']) {
  test(`light write ${mode}: no unsafe resend`, async t => {
    const c = await setup(t); c.model[mode] = true;
    await c.characteristic('l000001', 'On').handleSetRequest(true, {});
    await c.advance(16000);
    assert.equal(c.writes.length, 1);
    if (mode === 'ambiguous') {
      assert.equal(await c.characteristic('l000001', 'On').handleGetRequest(), true);
    } else {
      await assert.rejects(c.characteristic('l000001', 'On').handleGetRequest());
      assert.ok(c.messages.some(m => m.includes('Light command failed')));
    }
  });
}

test('busy preflight waits, shutdown cancels queued commands', async t => {
  const c = await setup(t); c.model.busy = true;
  await c.characteristic('l000001', 'On').handleSetRequest(true, {});
  await c.advance(1500); assert.equal(c.writes.length, 0);
  c.model.busy = false; await c.advance(2500); assert.equal(c.writes.length, 1);
  c.model.busy = true;
  await c.characteristic('l000002', 'On').handleSetRequest(true, {});
  c.api.emit('shutdown'); c.model.busy = false; await c.advance(4000);
  assert.equal(c.writes.length, 1);
});

test('lights-only duplicate controller addresses cannot take over handlers', async t => {
  const c = await setup(t, { devices: [{ ipAddress: '192.0.2.1' }, { ipAddress: '192.0.2.2' }] });
  assert.equal(c.registered.length, 4);
  assert.ok(c.messages.some(m => m.includes('Duplicate controller identity')));
});

test('98-output discovery and bounded burst retain queue safeguards', async t => {
  const c = await setup(t, { data: fixture('lights-large.json') });
  assert.equal(c.registered.length, 98);
  // Hold preflight busy so all admissions exercise the unchanged 64-intention cap.
  c.model.busy = true;
  let accepted = 0; let refused = 0;
  for (const id of Object.keys(c.data.myLights.lights)) {
    try {
      await c.characteristic(id, 'On').handleSetRequest(true, {}); accepted++;
    } catch {
      refused++;
    }
  }
  assert.equal(accepted, 64); assert.equal(refused, 34);
  await c.advance(31000);
  assert.equal(c.writes.length, 0);
  c.model.busy = false; await c.advance(31000);
  await c.characteristic('l000001', 'On').handleSetRequest(true, {});
  await c.advance(1500);
  assert.equal(c.writes.length, 1);
});

test('cached restart retains dimmer service, context and identity across IP/name changes', async t => {
  const first = await setup(t);
  const cached = [...first.platform.accessories.values()];
  const services = cached.map(a => [...a.services]);
  first.api.emit('shutdown');
  t.mock.restoreAll(); t.mock.timers.reset();
  const data = small(); data.myLights.lights.l000001.name = 'Updated name';
  const second = await setup(t, { data, cached, devices: [{ ipAddress: '192.0.2.99' }] });
  assert.equal(second.registered.length, 0);
  assert.equal(second.accessory('l000001'), cached[0]);
  assert.equal(cached[0].displayName, 'Updated name');
  assert.equal(cached[0].context.lightDimmer, true);
  assert.deepEqual(cached.map(a => a.services), services);
  assert.equal(await second.characteristic('l000001', 'Brightness').handleGetRequest(), 50);
});

test('cached exclusion removes only explicitly excluded light even if its entry is absent', async t => {
  const first = await setup(t);
  const cached = [...first.platform.accessories.values()];
  first.api.emit('shutdown'); t.mock.restoreAll(); t.mock.timers.reset();
  const data = small(); delete data.myLights.lights.l000001;
  const c = await setup(t, { data, cached, exclude: ['l000001'] });
  assert.equal(c.removed.length, 1);
  assert.equal(c.accessory('l000001'), undefined);
  assert.equal(c.platform.accessories.size, 3);
});

test('missing entry and stale controller cannot serve fabricated Off; recovery restores state', async t => {
  const c = await setup(t);
  const saved = c.data.myLights.lights.l000001;
  delete c.data.myLights.lights.l000001;
  await c.advance(30100);
  await assert.rejects(c.characteristic('l000001', 'On').handleGetRequest());
  c.data.myLights.lights.l000001 = saved;
  await c.advance(30100);
  c.model.fail = true; await c.advance(91000);
  await assert.rejects(c.characteristic('l000001', 'On').handleGetRequest());
  c.model.fail = false; await c.advance(30100);
  assert.equal(await c.characteristic('l000001', 'On').handleGetRequest(), false);
});

test('unknown capability can acquire Brightness once, but a malformed individual output leaves healthy outputs usable', async t => {
  const data = small(); delete data.myLights.lights.l000001.value;
  const c = await setup(t, { data }); const a = c.accessory('l000001');
  const service = a.getService(c.api.hap.Service.Lightbulb);
  assert.equal(service.testCharacteristic(c.api.hap.Characteristic.Brightness), false);
  c.data.myLights.lights.l000001.value = 20;
  c.data.myLights.lights.l000002.state = 'invalid';
  await c.advance(30100);
  assert.equal(c.accessory('l000001'), a);
  assert.equal(service.testCharacteristic(c.api.hap.Characteristic.Brightness), true);
  assert.equal(await c.characteristic('l000001', 'Brightness').handleGetRequest(), 20);
  await assert.rejects(c.characteristic('l000002', 'On').handleGetRequest());
});

test('preflight capability contradiction prevents a queued physical write', async t => {
  const c = await setup(t);
  c.model.readHook = () => {
    delete c.data.myLights.lights.l000001.value;
    c.data.myLights.lights.l000001.relay = true;
  };
  await c.characteristic('l000001', 'On').handleSetRequest(true, {});
  await c.advance(1500);
  assert.equal(c.writes.length, 0);
});

test('small light burst and interleaved thermostat command share serialization without AC starvation', async t => {
  const data = fixture('myzone.json');
  data.myLights = small().myLights; data.system.mid = 'fixture-controller';
  const c = await setup(t, { data });
  const thermostat = [...c.platform.accessories.values()].find(a => a.displayName === 'Aircon');
  assert.ok(thermostat);
  await c.characteristic('l000001', 'On').handleSetRequest(true, {});
  await c.characteristic('l000002', 'On').handleSetRequest(true, {});
  await thermostat.getService(c.api.hap.Service.Thermostat)
    .getCharacteristic(c.api.hap.Characteristic.TargetTemperature).handleSetRequest(25, {});
  await c.characteristic('l000003', 'On').handleSetRequest(true, {});
  await c.advance(6000);
  assert.equal(c.writes.length, 4, JSON.stringify({ writes: c.writes, messages: c.messages }));
  assert.ok(c.writes[2].aircon);
  assert.equal(c.maximum(), 1);
  assert.equal(c.data.aircons.ac1.info.setTemp, 25);
  for (const id of ['l000001', 'l000002', 'l000003']) {
    assert.equal(c.data.myLights.lights[id].state, 'on');
  }
});

test('bounded mixed-output burst completes in order while large scenes expire safely', async t => {
  const data = fixture('lights-large.json');
  for (const light of Object.values(data.myLights.lights)) {
    light.state = 'off';
  }
  const c = await setup(t, { data });
  const ids = Object.keys(data.myLights.lights);
  for (const id of ids.slice(0, 12)) {
    await c.characteristic(id, 'On').handleSetRequest(true, {});
  }
  await c.advance(13000);
  assert.deepEqual(c.writes.map(write => write.id), ids.slice(0, 12));
  for (const id of ids.slice(0, 12)) {
    assert.equal(await c.characteristic(id, 'On').handleGetRequest(), true);
  }
  // Deliberately overload the unchanged queue; do not promise whole-house scene completion.
  for (const light of Object.values(data.myLights.lights)) {
    light.state = 'off';
  }
  await c.advance(30100);
  let refused = 0;
  for (const id of ids) {
    try {
      await c.characteristic(id, 'On').handleSetRequest(true, {});
    } catch {
      refused++;
    }
  }
  await c.advance(32000);
  assert.equal(refused, 34);
  assert.ok(c.writes.length > 12 && c.writes.length < 76);
  assert.ok(c.messages.some(message => /expired/.test(message)));
  assert.equal(c.maximum(), 1);
  assert.ok(c.writes.every(write => ids.includes(write.id)));
  assert.equal(new Set(c.writes.slice(12).map(write => write.id)).size, c.writes.length - 12);
});
