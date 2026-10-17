import assert from 'node:assert/strict';
import test from 'node:test';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';

const identity = JSON.stringify(['AdvantageAir', 'busy-controller', 'unit', 'aircon']);
const zone = key => JSON.stringify(['AdvantageAir', 'busy-controller', 'unit', 'zone', key]);

async function flush() {
  for (let i = 0; i < 80; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = {
    system: { mid: 'busy-controller', hasAircons: true, noOfAircons: 1 },
    aircons: { ac1: {
      info: { uid: 'unit', name: 'AC', state: 'on', mode: 'cool', fan: 'low', myZone: 1, setTemp: 24,
        countDownToOn: 0, countDownToOff: 0 },
      zones: {
        z01: { number: 1, name: 'Living', type: 1, state: 'open', setTemp: 24, error: 0, measuredTemp: 22 },
        z02: { number: 7, name: 'Bedroom', type: 1, state: 'close', setTemp: 23, error: 0, measuredTemp: 21 },
        z03: { number: 3, name: 'Percentage', type: 0, state: 'open', value: 40 },
      },
    } },
  };
  const model = { busyUntil: 0, error: '', writeBusy: 0, reject: false, ambiguous: false, ...options };
  const writes = [];
  const reads = [];
  const updates = [];
  const warnings = [];
  const events = [];
  const progress = [];
  t.mock.method(globalThis, 'fetch', async url => {
    if (url.pathname === '/setAircon') {
      const patch = JSON.parse(url.searchParams.get('json'));
      writes.push(patch);
      if (model.reject) {
        return { ok: true, text: async () => 'false' };
      }
      for (const [ac, value] of Object.entries(patch)) {
        Object.assign(data.aircons[ac].info, value.info);
        for (const [key, fields] of Object.entries(value.zones ?? {})) {
          Object.assign(data.aircons[ac].zones[key], fields);
        }
      }
      model.busyUntil = Date.now() + model.writeBusy;
      if (model.ambiguous) {
        throw new Error('Ambiguous write delivery');
      }
      return { ok: true, text: async () => '{}' };
    }
    assert.equal(url.pathname, '/getSystemData');
    reads.push(Date.now());
    model.onRead?.();
    if (model.error === 'connection') {
      throw new Error('Connection failed');
    }
    return {
      ok: model.error !== 'http', status: model.error === 'http' ? 503 : 200,
      text: async () => {
        if (model.error === 'body') {
          throw new Error('Body failed');
        }
        if (model.error === 'json') {
          return '{';
        }
        if (model.error === 'schema') {
          return '{"unexpected":true}';
        }
        if (model.error === 'incomplete') {
          return JSON.stringify({ system: data.system, aircons: {} });
        }
        return JSON.stringify(Date.now() < model.busyUntil ? {} : data);
      },
    };
  });
  const coordinator = new ControllerCoordinator(
    new AdvantageAirClient({ ipAddress: '192.0.2.1' }),
    (state, reason) => updates.push({ state: globalThis.structuredClone(state), reason }),
    message => warnings.push(message),
    event => events.push(event),
    undefined,
    event => {
      progress.push(event);
      model.onProgress?.(event);
    },
  );
  t.after(() => coordinator.stop());
  coordinator.start();
  await flush();
  const advance = async ms => {
    for (let left = ms; left > 0;) {
      const step = Math.min(left, 100);
      t.mock.timers.tick(step);
      left -= step;
      await flush();
    }
  };
  return { coordinator, data, model, writes, reads, updates, warnings, events, progress, advance };
}

const commands = [
  ['zone', c => c.requestZone(zone('z02'), true)],
  ['percentage On', c => c.requestPercentageZoneState(zone('z03'), false)],
  ['percentage value', c => c.requestZonePercentage(zone('z03'), 55)],
  ['thermostat mode', c => c.requestThermostatMode(identity, 'heat')],
  ['thermostat temperature', c => c.requestThermostatTemperature(identity, 25)],
  ['fan speed', c => c.requestFanSpeed(identity, 90)],
  ['ventilation', c => c.requestModeFan(identity, 'vent', true)],
  ['dry', c => c.requestModeFan(identity, 'dry', true)],
  ['timer', c => c.requestTimer(identity, true, 2700)],
];

for (const [name, request] of commands) {
  test(`${name}: busy preflight waits for fresh addressing then dispatches exactly once`, async t => {
    const c = await setup(t);
    c.model.busyUntil = Date.now() + 4000;
    request(c.coordinator);
    await flush();
    await c.advance(3900);
    assert.equal(c.writes.length, 0);
    c.data.aircons.ac9 = c.data.aircons.ac1;
    delete c.data.aircons.ac1;
    await c.advance(1200);
    assert.equal(c.writes.length, 1);
    assert.deepEqual(Object.keys(c.writes[0]), ['ac9']);
    assert.equal(c.events[0].outcome, 'confirmed');
    assert.deepEqual(c.warnings, []);
    assert.equal(c.updates.some(update => update.reason === 'failure'), false);
  });
}

test('busy preflight replans an externally satisfied timer as unchanged without a write', async t => {
  const c = await setup(t);
  c.model.busyUntil = Date.now() + 4000;
  c.coordinator.requestTimer(identity, true, 2700);
  await flush();
  c.data.aircons.ac1.info.countDownToOff = 45;
  await c.advance(4100);
  assert.deepEqual(c.writes, []);
  assert.equal(c.events[0].outcome, 'unchanged');
  assert.deepEqual(c.warnings, []);
});

test('persistent preflight busy expires at the existing 15-second deadline without a late write', async t => {
  const c = await setup(t);
  c.model.busyUntil = Infinity;
  c.coordinator.requestFanSpeed(identity, 90);
  await flush();
  await c.advance(14900);
  assert.deepEqual(c.warnings, []);
  await c.advance(100);
  assert.equal(c.warnings.length, 1);
  assert.match(c.warnings[0], /expired/);
  const attempts = c.reads.length;
  c.model.busyUntil = 0;
  await c.advance(4000);
  assert.equal(c.reads.length, attempts);
  assert.deepEqual(c.writes, []);
});

for (const kind of ['shared', 'MyZone']) {
  test(`${kind}: supersession during busy preflight cannot dispatch the obsolete selection`, async t => {
    const c = await setup(t);
    c.model.busyUntil = Date.now() + 4000;
    if (kind === 'shared') {
      c.coordinator.requestFanSpeed(identity, 90);
    } else {
      c.coordinator.requestMyZoneSelection(identity, zone('z02'));
    }
    await flush();
    await c.advance(1500);
    if (kind === 'shared') {
      c.coordinator.requestFanSpeed(identity, 25);
    } else {
      c.coordinator.requestMyZoneSelection(identity, zone('z01'));
    }
    await c.advance(4000);
    assert.deepEqual(c.writes, []);
    assert.equal(c.events.length, 1);
    assert.equal(c.events[0].outcome, 'unchanged');
    assert.deepEqual(c.warnings, []);
  });

  test(`${kind}: shutdown during busy preflight prevents further reads and writes`, async t => {
    const c = await setup(t);
    c.model.busyUntil = Infinity;
    if (kind === 'shared') {
      c.coordinator.requestFanSpeed(identity, 90);
    } else {
      c.coordinator.requestMyZoneSelection(identity, zone('z02'));
    }
    await flush();
    await c.advance(1100);
    c.coordinator.stop();
    const attempts = c.reads.length;
    c.model.busyUntil = 0;
    await c.advance(20000);
    assert.equal(c.reads.length, attempts);
    assert.deepEqual(c.writes, []);
    assert.deepEqual(c.warnings, []);
  });
}

test('MyZone busy between confirmed steps continues without replay and replans fresh addresses/target', async t => {
  const c = await setup(t);
  c.model.onProgress = event => {
    if (event.outcome !== 'confirmed') {
      return;
    }
    if (event.step === 'open') {
      c.data.aircons.ac9 = c.data.aircons.ac1;
      delete c.data.aircons.ac1;
      c.model.busyUntil = Date.now() + 4000;
    } else if (event.step === 'select') {
      c.data.aircons.ac9.zones.z02.setTemp = 22;
      c.model.busyUntil = Date.now() + 4000;
    }
  };
  c.coordinator.requestMyZoneSelection(identity, zone('z02'));
  await c.advance(12000);
  assert.deepEqual(c.writes, [
    { ac1: { zones: { z02: { state: 'open' } } } },
    { ac9: { info: { myZone: 7 } } },
    { ac9: { info: { setTemp: 22 } } },
  ]);
  assert.deepEqual(c.progress.filter(p => p.outcome === 'confirmed').map(p => p.step), ['open', 'select', 'target']);
  assert.equal(c.events[0].outcome, 'confirmed');
  assert.deepEqual(c.warnings, []);
});

test('MyZone busy between steps expires on the original budget, retaining confirmed partial progress', async t => {
  const c = await setup(t);
  c.model.onProgress = event => {
    if (event.step === 'open' && event.outcome === 'confirmed') {
      c.model.busyUntil = Infinity;
    }
  };
  c.coordinator.requestMyZoneSelection(identity, zone('z02'));
  await flush();
  await c.advance(14900);
  assert.deepEqual(c.warnings, []);
  await c.advance(100);
  assert.match(c.warnings[0], /select step failed.*Earlier confirmed steps: open.*no rollback/);
  assert.equal(c.writes.length, 1);
  assert.equal(c.updates.filter(u => u.reason === 'read').at(-1).state.data.aircons.ac1.zones.z02.state, 'open');
  c.model.busyUntil = 0;
  await c.advance(4000);
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.events, []);
});

test('MyZone still refuses a changed reported number after busy inter-step reads', async t => {
  const c = await setup(t);
  c.model.onProgress = event => {
    if (event.step === 'open' && event.outcome === 'confirmed') {
      c.model.busyUntil = Date.now() + 4000;
      c.data.aircons.ac1.zones.z02.number = 9;
    }
  };
  c.coordinator.requestMyZoneSelection(identity, zone('z02'));
  await c.advance(6000);
  assert.equal(c.writes.length, 1);
  assert.match(c.warnings[0], /number changed after dispatch/);
});

test('startup busy recovers in the same poll without a failure/recovery period', async t => {
  const c = await setup(t, { busyUntil: 5000 });
  assert.equal(c.updates.length, 0);
  await c.advance(4100);
  assert.deepEqual(c.updates.map(u => u.reason), ['read']);
  assert.equal(c.updates[0].state.lastAttemptFailed, false);
  assert.equal(c.reads.length, 5);
  assert.equal(c.coordinator.readFanSpeed(identity), 25);
});

test('ordinary busy poll retains data during retries then publishes without a failure event', async t => {
  const c = await setup(t);
  c.model.busyUntil = Date.now() + 34000;
  await c.advance(33000);
  assert.equal(c.updates.length, 1);
  assert.equal(c.coordinator.readFanSpeed(identity), 25);
  await c.advance(1100);
  assert.deepEqual(c.updates.map(u => u.reason), ['read', 'read']);
});

for (const startup of [true, false]) {
  test(`${startup ? 'startup' : 'ordinary'} persistent busy poll fails at 10 seconds and retains last-good data`, async t => {
    const c = await setup(t, startup ? { busyUntil: Infinity } : {});
    c.model.busyUntil = Infinity;
    if (!startup) {
      await c.advance(30000);
    }
    await c.advance(9900);
    assert.equal(c.updates.some(u => u.reason === 'failure'), false);
    await c.advance(100);
    assert.equal(c.updates.at(-1).reason, 'failure');
    assert.equal(c.updates.at(-1).state.lastAttemptFailed, true);
    assert.equal(!!c.updates.at(-1).state.data, !startup);
    const attempts = c.reads.length;
    c.model.busyUntil = 0;
    await c.advance(29900);
    assert.equal(c.reads.length, attempts);
    await c.advance(100);
    assert.equal(c.updates.at(-1).reason, 'read');
  });
}

for (const error of ['json', 'schema', 'incomplete', 'http', 'connection', 'body']) {
  test(`${error} read failures are not busy-retried in polling, shared preflight or MyZone`, async t => {
    const c = await setup(t);
    c.model.error = error;
    c.coordinator.requestFanSpeed(identity, 90);
    await flush();
    assert.equal(c.reads.length, 2);
    assert.equal(c.warnings.length, 1);
    c.coordinator.requestMyZoneSelection(identity, zone('z02'));
    await flush();
    assert.equal(c.reads.length, 3);
    assert.equal(c.warnings.length, 2);
    await c.advance(30000);
    assert.equal(c.reads.length, 4);
    assert.equal(c.updates.at(-1).reason, 'failure');
    await c.advance(5000);
    assert.equal(c.reads.length, 4);
    assert.deepEqual(c.writes, []);
  });
}

test('busy preflight then ambiguous delivery confirms by reads without repeating the physical write', async t => {
  const c = await setup(t, { ambiguous: true, writeBusy: 4000 });
  c.model.busyUntil = Date.now() + 4000;
  c.coordinator.requestFanSpeed(identity, 90);
  await c.advance(10000);
  assert.equal(c.writes.length, 1);
  assert.equal(c.events[0].outcome, 'confirmed');
  assert.deepEqual(c.warnings, []);
});

test('busy preflight does not convert explicit command rejection into a retry', async t => {
  const c = await setup(t, { reject: true });
  c.model.busyUntil = Date.now() + 4000;
  c.coordinator.requestFanSpeed(identity, 90);
  await c.advance(6000);
  assert.equal(c.writes.length, 1);
  assert.match(c.warnings[0], /rejected/);
  assert.deepEqual(c.events, []);
});
