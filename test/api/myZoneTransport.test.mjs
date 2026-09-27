import assert from 'node:assert/strict';
import test from 'node:test';
import { AdvantageAirClient, AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';

function setup(t, response = '{}') {
  const writes = [];
  t.mock.method(globalThis, 'fetch', async (url) => {
    assert.equal(url.pathname, '/setAircon');
    writes.push(JSON.parse(url.searchParams.get('json')));
    return { ok: true, status: 200, text: async () => response };
  });
  return { client: new AdvantageAirClient({ ipAddress: '192.0.2.1' }), writes };
}

test('MyZone transport sends separate number-only and exact main-target-only patches', async t => {
  const c = setup(t);
  await c.client.requestMyZoneSelection('ac2', 7);
  await c.client.requestMyZoneTarget('ac2', 23.5);
  assert.deepEqual(c.writes, [
    { ac2: { info: { myZone: 7 } } },
    { ac2: { info: { setTemp: 23.5 } } },
  ]);
});

test('MyZone transport rejects invalid addresses, numbers and targets without sending', async t => {
  const c = setup(t);
  for (const value of [0, -1, 1.5, '7', undefined, Infinity]) {
    await assert.rejects(c.client.requestMyZoneSelection('ac1', value));
  }
  for (const value of [15, 33, '24', undefined, NaN]) {
    await assert.rejects(c.client.requestMyZoneTarget('ac1', value));
  }
  await assert.rejects(c.client.requestMyZoneSelection('invalid', 7));
  await assert.rejects(c.client.requestMyZoneTarget('invalid', 24));
  assert.deepEqual(c.writes, []);
});

test('MyZone transport exposes explicit rejection', async t => {
  const c = setup(t, 'false');
  await assert.rejects(c.client.requestMyZoneSelection('ac1', 7), AirconCommandRejectedError);
  await assert.rejects(c.client.requestMyZoneTarget('ac1', 24), AirconCommandRejectedError);
  assert.equal(c.writes.length, 2);
});

test('cancelled MyZone transport never reaches fetch', async t => {
  const c = setup(t);
  const controller = new globalThis.AbortController();
  controller.abort();
  await assert.rejects(c.client.requestMyZoneSelection('ac1', 7, controller.signal));
  await assert.rejects(c.client.requestMyZoneTarget('ac1', 24, controller.signal));
  assert.deepEqual(c.writes, []);
});
