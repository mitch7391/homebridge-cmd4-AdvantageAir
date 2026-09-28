import assert from 'node:assert/strict';
import test from 'node:test';
import { activeMyZoneNumber, myZoneTarget, planMyZoneSelection } from '../../dist/api/myZoneCommand.js';

function aircon() {
  return {
    info: { myZone: 1, setTemp: 24, state: 'off', mode: 'cool', fan: 'auto' },
    zones: {
      z01: { number: 1, type: 1, state: 'open', setTemp: 24 },
      z02: { number: 7, type: 2, state: 'close', setTemp: 23.5 },
      z03: { number: 9, type: 0, state: 'open', setTemp: 22, value: 50 },
    },
  };
}

test('MyZone planner preserves fractional targets and uses reported numbers without mutation', () => {
  const data = aircon();
  const before = globalThis.structuredClone(data);
  assert.deepEqual(planMyZoneSelection(data, 'z02'), {
    zoneNumber: 7, temperature: 23.5, open: false, selected: false, targetMatches: false,
  });
  assert.deepEqual(data, before);
});

test('MyZone planner identifies already satisfied selection and target', () => {
  const data = aircon();
  assert.deepEqual(planMyZoneSelection(data, 'z01'), {
    zoneNumber: 1, temperature: 24, open: true, selected: true, targetMatches: true,
  });
});

test('MyZone admission never enables installer-disabled or invalid MyZone', () => {
  for (const value of [0, -1, 1.5, undefined, null, '1', NaN, Infinity]) {
    const data = aircon();
    data.info.myZone = value;
    assert.throws(() => planMyZoneSelection(data, 'z02'), /installer-configured/);
  }
});

test('MyZone rejects invalid capability, state, addressing and ambiguous numbers', () => {
  const edits = [
    data => {
      delete data.zones.z02;
    },
    data => {
      data.zones.z02.type = 0;
    },
    data => {
      data.zones.z02.type = undefined;
    },
    data => {
      data.zones.z02.state = 'unknown';
    },
    data => {
      data.zones.z02.number = 0;
    },
    data => {
      data.zones.z02.number = 7.5;
    },
    data => {
      data.zones.z03.number = 7;
    },
    data => {
      data.zones.z03.number = 1;
    },
    data => {
      data.zones.z01.type = 0;
    },
    data => {
      data.info.myZone = 99;
    },
  ];
  for (const edit of edits) {
    const data = aircon();
    edit(data);
    assert.throws(() => planMyZoneSelection(data, 'z02'));
  }
  assert.throws(() => planMyZoneSelection(aircon(), 'constructor'));
});

test('MyZone target validation is separate from thermostat whole-degree input policy', () => {
  for (const value of [16, 16.5, 23.5, 32]) {
    assert.equal(myZoneTarget(value), value);
  }
  for (const value of [15.5, 32.5, undefined, null, '24', NaN, Infinity]) {
    assert.throws(() => myZoneTarget(value));
  }
});

test('MyZone classification uses type rather than RSSI or fabricated sensor readings', () => {
  const data = aircon();
  Object.assign(data.zones.z02, { rssi: 0, measuredTemp: 0 });
  assert.equal(planMyZoneSelection(data, 'z02').zoneNumber, 7);
  assert.equal(activeMyZoneNumber(data), 1);
});
