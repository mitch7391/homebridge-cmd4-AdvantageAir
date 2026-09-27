import assert from 'node:assert/strict';
import test from 'node:test';
import { AdvantageAirClient, AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';

const client = () => new AdvantageAirClient({ ipAddress: '192.0.2.1' });

test('MyZone transport sends separate selection and main-target payloads without rounding', async t => {
  const writes = [];
  t.mock.method(globalThis, 'fetch', async url => {
    assert.equal(url.pathname, '/setAircon');
    writes.push(JSON.parse(url.searchParams.get('json')));
    return { ok: true, text: async () => '{}' };
  });

  const c = client();
  assert.deepEqual(await c.requestMyZoneSelection('ac2', 7), {});
  assert.deepEqual(await c.requestMyZoneTarget('ac2', 24.5), {});

  assert.deepEqual(writes, [
    { ac2: { info: { myZone: 7 } } },
    { ac2: { info: { setTemp: 24.5 } } },
  ]);
});

test('MyZone transport refuses disabling, malformed numbers and invalid targets before sending', async t => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('Unexpected request');
  });
  const c = client();

  for (const number of [0, -1, 1.5, '7', undefined, null, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    await assert.rejects(c.requestMyZoneSelection('ac1', number));
  }
  for (const temperature of [15, 33, '24', undefined, null, NaN, Infinity]) {
    await assert.rejects(c.requestMyZoneTarget('ac1', temperature));
  }
  for (const address of ['invalid', 'ac1?extra', '', null, undefined]) {
    await assert.rejects(c.requestMyZoneSelection(address, 7));
    await assert.rejects(c.requestMyZoneTarget(address, 24));
  }

  assert.equal(fetch.mock.callCount(), 0);
});

test('MyZone target transport accepts both documented temperature boundaries', async t => {
  const writes = [];
  t.mock.method(globalThis, 'fetch', async url => {
    writes.push(JSON.parse(url.searchParams.get('json')));
    return { ok: true, text: async () => '{}' };
  });
  const c = client();
  await c.requestMyZoneTarget('ac1', 16);
  await c.requestMyZoneTarget('ac1', 32);
  assert.deepEqual(writes, [
    { ac1: { info: { setTemp: 16 } } },
    { ac1: { info: { setTemp: 32 } } },
  ]);
});

test('explicit rejection is reported once for either MyZone write and the queue remains usable', async t => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return { ok: true, text: async () => calls <= 2 ? 'false' : '{}' };
  });
  const c = client();

  await assert.rejects(c.requestMyZoneSelection('ac1', 7), AirconCommandRejectedError);
  assert.equal(calls, 1);
  await assert.rejects(c.requestMyZoneTarget('ac1', 24), AirconCommandRejectedError);
  assert.equal(calls, 2);
  await c.requestMyZoneSelection('ac1', 9);
  assert.equal(calls, 3);
});

test('ambiguous MyZone transport failure never retries the physical write', async t => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    calls++;
    throw new Error('Private connection detail');
  });
  const c = client();

  await assert.rejects(c.requestMyZoneSelection('ac1', 7), /Could not connect/);
  assert.equal(calls, 1);
  await assert.rejects(c.requestMyZoneTarget('ac1', 24.5), /Could not connect/);
  assert.equal(calls, 2);
});

test('cancelled MyZone writes never reach the controller', async t => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('Unexpected request');
  });
  const abort = new globalThis.AbortController();
  abort.abort();
  const c = client();

  await assert.rejects(c.requestMyZoneSelection('ac1', 7, abort.signal), /cancelled/);
  await assert.rejects(c.requestMyZoneTarget('ac1', 24.5, abort.signal), /cancelled/);
  assert.equal(fetch.mock.callCount(), 0);
});
