import assert from 'node:assert/strict';
import fs from 'node:fs';
import { URL } from 'node:url';
import test from 'node:test';

import { AdvantageAirClient } from '../../dist/api/advantageAirClient.js';
import { PLATFORM_NAME } from '../../dist/settings.js';

const config = JSON.parse(fs.readFileSync(new URL('../../config.schema.json', import.meta.url), 'utf8'));
const properties = config.schema.properties;
const controller = properties.devices.items;

test('native schema exposes controller setup without legacy or Homebridge-owned bridge settings', () => {
  assert.equal(config.pluginAlias, PLATFORM_NAME);
  assert.equal(config.pluginType, 'platform');
  assert.equal(config.singular, true);
  assert.equal(config.strictValidation, false);
  assert.equal(config.customUi, undefined);
  assert.deepEqual(Object.keys(properties).sort(), ['debug', 'devices', 'name']);
  assert.deepEqual(Object.keys(controller.properties).sort(), ['debug', 'homeName', 'ipAddress', 'name', 'port']);
  assert.deepEqual(controller.required, ['ipAddress']);
  assert.equal(properties.devices.minItems, 1);
});

test('schema address and port defaults match the existing native client contract', () => {
  const port = controller.properties.port;
  assert.equal(port.default, 2025);
  assert.equal(port.minimum, 1);
  assert.equal(port.maximum, 65535);
  assert.equal(port.type, 'integer');
  assert.equal(controller.properties.ipAddress.format, 'ipv4');
  assert.doesNotThrow(() => new AdvantageAirClient({ ipAddress: '192.0.2.1' }));
  for (const value of [port.minimum, port.default, port.maximum]) {
    assert.doesNotThrow(() => new AdvantageAirClient({ ipAddress: '192.0.2.1', port: value }));
  }
  for (const value of [0, 65536, 2025.5]) {
    assert.throws(() => new AdvantageAirClient({ ipAddress: '192.0.2.1', port: value }));
  }
});

test('optional controller label and debug help reflect native runtime behaviour', () => {
  assert.equal(controller.properties.name.default, undefined);
  assert.equal(controller.properties.debug.default, false);
  assert.match(controller.properties.name.description, /Controller 1/);
  assert.match(controller.properties.name.description, /does not rename/);
  assert.match(controller.properties.debug.description, /No Homebridge Debug Mode required/);
});


test('standard layout hides retained labels, uses controller tabs and a numeric port, then global debug', () => {
  assert.match(config.headerDisplay, /v4-beta\/assets\/settings-header.png/);
  assert.match(config.headerDisplay, /Advantage Air Device Settings/);
  assert.deepEqual(config.layout[0], { key: 'name', type: 'hidden', htmlClass: 'd-none' });
  const tabs = config.layout[1];
  assert.equal(tabs.type, 'tabarray');
  assert.equal(tabs.key, 'devices');
  assert.deepEqual(tabs.items, [
    { key: 'devices[].name', type: 'hidden', htmlClass: 'd-none' }, 'devices[].homeName', 'devices[].ipAddress',
    { key: 'devices[].port', type: 'number' }, 'devices[].debug',
  ]);
  assert.equal(tabs.title, '{{ value.homeName || \'Controller\' }}');
  assert.deepEqual(config.layout[2], { type: 'fieldset', title: 'Plugin-wide diagnostics',
    htmlClass: 'mt-4 border-top pt-3', items: ['debug'] });
  assert.match(properties.debug.description, /No Homebridge Debug Mode required/);
  assert.equal(controller.properties.homeName.default, 'Aircon');
  assert.equal(properties.devices.maxItems, undefined);
  assert.equal(properties.debug.default, false);
  assert.equal(controller.properties.name.default, undefined, 'Do not fill in an absent legacy controller label.');
  assert.equal(properties.name.default, 'Homebridge Advantage Air');
  assert.doesNotThrow(() => new AdvantageAirClient({ ipAddress: '192.0.2.1', port: 10211 }));
});
