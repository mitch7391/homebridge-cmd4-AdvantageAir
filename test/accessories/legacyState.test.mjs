import assert from 'node:assert/strict';
import test from 'node:test';
import { URL } from 'node:url';
import fs from 'node:fs';

import {
  UnavailableStateError,
  fanSpeedPercentage,
  ventilationIsOn,
  zoneIsOpen,
  zoneTemperature,
  thermostatCurrentTemperature,
  thermostatTargetTemperature,
  thermostatTargetMode,
} from '../../dist/accessories/legacyState.js';

function aircon(info) {
  return { info, zones: {} };
}

test('ventilation is on only when powered on in vent mode', () => {
  assert.equal(ventilationIsOn(aircon({ state: 'on', mode: 'vent' })), true);

  for (const mode of ['heat', 'cool', 'dry']) {
    assert.equal(ventilationIsOn(aircon({ state: 'on', mode })), false);
  }

  assert.equal(ventilationIsOn(aircon({ state: 'off', mode: 'vent' })), false);
});

test('unknown power or active mode is unavailable', () => {
  assert.throws(
    () => ventilationIsOn(aircon({ state: 'unknown', mode: 'vent' })),
    UnavailableStateError,
  );

  assert.throws(
    () => ventilationIsOn(aircon({ state: 'on', mode: 'unknown' })),
    UnavailableStateError,
  );
});

test('fan speeds retain the legacy percentage mapping', () => {
  for (const [fan, expected] of [
    ['low', 25],
    ['medium', 50],
    ['high', 90],
    ['auto', 100],
    ['autoAA', 100],
  ]) {
    assert.equal(fanSpeedPercentage(aircon({ fan })), expected);
  }
});

test('unknown fan speeds are not silently treated as automatic', () => {
  for (const fan of [undefined, null, '', 'unexpected']) {
    assert.throws(
      () => fanSpeedPercentage(aircon({ fan })),
      UnavailableStateError,
    );
  }
});

test('zone switches reflect open and closed positions', () => {
  assert.equal(zoneIsOpen({ state: 'open' }), true);
  assert.equal(zoneIsOpen({ state: 'close' }), false);
});

test('unknown zone positions are unavailable', () => {
  for (const state of [undefined, null, '', 'unknown']) {
    assert.throws(() => zoneIsOpen({ state }), UnavailableStateError);
  }
});

test('zone temperature preserves finite numeric readings including zero', () => {
  for (const measuredTemp of [0, 18.5, 25.4]) {
    assert.equal(zoneTemperature({ measuredTemp }), measuredTemp);
  }
});

test('missing or invalid temperatures are unavailable', () => {
  for (const measuredTemp of [undefined, null, '25', NaN, Infinity, -Infinity]) {
    assert.throws(
      () => zoneTemperature({ measuredTemp }),
      UnavailableStateError,
    );
  }
});

function temperatureSystem() {
  return aircon({
    myZone: 0,
    constant1: 1,
    setTemp: 24,
  });
}

function systemWithSensors() {
  const data = temperatureSystem();

  data.zones = {
    z01: {
      number: 1,
      type: 1,
      error: 0,
      measuredTemp: 23.1,
      setTemp: 24,
    },
    z02: {
      number: 2,
      type: 1,
      error: 0,
      measuredTemp: 18.9,
      setTemp: 22,
    },
  };

  return data;
}

test('thermostat uses the first constant zone without an active myZone', () => {
  const data = systemWithSensors();

  assert.equal(thermostatCurrentTemperature(data), 23.1);
  assert.equal(thermostatTargetTemperature(data), 24);
});

test('active myZone supplies measured and target temperatures', () => {
  const data = systemWithSensors();
  data.info.myZone = 2;

  assert.equal(thermostatCurrentTemperature(data), 18.9);
  assert.equal(thermostatTargetTemperature(data), 22);
});

test('reference zones are located by number rather than their key', () => {
  const data = systemWithSensors();
  data.zones.renamedKey = data.zones.z01;
  delete data.zones.z01;

  assert.equal(thermostatCurrentTemperature(data), 23.1);
});

test('failed myZone sensor does not fall back to a different room', () => {
  const data = systemWithSensors();
  data.info.myZone = 2;
  data.zones.z02.error = 1;

  assert.throws(
    () => thermostatCurrentTemperature(data),
    UnavailableStateError,
  );
  assert.equal(thermostatTargetTemperature(data), 22);
});

test('unusable reference sensors are rejected', () => {
  for (const change of [
    { type: 0 },
    { type: undefined },
    { error: 1 },
    { error: undefined },
    { tempSensorClash: true },
    { measuredTemp: undefined },
  ]) {
    const data = systemWithSensors();
    Object.assign(data.zones.z01, change);

    assert.throws(
      () => thermostatCurrentTemperature(data),
      UnavailableStateError,
    );
  }
});

test('missing or duplicate reference zones are rejected', () => {
  const missing = systemWithSensors();
  delete missing.zones.z01;

  const duplicate = systemWithSensors();
  duplicate.zones.z02.number = 1;

  for (const data of [missing, duplicate]) {
    assert.throws(
      () => thermostatCurrentTemperature(data),
      UnavailableStateError,
    );
  }
});

test('target temperature cannot substitute for missing measured temperature', () => {
  const data = systemWithSensors();
  delete data.zones.z01.measuredTemp;

  assert.equal(thermostatTargetTemperature(data), 24);
  assert.throws(
    () => thermostatCurrentTemperature(data),
    UnavailableStateError,
  );
});

test('invalid temperature-control selections are rejected', () => {
  for (const myZone of [undefined, null, '0', -1, 1.5]) {
    const data = systemWithSensors();
    data.info.myZone = myZone;

    assert.throws(
      () => thermostatCurrentTemperature(data),
      UnavailableStateError,
    );
    assert.throws(
      () => thermostatTargetTemperature(data),
      UnavailableStateError,
    );
  }
});

test('target temperatures must be finite numbers within 16 to 32 degrees', () => {
  for (const target of [16, 24, 32]) {
    const data = systemWithSensors();
    data.info.setTemp = target;
    assert.equal(thermostatTargetTemperature(data), target);
  }

  for (const target of [undefined, null, '24', 15, 33, NaN, Infinity]) {
    const data = systemWithSensors();
    data.info.setTemp = target;

    assert.throws(
      () => thermostatTargetTemperature(data),
      UnavailableStateError,
    );
  }
});

test('powered-off aircon presents thermostat Off regardless of stored mode', () => {
  for (const mode of ['heat', 'cool', 'vent', 'dry']) {
    assert.equal(
      thermostatTargetMode(aircon({ state: 'off', mode })),
      'off',
    );
  }
});

test('powered-on heating and cooling map to their thermostat modes', () => {
  for (const mode of ['heat', 'cool']) {
    assert.equal(
      thermostatTargetMode(aircon({ state: 'on', mode })),
      mode,
    );
  }
});

test('vent and dry never map to thermostat Auto or alter controller data', () => {
  for (const mode of ['vent', 'dry']) {
    const data = aircon({ state: 'on', mode });
    const before = JSON.stringify(data);

    assert.equal(thermostatTargetMode(data), 'off');
    assert.equal(JSON.stringify(data), before);
  }
});

test('unknown thermostat power or active mode is unavailable', () => {
  for (const info of [
    { state: 'unknown', mode: 'cool' },
    { state: 'on', mode: 'unknown' },
    { state: 'on', mode: 'auto' },
  ]) {
    assert.throws(
      () => thermostatTargetMode(aircon(info)),
      UnavailableStateError,
    );
  }
});

function sensorless() {
  // Retained percentage-zone lab payload: explicit type 0, myZone/constant1 0.
  return JSON.parse(fs.readFileSync(new URL('../../dev/lab/fixtures/percentage.json', import.meta.url))).aircons.ac1;
}

test('sensorless thermostat displays the observed AC setpoint with or without a constant zone', () => {
  for (const constant1 of [0, 6]) {
    const data = sensorless();
    data.info.constant1 = constant1;
    data.zones.z06.measuredTemp = -20; // Type-0 placeholder is not a sensor reading.
    assert.equal(thermostatCurrentTemperature(data), 24);
    data.info.setTemp = 27;
    assert.equal(thermostatCurrentTemperature(data), 27);
    assert.equal(thermostatTargetTemperature(data), 27);
  }
});

test('sensorless fallback refuses incomplete or ambiguous topology and invalid setpoints', () => {
  const changes = [
    data => {
      data.zones = {};
    },
    data => {
      delete data.zones.z06.type;
    },
    data => {
      data.zones.z06.type = '0';
    },
    data => {
      data.info.myZone = 6;
    },
    data => {
      delete data.info.myZone;
    },
    data => {
      delete data.info.constant1;
    },
    data => {
      data.info.constant1 = 1;
    },
    data => {
      data.info.noOfZones = 2;
    },
    data => {
      delete data.info.noOfZones;
    },
    data => {
      data.zones.z06.number = undefined;
    },
    data => {
      data.zones.z07 = { ...data.zones.z06 };
      data.info.noOfZones = 2;
      data.info.constant1 = 6;
    },
  ];
  for (const change of changes) {
    const data = sensorless();
    change(data);
    assert.throws(() => thermostatCurrentTemperature(data), UnavailableStateError);
  }
  for (const setTemp of [undefined, null, '24', NaN, Infinity, 15, 33]) {
    const data = sensorless();
    data.info.setTemp = setTemp;
    assert.throws(() => thermostatCurrentTemperature(data), UnavailableStateError);
  }
});

test('a declared temperature sensor never uses the fallback on radio, measurement or sensor failure', () => {
  for (const patch of [{ error: 1 }, { measuredTemp: undefined }, { tempSensorClash: true }]) {
    const data = sensorless();
    data.info.constant1 = 6;
    Object.assign(data.zones.z06, { type: 1, error: 0, measuredTemp: 21.5, rssi: 0 }, patch);
    assert.throws(() => thermostatCurrentTemperature(data), UnavailableStateError);
  }
  const data = sensorless();
  data.info.constant1 = 6;
  Object.assign(data.zones.z06, { type: 1, error: 0, measuredTemp: 21.5 });
  assert.equal(thermostatCurrentTemperature(data), 21.5);
});

test('retained historical sensorless payload uses its main setpoint despite duplicate non-reference zone numbers', () => {
  const data = JSON.parse(fs.readFileSync(new URL('../testData/advantageAirMultipleSystems.txt', import.meta.url))).aircons.ac1;
  assert.ok(Object.values(data.zones).every(zone => zone.type === 0));
  assert.equal(thermostatCurrentTemperature(data), data.info.setTemp);
});
