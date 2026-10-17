import assert from 'node:assert/strict';
import test from 'node:test';

import { planZoneSwitch, ZoneCommandError } from '../../dist/api/zoneCommand.js';

function snapshot() {
  return {
    info: { myZone: 0, noOfConstants: 1, constant1: 1, state: 'on', mode: 'cool' },
    zones: {
      z01: { number: 1, type: 1, state: 'open', measuredTemp: 23.5 },
      z02: { number: 2, type: 1, state: 'close', measuredTemp: 24.5 },
    },
  };
}

test('planner opens a zone with a state-only patch', () => {
  assert.deepEqual(planZoneSwitch(snapshot(), 'z02', true), {
    kind: 'command',
    requestedState: 'open',
    patch: { zones: { z02: { state: 'open' } } },
  });
});

test('planner allows a constant zone to close even when it is the only open zone', () => {
  assert.deepEqual(planZoneSwitch(snapshot(), 'z01', false), {
    kind: 'command',
    requestedState: 'close',
    patch: { zones: { z01: { state: 'close' } } },
  });
});

test('planner does not use constant counts as its own airflow rule', () => {
  const aircon = snapshot();
  aircon.info.noOfConstants = 2;
  aircon.info.constant2 = 2;
  aircon.zones.z02.state = 'open';
  assert.equal(planZoneSwitch(aircon, 'z01', false).kind, 'command');
});

test('planner returns unchanged when the reported state already matches', () => {
  assert.deepEqual(planZoneSwitch(snapshot(), 'z01', true), {
    kind: 'unchanged', requestedState: 'open',
  });
  assert.deepEqual(planZoneSwitch(snapshot(), 'z02', false), {
    kind: 'unchanged', requestedState: 'close',
  });
});

test('planner refuses to close the active myZone', () => {
  const aircon = snapshot();
  aircon.info.myZone = 1;
  assert.throws(() => planZoneSwitch(aircon, 'z01', false), /Select another myZone/);
});

test('planner permits another zone to close while myZone stays selected', () => {
  const aircon = snapshot();
  aircon.info.myZone = 1;
  aircon.zones.z02.state = 'open';
  assert.deepEqual(planZoneSwitch(aircon, 'z02', false).patch, {
    zones: { z02: { state: 'close' } },
  });
});

test('planner resolves myZone by reported number rather than zone key', () => {
  const aircon = snapshot();
  aircon.info.myZone = 7;
  aircon.zones.z01.number = 7;
  assert.throws(() => planZoneSwitch(aircon, 'z01', false), /Select another myZone/);
});

test('planner rejects missing or ambiguous active myZone addressing', () => {
  const aircon = snapshot();
  aircon.info.myZone = 7;
  assert.throws(() => planZoneSwitch(aircon, 'z01', false), /identified uniquely/);
  aircon.zones.z01.number = 7;
  aircon.zones.z02.number = 7;
  assert.throws(() => planZoneSwitch(aircon, 'z01', false), /identified uniquely/);
});

test('planner refuses a closure when myZone metadata is invalid', () => {
  for (const value of [undefined, null, '0', -1, 1.5, NaN, Infinity]) {
    const aircon = snapshot();
    aircon.info.myZone = value;
    assert.throws(() => planZoneSwitch(aircon, 'z01', false), ZoneCommandError);
  }
});

test('planner can open a zone without needing myZone metadata', () => {
  const aircon = snapshot();
  delete aircon.info.myZone;
  assert.equal(planZoneSwitch(aircon, 'z02', true).kind, 'command');
});

test('planner rejects missing zones and unknown zone states', () => {
  assert.throws(() => planZoneSwitch(snapshot(), 'z99', true), ZoneCommandError);
  assert.throws(() => planZoneSwitch(snapshot(), 'toString', true), ZoneCommandError);
  for (const state of [undefined, null, 'unknown', 'closed']) {
    const aircon = snapshot();
    aircon.zones.z01.state = state;
    assert.throws(() => planZoneSwitch(aircon, 'z01', false), ZoneCommandError);
  }
});

test('planner rejects non-boolean switch requests', () => {
  for (const value of [0, 1, 'false', 'true', undefined, null]) {
    assert.throws(() => planZoneSwitch(snapshot(), 'z02', value), ZoneCommandError);
  }
});

test('planner leaves controller data and airflow settings unchanged', () => {
  const aircon = snapshot();
  aircon.zones.z01.type = 0;
  aircon.zones.z01.value = 35;
  const before = JSON.parse(JSON.stringify(aircon));
  const plan = planZoneSwitch(aircon, 'z01', false);
  assert.deepEqual(aircon, before);
  assert.deepEqual(plan.patch, { zones: { z01: { state: 'close' } } });
  plan.patch.zones.z01.state = 'open';
  assert.deepEqual(aircon, before);
});

test('planner does not switch off the air conditioner to close a zone', () => {
  const aircon = snapshot();
  const plan = planZoneSwitch(aircon, 'z01', false);
  assert.equal(Object.hasOwn(plan.patch, 'info'), false);
  assert.equal(aircon.info.state, 'on');
});
