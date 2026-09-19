import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';
import { pathToFileURL, URL } from 'node:url';

import { ZoneSwitchAccessory } from '../../dist/accessories/zoneSwitchAccessory.js';
import { ZoneCommandError } from '../../dist/api/zoneCommand.js';

const require = createRequire(import.meta.url);
const entry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', entry).href);

function deferred() {
  let resolve;
  const promise = new Promise(done => {
    resolve = done;
  });
  return { promise, resolve };
}

function setup(restore = false) {
  const api = new HomebridgeAPI();
  const accessory = new api.platformAccessory(
    'Living Zone',
    api.hap.uuid.generate('living-zone'),
  );
  const existing = restore
    ? accessory.addService(api.hap.Service.Switch, 'Living Zone')
    : undefined;
  let state = true;
  const warnings = [];
  const options = {
    getOn: () => state,
    async setOn(on) {
      state = on;
    },
    warn: message => warnings.push(message),
  };
  const handler = new ZoneSwitchAccessory(api, accessory, options);
  const service = accessory.getService(api.hap.Service.Switch);
  return {
    api, accessory, existing, options, handler, service, warnings,
    on: service.getCharacteristic(api.hap.Characteristic.On),
    setState: value => {
      state = value;
    },
  };
}

function unavailable(context) {
  return error => error === context.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE;
}

test('zone switch reads and publishes the supplied controller state', async () => {
  const c = setup();
  assert.equal(await c.on.handleGetRequest(), true);
  c.setState(false);
  c.handler.update();
  assert.equal(c.on.value, false);
  assert.equal(await c.on.handleGetRequest(), false);
});

test('zone switch waits for write confirmation before completing a following read', async () => {
  const c = setup();
  const gate = deferred();
  const started = deferred();
  c.options.setOn = async on => {
    started.resolve();
    await gate.promise;
    c.setState(on);
  };
  const write = c.on.handleSetRequest(false);
  await started.promise;
  let completed = false;
  const read = c.on.handleGetRequest().then(value => {
    completed = true;
    return value;
  });
  await Promise.resolve();
  assert.equal(completed, false);
  gate.resolve();
  await write;
  assert.equal(await read, false);
});

test('polling does not publish an older value while a zone write is pending', async () => {
  const c = setup();
  const gate = deferred();
  const started = deferred();
  c.handler.update();
  c.options.setOn = async on => {
    started.resolve();
    await gate.promise;
    c.setState(on);
  };
  const write = c.on.handleSetRequest(false);
  await started.promise;
  c.setState(false);
  c.handler.update();
  assert.equal(c.on.value, true);
  gate.resolve();
  await write;
  assert.equal(await c.on.handleGetRequest(), false);
});

test('active myZone refusal logs its zone and reason once and fails the HomeKit write', async () => {
  const c = setup();
  c.options.setOn = async () => {
    throw new ZoneCommandError('Select another myZone before closing this zone.');
  };
  await assert.rejects(c.on.handleSetRequest(false), unavailable(c));
  assert.equal(c.warnings.length, 1);
  assert.match(c.warnings[0], /Living Zone/);
  assert.match(c.warnings[0], /Select another myZone/);
  c.handler.update();
  c.handler.update();
  assert.equal(await c.on.handleGetRequest(), true);
  assert.equal(c.warnings.length, 1);
});

test('unexpected write errors do not expose private details in logs', async () => {
  const c = setup();
  c.options.setOn = async () => {
    throw new Error('private controller payload');
  };
  await assert.rejects(c.on.handleSetRequest(false), unavailable(c));
  assert.match(c.warnings[0], /could not be confirmed/);
  assert.equal(c.warnings[0].includes('private'), false);
});

test('a read waiting on a failed zone write reports unavailable', async () => {
  const c = setup();
  const gate = deferred();
  const started = deferred();
  c.options.setOn = async () => {
    started.resolve();
    await gate.promise;
    throw new ZoneCommandError('The controller did not confirm the requested zone state.');
  };
  const write = assert.rejects(c.on.handleSetRequest(false), unavailable(c));
  await started.promise;
  const read = assert.rejects(c.on.handleGetRequest(), unavailable(c));
  gate.resolve();
  await Promise.all([write, read]);
  assert.equal(c.warnings.length, 1);
});

test('a later queued switch write can succeed after an earlier write fails', async () => {
  const c = setup();
  const gate = deferred();
  const started = deferred();
  const calls = [];
  c.options.setOn = async on => {
    calls.push(on);
    if (calls.length === 1) {
      started.resolve();
      await gate.promise;
      throw new ZoneCommandError('First command refused.');
    }
    c.setState(on);
  };
  const first = assert.rejects(c.on.handleSetRequest(false), unavailable(c));
  await started.promise;
  const second = c.on.handleSetRequest(true);
  const read = c.on.handleGetRequest();
  assert.deepEqual(calls, [false]);
  gate.resolve();
  await Promise.all([first, second]);
  assert.equal(await read, true);
  assert.deepEqual(calls, [false, true]);
});

test('unavailable switch readings fail without producing command warnings', async () => {
  const c = setup();
  c.options.getOn = () => {
    throw new Error('No fresh state');
  };
  await assert.rejects(c.on.handleGetRequest(), unavailable(c));
  c.handler.update();
  assert.equal(c.warnings.length, 0);
});

test('zone switch reuses a restored service', () => {
  const c = setup(true);
  assert.equal(c.service, c.existing);
  assert.equal(
    c.accessory.services.filter(
      service => service.UUID === c.api.hap.Service.Switch.UUID,
    ).length,
    1,
  );
});
