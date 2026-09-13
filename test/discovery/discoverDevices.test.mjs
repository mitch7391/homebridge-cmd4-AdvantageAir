import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { URL } from 'node:url';

import { discoverDevices } from '../../dist/discovery/discoverDevices.js';
import { validateSystemData } from '../../dist/api/systemData.js';

function sample() {
  return {
    system: { mid: 'controller-one' },
    aircons: {
      ac1: {
        info: { uid: 'aircon-one', name: 'Air conditioner' },
        zones: {
          z01: { name: 'Living room' },
        },
      },
    },
  };
}

function identities(data) {
  return discoverDevices(data).map(device => device.identity).sort();
}

for (const [filename, airconCount, zoneCount] of [
  ['advantageAirSingleSystem.txt', 1, 6],
  ['advantageAirMultipleSystems.txt', 2, 20],
]) {
  test(`discovers devices from ${filename}`, () => {
    const data = validateSystemData(JSON.parse(fs.readFileSync(
      new URL(`../testData/${filename}`, import.meta.url),
      'utf8',
    )));

    const devices = discoverDevices(data);

    assert.equal(devices.filter(device => device.kind === 'aircon').length, airconCount);
    assert.equal(devices.filter(device => device.kind === 'zone').length, zoneCount);
    assert.equal(new Set(devices.map(device => device.identity)).size, devices.length);
  });
}

test('renaming devices does not change their identities', () => {
  const data = sample();
  const original = identities(data);

  data.aircons.ac1.info.name = 'Renamed air conditioner';
  data.aircons.ac1.zones.z01.name = 'Renamed room';

  assert.deepEqual(identities(data), original);

  const devices = discoverDevices(data);
  assert.equal(devices[0].name, 'Renamed air conditioner');
  assert.equal(devices[1].name, 'Renamed room');
});

test('changing an aircon key preserves identity and updates addressing', () => {
  const data = sample();
  const original = identities(data);

  data.aircons.ac2 = data.aircons.ac1;
  delete data.aircons.ac1;

  assert.deepEqual(identities(data), original);
  assert.ok(discoverDevices(data).every(device => device.airconKey === 'ac2'));
});

test('identical aircon and zone IDs on different controllers remain distinct', () => {
  const first = sample();
  const second = sample();
  second.system.mid = 'controller-two';

  const combined = [...identities(first), ...identities(second)];
  assert.equal(new Set(combined).size, combined.length);
});

test('missing identifiers stop discovery', () => {
  for (const invalidId of [undefined, null, '', '   ', 123]) {
    const missingController = sample();
    missingController.system.mid = invalidId;

    assert.throws(
      () => discoverDevices(missingController),
      /valid controller ID/,
    );

    const missingAircon = sample();
    missingAircon.aircons.ac1.info.uid = invalidId;

    assert.throws(
      () => discoverDevices(missingAircon),
      /valid air conditioner ID/,
    );
  }
});

test('duplicate aircon IDs stop discovery', () => {
  const data = sample();
  data.aircons.ac2 = {
    info: { uid: 'aircon-one', name: 'Another air conditioner' },
    zones: {},
  };

  assert.throws(() => discoverDevices(data), /duplicate air conditioner IDs/);
});

test('missing display names fall back to addressing keys', () => {
  const data = sample();
  delete data.aircons.ac1.info.name;
  data.aircons.ac1.zones.z01.name = '   ';

  const devices = discoverDevices(data);

  assert.equal(devices[0].name, 'ac1');
  assert.equal(devices[1].name, 'z01');
});

test('an empty aircon collection produces no discovery entries', () => {
  assert.deepEqual(discoverDevices({ system: {}, aircons: {} }), []);
});
