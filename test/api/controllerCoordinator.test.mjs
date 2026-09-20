import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { URL, pathToFileURL } from 'node:url';
import test from 'node:test';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';

const require = createRequire(import.meta.url);
const entry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', entry).href);
async function flush() {
  for (let i = 0; i < 60; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = {
    system: { mid: 'controller', hasAircons: true, noOfAircons: 1 },
    aircons: { ac1: {
      info: { uid: 'unit', myZone: 0, constant1: 1 },
      zones: Object.fromEntries(['z01', 'z02', 'z03'].map((key, i) => [key, {
        name: ['Living', 'Theatre', 'Bedroom'][i], number: i + 1, type: 1,
        state: 'open', error: 0, measuredTemp: 23 + i,
      }])),
    } },
  };
  const model = { delay: 6500, busy: true, readFailure: false, reject: false, ambiguous: false,
    never: false, readLatency: 0, ...options };
  let transition;
  let active = 0;
  let maximum = 0;
  const requests = [];
  const writes = [];
  const delay = (ms, signal) => new Promise((resolve, reject) => {
    let abort = () => {};
    const timer = globalThis.setTimeout(() => {
      signal.removeEventListener('abort', abort);
      resolve();
    }, ms);
    abort = () => {
      globalThis.clearTimeout(timer);
      reject(new Error('aborted'));
    };
    signal.addEventListener('abort', abort, { once: true });
  });
  const fetchStub = t.mock.method(globalThis, 'fetch', async (url, { signal }) => {
    active++;
    maximum = Math.max(active, maximum);
    requests.push({ path: url.pathname, at: Date.now() });
    try {
      if (url.pathname === '/setAircon') {
        const patch = JSON.parse(url.searchParams.get('json'));
        const [aircon, body] = Object.entries(patch)[0];
        const [zone, value] = Object.entries(body.zones)[0];
        writes.push({ aircon, zone, state: value.state, at: Date.now() });
        if (model.reject) {
          return { ok: true, text: async () => 'false' };
        }
        transition = { aircon, zone, state: value.state, due: Date.now() + model.delay };
        if (model.ambiguous) {
          throw new Error('private transport details');
        }
        return { ok: true, text: async () => '{}' };
      }
      if (model.readLatency) {
        await delay(model.readLatency, signal);
      }
      if (model.readFailure) {
        throw new Error('private response');
      }
      if (transition && Date.now() >= transition.due && !model.never) {
        data.aircons[transition.aircon].zones[transition.zone].state = transition.state;
        transition = undefined;
      }
      const body = transition && model.busy ? {} : globalThis.structuredClone(data);
      return { ok: true, text: async () => JSON.stringify(body) };
    } finally {
      active--;
    }
  });
  const api = new HomebridgeAPI();
  const messages = { info: [], warn: [], error: [], debug: [] };
  const log = Object.fromEntries(Object.keys(messages).map(level => [level,
    (...args) => messages[level].push(args.join(' ')),
  ]));
  const platform = new AdvantageAirPlatform(log, {
    platform: 'AdvantageAir', devices: [{ ipAddress: '192.0.2.1', name: 'Controller' }],
  }, api);
  t.after(() => api.emit('shutdown'));
  api.emit('didFinishLaunching');
  await flush();
  const advance = async ms => {
    for (let remaining = ms; remaining > 0;) {
      const step = Math.min(remaining, 10);
      t.mock.timers.tick(step);
      remaining -= step;
      await flush();
    }
  };
  const accessory = name => [...platform.accessories.values()].find(item => item.displayName === name);
  const on = (name = 'Bedroom') => accessory(`${name} Zone`).getService(api.hap.Service.Switch)
    .getCharacteristic(api.hap.Characteristic.On);
  return { api, platform, model, data, requests, writes, messages, advance, on, accessory, fetchStub,
    max: () => maximum };
}

test('full HAP write returns before slow confirmation; immediate reads retain requested state', async t => {
  const c = await setup(t);
  const on = c.on();
  const hap = c.accessory('Bedroom Zone')._associatedHAPAccessory;
  hap.aid = 1;
  on.iid = 10;
  const warnings = [];
  hap.on('characteristic-warning', warning => warnings.push(warning));
  let reply;
  hap.handleSetCharacteristics({}, { characteristics: [{ aid: 1, iid: 10, value: false }] },
    (error, response) => {
      assert.equal(error, undefined);
      reply = response;
    });
  await flush();
  assert.equal(reply.characteristics[0].status, 0);
  assert.equal(Date.now(), 1000);
  assert.equal(c.data.aircons.ac1.zones.z03.state, 'open');
  assert.equal(await on.handleGetRequest(), false);
  await c.advance(7100);
  assert.equal(c.data.aircons.ac1.zones.z03.state, 'close');
  assert.equal(await on.handleGetRequest(), false);
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.messages.warn, []);
  assert.deepEqual(warnings, []);
  assert.equal(c.max(), 1);
});

test('rapid reversal waits for the sent command and does not display its older completion', async t => {
  const c = await setup(t);
  await c.on().handleSetRequest(false);
  await flush();
  assert.equal(c.writes.length, 1);
  await c.on().handleSetRequest(true);
  await flush();
  assert.equal(await c.on().handleGetRequest(), true);
  await c.advance(7100);
  assert.deepEqual(c.writes.map(item => item.state), ['close', 'open']);
  assert.equal(await c.on().handleGetRequest(), true);
  assert.equal(c.on().value, true);
  await c.advance(7100);
  assert.equal(c.data.aircons.ac1.zones.z03.state, 'open');
  assert.deepEqual(c.messages.warn, []);
});

test('unsent reversals collapse to the latest intent without a physical write', async t => {
  const c = await setup(t);
  c.model.readLatency = 100;
  await c.on().handleSetRequest(false);
  await flush();
  await c.on().handleSetRequest(true);
  await c.advance(300);
  assert.equal(c.writes.length, 0);
  assert.equal(await c.on().handleGetRequest(), true);
});

test('multiple rooms execute fairly and confirmation updates temperature observations', async t => {
  const c = await setup(t, { delay: 1000 });
  await c.on('Bedroom').handleSetRequest(false);
  await flush();
  await c.on('Theatre').handleSetRequest(false);
  await c.on('Bedroom').handleSetRequest(true);
  c.data.aircons.ac1.zones.z03.measuredTemp = 28;
  await c.advance(4000);
  assert.deepEqual(c.writes.map(item => item.zone), ['z03', 'z02', 'z03']);
  assert.equal(c.max(), 1);
  const temperature = c.accessory('Bedroom Temperature').getService(c.api.hap.Service.TemperatureSensor)
    .getCharacteristic(c.api.hap.Characteristic.CurrentTemperature);
  assert.equal(await temperature.handleGetRequest(), 28);
});

test('myZone refusal is immediate, named and sends nothing', async t => {
  const c = await setup(t);
  c.data.aircons.ac1.info.myZone = 3;
  await c.advance(30000);
  await assert.rejects(c.on().handleSetRequest(false));
  assert.equal(c.writes.length, 0);
  assert.match(c.messages.warn[0], /Bedroom Zone.*Select another myZone/);
});

test('myZone is rechecked after admission before dispatch', async t => {
  const c = await setup(t);
  c.data.aircons.ac1.info.myZone = 3;
  await c.on().handleSetRequest(false);
  await flush();
  assert.equal(c.writes.length, 0);
  assert.match(c.messages.warn[0], /Select another myZone/);
  await assert.rejects(c.on().handleGetRequest());
});

test('constant zone closure does not change another zone or airflow settings', async t => {
  const c = await setup(t, { delay: 0 });
  await c.on('Living').handleSetRequest(false);
  await c.advance(1100);
  assert.deepEqual(c.writes.map(({ zone, state }) => ({ zone, state })), [{ zone: 'z01', state: 'close' }]);
  assert.equal(c.data.aircons.ac1.info.constant1, 1);
  assert.equal(c.data.aircons.ac1.zones.z02.state, 'open');
});

test('explicit rejection marks the zone unavailable and never retries the write', async t => {
  const c = await setup(t, { reject: true });
  await c.on().handleSetRequest(false);
  await flush();
  await assert.rejects(c.on().handleGetRequest());
  assert.match(c.messages.warn[0], /rejected/);
  await c.advance(30000);
  assert.equal(await c.on().handleGetRequest(), true);
  assert.equal(c.writes.length, 1);
});

test('ambiguous write reconciles through reads without resending', async t => {
  const c = await setup(t, { ambiguous: true });
  await c.on().handleSetRequest(false);
  await c.advance(7100);
  assert.equal(c.data.aircons.ac1.zones.z03.state, 'close');
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.messages.warn, []);
});

test('ambiguous write also waits through old but valid readings', async t => {
  const c = await setup(t, { ambiguous: true, busy: false });
  await c.on().handleSetRequest(false);
  await c.advance(7100);
  assert.equal(c.data.aircons.ac1.zones.z03.state, 'close');
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.messages.warn, []);
});

test('never-confirmed change expires and cancels dependent intentions', async t => {
  const c = await setup(t, { never: true });
  await c.on().handleSetRequest(false);
  await flush();
  await c.on('Theatre').handleSetRequest(false);
  await c.advance(15100);
  await assert.rejects(c.on().handleGetRequest());
  await assert.rejects(c.on('Theatre').handleGetRequest());
  assert.equal(c.writes.length, 1);
  assert.equal(c.messages.warn.length, 2);
  assert.equal(JSON.stringify(c.messages).includes('private'), false);
});

test('shutdown cancels work and does not replay accepted requests', async t => {
  const c = await setup(t);
  await c.on().handleSetRequest(false);
  await flush();
  await c.on('Theatre').handleSetRequest(false);
  const count = c.requests.length;
  c.api.emit('shutdown');
  await c.advance(40000);
  assert.equal(c.requests.length, count);
  assert.equal(c.writes.length, 1);
  await assert.rejects(c.on().handleGetRequest());
  await assert.rejects(c.on().handleSetRequest(true));
});

test('a changed controller identity cannot receive a queued write', async t => {
  const c = await setup(t);
  c.data.system.mid = 'replacement';
  await c.on().handleSetRequest(false);
  await flush();
  assert.equal(c.writes.length, 0);
  assert.match(c.messages.warn[0], /identity/);
});

test('ordinary polling is deferred during confirmation rather than warning on busy reads', async t => {
  const c = await setup(t);
  await c.advance(29000);
  await c.on().handleSetRequest(false);
  await c.advance(7100);
  assert.equal(c.requests.filter(item => item.at === 31000).length, 0);
  assert.deepEqual(c.messages.warn, []);
  assert.equal(c.max(), 1);
});

test('recorded 7.225-second trace confirms after HomeKit has already acknowledged admission', async t => {
  const c = await setup(t);
  const initial = globalThis.structuredClone(c.data);
  const confirmed = globalThis.structuredClone(c.data);
  confirmed.aircons.ac1.zones.z03.state = 'close';
  confirmed.aircons.ac1.zones.z03.measuredTemp = 28;
  const start = Date.now();
  const replies = [[257, initial], [279, {}], [1382, {}], [2509, {}], [3638, {}],
    [4776, {}], [5994, {}], [7225, confirmed]];
  const paths = [];
  c.fetchStub.mock.mockImplementation(async url => {
    const reply = replies[paths.length];
    assert.ok(reply, 'Unexpected extra request');
    paths.push(url.pathname);
    await new Promise(resolve => globalThis.setTimeout(resolve, Math.max(0, start + reply[0] - Date.now())));
    return { ok: true, text: async () => JSON.stringify(reply[1]) };
  });
  await c.on().handleSetRequest(false);
  assert.equal(Date.now(), start);
  await c.advance(7000);
  assert.equal(await c.on().handleGetRequest(), false);
  assert.deepEqual(c.messages.warn, []);
  await c.advance(300);
  const temperature = c.accessory('Bedroom Temperature').getService(c.api.hap.Service.TemperatureSensor)
    .getCharacteristic(c.api.hap.Characteristic.CurrentTemperature);
  assert.equal(await temperature.handleGetRequest(), 28, 'Confirmed snapshot reached the temperature manager too');
  assert.equal(await c.on().handleGetRequest(), false);
  assert.deepEqual(c.messages.warn, []);
  assert.equal(paths.filter(path => path === '/setAircon').length, 1);
  assert.equal(paths.length, 8);
});

test('late preflight completion cannot send after its operation deadline', async t => {
  const c = await setup(t);
  let release;
  t.mock.method(AdvantageAirClient.prototype, 'getFreshSystemData', () => new Promise(resolve => {
    release = resolve;
  }));
  await c.on().handleSetRequest(false);
  await flush();
  await c.advance(15100);
  await assert.rejects(c.on().handleGetRequest());
  release(c.data);
  await flush();
  assert.equal(c.writes.length, 0);
  assert.equal(c.messages.warn.length, 1);
});

test('shutdown during preflight prevents a late write even if the reader ignores cancellation', async t => {
  const c = await setup(t);
  let release;
  t.mock.method(AdvantageAirClient.prototype, 'getFreshSystemData', () => new Promise(resolve => {
    release = resolve;
  }));
  await c.on().handleSetRequest(false);
  await flush();
  c.api.emit('shutdown');
  release(c.data);
  await flush();
  assert.equal(c.writes.length, 0);
  assert.deepEqual(c.messages.warn, []);
});

test('queued intents expire without being sent after their acceptance lifetime', async t => {
  const c = await setup(t, { delay: 14000 });
  await c.on('Bedroom').handleSetRequest(false);
  await flush();
  await c.on('Theatre').handleSetRequest(false);
  await c.on('Living').handleSetRequest(false);
  await c.on('Bedroom').handleSetRequest(true);
  await c.advance(31000);
  assert.equal(c.writes.some(item => item.state === 'open'), false);
  assert.ok(c.writes.every(item => item.at < 31000));
  assert.ok(c.messages.warn.some(message => message.includes('expired')));
  assert.equal(new Set(c.messages.warn.map(message => message.split(':')[0])).size, c.messages.warn.length);
});

test('stale valid responses never count as confirmation and do not trigger write retries', async t => {
  const c = await setup(t, { never: true, busy: false });
  await c.on().handleSetRequest(false);
  await c.advance(15100);
  await assert.rejects(c.on().handleGetRequest());
  assert.equal(c.writes.length, 1);
  assert.equal(c.messages.warn.length, 1);
});

test('confirmation failure faults only the affected zone and recovers from a later poll', async t => {
  const c = await setup(t, { never: true, busy: false });
  await c.on().handleSetRequest(false);
  await c.advance(15100);
  assert.equal(await c.on('Living').handleGetRequest(), true);
  await assert.rejects(c.on().handleGetRequest());
  c.model.never = false;
  await c.advance(30000);
  assert.equal(await c.on().handleGetRequest(), false);
  assert.equal(c.writes.length, 1);
});

test('malformed confirmation is a fault rather than an unlimited busy retry', async t => {
  const c = await setup(t);
  await c.on().handleSetRequest(false);
  await flush();
  c.fetchStub.mock.mockImplementation(async () => ({ ok: true, text: async () => '{private' }));
  await c.advance(1100);
  await assert.rejects(c.on().handleGetRequest());
  assert.equal(c.messages.warn.length, 1);
  assert.equal(JSON.stringify(c.messages).includes('private'), false);
  assert.equal(c.writes.length, 1);
});

test('a slow HTTP preflight is aborted without ever sending a late write', async t => {
  const c = await setup(t);
  c.model.readLatency = 20000;
  await c.on().handleSetRequest(false);
  await c.advance(21000);
  assert.equal(c.writes.length, 0);
  assert.equal(c.messages.warn.length, 1);
  await assert.rejects(c.on().handleGetRequest());
});

test('admission has a fixed capacity and observer errors do not prevent stopping queued work', async t => {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = { system: { mid: 'controller' }, aircons: { ac1: {
    info: { uid: 'unit', myZone: 0 },
    zones: Object.fromEntries(Array.from({ length: 65 }, (_, i) => [`z${i + 1}`, {
      number: i + 1, type: 1, state: 'open',
    }])),
  } } };
  let writes = 0;
  const coordinator = new ControllerCoordinator({
    async getSystemData() {
      return data;
    },
    async getFreshSystemData() {
      return data;
    },
    async requestZoneState() {
      writes++;
    },
  }, () => {
    throw new Error('observer failure');
  }, () => {});
  t.after(() => coordinator.stop());
  coordinator.start();
  await flush();
  const identity = i => JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', `z${i}`]);
  for (let i = 1; i <= 64; i++) {
    coordinator.requestZone(identity(i), false);
  }
  assert.throws(() => coordinator.requestZone(identity(65), false), /Too many/);
  coordinator.stop();
  await flush();
  assert.equal(writes, 0);
});

test('stable identity resolves changed aircon addressing before writing', async t => {
  const c = await setup(t, { delay: 0 });
  c.data.aircons.ac2 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  await c.on().handleSetRequest(false);
  await c.advance(1100);
  assert.equal(c.writes.length, 1);
  assert.equal(c.writes[0].aircon, 'ac2');
  assert.equal(await c.on().handleGetRequest(), false);
  assert.equal(c.platform.accessories.size, 6);
});
