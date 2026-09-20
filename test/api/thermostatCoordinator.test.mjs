import assert from 'node:assert/strict';
import test from 'node:test';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';
import { AdvantageAirClient, AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';

const identity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'aircon']);
const zoneIdentity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', 'z02']);

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
      info: { uid: 'unit', name: 'Aircon', state: 'off', mode: 'cool', myZone: 0, setTemp: 24 },
      zones: {
        z01: { number: 1, name: 'Living', type: 1, state: 'open', setTemp: 24, error: 0, measuredTemp: 23 },
        z02: { number: 7, name: 'Bedroom', type: 1, state: 'open', setTemp: 24, error: 0, measuredTemp: 22 },
      },
    } },
  };
  const model = { delay: 1000, busy: true, reject: false, ambiguous: false, never: false,
    mainOnly: false, modeOnly: false, readLatency: 0, ...options };
  let transition;
  let active = 0;
  let maximum = 0;
  const requests = [];
  const writes = [];
  const events = [];
  const warnings = [];
  const observations = [];
  const fetchStub = t.mock.method(globalThis, 'fetch', async (url, { signal }) => {
    active++;
    maximum = Math.max(maximum, active);
    requests.push(url.pathname);
    try {
      if (model.readLatency && url.pathname === '/getSystemData') {
        await new Promise((resolve, reject) => {
          let abort = () => {};
          const timer = globalThis.setTimeout(() => {
            signal.removeEventListener('abort', abort);
            resolve();
          }, model.readLatency);
          abort = () => {
            globalThis.clearTimeout(timer);
            reject(new Error('aborted'));
          };
          signal.addEventListener('abort', abort, { once: true });
        });
      }
      if (url.pathname === '/setAircon') {
        const payload = JSON.parse(url.searchParams.get('json'));
        writes.push(payload);
        if (model.reject) {
          return { ok: true, status: 200, text: async () => 'false' };
        }
        const [key, patch] = Object.entries(payload)[0];
        transition = { key, patch, due: Date.now() + model.delay };
        if (model.ambiguous) {
          throw new Error('private transport detail');
        }
        return { ok: true, status: 200, text: async () => '{}' };
      }
      if (transition && !model.never && Date.now() >= transition.due) {
        const { key, patch } = transition;
        if (patch.info) {
          const update = { ...patch.info };
          if (model.modeOnly) {
            delete update.state;
          }
          Object.assign(data.aircons[key].info, update);
        }
        if (!model.mainOnly) {
          for (const [zone, patchZone] of Object.entries(patch.zones ?? {})) {
            Object.assign(data.aircons[key].zones[zone], patchZone);
          }
        }
        transition = undefined;
      }
      const response = transition && model.busy ? {} : globalThis.structuredClone(data);
      return { ok: true, status: 200, text: async () => JSON.stringify(response) };
    } finally {
      active--;
    }
  });
  const client = new AdvantageAirClient({ ipAddress: '192.0.2.1' });
  const coordinator = new ControllerCoordinator(client,
    (state, reason) => observations.push({ state, reason }), message => warnings.push(message), event => {
      events.push(event);
      if (model.throwConfirmation) {
        throw new Error('observer failed');
      }
    });
  t.after(() => coordinator.stop());
  coordinator.start();
  await flush();
  const advance = async ms => {
    for (let remaining = ms; remaining > 0;) {
      const step = Math.min(remaining, 50);
      t.mock.timers.tick(step);
      remaining -= step;
      await flush();
    }
  };
  return { data, model, client, coordinator, requests, writes, warnings, events, observations, advance, fetchStub,
    max: () => maximum };
}

test('mode admission is immediate, desired state survives busy reads, and heat requires power plus mode confirmation', async t => {
  const c = await setup(t, { delay: 6500 });
  assert.equal(c.coordinator.requestThermostatMode(identity, 'heat'), undefined);
  assert.equal(c.coordinator.readThermostatMode(identity), 'heat');
  assert.equal(c.data.aircons.ac1.info.state, 'off');
  assert.equal(c.events.length, 0);
  await c.advance(7100);
  assert.deepEqual(c.writes, [{ ac1: { info: { state: 'on', mode: 'heat' } } }]);
  assert.equal(c.coordinator.readThermostatMode(identity), 'heat');
  assert.equal(c.events[0].kind, 'mode');
  assert.equal(c.events[0].outcome, 'confirmed');
  assert.deepEqual(c.warnings, []);
});

test('mode-only response without requested power never confirms Heat', async t => {
  const c = await setup(t, { modeOnly: true });
  c.coordinator.requestThermostatMode(identity, 'heat');
  await c.advance(15100);
  assert.equal(c.events.length, 0);
  assert.equal(c.writes.length, 1);
  assert.equal(c.warnings.length, 1);
  assert.throws(() => c.coordinator.readThermostatMode(identity), /could not be confirmed/);
});

test('temperature admission keeps measured data unchanged until all legacy targets confirm', async t => {
  const c = await setup(t, { delay: 3000 });
  c.coordinator.requestThermostatTemperature(identity, 26.5);
  assert.equal(c.coordinator.readThermostatTemperature(identity), 26.5);
  assert.equal(c.data.aircons.ac1.info.setTemp, 24);
  assert.equal(c.observations.at(-1).state.data.aircons.ac1.zones.z01.measuredTemp, 23);
  await c.advance(3100);
  assert.deepEqual(c.writes, [{ ac1: { info: { setTemp: 26.5 },
    zones: { z01: { setTemp: 26.5 }, z02: { setTemp: 26.5 } } } }]);
  assert.equal(c.data.aircons.ac1.info.state, 'off');
  assert.equal(c.events[0].temperature, 26.5);
});

test('matching main target cannot falsely confirm missing zone target updates', async t => {
  const c = await setup(t, { mainOnly: true });
  c.coordinator.requestThermostatTemperature(identity, 26);
  await c.advance(15100);
  assert.equal(c.events.length, 0);
  assert.equal(c.warnings.length, 1);
  assert.equal(c.writes.length, 1);
  assert.throws(() => c.coordinator.readThermostatTemperature(identity), /could not be confirmed/);
  assert.equal(c.coordinator.readZone(zoneIdentity), true);
});

test('rapid unsent temperatures coalesce without cancelling independently queued mode and zone edits', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatTemperature(identity, 25);
  c.coordinator.requestThermostatTemperature(identity, 26);
  c.coordinator.requestThermostatTemperature(identity, 27);
  c.coordinator.requestThermostatMode(identity, 'heat');
  c.coordinator.requestZone(zoneIdentity, false);
  await c.advance(3200);
  assert.equal(c.writes.length, 3);
  assert.equal(c.writes[0].ac1.info.setTemp, 27);
  assert.equal(c.writes[1].ac1.info.mode, 'heat');
  assert.equal(c.writes[2].ac1.zones.z02.state, 'close');
  assert.equal(c.max(), 1);
  assert.deepEqual(c.warnings, []);
});

test('temperature replacement during preflight suppresses the older unsent write', async t => {
  const c = await setup(t);
  c.model.readLatency = 200;
  c.coordinator.requestThermostatTemperature(identity, 25);
  await flush();
  c.coordinator.requestThermostatTemperature(identity, 26);
  await c.advance(1900);
  assert.equal(c.writes.length, 1);
  assert.equal(c.writes[0].ac1.info.setTemp, 26);
});

test('sent mode reversal confirms older command before sending Off and retains latest desired value', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatMode(identity, 'heat');
  await flush();
  c.coordinator.requestThermostatMode(identity, 'off');
  assert.equal(c.coordinator.readThermostatMode(identity), 'off');
  await c.advance(1100);
  assert.equal(c.coordinator.readThermostatMode(identity), 'off');
  await c.advance(1100);
  assert.deepEqual(c.events.map(e => [e.mode, e.superseded]), [['heat', true], ['off', false]]);
  assert.equal(c.data.aircons.ac1.info.state, 'off');
});

test('sent temperature edit keeps another queued zone ahead of its replacement', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatTemperature(identity, 25);
  await flush();
  c.coordinator.requestZone(zoneIdentity, false);
  c.coordinator.requestThermostatTemperature(identity, 26);
  await c.advance(1100);
  assert.equal(c.coordinator.readThermostatTemperature(identity), 26);
  await c.advance(2200);
  assert.equal(c.writes[0].ac1.info.setTemp, 25);
  assert.equal(c.writes[1].ac1.zones.z02.state, 'close');
  assert.equal(c.writes[2].ac1.info.setTemp, 26);
  assert.equal(c.events[0].superseded, true);
});

test('fresh preflight follows a changed myZone selection', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatTemperature(identity, 27);
  c.data.aircons.ac1.info.myZone = 7;
  await c.advance(1100);
  assert.deepEqual(c.writes[0].ac1.zones, { z02: { setTemp: 27 } });
  assert.equal(c.data.aircons.ac1.zones.z01.setTemp, 24);
});

test('myZone change after dispatch fails reconciliation and cancels queued dependent commands', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatTemperature(identity, 27);
  await flush();
  c.coordinator.requestThermostatMode(identity, 'heat');
  c.data.aircons.ac1.info.myZone = 7;
  await c.advance(1100);
  assert.equal(c.writes.length, 1);
  assert.equal(c.events.length, 0);
  assert.equal(c.warnings.length, 2);
  assert.match(c.warnings[0], /myZone selection changed/);
  assert.match(c.warnings[1], /preceding controller command/);
});

test('active myZone becoming ambiguous cannot confirm a temperature command', async t => {
  const c = await setup(t);
  c.data.aircons.ac1.info.myZone = 7;
  c.coordinator.requestThermostatTemperature(identity, 27);
  await flush();
  c.data.aircons.ac1.zones.z01.number = 7;
  await c.advance(1100);
  assert.equal(c.events.length, 0);
  assert.match(c.warnings[0], /ambiguous/);
});

test('explicit thermostat Off turns off ventilation even though its thermostat projection is Off', async t => {
  const c = await setup(t);
  c.data.aircons.ac1.info.state = 'on';
  c.data.aircons.ac1.info.mode = 'vent';
  await c.advance(30000);
  assert.equal(c.coordinator.readThermostatMode(identity), 'off');
  c.coordinator.requestThermostatMode(identity, 'off');
  await c.advance(1100);
  assert.deepEqual(c.writes, [{ ac1: { info: { state: 'off' } } }]);
  assert.equal(c.data.aircons.ac1.info.mode, 'vent');
});

test('already-satisfied thermostat requests get fresh verification with no write', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatMode(identity, 'off');
  c.coordinator.requestThermostatTemperature(identity, 24);
  await flush();
  assert.equal(c.writes.length, 0);
  assert.deepEqual(c.events.map(e => e.outcome), ['unchanged', 'unchanged']);
});

test('invalid requests are refused immediately before any thermostat write', async t => {
  const c = await setup(t);
  const before = c.requests.length;
  assert.throws(() => c.coordinator.requestThermostatMode(identity, 'auto'));
  assert.throws(() => c.coordinator.requestThermostatTemperature(identity, 33));
  assert.throws(() => c.coordinator.requestThermostatMode(zoneIdentity, 'heat'));
  assert.equal(c.requests.length, before);
  assert.equal(c.writes.length, 0);
});

test('explicit rejection cancels dependent work and never logs confirmation', async t => {
  const c = await setup(t, { reject: true });
  c.coordinator.requestThermostatMode(identity, 'heat');
  c.coordinator.requestZone(zoneIdentity, false);
  await flush();
  assert.equal(c.writes.length, 1);
  assert.equal(c.events.length, 0);
  assert.equal(c.warnings.length, 2);
  assert.match(c.warnings[0], /Controller rejected/);
});

test('ambiguous thermostat delivery is confirmed by reads without resending', async t => {
  const c = await setup(t, { ambiguous: true });
  c.coordinator.requestThermostatTemperature(identity, 26);
  await c.advance(1100);
  assert.equal(c.writes.length, 1);
  assert.equal(c.events.length, 1);
  assert.deepEqual(c.warnings, []);
});

test('preflight timeout cannot later send a thermostat command', async t => {
  const c = await setup(t);
  c.model.readLatency = 20000;
  c.coordinator.requestThermostatMode(identity, 'heat');
  await c.advance(21000);
  assert.equal(c.writes.length, 0);
  assert.equal(c.events.length, 0);
  assert.equal(c.warnings.length, 1);
});

test('shutdown aborts pending reconciliation and prevents later commands or confirmation', async t => {
  const c = await setup(t, { delay: 5000 });
  c.coordinator.requestThermostatMode(identity, 'heat');
  await flush();
  c.coordinator.requestThermostatTemperature(identity, 26);
  c.coordinator.stop();
  await c.advance(20000);
  assert.equal(c.writes.length, 1);
  assert.equal(c.events.length, 0);
  assert.deepEqual(c.warnings, []);
  assert.throws(() => c.coordinator.readThermostatMode(identity), /unavailable/);
});

test('stable aircon identity follows new addressing before dispatch', async t => {
  const c = await setup(t);
  c.data.aircons.ac2 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  c.coordinator.requestThermostatMode(identity, 'heat');
  await c.advance(1100);
  assert.deepEqual(c.writes, [{ ac2: { info: { state: 'on', mode: 'heat' } } }]);
  assert.equal(c.events.length, 1);
});

test('replacement aircon identity during preflight prevents writing to the new unit', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatMode(identity, 'heat');
  c.data.aircons.ac1.info.uid = 'different-unit';
  await flush();
  assert.equal(c.writes.length, 0);
  assert.match(c.warnings[0], /identity is unavailable/);
});

test('confirmation logger exceptions do not turn thermostat success into failure', async t => {
  const c = await setup(t, { throwConfirmation: true });
  c.coordinator.requestThermostatMode(identity, 'heat');
  c.coordinator.requestThermostatTemperature(identity, 26);
  await c.advance(2200);
  assert.equal(c.events.length, 2);
  assert.deepEqual(c.warnings, []);
});

test('aircon replacement or target capability loss after dispatch cannot confirm the old request', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatTemperature(identity, 26);
  await flush();
  c.data.aircons.ac1.zones.z02.type = 0;
  await c.advance(1100);
  assert.equal(c.events.length, 0);
  assert.match(c.warnings[0], /target zone changed/);
  // A later valid poll restores availability before a separate mode request.
  await c.advance(30000);
  c.coordinator.requestThermostatMode(identity, 'heat');
  await flush();
  c.data.aircons.ac1.info.uid = 'replacement';
  await c.advance(1100);
  assert.equal(c.events.length, 0);
  assert.match(c.warnings[1], /identity is unavailable/);
});

test('queued thermostat transport cancellation sends nothing after the preceding read', async t => {
  const c = await setup(t);
  let release;
  let requests = 0;
  c.fetchStub.mock.mockImplementation(async () => {
    requests++;
    await new Promise(resolve => {
      release = resolve;
    });
    return { ok: true, status: 200, text: async () => JSON.stringify(c.data) };
  });
  const read = c.client.getFreshSystemData();
  await flush();
  const abort = new globalThis.AbortController();
  const write = c.client.requestThermostatPatch('ac1', { info: { state: 'on', mode: 'heat' } }, abort.signal);
  const rejected = assert.rejects(write, /cancelled/);
  abort.abort();
  release();
  await read;
  await rejected;
  assert.equal(requests, 1);
});

test('stale data prevents thermostat reads and new requests until a valid observation returns', async t => {
  const c = await setup(t);
  c.fetchStub.mock.mockImplementation(async () => {
    throw new Error('unavailable');
  });
  await c.advance(91000);
  assert.throws(() => c.coordinator.readThermostatMode(identity), /Fresh controller data/);
  assert.throws(() => c.coordinator.readThermostatTemperature(identity), /Fresh controller data/);
  assert.throws(() => c.coordinator.requestThermostatMode(identity, 'heat'), /Fresh controller data/);
  assert.throws(() => c.coordinator.requestThermostatTemperature(identity, 26), /Fresh controller data/);
  assert.equal(c.writes.length, 0);
});

test('queued work cannot outlive the accepted-intent deadline while preceding commands are slow', async t => {
  const c = await setup(t, { delay: 14000 });
  c.coordinator.requestThermostatMode(identity, 'heat');
  c.coordinator.requestThermostatTemperature(identity, 26);
  c.coordinator.requestZone(zoneIdentity, false);
  const living = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', 'z01']);
  c.coordinator.requestZone(living, false);
  await c.advance(31000);
  assert.equal(c.writes.length, 3);
  assert.equal(c.writes.some(write => write.ac1.zones?.z01?.state === 'close'), false);
  assert.ok(c.warnings.some(message => message.includes('expired')));
  assert.equal(c.events.length, 2);
});

test('thermostat transport encodes one aircon patch and rejects unexpected fields before sending', async t => {
  const c = await setup(t);
  const invalid = [null, {}, { info: { state: 'on' } }, { info: { state: 'on', mode: 'dry' } },
    { info: { state: 'off', fan: 'high' } }, { info: { setTemp: '26' } }, { info: { setTemp: NaN } },
    { info: { setTemp: 26 }, zones: { z01: { setTemp: 25 } } },
    { info: { setTemp: 26 }, zones: { z01: { setTemp: 26, state: 'close' } } },
    { info: { state: 'off' }, zones: {} }, { info: { setTemp: 26 }, zones: [] },
    { info: { setTemp: 26 }, extra: true }, { info: { setTemp: 26 }, zones: { bad: { setTemp: 26 } } }];
  for (const patch of invalid) {
    await assert.rejects(c.client.requestThermostatPatch('ac1', patch));
  }
  await assert.rejects(c.client.requestThermostatPatch('ac1?extra', { info: { state: 'off' } }));
  assert.equal(c.writes.length, 0);
  await c.client.requestThermostatPatch('ac1', { info: { setTemp: 26.5 }, zones: { z02: { setTemp: 26.5 } } });
  assert.deepEqual(c.writes, [{ ac1: { info: { setTemp: 26.5 }, zones: { z02: { setTemp: 26.5 } } } }]);
  c.model.reject = true;
  await assert.rejects(c.client.requestThermostatPatch('ac1', { info: { state: 'off' } }), AirconCommandRejectedError);
});
