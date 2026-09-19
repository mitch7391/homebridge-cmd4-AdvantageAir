import assert from 'node:assert/strict';
import test from 'node:test';

import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { ZoneCommandExecutor } from '../../dist/api/zoneCommandExecutor.js';

const identity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', 'z03']);

function snapshot(state) {
  return {
    system: { mid: 'controller' },
    aircons: {
      ac1: {
        info: { uid: 'unit', myZone: 0, constant1: 1 },
        zones: { z03: { number: 3, type: 1, state } },
      },
    },
  };
}

async function flush() {
  for (let i = 0; i < 40; i++) {
    await Promise.resolve();
  }
}

function prepare(t, initial, preflightMs, writeMs, confirmations) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const requests = [];
  let reads = 0;
  t.mock.method(globalThis, 'fetch', async (url) => {
    const endpoint = url.pathname;
    requests.push(endpoint);
    let value;
    let elapsed;
    if (endpoint === '/setAircon') {
      value = {};
      elapsed = writeMs;
    } else {
      assert.equal(endpoint, '/getSystemData');
      const reply = reads === 0
        ? [preflightMs, snapshot(initial)]
        : confirmations[reads - 1];
      assert.ok(reply, 'Unexpected extra confirmation request');
      [elapsed, value] = reply;
      reads++;
    }
    await new Promise(resolve => globalThis.setTimeout(resolve, elapsed));
    return { ok: true, text: async () => JSON.stringify(value) };
  });
  const client = new AdvantageAirClient({ ipAddress: '192.0.2.1' });
  const executor = new ZoneCommandExecutor(client);
  t.after(() => executor.stop());
  let settled;
  const completion = executor.setZone(identity, initial === 'close').then(
    value => {
      settled = { value };
    },
    error => {
      settled = { error };
    },
  );
  const advance = async (ms) => {
    t.mock.timers.tick(ms);
    await flush();
  };
  return { requests, completion, advance, settled: () => settled };
}

test('live close sequence confirms after empty responses and one stale response', async (t) => {
  const replies = [[167, {}], [124, {}], [122, {}], [127, snapshot('open')], [123, snapshot('close')]];
  const trial = prepare(t, 'open', 382, 35, replies);
  await flush();
  await trial.advance(382);
  await trial.advance(35);
  for (const [latency] of replies) {
    await trial.advance(1000);
    await trial.advance(latency);
  }
  await trial.completion;
  assert.equal(trial.settled().value.outcome, 'confirmed');
  assert.equal(trial.requests.filter(path => path === '/setAircon').length, 1);
});

test('default confirmation uses remaining deadline after four empty replies and a stale fifth reply', async (t) => {
  // The first five replies follow the failed live opening trace. A sixth
  // matching reply is a test scenario, not a response observed in that trace.
  const replies = [[91, {}], [127, {}], [126, {}], [122, {}], [123, snapshot('close')], [120, snapshot('open')]];
  const trial = prepare(t, 'close', 39, 28, replies);
  await flush();
  await trial.advance(39);
  await trial.advance(28);
  for (const [latency] of replies.slice(0, 5)) {
    await trial.advance(1000);
    await trial.advance(latency);
  }
  assert.equal(trial.settled(), undefined, 'Do not give up while confirmation time remains');
  await trial.advance(1000);
  await trial.advance(120);
  await trial.completion;
  assert.equal(trial.settled().value.outcome, 'confirmed');
  assert.equal(trial.settled().value.data.aircons.ac1.zones.z03.state, 'open');
  assert.equal(trial.requests.filter(path => path === '/setAircon').length, 1);
  assert.ok(Date.now() - 1000 < 7000);
});

test('default confirmation still expires at seven seconds without resending or reading afterwards', async (t) => {
  const replies = [[91, {}], [127, {}], [126, {}], [122, {}], [123, snapshot('close')], [120, snapshot('close')]];
  const trial = prepare(t, 'close', 39, 28, replies);
  await flush();
  await trial.advance(39);
  await trial.advance(28);
  for (const [latency] of replies) {
    await trial.advance(1000);
    await trial.advance(latency);
  }
  assert.equal(trial.settled(), undefined);
  await trial.advance(8000 - Date.now());
  await trial.completion;
  assert.match(trial.settled().error.message, /timed out/);
  assert.equal(Date.now(), 8000);
  assert.equal(trial.requests.filter(path => path === '/setAircon').length, 1);
  const requestCount = trial.requests.length;
  await trial.advance(30000);
  assert.equal(trial.requests.length, requestCount);
});
