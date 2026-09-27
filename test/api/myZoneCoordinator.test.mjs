import assert from 'node:assert/strict';
import test from 'node:test';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';
import { AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';
import { ControllerBusyError } from '../../dist/api/systemData.js';

const identity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'aircon']);
const zoneIdentity = key => JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', key]);

function fixture() {
  return {
    system: { mid: 'controller', hasAircons: true, noOfAircons: 1 },
    aircons: {
      ac1: {
        info: {
          uid: 'unit', name: 'AC', myZone: 1, constant1: 1,
          state: 'off', mode: 'cool', fan: 'auto', setTemp: 24,
        },
        zones: {
          z01: {
            name: 'Living', number: 1, type: 1, state: 'open',
            setTemp: 24, measuredTemp: 23, error: 0, value: 100,
          },
          z02: {
            name: 'Bedroom', number: 7, type: 1, state: 'close',
            setTemp: 22, measuredTemp: 21, error: 0, value: 40,
          },
          z03: {
            name: 'Study', number: 9, type: 1, state: 'open',
            setTemp: 26, measuredTemp: 25, error: 0, value: 60,
          },
        },
      },
    },
  };
}

async function flush() {
  for (let i = 0; i < 40; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = fixture();
  options.configure?.(data);
  const writes = [];
  const warnings = [];
  const events = [];
  const observations = [];
  const model = {
    readLatency: 0,
    failReads: false,
    delay: 0,
    ...options,
  };
  let pending;

  async function read() {
    if (model.readLatency) {
      await new Promise(resolve => globalThis.setTimeout(resolve, model.readLatency));
    }
    if (model.failReads) {
      throw new Error('Read unavailable');
    }
    if (pending) {
      if (Date.now() < pending.at) {
        throw new ControllerBusyError();
      }
      const apply = pending.apply;
      pending = undefined;
      apply();
    }
    model.onRead?.(data);
    return globalThis.structuredClone(data);
  }

  async function write(action, aircon, value, apply, signal) {
    signal?.throwIfAborted();
    writes.push({ action, aircon, value });
    if (model.reject === action) {
      throw new AirconCommandRejectedError('Rejected');
    }
    if (!model.ignoreWrites) {
      if (model.delay) {
        pending = { at: Date.now() + model.delay, apply };
      } else {
        apply();
      }
    }
    if (model.ambiguous) {
      throw new Error('Connection dropped after possible delivery');
    }
    return {};
  }

  const client = {
    getSystemData: read,
    getFreshSystemData: read,
    requestZoneState: (ac, zone, state, signal) => write(
      'open', ac, { zone, state },
      () => {
        data.aircons[ac].zones[zone].state = state;
      }, signal,
    ),
    requestMyZoneSelection: (ac, number, signal) => write(
      'select', ac, number,
      () => {
        data.aircons[ac].info.myZone = number;
        if (model.autoAlign) {
          data.aircons[ac].info.setTemp = Object.values(data.aircons[ac].zones)
            .find(zone => zone.number === number).setTemp;
        }
      }, signal,
    ),
    requestMyZoneTarget: (ac, temperature, signal) => write(
      'target', ac, temperature,
      () => {
        data.aircons[ac].info.setTemp = model.truncateTarget
          ? Math.trunc(temperature) : temperature;
      }, signal,
    ),
    requestThermostatPatch: (ac, patch, signal) => write(
      'thermostat', ac, patch,
      () => {
        Object.assign(data.aircons[ac].info, patch.info);
        for (const [key, fields] of Object.entries(patch.zones ?? {})) {
          Object.assign(data.aircons[ac].zones[key], fields);
        }
      }, signal,
    ),
    requestFanSpeed: (ac, fan, signal) => write(
      'fan', ac, fan,
      () => {
        data.aircons[ac].info.fan = fan;
      }, signal,
    ),
  };

  const coordinator = new ControllerCoordinator(
    client,
    state => observations.push(state),
    message => warnings.push(message),
    event => events.push(event),
  );
  t.after(() => coordinator.stop());
  coordinator.start();
  await flush();

  async function advance(ms) {
    await flush();
    for (let elapsed = 0; elapsed < ms; elapsed += 100) {
      t.mock.timers.tick(Math.min(100, ms - elapsed));
      await flush();
    }
  }

  return { coordinator, data, model, writes, warnings, events, observations, advance };
}

test('MyZone opens, selects reported number, then aligns only the main target', async t => {
  const c = await setup(t);
  const before = globalThis.structuredClone(c.data.aircons.ac1);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(3500);

  assert.deepEqual(c.writes, [
    { action: 'open', aircon: 'ac1', value: { zone: 'z02', state: 'open' } },
    { action: 'select', aircon: 'ac1', value: 7 },
    { action: 'target', aircon: 'ac1', value: 22 },
  ]);
  assert.equal(c.events.length, 1);
  assert.equal(c.events[0].kind, 'myZone');
  assert.equal(c.events[0].outcome, 'confirmed');
  assert.deepEqual(c.warnings, []);
  assert.deepEqual(c.data.aircons.ac1.zones.z01, before.zones.z01);
  assert.deepEqual(c.data.aircons.ac1.zones.z03, before.zones.z03);
  for (const key of ['state', 'mode', 'fan']) {
    assert.equal(c.data.aircons.ac1.info[key], before.info[key]);
  }
  assert.equal(c.data.aircons.ac1.zones.z02.value, 40);
});

test('MyZone accepts observed automatic target alignment without an unnecessary target write', async t => {
  const c = await setup(t, { autoAlign: true });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(2500);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select']);
  assert.equal(c.events.length, 1);
});

test('MyZone already satisfied is freshly checked without a physical write', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z01'));
  await flush();
  assert.deepEqual(c.writes, []);
  assert.equal(c.events[0].outcome, 'unchanged');
});

test('MyZone preflight resolves changed aircon address, reported zone number and target', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.data.aircons.ac2 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  c.data.aircons.ac2.zones.z02.number = 12;
  c.data.aircons.ac2.zones.z02.setTemp = 25;
  await c.advance(3500);
  assert.ok(c.writes.every(write => write.aircon === 'ac2'));
  assert.equal(c.writes[1].value, 12);
  assert.equal(c.writes[2].value, 25);
  assert.equal(c.events.length, 1);
});

test('MyZone refuses a replaced stable identity before dispatch', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.data.aircons.ac1.info.uid = 'replacement';
  await flush();
  assert.deepEqual(c.writes, []);
  assert.match(c.warnings[0], /identity is unavailable/);
});

for (const [label, change] of [
  ['installer-disabled MyZone', data => {
    data.aircons.ac1.info.myZone = 0;
  }],
  ['percentage target zone', data => {
    data.aircons.ac1.zones.z02.type = 0;
  }],
  ['duplicate reported number', data => {
    data.aircons.ac1.zones.z03.number = 7;
  }],
]) {
  test(`MyZone admission refuses ${label}`, async t => {
    const c = await setup(t, { configure: change });
    assert.throws(() => c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02')));
    assert.deepEqual(c.writes, []);
  });
}

test('unsent MyZone selections coalesce while independently queued fan work remains ordered', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.coordinator.requestFanSpeed(identity, 25);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  await c.advance(3500);
  assert.deepEqual(c.writes.map(write => [write.action, write.value]), [
    ['select', 9], ['target', 26], ['fan', 'low'],
  ]);
  assert.deepEqual(c.warnings, []);
});

test('a newer MyZone selection during preflight suppresses the older unsent sequence', async t => {
  const c = await setup(t);
  c.model.readLatency = 200;
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  await c.advance(4000);
  assert.deepEqual(c.writes.map(write => write.action), ['select', 'target']);
  assert.equal(c.writes[0].value, 9);
  assert.equal(c.events.length, 1);
});

test('an already transmitted MyZone sequence finishes before its queued replacement', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  assert.equal(c.writes.length, 1);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  await c.advance(5500);
  assert.deepEqual(c.writes.map(write => write.action), [
    'open', 'select', 'target', 'select', 'target',
  ]);
  assert.deepEqual(c.events.map(event => event.superseded), [true, false]);
  assert.equal(c.data.aircons.ac1.info.myZone, 9);
  assert.deepEqual(c.warnings, []);
});

test('explicit MyZone rejection stops the sequence and follows existing queued-work cancellation policy', async t => {
  const c = await setup(t, { reject: 'select' });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.coordinator.requestThermostatTemperature(identity, 27);
  await c.advance(2500);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select']);
  assert.deepEqual(c.events, []);
  assert.equal(c.warnings.length, 2);
  assert.match(c.warnings[0], /rejected/);
  assert.match(c.warnings[1], /preceding controller command/);
});

test('ambiguous MyZone delivery reconciles every step by readback without resending', async t => {
  const c = await setup(t, { ambiguous: true });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(3500);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select', 'target']);
  assert.equal(c.events.length, 1);
  assert.deepEqual(c.warnings, []);
});

test('an unconfirmed MyZone step times out without resending or advancing', async t => {
  const c = await setup(t, { ambiguous: true, ignoreWrites: true });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(16000);
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.events, []);
  assert.equal(c.warnings.length, 1);
  assert.match(c.warnings[0], /expired/);
});

test('shutdown prevents later MyZone steps and confirmation', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  c.coordinator.stop();
  await c.advance(20000);
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.events, []);
  assert.deepEqual(c.warnings, []);
  assert.throws(() => c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03')), /unavailable/);
});

test('stale controller data prevents new MyZone requests', async t => {
  const c = await setup(t);
  c.model.failReads = true;
  await c.advance(91000);
  assert.throws(() => c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02')), /Fresh controller data/);
  assert.deepEqual(c.writes, []);
});

test('a timed-out MyZone preflight cannot later dispatch a write', async t => {
  const c = await setup(t);
  c.model.readLatency = 20000;
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(21000);
  assert.deepEqual(c.writes, []);
  assert.deepEqual(c.events, []);
  assert.equal(c.warnings.length, 1);
});

test('the complete MyZone sequence remains bounded by the accepted-intent expiry', async t => {
  const c = await setup(t, { delay: 11000 });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(31000);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select', 'target']);
  assert.deepEqual(c.events, []);
  assert.equal(c.warnings.length, 1);
  assert.match(c.warnings[0], /expired/);
});

test('a queued thermostat temperature uses the newly confirmed MyZone', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.coordinator.requestThermostatTemperature(identity, 27);
  await c.advance(4500);
  assert.equal(c.writes.at(-1).action, 'thermostat');
  assert.deepEqual(c.writes.at(-1).value, {
    info: { setTemp: 27 }, zones: { z02: { setTemp: 27 } },
  });
  assert.equal(c.data.aircons.ac1.zones.z01.setTemp, 24);
  assert.equal(c.data.aircons.ac1.info.setTemp, 27);
  assert.deepEqual(c.warnings, []);
});

test('a preceding thermostat temperature finishes before MyZone chooses its own zone target', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatTemperature(identity, 25);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(4500);
  assert.equal(c.writes[0].action, 'thermostat');
  assert.equal(c.data.aircons.ac1.zones.z01.setTemp, 25);
  assert.equal(c.data.aircons.ac1.zones.z02.setTemp, 22);
  assert.equal(c.data.aircons.ac1.info.setTemp, 22);
  assert.deepEqual(c.warnings, []);
});

test('MyZone replans the target from fresh state after opening', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  c.data.aircons.ac1.zones.z02.setTemp = 23.5;
  await c.advance(3500);
  assert.equal(c.writes.at(-1).value, 23.5);
  assert.equal(c.events.length, 1);
  assert.deepEqual(c.warnings, []);
});

test('whole-degree readback does not falsely confirm a fractional MyZone target or trigger a resend', async t => {
  const c = await setup(t, {
    truncateTarget: true,
    configure: data => {
      data.aircons.ac1.zones.z02.setTemp = 23.5;
    },
  });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(18000);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select', 'target']);
  assert.equal(c.writes.at(-1).value, 23.5);
  assert.deepEqual(c.events, []);
  assert.equal(c.warnings.length, 1);
});

test('a reported zone-number change after dispatch cannot confirm the previous selection', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  c.data.aircons.ac1.zones.z02.number = 12;
  await c.advance(1500);
  assert.equal(c.writes.length, 1);
  assert.deepEqual(c.events, []);
  assert.match(c.warnings[0], /number changed/);
});
