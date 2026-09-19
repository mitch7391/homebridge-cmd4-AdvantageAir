import assert from 'node:assert/strict';
import test from 'node:test';

import { ZoneCommandExecutor } from '../../dist/api/zoneCommandExecutor.js';

const identity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', 'z01']);

function snapshot(state = 'open', myZone = 0, key = 'ac1') {
  return {
    system: { mid: 'controller' },
    aircons: {
      [key]: {
        info: { uid: 'unit', myZone, constant1: 1 },
        zones: { z01: { number: 1, state } },
      },
    },
  };
}

function setup(t, reads, send = async () => ({}), attempts = 3) {
  const writes = [];
  let count = 0;
  const executor = new ZoneCommandExecutor({
    async getFreshSystemData() {
      const value = reads[count++];
      if (value instanceof Error) {
        throw value;
      }
      assert.ok(value, 'Unexpected extra read');
      return value;
    },
    async requestZoneState(...args) {
      writes.push(args.slice(0, 3));
      return send(...args);
    },
  }, attempts, 1);
  t.after(() => executor.stop());
  return { executor, writes, readCount: () => count };
}

test('executor confirms only after a read reports the requested state', async (t) => {
  const confirmed = snapshot('close');
  const { executor, writes } = setup(t, [snapshot(), snapshot(), confirmed]);
  const result = await executor.setZone(identity, false);
  assert.equal(result.outcome, 'confirmed');
  assert.equal(result.data, confirmed);
  assert.deepEqual(writes, [['ac1', 'z01', 'close']]);
});

test('executor retries failed confirmation reads without resending a command', async (t) => {
  const { executor, writes, readCount } = setup(t, [
    snapshot(), new Error('Incomplete response'), snapshot('close'),
  ]);
  assert.equal((await executor.setZone(identity, false)).outcome, 'confirmed');
  assert.equal(writes.length, 1);
  assert.equal(readCount(), 3);
});

test('executor bounds confirmation attempts when a constant zone remains open', async (t) => {
  const { executor, writes, readCount } = setup(t, [
    snapshot(), snapshot(), snapshot(), snapshot(),
  ]);
  await assert.rejects(executor.setZone(identity, false), /did not confirm/);
  assert.equal(writes.length, 1);
  assert.equal(readCount(), 4);
});

test('executor does not write when the fresh state already matches', async (t) => {
  const { executor, writes } = setup(t, [snapshot('close')]);
  assert.equal((await executor.setZone(identity, false)).outcome, 'unchanged');
  assert.equal(writes.length, 0);
});

test('executor refuses an active myZone closure before sending', async (t) => {
  const { executor, writes } = setup(t, [snapshot('open', 1)]);
  await assert.rejects(executor.setZone(identity, false), /Select another myZone/);
  assert.equal(writes.length, 0);
});

test('executor follows stable identity when an aircon key changes', async (t) => {
  const { executor, writes } = setup(t, [
    snapshot('open', 0, 'ac2'), snapshot('close', 0, 'ac3'),
  ]);
  assert.equal((await executor.setZone(identity, false)).outcome, 'confirmed');
  assert.deepEqual(writes, [['ac2', 'z01', 'close']]);
});

test('executor cannot confirm from a different controller at the same address', async (t) => {
  const other = snapshot('close');
  other.system.mid = 'other controller';
  const { executor } = setup(t, [snapshot(), other]);
  await assert.rejects(executor.setZone(identity, false), /identity is unavailable/);
});

test('executor serializes whole commands and replans a queued request', async (t) => {
  const { executor, writes } = setup(t, [
    snapshot(), snapshot('close'), snapshot('close'),
  ]);
  const first = executor.setZone(identity, false);
  const second = executor.setZone(identity, false);
  assert.equal((await first).outcome, 'confirmed');
  assert.equal((await second).outcome, 'unchanged');
  assert.equal(writes.length, 1);
});

test('a failed command does not prevent the next queued command', async (t) => {
  const { executor, writes } = setup(t, [snapshot('open', 1), snapshot('close')]);
  const first = assert.rejects(executor.setZone(identity, false), /Select another myZone/);
  const second = executor.setZone(identity, false);
  await first;
  assert.equal((await second).outcome, 'unchanged');
  assert.equal(writes.length, 0);
});

test('a write error is reported without retrying or claiming confirmation', async (t) => {
  const { executor, writes, readCount } = setup(t, [snapshot()], async () => {
    throw new Error('Controller request timed out.');
  });
  await assert.rejects(executor.setZone(identity, false), /timed out/);
  assert.equal(writes.length, 1);
  assert.equal(readCount(), 1);
});

test('shutdown during a read prevents its command and subsequent queued commands', async () => {
  let release;
  let reads = 0;
  let writes = 0;
  const executor = new ZoneCommandExecutor({
    getFreshSystemData() {
      reads++;
      return new Promise(resolve => {
        release = resolve;
      });
    },
    async requestZoneState() {
      writes++;
    },
  });
  const first = assert.rejects(executor.setZone(identity, false), /stopped/);
  const second = assert.rejects(executor.setZone(identity, true), /stopped/);
  await Promise.resolve();
  executor.stop();
  release(snapshot());
  await Promise.all([first, second]);
  assert.equal(reads, 1);
  assert.equal(writes, 0);
});

test('executor rejects invalid confirmation settings', () => {
  for (const [attempts, delay] of [
    [0, 1], [11, 1], [1.5, 1], [1, 0], [1, 10001],
  ]) {
    assert.throws(() => new ZoneCommandExecutor({}, attempts, delay), /Invalid/);
  }
});

test('shutdown cancels the confirmation wait without starting another read', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  let reads = 0;
  let writes = 0;
  const executor = new ZoneCommandExecutor({
    async getFreshSystemData() {
      reads++;
      return snapshot();
    },
    async requestZoneState() {
      writes++;
    },
  });
  const result = assert.rejects(executor.setZone(identity, false), /stopped/);
  for (let i = 0; i < 10; i++) {
    await Promise.resolve();
  }
  assert.equal(writes, 1);
  executor.stop();
  await result;
  t.mock.timers.tick(10000);
  assert.equal(reads, 1);
});
