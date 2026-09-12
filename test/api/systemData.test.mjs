import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { URL } from 'node:url';

import {
  IncompleteSystemDataError,
  InvalidSystemDataError,
  validateSystemData,
} from '../../dist/api/systemData.js';

const fixtureFolder = new URL('../testData/', import.meta.url);

for (const filename of fs.readdirSync(fixtureFolder)) {
  if (!filename.endsWith('.txt')) {
    continue;
  }

  test(`validates fixture: ${filename}`, () => {
    const input = JSON.parse(
      fs.readFileSync(new URL(filename, fixtureFolder), 'utf8'),
    );

    if (filename === 'failedAirConRetrieveSystemData.txt') {
      assert.throws(
        () => validateSystemData(input),
        IncompleteSystemDataError,
      );
    } else {
      assert.equal(validateSystemData(input), input);
    }
  });
}

test('accepts a controller explicitly reporting no air conditioners', () => {
  const input = {
    system: { hasAircons: false, noOfAircons: 0 },
    aircons: {},
  };

  assert.equal(validateSystemData(input), input);
});

test('rejects partially missing air conditioners', () => {
  assert.throws(
    () => validateSystemData({
      system: { hasAircons: true, noOfAircons: 2 },
      aircons: { ac2: { info: {}, zones: {} } },
    }),
    IncompleteSystemDataError,
  );
});

test('rejects malformed response structures', () => {
  const invalidResponses = [
    null,
    [],
    {},
    { system: {}, aircons: [] },
    { system: {}, aircons: { ac1: null } },
    { system: {}, aircons: { ac1: { info: {}, zones: [] } } },
    {
      system: {},
      aircons: { ac1: { info: {}, zones: { z01: null } } },
    },
    { system: { noOfAircons: '1' }, aircons: {} },
  ];

  for (const input of invalidResponses) {
    assert.throws(
      () => validateSystemData(input),
      InvalidSystemDataError,
    );
  }
});

test('preserves additional response fields', () => {
  const input = {
    system: { hasAircons: false, noOfAircons: 0 },
    aircons: {},
    myLights: { example: true },
  };

  assert.deepEqual(validateSystemData(input).myLights, { example: true });
});
