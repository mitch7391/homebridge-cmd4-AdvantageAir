import assert from 'node:assert/strict';
import test from 'node:test';
import { ControllerCoordinator } from '../../dist/api/controllerCoordinator.js';
import { AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';

const identity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'aircon']);
const zoneIdentity = key => JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', key]);

async function flush() {
  for (let i = 0; i < 60; i++) {
    await Promise.resolve();
  }
}

async function setup(t, options = {}) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const data = {
    system: { mid: 'controller', hasAircons: true, noOfAircons: 1 },
    aircons: {
      ac1: {
        info: { uid: 'unit', name: 'Aircon', state: 'off', mode: 'cool', fan: 'auto', myZone: 1, setTemp: 24 },
        zones: {
          z01: { number: 1, name: 'Living', type: 1, state: 'open', setTemp: 24, error: 0, measuredTemp: 22 },
          z02: { number: 7, name: 'Bedroom', type: 1, state: 'close', setTemp: 23.5, error: 0, measuredTemp: 21 },
          z03: { number: 9, name: 'Guest', type: 1, state: 'open', setTemp: 22, error: 0, measuredTemp: 20 },
          z04: { number: 4, name: 'Percentage', type: 0, state: 'open', value: 50, setTemp: 24 },
        },
      },
    },
  };
  const model = { delay: 1000, reject: '', ambiguous: '', never: '', readFailure: false, autoTarget: false, ...options };
  const writes = [];
  const events = [];
  const progress = [];
  const warnings = [];
  const snapshots = [];
  let transition;
  let held;

  const read = async () => {
    if (held) {
      const wait = held;
      held = undefined;
      await wait;
    }
    if (model.readFailure) {
      throw new Error('Private read detail');
    }
    if (transition && Date.now() >= transition.due && model.never !== transition.action) {
      transition.apply();
      transition = undefined;
    }
    return globalThis.structuredClone(data);
  };
  const send = async (action, details, apply) => {
    writes.push({ action, ...details });
    if (model.reject === action) {
      throw new AirconCommandRejectedError('Private rejection detail');
    }
    transition = { action, apply, due: Date.now() + model.delay };
    if (model.ambiguous === action || model.ambiguous === 'all') {
      throw new Error('Private delivery detail');
    }
    return {};
  };
  const client = {
    getSystemData: read,
    getFreshSystemData: read,
    requestZoneState: (ac, zone, state) => send('open', { ac, zone, state }, () => {
      data.aircons[ac].zones[zone].state = state;
    }),
    requestMyZoneSelection: (ac, number) => send('select', { ac, number }, () => {
      data.aircons[ac].info.myZone = number;
      if (model.autoTarget) {
        data.aircons[ac].info.setTemp = Object.values(data.aircons[ac].zones).find(zone => zone.number === number).setTemp;
      }
    }),
    requestMyZoneTarget: (ac, temperature) => send('target', { ac, temperature }, () => {
      data.aircons[ac].info.setTemp = model.truncate ? Math.trunc(temperature) : temperature;
    }),
    requestFanSpeed: (ac, fan) => send('fan', { ac, fan }, () => {
      data.aircons[ac].info.fan = fan;
    }),
    requestThermostatPatch: (ac, patch) => send('thermostat', { ac, patch }, () => {
      Object.assign(data.aircons[ac].info, patch.info);
      for (const [key, value] of Object.entries(patch.zones ?? {})) {
        Object.assign(data.aircons[ac].zones[key], value);
      }
    }),
  };
  const coordinator = new ControllerCoordinator(
    client,
    state => snapshots.push(globalThis.structuredClone(state)),
    message => warnings.push(message),
    event => events.push(event),
    () => {},
    event => {
      progress.push(event);
      if (model.throwProgress) {
        throw new Error('Observer failure');
      }
    },
  );
  t.after(() => coordinator.stop());
  coordinator.start();
  await flush();
  const advance = async ms => {
    for (let left = ms; left > 0;) {
      const step = Math.min(left, 50);
      t.mock.timers.tick(step);
      left -= step;
      await flush();
    }
  };
  const holdNextRead = () => {
    let release = () => {};
    held = new Promise(resolve => {
      release = resolve;
    });
    return release;
  };
  return { data, model, coordinator, writes, events, progress, warnings, snapshots, advance, holdNextRead };
}

test('MyZone opens, selects the reported number and copies the fractional target without unrelated changes', async t => {
  const c = await setup(t);
  const before = globalThis.structuredClone(c.data);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z02'));
  await c.advance(4000);
  assert.deepEqual(c.writes, [
    { action: 'open', ac: 'ac1', zone: 'z02', state: 'open' },
    { action: 'select', ac: 'ac1', number: 7 },
    { action: 'target', ac: 'ac1', temperature: 23.5 },
  ]);
  before.aircons.ac1.zones.z02.state = 'open';
  before.aircons.ac1.info.myZone = 7;
  before.aircons.ac1.info.setTemp = 23.5;
  assert.deepEqual(c.data, before);
  assert.deepEqual(c.progress.filter(event => event.outcome === 'confirmed').map(event => event.step), ['open', 'select', 'target']);
  assert.equal(c.events.at(-1).outcome, 'confirmed');
  assert.deepEqual(c.warnings, []);
});

test('fresh MyZone no-op performs no physical writes', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z01'));
  await flush();
  assert.deepEqual(c.writes, []);
  assert.equal(c.events.at(-1).outcome, 'unchanged');
});

test('controller-side exact target alignment avoids the target write', async t => {
  const c = await setup(t, { autoTarget: true });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(3000);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select']);
  assert.equal(c.data.aircons.ac1.info.setTemp, 23.5);
  assert.equal(c.events.at(-1).outcome, 'confirmed');
});

test('fresh preflight resolves aircon addressing, reported number and current target', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.data.aircons.ac9 = c.data.aircons.ac1;
  delete c.data.aircons.ac1;
  c.data.aircons.ac9.zones.z02.number = 17;
  c.data.aircons.ac9.zones.z02.setTemp = 25;
  await c.advance(4000);
  assert.ok(c.writes.every(write => write.ac === 'ac9'));
  assert.equal(c.writes[1].number, 17);
  assert.equal(c.writes[2].temperature, 25);
});

test('invalid admission and changed preflight identity cannot dispatch', async t => {
  const c = await setup(t);
  assert.throws(() => c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z04')), /temperature-controlled/);
  c.data.aircons.ac1.info.myZone = 0;
  const release = c.holdNextRead();
  c.coordinator.requestFanSpeed(identity, 25);
  await flush();
  release();
  await c.advance(1200);
  // Obtain a fresh disabled-MyZone snapshot through the existing controller queue.
  assert.throws(() => c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02')), /installer-configured/);
  c.data.aircons.ac1.info.myZone = 1;
  c.coordinator.requestFanSpeed(identity, 50);
  await c.advance(1200);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.data.aircons.ac1.info.uid = 'replacement';
  const count = c.writes.length;
  await c.advance(1000);
  assert.equal(c.writes.length, count);
  assert.match(c.warnings.at(-1), /identity is unavailable/);
});

test('rapid unsent MyZone selections coalesce for the aircon', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  await c.advance(3000);
  assert.deepEqual(c.writes.map(write => write.action), ['select', 'target']);
  assert.equal(c.writes[0].number, 9);
  assert.equal(c.data.aircons.ac1.zones.z02.state, 'close');
});

test('replacement during held preflight prevents the older unsent selection', async t => {
  const c = await setup(t);
  const release = c.holdNextRead();
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  release();
  await c.advance(3000);
  assert.deepEqual(c.writes.map(write => write.action), ['select', 'target']);
  assert.equal(c.writes[0].number, 9);
});

test('a transmitted selection finishes before its replacement and other controls retain queue order', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  assert.equal(c.writes[0].action, 'open');
  c.coordinator.requestFanSpeed(identity, 25);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z03'));
  await c.advance(8000);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select', 'target', 'fan', 'select', 'target']);
  assert.equal(c.events.find(event => event.kind === 'myZone').superseded, true);
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z03'));
});

test('ambiguous delivery at every MyZone step reconciles without resending', async t => {
  const c = await setup(t);
  c.model.ambiguous = 'all';
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(1100);
  await c.advance(3000);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select', 'target']);
  assert.equal(c.events.at(-1).outcome, 'confirmed');
  assert.deepEqual(c.warnings, []);
});

test('opening remains observed after explicit selection rejection, without rollback', async t => {
  const c = await setup(t, { reject: 'select' });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  c.coordinator.requestFanSpeed(identity, 25);
  await c.advance(3000);
  assert.deepEqual(c.writes.map(write => write.action), ['open', 'select']);
  assert.equal(c.data.aircons.ac1.zones.z02.state, 'open');
  assert.equal(c.snapshots.at(-1).data.aircons.ac1.zones.z02.state, 'open');
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z01'));
  assert.match(c.warnings[0], /select step failed.*Earlier confirmed steps: open/);
  assert.ok(c.warnings.some(message => message.includes('Cancelled')));
  assert.equal(c.events.length, 0);
});

test('selected MyZone remains authoritative after target rejection and later selection is accepted', async t => {
  const c = await setup(t, { reject: 'target' });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(3000);
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z02'));
  assert.equal(c.coordinator.readThermostatTemperature(identity), 23.5);
  assert.equal(c.snapshots.at(-1).data.aircons.ac1.info.myZone, 7);
  assert.equal(c.data.aircons.ac1.info.setTemp, 24);
  assert.match(c.warnings[0], /target step failed.*Earlier confirmed steps: open, select/);
  assert.equal(c.events.length, 0);
  c.model.reject = '';
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  await c.advance(3000);
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z03'));
  assert.equal(c.events.at(-1).outcome, 'confirmed');
});

test('fractional main-target normalization fails exact confirmation while retaining actual selection and target', async t => {
  const c = await setup(t, { truncate: true });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(16000);
  assert.equal(c.writes.filter(write => write.action === 'target').length, 1);
  assert.equal(c.data.aircons.ac1.info.setTemp, 23);
  assert.equal(c.data.aircons.ac1.zones.z02.setTemp, 23.5);
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z02'));
  assert.equal(c.snapshots.at(-1).data.aircons.ac1.info.setTemp, 23);
  assert.equal(c.events.length, 0);
  assert.match(c.warnings[0], /target step failed.*Earlier confirmed steps: open, select/);
});

test('target changes during confirmation are observed but never silently substituted or retried', async t => {
  const c = await setup(t, { never: 'target' });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(2200);
  c.data.aircons.ac1.zones.z02.setTemp = 25;
  await c.advance(1500);
  assert.equal(c.writes.filter(write => write.action === 'target').length, 1);
  assert.match(c.warnings[0], /target changed/);
  assert.equal(c.coordinator.readThermostatTemperature(identity), 25);
});

test('number changes after transmission fail without redirecting the remaining writes', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  c.data.aircons.ac1.zones.z02.number = 17;
  await c.advance(1500);
  assert.deepEqual(c.writes.map(write => write.action), ['open']);
  assert.match(c.warnings[0], /number changed after dispatch/);
});

test('the execution budget covers the whole sequence, not a renewed budget per step', async t => {
  const c = await setup(t, { delay: 6000 });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(16000);
  assert.equal(c.events.length, 0);
  assert.equal(c.coordinator.readMyZoneSelection(identity), zoneIdentity('z02'));
  assert.match(c.warnings[0], /target step failed/);
  assert.equal(c.writes.length, 3);
});

test('expired unsent MyZone intentions produce no writes', async t => {
  const c = await setup(t);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  t.mock.timers.tick(30000);
  await flush();
  assert.deepEqual(c.writes, []);
  assert.ok(c.warnings.some(message => message.includes('expired')));
});

test('shutdown during preflight prevents late writes and publication', async t => {
  const c = await setup(t);
  const release = c.holdNextRead();
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await flush();
  c.coordinator.stop();
  const count = c.snapshots.length;
  release();
  await flush();
  assert.deepEqual(c.writes, []);
  assert.equal(c.snapshots.length, count);
  assert.throws(() => c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02')), /Fresh controller data/);
});

test('shutdown after a confirmed open prevents remaining selection steps', async t => {
  const c = await setup(t, { delay: 3000 });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(3100);
  c.coordinator.stop();
  const count = c.writes.length;
  await c.advance(20000);
  assert.equal(c.writes.length, count);
  assert.equal(c.events.length, 0);
});

test('stale observed data refuses MyZone reads and new selections', async t => {
  const c = await setup(t);
  c.model.readFailure = true;
  await c.advance(91000);
  assert.throws(() => c.coordinator.readMyZoneSelection(identity), /Fresh controller data/);
  assert.throws(() => c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02')), /Fresh controller data/);
  assert.deepEqual(c.writes, []);
});

test('thermostat requests before and after selection target the correct reference zone', async t => {
  const c = await setup(t);
  c.coordinator.requestThermostatTemperature(identity, 26);
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(5000);
  assert.equal(c.data.aircons.ac1.zones.z01.setTemp, 26);
  assert.equal(c.data.aircons.ac1.zones.z02.setTemp, 23.5);
  assert.equal(c.data.aircons.ac1.info.setTemp, 23.5);

  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z03'));
  c.coordinator.requestThermostatTemperature(identity, 25);
  await c.advance(4000);
  assert.equal(c.data.aircons.ac1.info.myZone, 9);
  assert.equal(c.data.aircons.ac1.info.setTemp, 25);
  assert.equal(c.data.aircons.ac1.zones.z03.setTemp, 25);
  assert.equal(c.data.aircons.ac1.zones.z02.setTemp, 23.5);
  assert.deepEqual(c.warnings, []);
});

test('progress observer failures cannot interrupt MyZone execution', async t => {
  const c = await setup(t, { throwProgress: true });
  c.coordinator.requestMyZoneSelection(identity, zoneIdentity('z02'));
  await c.advance(4000);
  assert.equal(c.events.at(-1).outcome, 'confirmed');
  assert.deepEqual(c.warnings, []);
});
