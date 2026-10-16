import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';
import { pathToFileURL, URL } from 'node:url';

import { ZoneSwitchAccessory } from '../../dist/accessories/zoneSwitchAccessory.js';
import { ZoneCommandError } from '../../dist/api/zoneCommand.js';

const require = createRequire(import.meta.url);
const entry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', entry).href);

function setup(restore = false) {
  const api = new HomebridgeAPI();
  const accessory = new api.platformAccessory('Living Zone', api.hap.uuid.generate('living-zone'));
  const existing = restore ? accessory.addService(api.hap.Service.Switch, 'Living Zone') : undefined;
  let state = true;
  const warnings = [];
  const options = {
    getOn: () => state,
    setOn(on) {
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

test('active myZone refusal logs its zone and reason once and fails the HomeKit write', async () => {
  const c = setup();
  c.options.setOn = () => {
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
  c.options.setOn = () => {
    throw new Error('private controller payload');
  };
  await assert.rejects(c.on.handleSetRequest(false), unavailable(c));
  assert.match(c.warnings[0], /could not be accepted/);
  assert.equal(c.warnings[0].includes('private'), false);
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
  assert.equal(c.accessory.services.filter(service => service.UUID === c.api.hap.Service.Switch.UUID).length, 1);
});
