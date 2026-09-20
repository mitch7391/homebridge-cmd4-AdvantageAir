import assert from 'node:assert/strict';
import test from 'node:test';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { ControllerBusyError } from '../../dist/api/systemData.js';

const valid = { system: {}, aircons: {} };

function setup(t, respond, onDiagnostic) {
  const events = [];
  let requests = 0;
  t.mock.method(globalThis, 'fetch', async (...args) => {
    requests++;
    return respond(...args);
  });
  const client = new AdvantageAirClient({
    ipAddress: '192.0.2.99', timeoutMs: 100,
    onDiagnostic: onDiagnostic ?? (event => events.push(event)),
  });
  return { client, events, requests: () => requests };
}

test('diagnostics describe shared reads once and never expose response fields or addresses', async t => {
  const secret = 'PRIVATE-PIN-TOKEN-LOCATION';
  const c = setup(t, async () => ({
    ok: true, status: 200,
    text: async () => JSON.stringify({ ...valid, system: { mid: secret, pin: secret }, private: secret }),
  }));
  const [a, b] = await Promise.all([c.client.getSystemData(), c.client.getSystemData()]);
  assert.equal(a, b);
  assert.equal(c.requests(), 1);
  assert.deepEqual(c.events.map(event => event.event), ['send', 'headers', 'body']);
  assert.equal(c.events[2].json, 'object');
  for (const event of c.events) {
    assert.equal(event.id, 1);
    assert.equal(event.endpoint, '/getSystemData');
    assert.ok(event.elapsedMs >= 0);
    assert.ok(Object.keys(event).every(key => ['id', 'endpoint', 'event', 'elapsedMs', 'status', 'json'].includes(key)));
  }
  assert.equal(JSON.stringify(c.events).includes(secret), false);
  assert.equal(JSON.stringify(c.events).includes('192.0.2.99'), false);
});

test('body timing is emitted only after the body completes and includes its wait', async t => {
  let release;
  let now = 10;
  t.mock.method(globalThis.performance, 'now', () => now);
  const c = setup(t, async () => ({ ok: true, status: 200,
    text: () => new Promise(resolve => {
      release = resolve;
    }),
  }));
  const request = c.client.getSystemData();
  for (let i = 0; i < 10; i++) {
    await Promise.resolve();
  }
  assert.deepEqual(c.events.map(event => event.event), ['send', 'headers']);
  now = 1510;
  release(JSON.stringify(valid));
  await request;
  assert.equal(c.events.at(-1).elapsedMs, 1500);
});

test('busy and explicitly rejected replies have distinct summaries without command query data', async t => {
  const c = setup(t, async url => ({ ok: true, status: 200,
    text: async () => url.pathname === '/getSystemData' ? '{}' : 'false',
  }));
  await assert.rejects(c.client.getSystemData(), ControllerBusyError);
  await assert.rejects(c.client.requestZoneState('ac1', 'z03', 'close'));
  assert.equal(c.events[2].json, 'empty-object');
  assert.equal(c.events.at(-1).rejected, true);
  assert.equal(c.events.at(-1).id, 2);
  assert.equal(c.events.at(-1).endpoint, '/setAircon');
  assert.equal(JSON.stringify(c.events).includes('z03'), false);
  assert.equal(c.requests(), 2);
});

for (const [reason, response] of [
  ['connect', async () => {
    throw new Error('PRIVATE transport address');
  }],
  ['http', async () => ({ ok: false, status: 503, body: { cancel: async () => {} } })],
  ['body', async () => ({ ok: true, status: 200, text: async () => {
    throw new Error('PRIVATE response');
  } })],
  ['json', async () => ({ ok: true, status: 200, text: async () => 'PRIVATE invalid JSON' })],
]) {
  test(`diagnostics sanitize ${reason} failures and do not retry`, async t => {
    const c = setup(t, response);
    await assert.rejects(c.client.getSystemData());
    assert.equal(c.events.at(-1).event, 'error');
    assert.equal(c.events.at(-1).reason, reason);
    assert.equal(JSON.stringify(c.events).includes('PRIVATE'), false);
    assert.equal(c.requests(), 1);
  });
}

for (const reason of ['timeout', 'cancelled']) {
  test(`diagnostics distinguish ${reason} while waiting for the body`, async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const abort = new globalThis.AbortController();
    const c = setup(t, async (_, { signal }) => ({ ok: true, status: 200,
      text: () => new Promise((resolve, reject) => {
        signal.addEventListener('abort', () => reject(new Error('PRIVATE')), { once: true });
      }),
    }));
    const request = c.client.getSystemData(abort.signal);
    const rejected = assert.rejects(request);
    for (let i = 0; i < 10; i++) {
      await Promise.resolve();
    }
    if (reason === 'timeout') {
      t.mock.timers.tick(100);
    } else {
      abort.abort();
    }
    await rejected;
    assert.equal(c.events.at(-1).reason, reason);
    assert.equal(c.requests(), 1);
  });
}

test('throwing diagnostic observers do not change successes, failures, or subsequent queue progress', async t => {
  let fail = false;
  const c = setup(t, async () => {
    if (fail) {
      throw new Error('network failure');
    }
    return { ok: true, status: 200, text: async () => JSON.stringify(valid) };
  }, () => {
    throw new Error('logger failed');
  });
  assert.deepEqual(await c.client.getSystemData(), valid);
  fail = true;
  await assert.rejects(c.client.getSystemData(), /Could not connect/);
  fail = false;
  assert.deepEqual(await c.client.getSystemData(), valid);
  assert.equal(c.requests(), 3);
});
