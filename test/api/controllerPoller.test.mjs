import assert from 'node:assert/strict';
import test from 'node:test';

import { ControllerPoller } from '../../dist/api/controllerPoller.js';

function snapshot(name = 'Test controller') {
  return {
    system: { name, hasAircons: false, noOfAircons: 0 },
    aircons: {},
  };
}

function deferred() {
  let resolve;
  let reject;

  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });

  return { promise, resolve, reject };
}

async function flushPromises() {
  await Promise.resolve();
  await Promise.resolve();
}

function prepare(t, reader) {
  t.mock.timers.enable({
    apis: ['setTimeout', 'Date'],
    now: 1000,
  });

  const poller = new ControllerPoller(reader, 100);
  t.after(() => poller.stop());
  return poller;
}

test('starts immediately and ignores duplicate starts', async (t) => {
  let calls = 0;
  const poller = prepare(t, {
    async getSystemData() {
      calls++;
      return snapshot();
    },
  });

  assert.equal(poller.state.data, undefined);

  poller.start();
  poller.start();
  await flushPromises();

  assert.equal(calls, 1);
  assert.equal(poller.state.lastSuccessAt, 1000);

  t.mock.timers.tick(99);
  assert.equal(calls, 1);

  t.mock.timers.tick(1);
  await flushPromises();
  assert.equal(calls, 2);
});

test('waits until a read finishes before scheduling another', async (t) => {
  const pending = deferred();
  let calls = 0;

  const poller = prepare(t, {
    getSystemData() {
      calls++;
      return pending.promise;
    },
  });

  poller.start();
  t.mock.timers.tick(1000);
  assert.equal(calls, 1);

  pending.resolve(snapshot());
  await flushPromises();

  t.mock.timers.tick(99);
  assert.equal(calls, 1);

  t.mock.timers.tick(1);
  await flushPromises();
  assert.equal(calls, 2);
});

test('retains valid data after failure and recovers later', async (t) => {
  let calls = 0;

  const poller = prepare(t, {
    async getSystemData() {
      calls++;

      if (calls === 2) {
        throw new Error('Simulated failure');
      }

      return snapshot(calls === 1 ? 'First' : 'Recovered');
    },
  });

  poller.start();
  await flushPromises();

  t.mock.timers.tick(100);
  await flushPromises();

  assert.equal(poller.state.data.system.name, 'First');
  assert.equal(poller.state.lastSuccessAt, 1000);
  assert.equal(poller.state.lastAttemptAt, 1100);
  assert.equal(poller.state.lastAttemptFailed, true);

  t.mock.timers.tick(100);
  await flushPromises();

  assert.equal(poller.state.data.system.name, 'Recovered');
  assert.equal(poller.state.lastSuccessAt, 1200);
  assert.equal(poller.state.lastAttemptFailed, false);
});

test('first-read failure leaves the cache empty', async (t) => {
  const poller = prepare(t, {
    async getSystemData() {
      throw new Error('Simulated failure');
    },
  });

  poller.start();
  await flushPromises();

  assert.equal(poller.state.data, undefined);
  assert.equal(poller.state.lastSuccessAt, undefined);
  assert.equal(poller.state.lastAttemptFailed, true);
});

test('stop cancels scheduled reads and prevents restart', async (t) => {
  let calls = 0;
  const poller = prepare(t, {
    async getSystemData() {
      calls++;
      return snapshot();
    },
  });

  poller.start();
  await flushPromises();

  poller.stop();
  poller.stop();
  poller.start();

  t.mock.timers.tick(1000);
  await flushPromises();

  assert.equal(calls, 1);
});

test('ignores a successful response arriving after shutdown', async (t) => {
  const pending = deferred();
  let calls = 0;
  const poller = prepare(t, {
    getSystemData() {
      calls++;
      return pending.promise;
    },
  });

  poller.start();
  poller.stop();

  pending.resolve(snapshot());
  await flushPromises();
  t.mock.timers.tick(1000);

  assert.equal(poller.state.data, undefined);
  assert.equal(calls, 1);
});

test('handles a failed response arriving after shutdown', async (t) => {
  const pending = deferred();
  const poller = prepare(t, {
    getSystemData() {
      return pending.promise;
    },
  });

  poller.start();
  poller.stop();

  pending.reject(new Error('Simulated late failure'));
  await flushPromises();

  assert.equal(poller.state.lastAttemptFailed, false);
  assert.equal(poller.state.data, undefined);
});

test('callers cannot modify cached data through the state getter', async (t) => {
  const poller = prepare(t, {
    async getSystemData() {
      return snapshot();
    },
  });

  poller.start();
  await flushPromises();

  const state = poller.state;
  state.data.system.name = 'Changed externally';

  assert.equal(poller.state.data.system.name, 'Test controller');
});

test('continues polling when an update observer throws', async (t) => {
  t.mock.timers.enable({
    apis: ['setTimeout', 'Date'],
    now: 1000,
  });

  let reads = 0;
  let notifications = 0;

  const poller = new ControllerPoller({
    async getSystemData() {
      reads++;
      return snapshot();
    },
  }, 100, () => {
    notifications++;
    throw new Error('Simulated observer failure');
  });

  t.after(() => poller.stop());

  poller.start();
  await flushPromises();

  assert.equal(reads, 1);
  assert.equal(notifications, 1);
  assert.equal(poller.state.lastAttemptFailed, false);

  t.mock.timers.tick(100);
  await flushPromises();

  assert.equal(reads, 2);
  assert.equal(notifications, 2);
  assert.equal(poller.state.lastSuccessAt, 1100);
});

test('an observer can stop polling without scheduling another read', async (t) => {
  t.mock.timers.enable({
    apis: ['setTimeout', 'Date'],
    now: 1000,
  });

  let reads = 0;
  let notifications = 0;

  const poller = new ControllerPoller({
    async getSystemData() {
      reads++;
      return snapshot();
    },
  }, 100, () => {
    notifications++;
    poller.stop();
  });

  t.after(() => poller.stop());

  poller.start();
  await flushPromises();

  t.mock.timers.tick(1000);
  await flushPromises();

  assert.equal(reads, 1);
  assert.equal(notifications, 1);
  assert.equal(poller.state.lastSuccessAt, 1000);
});
