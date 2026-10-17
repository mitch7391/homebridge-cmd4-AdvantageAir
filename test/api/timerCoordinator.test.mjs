import assert from 'node:assert/strict';
import test from 'node:test';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';
import { AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';
import { ControllerBusyError } from '../../dist/api/systemData.js';

const identity = JSON.stringify(['AdvantageAir', 'timer-controller', 'timer-unit', 'aircon']);
async function flush() {
  for (let i = 0; i < 60; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = {
    system: { mid: 'timer-controller', hasAircons: true, noOfAircons: 1 },
    aircons: { ac1: {
      info: { uid: 'timer-unit', name: 'AC', state: 'on', mode: 'cool', fan: 'low', myZone: 0, setTemp: 24,
        countDownToOn: 0, countDownToOff: 0 },
      zones: { z01: { number: 1, type: 1, name: 'Living', state: 'open', setTemp: 24, measuredTemp: 22, error: 0 } },
    } },
  };
  const model = { ...options };
  const writes = [];
  const warnings = [];
  const events = [];
  const snapshots = [];
  let transition;
  let held;
  const read = async () => {
    if (held) {
      const pending = held;
      held = undefined;
      await pending;
    }
    if (model.busy || transition && Date.now() < transition.due) {
      throw new ControllerBusyError('busy');
    }
    if (model.failRead) {
      throw new Error('private');
    }
    if (transition && !model.never) {
      transition.apply();
      transition = undefined;
    }
    return globalThis.structuredClone(data);
  };
  const send = async (action, ac, patch) => {
    writes.push({ action, ac, patch });
    if (model.reject) {
      throw new AirconCommandRejectedError('private');
    }
    transition = { due: Date.now() + (model.delay ?? 100), apply: () => {
      Object.assign(data.aircons[ac].info, patch);
      if (model.tick && action === 'timer') {
        for (const field of ['countDownToOn', 'countDownToOff']) {
          if (data.aircons[ac].info[field] > 0) {
            data.aircons[ac].info[field]--;
          }
        }
      }
    } };
    if (model.ambiguous) {
      throw new Error('private delivery');
    }
  };
  const client = {
    getSystemData: read, getFreshSystemData: read,
    requestZoneState: async () => assert.fail('Timer must not write zones'),
    requestTimer: (ac, field, minutes) => send('timer', ac, { [field]: minutes }),
    requestFanSpeed: (ac, fan) => send('fan', ac, { fan }),
    requestThermostatPatch: (ac, patch) => send('thermostat', ac, patch.info),
  };
  const coordinator = new ControllerCoordinator(client, state => snapshots.push(state), message => warnings.push(message),
    event => events.push(event));
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
  const hold = () => {
    let release;
    held = new Promise(resolve => {
      release = resolve;
    });
    return release;
  };
  return { coordinator, data, model, writes, warnings, events, snapshots, advance, hold, client };
}

test('timer admission is optimistic only for Active; fresh power/address choose physical direction', async t => {
  const c = await setup(t);
  c.coordinator.requestTimer(identity, true, 1800);
  assert.deepEqual(c.coordinator.readTimer(identity), { active: true, inUse: false, remaining: 0 });
  c.data.aircons.ac9 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  c.data.aircons.ac9.info.state = 'off';
  const before = globalThis.structuredClone(c.data);
  await c.advance(1500);
  assert.deepEqual(c.writes, [{ action: 'timer', ac: 'ac9', patch: { countDownToOn: 30 } }]);
  before.aircons.ac9.info.countDownToOn = 30;
  assert.deepEqual(c.data, before);
  assert.deepEqual(c.coordinator.readTimer(identity), { active: true, inUse: true, remaining: 1800 });
});

test('timer retains stable identity requirements during preflight', async t => {
  const c = await setup(t);
  c.coordinator.requestTimer(identity, true, 1800);
  c.data.aircons.ac1.info.uid = 'different-unit';
  await flush();
  assert.deepEqual(c.writes, []);
  assert.equal(c.warnings.length, 1);
});

test('timer rapid unsent changes coalesce and unrelated fan work keeps its queue position', async t => {
  const c = await setup(t);
  c.coordinator.requestTimer(identity, true, 1800, true);
  c.coordinator.requestFanSpeed(identity, 90);
  c.coordinator.requestTimer(identity, true, 7200, true);
  await c.advance(3000);
  assert.deepEqual(c.writes.map(w => w.patch), [{ countDownToOff: 120 }, { fan: 'high' }]);
});

test('a newer timer selection supersedes an unsent held preflight', async t => {
  const c = await setup(t);
  const release = c.hold();
  c.coordinator.requestTimer(identity, true, 1800, true);
  await flush();
  c.coordinator.requestTimer(identity, true, 3600, true);
  release();
  await c.advance(1500);
  assert.deepEqual(c.writes.map(w => w.patch), [{ countDownToOff: 60 }]);
});

test('in-flight timer completes once then pending cancellation clears countdown without power writes', async t => {
  const c = await setup(t);
  c.coordinator.requestTimer(identity, true, 1800);
  await flush();
  c.coordinator.requestTimer(identity, false, 1800);
  assert.equal(c.coordinator.readTimer(identity).active, false);
  await c.advance(2500);
  assert.deepEqual(c.writes.map(w => w.patch), [{ countDownToOff: 30 }, { countDownToOff: 0 }]);
  assert.equal(c.events[0].superseded, true);
  assert.equal(c.data.aircons.ac1.info.state, 'on');
});

test('timer cancellation and duplicate activation use fresh no-op detection', async t => {
  const c = await setup(t);
  c.coordinator.requestTimer(identity, false, 1800);
  await flush();
  c.data.aircons.ac1.info.countDownToOff = 29;
  await c.advance(30100);
  c.coordinator.requestTimer(identity, true, 1800);
  await flush();
  assert.deepEqual(c.writes, []);
  assert.equal(c.events.length, 2);
  assert.ok(c.events.every(e => e.outcome === 'unchanged'));
});

test('timer ambiguous delivery and transient empty reads reconcile once including one minute tick', async t => {
  const c = await setup(t, { ambiguous: true, delay: 3500, tick: true });
  c.coordinator.requestTimer(identity, true, 1800);
  await c.advance(4500);
  assert.equal(c.writes.length, 1);
  assert.equal(c.events[0].outcome, 'confirmed');
  assert.equal(c.coordinator.readTimer(identity).remaining, 1740);
  assert.deepEqual(c.warnings, []);
});

test('timer rejection fails immediately and follows existing dependent cancellation policy', async t => {
  const c = await setup(t, { reject: true });
  c.coordinator.requestTimer(identity, true, 1800);
  c.coordinator.requestFanSpeed(identity, 90);
  await flush();
  assert.equal(c.writes.length, 1);
  assert.equal(c.warnings.length, 2);
  assert.match(c.warnings[0], /Timer command failed.*rejected/);
  assert.match(c.warnings[1], /Cancelled because/);
});

test('timer confirmation timeout never resends or issues power cleanup', async t => {
  const c = await setup(t, { never: true });
  c.coordinator.requestTimer(identity, true, 1800);
  await c.advance(16000);
  assert.equal(c.writes.length, 1);
  assert.equal(c.events.length, 0);
  assert.match(c.warnings[0], /expired/);
  assert.throws(() => c.coordinator.readTimer(identity));
});

test('timer handles natural expiry, early power attainment and bin cancellation only by observation', async t => {
  const c = await setup(t);
  for (const [state, field, finalState] of [['on', 'countDownToOff', 'off'], ['off', 'countDownToOn', 'on'],
    ['on', 'countDownToOff', 'on']]) {
    Object.assign(c.data.aircons.ac1.info, { state, countDownToOn: 0, countDownToOff: 0, [field]: 1 });
    await c.advance(30100);
    assert.equal(c.coordinator.readTimer(identity).remaining, 60);
    c.model.busy = true;
    await c.advance(30100);
    assert.equal(c.coordinator.readTimer(identity).remaining, 60);
    c.model.busy = false;
    Object.assign(c.data.aircons.ac1.info, { state: finalState, countDownToOn: 0, countDownToOff: 0 });
    await c.advance(30100);
    assert.deepEqual(c.coordinator.readTimer(identity), { active: false, inUse: false, remaining: 0 });
  }
  assert.deepEqual(c.writes, []);
});

test('timer stale data, shutdown and expired held preflight cannot dispatch', async t => {
  const c = await setup(t);
  const release = c.hold();
  c.coordinator.requestTimer(identity, true, 1800);
  await flush();
  await c.advance(31000);
  release();
  await flush();
  assert.deepEqual(c.writes, []);
  c.model.failRead = true;
  await c.advance(100000);
  assert.throws(() => c.coordinator.requestTimer(identity, true, 1800));
  c.coordinator.stop();
  assert.throws(() => c.coordinator.readTimer(identity));
  assert.throws(() => c.coordinator.requestTimer(identity, true, 1800));
});

test('timer preflight follows an earlier thermostat power command without corrupting temperature', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatMode(identity, 'off');
  c.coordinator.requestTimer(identity, true, 1800);
  await c.advance(2500);
  assert.deepEqual(c.writes.map(w => w.patch), [{ state: 'off' }, { countDownToOn: 30 }]);
  assert.equal(c.data.aircons.ac1.info.setTemp, 24);
  assert.equal(c.data.aircons.ac1.info.mode, 'cool');
});

test('one-minute timer confirms once when positive and never confirms a zero/no-timer readback', async t => {
  const c = await setup(t);
  c.coordinator.requestTimer(identity, true, 60);
  await c.advance(1500);
  assert.equal(c.events.length, 1);
  assert.equal(c.events[0].outcome, 'confirmed');
  assert.deepEqual(c.writes[0].patch, { countDownToOff: 1 });
  c.coordinator.requestTimer(identity, false, 60);
  await c.advance(1500);
  const confirmed = c.events.length;
  c.model.never = true;
  c.coordinator.requestTimer(identity, true, 60);
  await c.advance(16000);
  assert.equal(c.events.length, confirmed);
  assert.equal(c.writes.length, 3);
  assert.match(c.warnings.at(-1), /expired/);
});
