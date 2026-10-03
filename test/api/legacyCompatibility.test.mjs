import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { pathToFileURL, URL } from 'node:url';
import test from 'node:test';

import register from '../../dist/index.js';
import { AdvantageAirPlatform } from '../../dist/platform.js';
import { LegacyCompatibilityPlatform } from '../../dist/legacyCompatibility.js';
import { LEGACY_PLATFORM_NAME, PLATFORM_NAME, PLUGIN_NAME } from '../../dist/settings.js';

const require = createRequire(import.meta.url);
const entry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', entry).href);

test('entry point registers native and inert legacy aliases under the same package', () => {
  const registrations = [];
  register({ registerPlatform: (...args) => registrations.push(args) });
  assert.deepEqual(registrations, [
    [PLUGIN_NAME, PLATFORM_NAME, AdvantageAirPlatform],
    [PLUGIN_NAME, LEGACY_PLATFORM_NAME, LegacyCompatibilityPlatform],
  ]);
  assert.equal(PLATFORM_NAME, 'AdvantageAir');
  assert.equal(LEGACY_PLATFORM_NAME, 'cmd4AdvantageAir');
});

test('legacy handler logs once without accessing configuration or the Homebridge API', () => {
  const notices = [];
  const forbidden = new Proxy({}, { get() {
    assert.fail('The legacy handler must not access controller configuration or the API.');
  } });
  const handler = new LegacyCompatibilityPlatform(
    { warn: message => notices.push(message) }, forbidden, forbidden,
  );
  assert.equal(notices.length, 1);
  assert.match(notices[0], /compatibility only/);
  assert.match(notices[0], /Configure the AdvantageAir platform separately/);
  assert.deepEqual(Object.keys(handler), []);
  assert.equal(HomebridgeAPI.isDynamicPlatformPlugin(handler), false);
  assert.equal(HomebridgeAPI.isStaticPlatformPlugin(handler), false);
});

test('legacy-only startup adds no listeners or accessories and leaves old configuration intact', () => {
  const api = new HomebridgeAPI();
  const config = { platform: LEGACY_PLATFORM_NAME, name: 'Old helper',
    devices: [{ ipAddress: '192.0.2.1', port: 2025, debug: true }] };
  const before = JSON.stringify(config);
  const events = api.eventNames();
  for (const method of ['registerPlatformAccessories', 'updatePlatformAccessories',
    'unregisterPlatformAccessories', 'publishExternalAccessories']) {
    api[method] = () => assert.fail('Legacy startup must not register or alter accessories.');
  }
  new LegacyCompatibilityPlatform({ warn() {} }, config, api);
  api.emit('didFinishLaunching');
  api.emit('shutdown');
  assert.deepEqual(api.eventNames(), events);
  assert.equal(JSON.stringify(config), before);
});

test('legacy registration does not replace native configuration or startup', () => {
  const api = new HomebridgeAPI();
  const warnings = [];
  const log = { warn: message => warnings.push(message), info() {}, debug() {}, error() {} };
  new LegacyCompatibilityPlatform(log, { platform: LEGACY_PLATFORM_NAME }, api);
  const native = new AdvantageAirPlatform(log, { platform: PLATFORM_NAME, name: 'Native', devices: [] }, api);
  assert.equal(HomebridgeAPI.isDynamicPlatformPlugin(native), true);
  assert.equal(native.config.platform, PLATFORM_NAME);
  assert.equal(warnings.length, 2);
  assert.match(warnings[1], /No controllers configured/);
  api.emit('shutdown');
});

test('legacy backend bytes remain frozen and package allowlist includes the root entry point', () => {
  const bytes = fs.readFileSync(new URL('../../AdvAir.sh', import.meta.url));
  const blob = crypto.createHash('sha1').update('blob ' + bytes.length + '\0').update(bytes).digest('hex');
  assert.equal(blob, 'c8b6e7d12530dd3d4bb27b71bfa3d063139fcf53');
  assert.ok(bytes.toString('utf8').startsWith('#!/bin/bash\n'));
  const pkg = JSON.parse(fs.readFileSync(new URL('../../package.json', import.meta.url), 'utf8'));
  assert.ok(pkg.files.includes('AdvAir.sh'));
  assert.ok(pkg.files.includes('docs/v3-migration.md'));
  assert.equal(pkg.private, true);
  assert.equal(pkg.dependencies, undefined);
});
