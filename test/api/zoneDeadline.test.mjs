import assert from 'node:assert/strict';
import test from 'node:test';

import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { ZoneCommandExecutor } from '../../dist/api/zoneCommandExecutor.js';

const identity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', 'z01']);

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

test('zone deadline releases a slow preflight read without allowing a later write', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const read = deferred();
  let writes = 0;
  const executor = new ZoneCommandExecutor({
    getFreshSystemData: () => read.promise,
    async requestZoneState() {
      writes++;
    },
  });
  t.after(() => executor.stop());
  const result = assert.rejects(executor.setZone(identity, false), /timed out/);
  await flush();
  t.mock.timers.tick(7000);
  await result;
  read.resolve(snapshot());
  await flush();
  assert.equal(writes, 0);
});

test('zone deadlines include executor queue time and cannot release its actual execution queue early', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const firstRead = deferred();
  let reads = 0;
  let writes = 0;
  const executor = new ZoneCommandExecutor({
    getFreshSystemData() {
      reads++;
      return reads === 1 ? firstRead.promise : Promise.resolve(snapshot('close'));
    },
    async requestZoneState() {
      writes++;
    },
  });
  t.after(() => executor.stop());
  const first = assert.rejects(executor.setZone(identity, false), /timed out/);
  await flush();
  t.mock.timers.tick(1000);
  const second = assert.rejects(executor.setZone(identity, false), /timed out/);
  t.mock.timers.tick(6000);
  await first;
  assert.equal(reads, 1);
  t.mock.timers.tick(1000);
  await second;
  firstRead.resolve(snapshot());
  await flush();
  assert.equal(reads, 1);
  assert.equal(writes, 0);
  assert.equal((await executor.setZone(identity, false)).outcome, 'unchanged');
  assert.equal(reads, 2);
});

test('upstream cancellation releases queued commands before a blocked read finishes', async (t) => {
  const read = deferred();
  const controller = new globalThis.AbortController();
  let reads = 0;
  const executor = new ZoneCommandExecutor({
    getFreshSystemData() {
      reads++;
      return read.promise;
    },
    async requestZoneState() {
      assert.fail('Cancelled requests must not write');
    },
  });
  t.after(() => executor.stop());
  const first = assert.rejects(executor.setZone(identity, false), /stopped/);
  await flush();
  const second = assert.rejects(executor.setZone(identity, false, controller.signal), /cancelled/);
  controller.abort();
  await second;
  assert.equal(reads, 1);
  executor.stop();
  await first;
  read.resolve(snapshot());
  await flush();
  assert.equal(reads, 1);
});

test('shutdown rejects all waiting commands without waiting for an active read', async (t) => {
  const read = deferred();
  const executor = new ZoneCommandExecutor({
    getFreshSystemData: () => read.promise,
    async requestZoneState() {
      assert.fail('Shutdown must prevent writing');
    },
  });
  t.after(() => executor.stop());
  const first = assert.rejects(executor.setZone(identity, false), /stopped/);
  const second = assert.rejects(executor.setZone(identity, true), /stopped/);
  await flush();
  executor.stop();
  await Promise.all([first, second]);
  read.resolve(snapshot());
  await flush();
});

test('upstream cancellation cancels confirmation waits and prevents subsequent reads', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const controller = new globalThis.AbortController();
  let reads = 0;
  let writes = 0;
  const executor = new ZoneCommandExecutor({
    async getFreshSystemData() {
      reads++;
      return snapshot();
    },
    async requestZoneState(aircon, zone, state, signal) {
      assert.equal(signal.aborted, false);
      writes++;
      return {};
    },
  });
  t.after(() => executor.stop());
  const result = assert.rejects(executor.setZone(identity, false, controller.signal), /cancelled/);
  await flush();
  assert.equal(writes, 1);
  controller.abort();
  await result;
  t.mock.timers.tick(10000);
  await flush();
  assert.equal(reads, 1);
});

test('late confirmation cannot turn a timed-out operation into success', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const confirmation = deferred();
  let reads = 0;
  let writes = 0;
  const executor = new ZoneCommandExecutor({
    getFreshSystemData() {
      reads++;
      return reads === 1 ? Promise.resolve(snapshot()) : confirmation.promise;
    },
    async requestZoneState() {
      writes++;
    },
  });
  t.after(() => executor.stop());
  const result = assert.rejects(executor.setZone(identity, false), /timed out/);
  await flush();
  t.mock.timers.tick(1000);
  await flush();
  assert.equal(reads, 2);
  t.mock.timers.tick(6000);
  await result;
  confirmation.resolve(snapshot('close'));
  await flush();
  assert.equal(reads, 2);
  assert.equal(writes, 1);
});

test('executor deadline aborts an active command request', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  let requestSignal;
  let reads = 0;
  const executor = new ZoneCommandExecutor({
    async getFreshSystemData() {
      reads++;
      return snapshot();
    },
    requestZoneState(aircon, zone, state, signal) {
      requestSignal = signal;
      return new Promise((resolve, reject) => {
        signal.addEventListener('abort', () => reject(signal.reason), { once: true });
      });
    },
  });
  t.after(() => executor.stop());
  const result = assert.rejects(executor.setZone(identity, false), /timed out/);
  await flush();
  assert.equal(requestSignal.aborted, false);
  t.mock.timers.tick(7000);
  await result;
  assert.equal(requestSignal.aborted, true);
  assert.equal(reads, 1);
});

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
