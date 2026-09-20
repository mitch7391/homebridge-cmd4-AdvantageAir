import assert from 'node:assert/strict';
import test from 'node:test';
import {
  planThermostatMode, planThermostatTemperature, ThermostatCommandError,
} from '../../dist/api/thermostatCommand.js';

function snapshot() {
  return {
    info: { state: 'on', mode: 'cool', fan: 'auto', myZone: 0, setTemp: 24, constant1: 1 },
    zones: {
      z01: { number: 1, type: 1, state: 'open', setTemp: 23, error: 0, rssi: 0 },
      z03: { number: 7, type: 2, state: 'close', setTemp: 25, error: 0 },
      z09: { number: 9, type: 0, state: 'open', value: 40 },
    },
  };
}

test('thermostat Heat and Cool combine power and mode in a single patch', () => {
  for (const mode of ['heat', 'cool']) {
    const aircon = snapshot();
    aircon.info.state = 'off';
    assert.deepEqual(planThermostatMode(aircon, mode), {
      kind: 'command', requestedMode: mode, patch: { info: { state: 'on', mode } },
    });
  }
});

test('matching thermostat mode is unchanged only while the aircon is on', () => {
  assert.deepEqual(planThermostatMode(snapshot(), 'cool'), { kind: 'unchanged', requestedMode: 'cool' });
  const aircon = snapshot();
  aircon.info.mode = 'heat';
  assert.equal(planThermostatMode(aircon, 'heat').kind, 'unchanged');
  aircon.info.state = 'off';
  assert.equal(planThermostatMode(aircon, 'heat').kind, 'command');
});

test('thermostat can select Heat or Cool from another controller mode', () => {
  for (const previous of ['cool', 'heat', 'vent', 'dry', 'unknown']) {
    for (const requested of ['cool', 'heat']) {
      if (previous === requested) {
        continue;
      }
      const aircon = snapshot();
      aircon.info.mode = previous;
      assert.deepEqual(planThermostatMode(aircon, requested).patch,
        { info: { state: 'on', mode: requested } });
    }
  }
});

test('explicit thermostat Off powers down heat, cool, vent and dry without changing stored mode', () => {
  for (const mode of ['heat', 'cool', 'vent', 'dry']) {
    const aircon = snapshot();
    aircon.info.mode = mode;
    assert.deepEqual(planThermostatMode(aircon, 'off'), {
      kind: 'command', requestedMode: 'off', patch: { info: { state: 'off' } },
    });
    assert.equal(aircon.info.mode, mode);
    aircon.info.state = 'off';
    assert.deepEqual(planThermostatMode(aircon, 'off'), { kind: 'unchanged', requestedMode: 'off' });
  }
});

test('thermostat rejects Auto, Dry, Vent and invalid requested modes', () => {
  for (const mode of ['auto', 'dry', 'vent', 'HEAT', '', 0, 1, 2, 3, true, null, undefined]) {
    assert.throws(() => planThermostatMode(snapshot(), mode), ThermostatCommandError);
  }
});

test('mode planning requires a known power state', () => {
  for (const state of [undefined, null, true, 'ON', 'unknown']) {
    const aircon = snapshot();
    aircon.info.state = state;
    for (const mode of ['off', 'heat', 'cool']) {
      assert.throws(() => planThermostatMode(aircon, mode), ThermostatCommandError);
    }
  }
});

test('legacy target updates main and all temperature zones with no myZone, including closed zones', () => {
  assert.deepEqual(planThermostatTemperature(snapshot(), 22.5), {
    kind: 'command', requestedTemperature: 22.5,
    patch: { info: { setTemp: 22.5 }, zones: { z01: { setTemp: 22.5 }, z03: { setTemp: 22.5 } } },
  });
});

test('active myZone uses its reported number rather than a zone key guessed from the number', () => {
  const aircon = snapshot();
  aircon.info.myZone = 7;
  assert.deepEqual(planThermostatTemperature(aircon, 26).patch,
    { info: { setTemp: 26 }, zones: { z03: { setTemp: 26 } } });
  assert.equal(aircon.zones.z01.setTemp, 23);
});

test('replanning follows a changed myZone and does not retain the previous target address', () => {
  const aircon = snapshot();
  aircon.info.myZone = 1;
  const first = planThermostatTemperature(aircon, 26);
  aircon.info.myZone = 7;
  const second = planThermostatTemperature(aircon, 26);
  assert.deepEqual(Object.keys(first.patch.zones), ['z01']);
  assert.deepEqual(Object.keys(second.patch.zones), ['z03']);
});

test('matching main target alone does not suppress required legacy zone updates', () => {
  assert.equal(planThermostatTemperature(snapshot(), 24).kind, 'command');
  const aircon = snapshot();
  aircon.zones.z01.setTemp = 24;
  aircon.zones.z03.setTemp = 24;
  assert.deepEqual(planThermostatTemperature(aircon, 24), {
    kind: 'unchanged', requestedTemperature: 24,
  });
});

test('active myZone no-op checks both main and selected target, ignoring unrelated targets', () => {
  const aircon = snapshot();
  aircon.info.myZone = 7;
  aircon.zones.z03.setTemp = 24;
  assert.equal(planThermostatTemperature(aircon, 24).kind, 'unchanged');
  aircon.info.setTemp = 25;
  assert.equal(planThermostatTemperature(aircon, 24).kind, 'command');
  aircon.info.setTemp = 24;
  aircon.zones.z03.setTemp = 25;
  assert.equal(planThermostatTemperature(aircon, 24).kind, 'command');
});

test('systems with only percentage zones or no zones receive only the main target', () => {
  for (const zones of [{}, { z09: { type: 0, value: 40 } }]) {
    const aircon = snapshot();
    aircon.zones = zones;
    assert.deepEqual(planThermostatTemperature(aircon, 27).patch, { info: { setTemp: 27 } });
  }
});

test('temperature bounds are inclusive and invalid values are refused without coercion or clamping', () => {
  for (const value of [16, 16.5, 24.5, 32]) {
    assert.equal(planThermostatTemperature(snapshot(), value).requestedTemperature, value);
  }
  for (const value of [15.9, 32.1, NaN, Infinity, -Infinity, '24', null, undefined, true]) {
    assert.throws(() => planThermostatTemperature(snapshot(), value), ThermostatCommandError);
  }
});

test('invalid, missing, ambiguous or non-temperature myZone is refused', () => {
  for (const myZone of [undefined, null, '0', -1, 1.5, NaN, Infinity, 99, 9]) {
    const aircon = snapshot();
    aircon.info.myZone = myZone;
    assert.throws(() => planThermostatTemperature(aircon, 26), ThermostatCommandError);
  }
  const aircon = snapshot();
  aircon.info.myZone = 7;
  aircon.zones.z01.number = 7;
  assert.throws(() => planThermostatTemperature(aircon, 26), /identified uniquely/);
});

test('unknown zone capability cannot silently omit a legacy target and writable keys are checked', () => {
  for (const type of [undefined, null, '1', -1, 1.5, NaN, Infinity]) {
    const aircon = snapshot();
    aircon.zones.z03.type = type;
    assert.throws(() => planThermostatTemperature(aircon, 26), ThermostatCommandError);
  }
  const aircon = snapshot();
  aircon.zones.invalid = aircon.zones.z03;
  delete aircon.zones.z03;
  assert.throws(() => planThermostatTemperature(aircon, 26), /addressing is invalid/);
});

test('temperature requests preserve power, mode, airflow and the source snapshot', () => {
  const aircon = snapshot();
  aircon.info.state = 'off';
  const before = globalThis.structuredClone(aircon);
  const plan = planThermostatTemperature(aircon, 26);
  assert.deepEqual(aircon, before);
  assert.deepEqual(Object.keys(plan.patch.info), ['setTemp']);
  plan.patch.info.setTemp = 18;
  plan.patch.zones.z01.setTemp = 18;
  assert.deepEqual(aircon, before);
  const modePlan = planThermostatMode(aircon, 'heat');
  modePlan.patch.info.mode = 'cool';
  assert.deepEqual(aircon, before);
});
