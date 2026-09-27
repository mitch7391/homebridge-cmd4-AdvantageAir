import assert from 'node:assert/strict';
import test from 'node:test';
import { MyZoneCommandError, planMyZoneSelection } from '../../dist/api/myZoneCommand.js';

function fixture() {
  return {
    info: { myZone: 1, setTemp: 24, state: 'off', mode: 'cool', fan: 'auto' },
    zones: {
      z01: { number: 1, type: 1, state: 'open', setTemp: 24, value: 100 },
      z02: { number: 7, type: 2, state: 'close', setTemp: 22, value: 40 },
      z03: { number: 9, type: 0, state: 'open', value: 55 },
    },
  };
}

test('MyZone plans opening, selection and target alignment in order without modifying input', () => {
  const data = fixture();
  const before = globalThis.structuredClone(data);
  assert.deepEqual(planMyZoneSelection(data, 'z02'), {
    action: 'open', zoneNumber: 7, temperature: 22,
  });
  assert.deepEqual(data, before);

  data.zones.z02.state = 'open';
  assert.equal(planMyZoneSelection(data, 'z02').action, 'select');

  data.info.myZone = 7;
  assert.equal(planMyZoneSelection(data, 'z02').action, 'temperature');

  data.info.setTemp = 22;
  assert.equal(planMyZoneSelection(data, 'z02').action, 'unchanged');
  assert.deepEqual(data.zones.z03, before.zones.z03);
});

test('MyZone uses the reported number, including after a fresh number or target change', () => {
  const data = fixture();
  data.zones.z02.state = 'open';
  data.zones.z02.number = 12;
  data.zones.z02.setTemp = 26;
  assert.deepEqual(planMyZoneSelection(data, 'z02'), {
    action: 'select', zoneNumber: 12, temperature: 26,
  });
});

test('MyZone refuses disabled or invalid installer configuration', () => {
  for (const value of [0, -1, 1.5, '1', null, undefined, NaN, Infinity]) {
    const data = fixture();
    data.info.myZone = value;
    assert.throws(() => planMyZoneSelection(data, 'z02'), MyZoneCommandError);
  }
});

test('MyZone refuses missing and non-temperature targets', () => {
  const data = fixture();
  assert.throws(() => planMyZoneSelection(data, 'missing'), /unavailable/);
  assert.throws(() => planMyZoneSelection(data, 'z03'), /temperature-controlled/);
  for (const type of [undefined, null, '1', -1, 1.5]) {
    data.zones.z02.type = type;
    assert.throws(() => planMyZoneSelection(data, 'z02'), /temperature-controlled/);
  }
});

test('MyZone refuses invalid or duplicate requested zone numbers', () => {
  for (const number of [undefined, null, '7', 0, -1, 1.5, Infinity, 1]) {
    const data = fixture();
    data.zones.z02.number = number;
    assert.throws(() => planMyZoneSelection(data, 'z02'), MyZoneCommandError);
  }
  const data = fixture();
  data.zones.z03.number = 7;
  assert.throws(() => planMyZoneSelection(data, 'z02'), /ambiguous/);
});

test('MyZone refuses missing, ambiguous or non-temperature active selections', () => {
  const data = fixture();
  data.info.myZone = 99;
  assert.throws(() => planMyZoneSelection(data, 'z02'), /uniquely/);
  data.info.myZone = 1;
  data.zones.z03.number = 1;
  assert.throws(() => planMyZoneSelection(data, 'z02'), /uniquely/);
  data.zones.z03.number = 9;
  data.zones.z01.type = 0;
  assert.throws(() => planMyZoneSelection(data, 'z02'), /temperature-controlled/);
});

test('MyZone validates state and target before opening or selecting', () => {
  const data = fixture();
  data.zones.z02.state = 'unknown';
  assert.throws(() => planMyZoneSelection(data, 'z02'), /state is unavailable/);
  data.zones.z02.state = 'close';
  for (const target of [undefined, null, '22', NaN, Infinity, 15, 33]) {
    data.zones.z02.setTemp = target;
    assert.throws(() => planMyZoneSelection(data, 'z02'), /valid temperature/);
  }
  for (const target of [16, 32]) {
    data.zones.z02.setTemp = target;
    assert.equal(planMyZoneSelection(data, 'z02').temperature, target);
  }
});

test('MyZone no-op does not require a reported damper value of 100', () => {
  const data = fixture();
  data.info.myZone = 7;
  data.info.setTemp = 22;
  data.zones.z02.state = 'open';
  assert.equal(planMyZoneSelection(data, 'z02').action, 'unchanged');
});

test('MyZone repairs a closed selected zone before checking target alignment', () => {
  const data = fixture();
  data.info.myZone = 7;
  data.info.setTemp = 22;
  assert.equal(planMyZoneSelection(data, 'z02').action, 'open');
});

test('MyZone preserves fractional targets and replans from each fresh observation', () => {
  const data = fixture();
  data.zones.z02.setTemp = 24.5;

  assert.deepEqual(planMyZoneSelection(data, 'z02'), {
    action: 'open', zoneNumber: 7, temperature: 24.5,
  });

  data.zones.z02.state = 'open';
  assert.equal(planMyZoneSelection(data, 'z02').action, 'select');

  // A fresh observation can change the target before alignment.
  data.info.myZone = 7;
  data.zones.z02.setTemp = 23.5;
  assert.deepEqual(planMyZoneSelection(data, 'z02'), {
    action: 'temperature', zoneNumber: 7, temperature: 23.5,
  });

  // A whole-degree main target does not establish an undocumented equivalence.
  data.info.setTemp = 23;
  assert.equal(planMyZoneSelection(data, 'z02').action, 'temperature');

  data.info.setTemp = 23.5;
  assert.equal(planMyZoneSelection(data, 'z02').action, 'unchanged');
});
