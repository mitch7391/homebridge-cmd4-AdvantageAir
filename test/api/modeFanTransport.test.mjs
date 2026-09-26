import assert from 'node:assert/strict';
import test from 'node:test';
import { AdvantageAirClient, AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';

const client = () => new AdvantageAirClient({ ipAddress: '192.0.2.1' });

test('mode transport encodes only Vent, Dry or power-off and leaves acknowledgement unconfirmed', async t => {
  const writes = [];
  t.mock.method(globalThis, 'fetch', async url => {
    assert.equal(url.pathname, '/setAircon');
    writes.push(JSON.parse(url.searchParams.get('json')));
    return { ok: true, text: async () => '{}' };
  });
  const c = client();
  const patches = [{ info: { state: 'on', mode: 'vent' } }, { info: { state: 'on', mode: 'dry' } },
    { info: { state: 'off' } }];
  for (const patch of patches) {
    assert.deepEqual(await c.requestModeFanPatch('ac2', patch), {});
  }
  assert.deepEqual(writes, patches.map(patch => ({ ac2: patch })));
});

test('mode transport refuses malformed or unrelated settings without sending', async t => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('Unexpected request');
  });
  const c = client();
  for (const patch of [null, [], {}, { info: [] }, { info: { state: 'on' } },
    { info: { state: 'on', mode: 'cool' } }, { info: { state: 'off', mode: 'dry' } },
    { info: { state: 'on', mode: 'dry', fan: 'high' } },
    { info: { state: 'off' }, zones: {} }]) {
    await assert.rejects(c.requestModeFanPatch('ac1', patch));
  }
  await assert.rejects(c.requestModeFanPatch('invalid', { info: { state: 'off' } }));
  assert.equal(fetch.mock.callCount(), 0);
});

test('rejected mode command is not retried and does not block the next request', async t => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => ({ ok: true, text: async () => ++calls === 1 ? 'false' : '{}' }));
  const c = client();
  await assert.rejects(c.requestModeFanPatch('ac1', { info: { state: 'on', mode: 'dry' } }), AirconCommandRejectedError);
  assert.equal(calls, 1);
  await c.requestModeFanPatch('ac1', { info: { state: 'on', mode: 'vent' } });
  assert.equal(calls, 2);
});

test('cancelled mode command never reaches the controller', async t => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => {
    throw new Error('Unexpected request');
  });
  const abort = new globalThis.AbortController();
  abort.abort();
  await assert.rejects(client().requestModeFanPatch('ac1', { info: { state: 'off' } }, abort.signal));
  assert.equal(fetch.mock.callCount(), 0);
});
