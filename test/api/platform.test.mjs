import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import test from 'node:test';

import { AdvantageAirPlatform } from '../../dist/platform.js';
import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';

function snapshot() {
  return {
    system: { hasAircons: true, noOfAircons: 1 },
    aircons: {
      ac1: {
        info: {},
        zones: { z01: {} },
      },
    },
  };
}

async function flushPromises() {
  await Promise.resolve();
  await Promise.resolve();
}

function setup(t, devices, read) {
  t.mock.timers.enable({
    apis: ['setTimeout', 'Date'],
    now: 1000,
  });

  t.mock.method(AdvantageAirClient.prototype, 'getSystemData', read);

  const messages = {
    info: [],
    warn: [],
    error: [],
    debug: [],
  };

  const log = Object.fromEntries(
    Object.keys(messages).map(level => [
      level,
      (...args) => messages[level].push(args.join(' ')),
    ]),
  );

  const api = new EventEmitter();
  const platform = new AdvantageAirPlatform(
    log,
    { platform: 'AdvantageAir', name: 'Test', devices },
    api,
  );

  t.after(() => api.emit('shutdown'));

  return { api, platform, messages };
}

test('starts each controller once and stops polling on shutdown', async (t) => {
  const clients = new Set();
  let reads = 0;

  const { api } = setup(t, [
    { ipAddress: '192.0.2.1' },
    { ipAddress: '192.0.2.2' },
  ], async function () {
    clients.add(this);
    reads++;
    return snapshot();
  });

  assert.equal(reads, 0);

  api.emit('didFinishLaunching');
  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(clients.size, 2);
  assert.equal(reads, 2);

  t.mock.timers.tick(30000);
  await flushPromises();
  assert.equal(reads, 4);

  api.emit('shutdown');
  t.mock.timers.tick(60000);
  await flushPromises();
  assert.equal(reads, 4);
});

test('skips invalid and duplicate controllers but starts valid ones', async (t) => {
  let reads = 0;

  const { api, messages } = setup(t, [
    { ipAddress: '192.0.2.1' },
    { ipAddress: '192.0.2.1', port: 2025 },
    { ipAddress: '192.0.2.1', port: 2026 },
    { ipAddress: 'invalid' },
    { ipAddress: '192.0.2.2', port: '2025' },
    null,
  ], async () => {
    reads++;
    return snapshot();
  });

  assert.equal(messages.error.length, 4);

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(reads, 2);
});

test('logs one warning per failure period and reports recovery', async (t) => {
  let reads = 0;

  const { api, messages } = setup(t, [
    { ipAddress: '192.0.2.1', name: 'Controller' },
  ], async () => {
    reads++;

    if (reads === 2 || reads === 3) {
      throw new Error('Private response content');
    }

    return snapshot();
  });

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(
    messages.info.filter(line => line.includes('first valid')).length,
    1,
  );

  t.mock.timers.tick(30000);
  await flushPromises();
  t.mock.timers.tick(30000);
  await flushPromises();

  assert.equal(messages.warn.length, 1);
  assert.match(messages.warn[0], /Retaining previously received data/);

  t.mock.timers.tick(30000);
  await flushPromises();

  assert.equal(
    messages.info.filter(line => line.includes('recovered')).length,
    1,
  );
  assert.equal(JSON.stringify(messages).includes('Private response content'), false);
});

test('debug summaries are enabled per controller', async (t) => {
  const { api, messages } = setup(t, [
    { ipAddress: '192.0.2.1', name: 'Verbose', debug: true },
    { ipAddress: '192.0.2.2', name: 'Quiet', debug: false },
  ], async () => snapshot());

  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(messages.debug.length, 1);
  assert.match(messages.debug[0], /Verbose/);
  assert.match(messages.debug[0], /1 air conditioner\(s\), 1 zone\(s\)/);
});

test('retains restored accessories without registering new ones', (t) => {
  const { platform } = setup(t, [], async () => snapshot());
  const accessory = { UUID: 'cached-accessory', displayName: 'Existing zone' };

  platform.configureAccessory(accessory);

  assert.equal(platform.accessories.get(accessory.UUID), accessory);
});

test('shutdown before launch prevents controller reads', async (t) => {
  let reads = 0;

  const { api } = setup(t, [
    { ipAddress: '192.0.2.1' },
  ], async () => {
    reads++;
    return snapshot();
  });

  api.emit('shutdown');
  api.emit('didFinishLaunching');
  await flushPromises();

  assert.equal(reads, 0);
});
