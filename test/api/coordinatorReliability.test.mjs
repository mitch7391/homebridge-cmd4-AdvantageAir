import '../helpers/coordinatorClock.mjs';
import assert from 'node:assert/strict';
import test from 'node:test';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';

const zone = key => JSON.stringify(['AdvantageAir', 'reliability-controller', 'unit', 'zone', key]);
const identity = JSON.stringify(['AdvantageAir', 'reliability-controller', 'unit', 'aircon']);
const light = id => JSON.stringify(['AdvantageAir', 'reliability-controller', 'light', id]);

async function flush() {
  for (let i = 0; i < 100; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = {
    system: { mid: 'reliability-controller', hasAircons: true, noOfAircons: 1 },
    aircons: { ac1: {
      info: { uid: 'unit', name: 'AC', state: 'on', mode: 'cool', fan: 'low', myZone: 0, constant1: 8, setTemp: 24 },
      zones: Object.fromEntries(Array.from({ length: 8 }, (_, i) => [`z0${i + 1}`, {
        number: i + 1, name: `Zone ${i + 1}`, type: 1, state: 'open', error: 0, measuredTemp: 22, setTemp: 24,
      }])),
    } },
  };
  data.myLights = { lights: Object.fromEntries(Array.from({ length: 30 }, (_, i) => {
    const id = `l${String(i + 1).padStart(6, '0')}`;
    return [id, { id, name: `Light ${i + 1}`, state: 'off', value: 100 }];
  })) };
  const model = { delay: 7000, busy: true, busyUntil: 0, readDelays: [], errors: [], ...options };
  const writes = [];
  const events = [];
  const warnings = [];
  const reads = [];
  let transition;
  const pause = (ms, signal) => new Promise((resolve, reject) => {
    let abort = () => {};
    const timer = globalThis.setTimeout(() => {
      signal.removeEventListener('abort', abort); resolve();
    }, ms);
    abort = () => {
      globalThis.clearTimeout(timer); reject(new Error('Cancelled'));
    };
    signal.addEventListener('abort', abort, { once: true });
  });
  const transport = async (url, { signal }) => {
    if (url.pathname === '/setAircon' || url.pathname === '/setLight') {
      let patch;
      if (url.pathname === '/setAircon') {
        patch = JSON.parse(url.searchParams.get('json'));
      } else {
        const match = /^\{id:"([a-zA-Z0-9_-]+)",(state|value):(on|off|\d+)\}$/.exec(url.searchParams.get('json'));
        assert.ok(match);
        patch = { light: { id: match[1], field: match[2], value: match[2] === 'value' ? Number(match[3]) : match[3] } };
      }
      writes.push({ patch, at: Date.now(), signal });
      model.onWrite?.(writes.length);
      if (model.reject) {
        return { ok: true, text: async () => 'false' };
      }
      transition = { patch, at: Date.now() + (model.delays?.shift() ?? model.delay) };
      if (model.writeDelay) {
        await pause(model.writeDelay, signal);
      }
      if (model.ambiguous) {
        throw new Error('Private write details');
      }
      return { ok: true, text: async () => '{}' };
    }
    assert.equal(url.pathname, '/getSystemData');
    reads.push(Date.now());
    const delay = model.readDelays.shift();
    if (delay) {
      await pause(delay, signal);
    }
    const error = model.errors.shift();
    if (error) {
      throw error;
    }
    if (transition && Date.now() >= transition.at && !model.never) {
      if (transition.patch.light) {
        const { id, field, value } = transition.patch.light;
        data.myLights.lights[id][field] = value;
      } else {
        for (const [ac, patch] of Object.entries(transition.patch)) {
          Object.assign(data.aircons[ac].info, patch.info);
          for (const [key, values] of Object.entries(patch.zones ?? {})) {
            Object.assign(data.aircons[ac].zones[key], values);
          }
        }
      }
      transition = undefined;
    }
    return { ok: true, text: async () => model.malformed ? '{private' : JSON.stringify(
      transition && model.busy || Date.now() < model.busyUntil ? {} : data) };
  };
  const fetchStub = t.mock.method(globalThis, 'fetch', transport);
  const client = new AdvantageAirClient({ ipAddress: '192.0.2.1' });
  const coordinator = new ControllerCoordinator(client,
    () => {}, message => warnings.push(message), event => {
      events.push(event); model.onConfirmed?.(event);
    },
    () => model.onSending?.());
  t.after(() => coordinator.stop());
  coordinator.start();
  await flush();
  const advance = async ms => {
    await flush();
    for (let remaining = ms; remaining > 0;) {
      const step = Math.min(remaining, 100);
      t.mock.timers.tick(step);
      remaining -= step;
      await flush();
    }
  };
  return { coordinator, client, data, model, writes, reads, events, warnings, advance, transport, fetchStub };
}

for (const delay of [5000, 7000, 9000]) {
  test(`five zones admitted one second apart all confirm with ${delay / 1000}-second readback`, async t => {
    const c = await setup(t, { delay });
    for (let i = 1; i <= 5; i++) {
      c.coordinator.requestZone(zone(`z0${i}`), false);
      await c.advance(1000);
    }
    await c.advance(50000);
    assert.deepEqual(c.warnings, [], 'Healthy burst must not expire while waiting or reconciling');
    assert.equal(c.events.filter(event => event.outcome === 'confirmed').length, 5);
    assert.deepEqual(c.writes.map(write => Object.keys(write.patch.ac1.zones)[0]), ['z01', 'z02', 'z03', 'z04', 'z05']);
    for (let i = 1; i <= 5; i++) {
      assert.equal(c.coordinator.readZone(zone(`z0${i}`)), false);
    }
  });
}

test('selection at 59 seconds retains nine seconds of preflight and 29 seconds of confirmation', async t => {
  const c = await setup(t, { delays: [29000, 29000, 1000, 29000] });
  const admitted = Date.now();
  c.model.onConfirmed = () => {
    if (c.events.length === 3) {
      c.model.readDelays.push(9000);
    }
  };
  for (let i = 1; i <= 4; i++) {
    c.coordinator.requestZone(zone(`z0${i}`), false);
  }
  await c.advance(97500);
  assert.deepEqual(c.writes.map(write => write.at - admitted), [0, 29000, 58000, 68000]);
  assert.equal(c.events.length, 4);
  assert.deepEqual(c.warnings, []);
});

test('identical duplicates do not renew waiting expiry; an already selected intention finishes', async t => {
  const c = await setup(t, { delay: 29000 });
  for (let i = 1; i <= 4; i++) {
    c.coordinator.requestZone(zone(`z0${i}`), false);
  }
  await c.advance(59000);
  c.coordinator.requestZone(zone('z04'), false);
  await c.advance(1000);
  assert.equal(c.warnings.length, 1);
  assert.match(c.warnings[0], /Zone 4.*expired before dispatch/);
  await c.advance(28000);
  assert.equal(c.writes.length, 3);
  assert.equal(c.events.length, 3);
  assert.equal(c.data.aircons.ac1.zones.z04.state, 'open');
});

test('changed unsent values get a new lifetime and retain their FIFO key position', async t => {
  const c = await setup(t, { delay: 29000 });
  for (let i = 1; i <= 4; i++) {
    c.coordinator.requestZone(zone(`z0${i}`), false);
  }
  await c.advance(59000);
  c.coordinator.requestZone(zone('z04'), true);
  c.coordinator.requestZone(zone('z05'), true);
  await c.advance(29000);
  assert.equal(c.writes.length, 3, 'Superseded closure must never dispatch');
  assert.deepEqual(c.events.slice(-2).map(event => [event.name, event.outcome]), [
    ['Zone 4 Zone', 'unchanged'], ['Zone 5 Zone', 'unchanged'],
  ]);
  assert.deepEqual(c.warnings, []);
});

test('empty reads may confirm at 29.999 seconds without renewing the write deadline', async t => {
  const c = await setup(t, { delay: 29999 });
  c.coordinator.requestZone(zone('z01'), false);
  await c.advance(28000);
  c.model.readDelays.push(999);
  await c.advance(1999);
  assert.equal(c.events.length, 1);
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.warnings, []);
});

for (const busy of [true, false]) {
  test(`${busy ? 'empty' : 'unchanged valid'} readback expires at 30 seconds and cancels pending replacements`, async t => {
    const c = await setup(t, { never: true, busy });
    c.coordinator.requestZone(zone('z01'), false);
    await flush();
    c.coordinator.requestZone(zone('z01'), true);
    c.coordinator.requestZone(zone('z02'), false);
    await c.advance(29900);
    assert.deepEqual(c.warnings, []);
    await c.advance(100);
    assert.equal(c.writes.length, 1);
    assert.equal(c.events.length, 0);
    assert.equal(c.warnings.filter(message => message.includes('Cancelled')).length, 2);
    c.model.never = false;
    await c.advance(31000);
    assert.equal(c.writes.length, 1, 'Recovery observes late physical progress but never replays cancelled work');
    assert.equal(c.coordinator.readZone(zone('z01')), false);
  });
}

test('a timed-out write response can still confirm, with only the original 30-second budget', async t => {
  const c = await setup(t, { delay: 15000, writeDelay: 15000 });
  c.coordinator.requestZone(zone('z01'), false);
  await c.advance(16000);
  assert.equal(c.writes.length, 1);
  assert.equal(c.events.length, 1);
  assert.deepEqual(c.warnings, []);
});

test('typed transient confirmation errors use two-second read retries and never replay a write', async t => {
  const c = await setup(t, { delay: 5000 });
  c.model.onWrite = () => c.model.errors.push(
    Object.assign(new Error('Private transport details'), { cause: { code: 'ECONNRESET' } }),
    Object.assign(new Error('Private transport details'), { code: 'ETIMEDOUT' }),
  );
  c.coordinator.requestZone(zone('z01'), false);
  await c.advance(5100);
  assert.deepEqual(c.reads.slice(2), [2000, 4000, 6000]);
  assert.equal(c.events.length, 1);
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.warnings, []);
});

for (const mode of ['malformed', 'identity', 'unknown-error']) {
  test(`${mode} confirmation is terminal, not classified as transient`, async t => {
    const c = await setup(t, { busy: false });
    c.model.onWrite = () => {
      if (mode === 'malformed') {
        c.model.malformed = true;
      }
      if (mode === 'identity') {
        c.data.system.mid = 'replacement-controller';
      }
      if (mode === 'unknown-error') {
        c.model.errors.push(new Error('Private unexpected detail'));
      }
    };
    c.coordinator.requestZone(zone('z01'), false);
    c.coordinator.requestZone(zone('z02'), false);
    await c.advance(2000);
    assert.equal(c.writes.length, 1);
    assert.equal(c.events.length, 0);
    assert.equal(c.warnings.length, 2);
    assert.equal(c.warnings.some(message => message.includes('Private')), false);
  });
}

test('explicit rejection does not cancel later fresh work; ambiguous delivery reconciles once', async t => {
  const c = await setup(t, { delay: 1000 });
  c.model.onWrite = count => {
    c.model.reject = count === 1; c.model.ambiguous = count === 2;
  };
  c.coordinator.requestZone(zone('z01'), false);
  c.coordinator.requestZone(zone('z02'), false);
  await c.advance(2000);
  assert.equal(c.writes.length, 2);
  assert.equal(c.events.length, 1);
  assert.equal(c.data.aircons.ac1.zones.z01.state, 'open');
  assert.equal(c.data.aircons.ac1.zones.z02.state, 'close');
  assert.equal(c.warnings.length, 1);
  assert.match(c.warnings[0], /rejected/);
});

test('rapid reversals during preflight and after sending never dispatch obsolete generations', async t => {
  const c = await setup(t, { delay: 5000 });
  c.model.readDelays.push(3000);
  c.coordinator.requestZone(zone('z01'), false);
  await c.advance(1000);
  c.coordinator.requestZone(zone('z01'), true);
  c.coordinator.requestZone(zone('z01'), false);
  c.coordinator.requestZone(zone('z01'), true);
  await c.advance(3000);
  assert.equal(c.writes.length, 0);
  c.coordinator.requestZone(zone('z01'), false);
  await flush();
  c.coordinator.requestZone(zone('z01'), true);
  c.coordinator.requestZone(zone('z01'), false);
  c.coordinator.requestZone(zone('z01'), true);
  await c.advance(5100);
  assert.equal(c.writes.length, 2);
  assert.equal(c.events.at(-1).superseded, true);
  assert.equal(c.coordinator.readZone(zone('z01')), true);
  await c.advance(5100);
  assert.equal(c.data.aircons.ac1.zones.z01.state, 'open');
  assert.equal(c.writes.length, 2);
});

test('supersession in a sending observer cannot dispatch the obsolete value', async t => {
  const c = await setup(t);
  c.model.onSending = () => {
    c.model.onSending = undefined;
    c.coordinator.requestZone(zone('z01'), true);
  };
  c.coordinator.requestZone(zone('z01'), false);
  await c.advance(100);
  assert.equal(c.writes.length, 0);
  assert.equal(c.events.at(-1).outcome, 'unchanged');
});

test('supersession queued immediately before the physical write cannot dispatch the obsolete value', async t => {
  const c = await setup(t);
  c.model.onSending = () => {
    c.model.onSending = undefined;
    globalThis.queueMicrotask(() => c.coordinator.requestZone(zone('z01'), true));
  };
  c.coordinator.requestZone(zone('z01'), false);
  await c.advance(20000);
  assert.equal(c.writes.length, 0);
  assert.equal(c.events.at(-1).outcome, 'unchanged');
});

for (const stage of ['queued', 'preflight', 'write', 'confirmation', 'read-retry']) {
  test(`shutdown during ${stage} prevents subsequent writes and late confirmation`, async t => {
    const c = await setup(t, { writeDelay: stage === 'write' ? 5000 : 0 });
    if (stage === 'preflight') {
      c.model.readDelays.push(5000);
    }
    if (stage === 'read-retry') {
      c.model.onWrite = () => c.model.errors.push(Object.assign(new Error('Reset'), { code: 'ECONNRESET' }));
    }
    c.coordinator.requestZone(zone('z01'), false);
    c.coordinator.requestZone(zone('z02'), false);
    if (stage !== 'queued') {
      await c.advance(stage === 'read-retry' ? 1100 : 100);
    }
    c.coordinator.stop();
    const writes = c.writes.length;
    await c.advance(130000);
    assert.equal(c.writes.length, writes);
    assert.equal(c.events.length, 0);
    assert.deepEqual(c.warnings, []);
  });
}

for (const confirmation of [false, true]) {
  test(`late ignored-abort ${confirmation ? 'confirmation' : 'preflight'} cannot resurrect a failed operation`, async t => {
    const c = await setup(t, { delay: 0 });
    let release;
    const held = new Promise(resolve => {
      release = resolve;
    });
    t.mock.method(c.client, 'getFreshSystemData', async () => {
      if (!confirmation || c.writes.length) {
        await held;
      }
      return globalThis.structuredClone(c.data);
    });
    c.coordinator.requestZone(zone('z01'), false);
    await c.advance(confirmation ? 30100 : 10100);
    c.data.aircons.ac1.zones.z01.state = 'close';
    release();
    await flush();
    assert.equal(c.events.length, 0);
    assert.equal(c.writes.length, confirmation ? 1 : 0);
    assert.equal(c.warnings.length, 1);
  });
}

test('wall-clock changes do not extend or shorten monotonic operation deadlines', async t => {
  const c = await setup(t, { never: true });
  const monotonic = Date.now.bind(Date);
  t.mock.method(globalThis.performance, 'now', monotonic);
  c.coordinator.requestZone(zone('z01'), false);
  await c.advance(1000);
  t.mock.method(Date, 'now', () => 900000000);
  await c.advance(28000);
  assert.deepEqual(c.warnings, []);
  t.mock.method(Date, 'now', () => 0);
  await c.advance(1000);
  assert.equal(c.warnings.length, 1);
  assert.equal(c.writes.length, 1);
});

for (const [count, brightness, delay, expected] of [[20, false, 1000, 20], [30, false, 1000, 30],
  [20, true, 1000, 40], [30, true, 1000, 60], [30, true, 2000, 30], [30, false, 3000, 20]]) {
  test(`${count} lights, brightness ${brightness}, ${delay}ms readback: bounded FIFO scene`, async t => {
    const c = await setup(t, { delay });
    const expectedOrder = [];
    for (let i = 1; i <= count; i++) {
      const id = `l${String(i).padStart(6, '0')}`;
      c.coordinator.requestLight(light(id), 'state', true);
      expectedOrder.push([id, 'state']);
      if (brightness) {
        c.coordinator.requestLight(light(id), 'value', 45);
        expectedOrder.push([id, 'value']);
      }
    }
    await c.advance(65000);
    assert.equal(c.writes.length, expected);
    assert.deepEqual(c.writes.map(write => [write.patch.light.id, write.patch.light.field]), expectedOrder.slice(0, expected));
    assert.equal(c.events.length, expected);
    assert.equal(c.warnings.length, expectedOrder.length - expected);
    assert.ok(c.warnings.every(message => message.includes('expired before dispatch')));
  });
}

test('mixed HVAC and lights retain FIFO including an unsent brightness replacement', async t => {
  const c = await setup(t, { delay: 1000 });
  c.coordinator.requestLight(light('l000001'), 'state', true);
  c.coordinator.requestFanSpeed(identity, 90);
  c.coordinator.requestLight(light('l000001'), 'value', 45);
  c.coordinator.requestZone(zone('z01'), false);
  c.coordinator.requestLight(light('l000001'), 'value', 55);
  await c.advance(5000);
  assert.deepEqual(c.writes.map(write => write.patch), [
    { light: { id: 'l000001', field: 'state', value: 'on' } },
    { ac1: { info: { fan: 'high' } } },
    { light: { id: 'l000001', field: 'value', value: 55 } },
    { ac1: { zones: { z01: { state: 'close' } } } },
  ]);
  assert.deepEqual(c.warnings, []);
});

test('an unresolved controller cannot cancel a separately configured coordinator', async t => {
  const c = await setup(t, { never: true });
  const secondData = globalThis.structuredClone(c.data);
  secondData.system.mid = 'independent';
  let secondWrites = 0;
  const secondEvents = [];
  const second = new ControllerCoordinator({
    getSystemData: async () => globalThis.structuredClone(secondData),
    getFreshSystemData: async () => globalThis.structuredClone(secondData),
    requestZoneState: async (ac, key, state) => {
      secondWrites++; secondData.aircons[ac].zones[key].state = state;
    },
  }, () => {}, () => {}, event => secondEvents.push(event));
  t.after(() => second.stop());
  second.start(); await flush();
  c.coordinator.requestZone(zone('z01'), false);
  second.requestZone(JSON.stringify(['AdvantageAir', 'independent', 'unit', 'zone', 'z01']), false);
  await c.advance(31000);
  assert.equal(secondWrites, 1);
  assert.equal(secondEvents.length, 1);
  assert.equal(c.warnings.length, 1);
});
