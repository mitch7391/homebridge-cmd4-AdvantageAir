import assert from 'node:assert/strict';
import test from 'node:test';

import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

function deferred() {
  let resolve;
  const promise = new Promise(done => {
    resolve = done;
  });
  return { promise, resolve };
}

function data(name) {
  return { system: { name }, aircons: {} };
}

function response(value) {
  return { ok: true, text: async () => JSON.stringify(value) };
}

function client() {
  return new AdvantageAirClient({ ipAddress: '127.0.0.1' });
}

test('a read after a write is fresh and an older read cannot clear its shared promise', async (t) => {
  const firstBody = deferred();
  const writeBody = deferred();
  const writeStarted = deferred();
  const paths = [];
  t.mock.method(globalThis, 'fetch', async endpoint => {
    paths.push(endpoint.pathname);
    if (paths.length === 1) {
      return { ok: true, text: () => firstBody.promise };
    }
    if (paths.length === 2) {
      writeStarted.resolve();
      return { ok: true, text: () => writeBody.promise };
    }
    return response(data('new'));
  });
  const connection = client();
  const oldRead = connection.getSystemData();
  const write = connection.requestZoneState('ac1', 'z01', 'open');
  const newRead = connection.getSystemData();
  assert.notEqual(oldRead, newRead);
  assert.equal(connection.getSystemData(), newRead);
  await Promise.resolve();
  assert.deepEqual(paths, ['/getSystemData']);
  firstBody.resolve(JSON.stringify(data('old')));
  assert.equal((await oldRead).system.name, 'old');
  await writeStarted.promise;
  assert.equal(connection.getSystemData(), newRead);
  assert.deepEqual(paths, ['/getSystemData', '/setAircon']);
  writeBody.resolve('{}');
  await write;
  assert.equal((await newRead).system.name, 'new');
  assert.deepEqual(paths, ['/getSystemData', '/setAircon', '/getSystemData']);
});

test('multiple writes preserve order and each separates shared reads', async (t) => {
  const order = [];
  t.mock.method(globalThis, 'fetch', async endpoint => {
    if (endpoint.pathname === '/setAircon') {
      const patch = JSON.parse(endpoint.searchParams.get('json'));
      order.push(patch.ac1.zones.z01.state);
      return response({});
    }
    order.push('read');
    return response(data('current'));
  });
  const connection = client();
  const firstWrite = connection.requestZoneState('ac1', 'z01', 'open');
  const firstRead = connection.getSystemData();
  const secondWrite = connection.requestZoneState('ac1', 'z01', 'close');
  const secondRead = connection.getSystemData();
  assert.notEqual(firstRead, secondRead);
  await Promise.all([firstWrite, firstRead, secondWrite, secondRead]);
  assert.deepEqual(order, ['open', 'read', 'close', 'read']);
});

test('a transport failure does not block a queued read', async (t) => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    if (++calls === 1) {
      throw new Error('Private failure details');
    }
    return response(data('recovered'));
  });
  const connection = client();
  const failed = assert.rejects(
    connection.requestZoneState('ac1', 'z01', 'open'), /Could not connect/,
  );
  const read = connection.getSystemData();
  await failed;
  assert.equal((await read).system.name, 'recovered');
  assert.equal(calls, 2);
});

test('a rejected write does not block a queued read', async (t) => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    return response(++calls === 1 ? false : data('current'));
  });
  const connection = client();
  const failed = assert.rejects(
    connection.requestZoneState('ac1', 'z01', 'open'), /rejected/,
  );
  const read = connection.getSystemData();
  await failed;
  assert.equal((await read).system.name, 'current');
  assert.equal(calls, 2);
});

test('invalid commands do not break read sharing or reach the network', async (t) => {
  const body = deferred();
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    calls++;
    return { ok: true, text: () => body.promise };
  });
  const connection = client();
  const read = connection.getSystemData();
  await assert.rejects(connection.requestZoneState('ac1', 'z01', 'invalid'));
  assert.equal(connection.getSystemData(), read);
  body.resolve(JSON.stringify(data('current')));
  await read;
  assert.equal(calls, 1);
});

test('an explicit fresh read queues a new request instead of sharing an old read', async (t) => {
  const body = deferred();
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    if (++calls === 1) {
      return { ok: true, text: () => body.promise };
    }
    return response(data('new'));
  });
  const connection = client();
  const oldRead = connection.getSystemData();
  const newRead = connection.getFreshSystemData();
  assert.notEqual(oldRead, newRead);
  body.resolve(JSON.stringify(data('old')));
  assert.equal((await oldRead).system.name, 'old');
  assert.equal((await newRead).system.name, 'new');
  assert.equal(calls, 2);
});
