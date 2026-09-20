import assert from 'node:assert/strict';
import test from 'node:test';

import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';


function snapshot(state = 'open') {
  return {
    system: { mid: 'controller' },
    aircons: {
      ac1: {
        info: { uid: 'unit', myZone: 0 },
        zones: { z01: { number: 1, state } },
      },
    },
  };
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((done, fail) => {
    resolve = done;
    reject = fail;
  });
  return { promise, resolve, reject };
}

async function flush() {
  for (let i = 0; i < 30; i++) {
    await Promise.resolve();
  }
}

function response(value) {
  return { ok: true, text: async () => JSON.stringify(value) };
}

test('client skips a cancelled write still waiting in the HTTP request queue', async (t) => {
  const readBody = deferred();
  const paths = [];
  t.mock.method(globalThis, 'fetch', async endpoint => {
    paths.push(endpoint.pathname);
    return paths.length === 1
      ? { ok: true, text: () => readBody.promise }
      : response(snapshot());
  });
  const client = new AdvantageAirClient({ ipAddress: '127.0.0.1' });
  const controller = new globalThis.AbortController();
  const read = client.getSystemData();
  const write = assert.rejects(client.requestZoneState('ac1', 'z01', 'close', controller.signal), /cancelled/);
  await flush();
  controller.abort();
  readBody.resolve(JSON.stringify(snapshot()));
  await Promise.all([read, write]);
  assert.deepEqual(paths, ['/getSystemData']);
  await client.getFreshSystemData();
  assert.deepEqual(paths, ['/getSystemData', '/getSystemData']);
});

test('client combines command cancellation with the active fetch signal', async (t) => {
  const controller = new globalThis.AbortController();
  let requestSignal;
  t.mock.method(globalThis, 'fetch', (endpoint, options) => {
    requestSignal = options.signal;
    return new Promise((resolve, reject) => {
      options.signal.addEventListener('abort', () => reject(options.signal.reason), { once: true });
    });
  });
  const client = new AdvantageAirClient({ ipAddress: '127.0.0.1' });
  const write = assert.rejects(client.requestZoneState('ac1', 'z01', 'close', controller.signal), /cancelled/);
  await flush();
  controller.abort();
  await write;
  assert.equal(requestSignal.aborted, true);
});

test('client cancellation remains effective while receiving a write response body', async (t) => {
  const controller = new globalThis.AbortController();
  let readingBody = false;
  t.mock.method(globalThis, 'fetch', async (endpoint, options) => ({
    ok: true,
    text: () => new Promise((resolve, reject) => {
      readingBody = true;
      options.signal.addEventListener('abort', () => reject(options.signal.reason), { once: true });
    }),
  }));
  const client = new AdvantageAirClient({ ipAddress: '127.0.0.1' });
  const write = assert.rejects(client.requestZoneState('ac1', 'z01', 'close', controller.signal), /cancelled/);
  await flush();
  assert.equal(readingBody, true);
  controller.abort();
  await write;
});
