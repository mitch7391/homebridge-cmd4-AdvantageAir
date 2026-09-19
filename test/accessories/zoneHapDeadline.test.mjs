import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';
import { pathToFileURL, URL } from 'node:url';

import { ZoneSwitchAccessory } from '../../dist/accessories/zoneSwitchAccessory.js';
import { ZoneCommandExecutor } from '../../dist/api/zoneCommandExecutor.js';

const require = createRequire(import.meta.url);
const entry = pathToFileURL(require.resolve('homebridge'));
const { HomebridgeAPI } = await import(new URL('./api.js', entry).href);

async function flush() {
  for (let i = 0; i < 50; i++) {
    await Promise.resolve();
  }
}

function setup(t, setOn) {
  t.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 });
  const api = new HomebridgeAPI();
  const accessory = new api.platformAccessory('Living Zone', api.hap.uuid.generate('deadline'));
  const warnings = [];
  new ZoneSwitchAccessory(api, accessory, {
    getOn: () => true, setOn, warn: message => warnings.push(message),
  });
  const on = accessory.getService(api.hap.Service.Switch).getCharacteristic(api.hap.Characteristic.On);
  return { api, accessory, on, warnings };
}

test('zone deadline answers the full HAP write before its timeout and prevents a late physical write', async (t) => {
  let release;
  let writes = 0;
  const executor = new ZoneCommandExecutor({
    getFreshSystemData() {
      return new Promise(resolve => {
        release = resolve;
      });
    },
    async requestZoneState() {
      writes++;
    },
  });
  const identity = JSON.stringify(['AdvantageAir', 'controller', 'unit', 'zone', 'z01']);
  const c = setup(t, async (on, signal) => {
    await executor.setZone(identity, on, signal);
  });
  const hap = c.accessory._associatedHAPAccessory;
  hap.aid = 1;
  c.on.iid = 10;
  hap.on('characteristic-warning', () => {});
  let reply;
  hap.handleSetCharacteristics({}, {
    characteristics: [{ aid: 1, iid: 10, value: false }],
  }, (error, response) => {
    assert.equal(error, undefined);
    reply = response;
  });
  await flush();
  t.mock.timers.tick(6999);
  await flush();
  assert.equal(reply, undefined);
  t.mock.timers.tick(1);
  await flush();
  assert.equal(reply.characteristics[0].status, c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  assert.equal(c.warnings.length, 1);
  assert.match(c.warnings[0], /timed out/);
  release({
    system: { mid: 'controller' },
    aircons: { ac1: { info: { uid: 'unit', myZone: 0 }, zones: { z01: { number: 1, state: 'open' } } } },
  });
  await flush();
  t.mock.timers.tick(10000);
  await flush();
  assert.equal(writes, 0);
  assert.equal(c.warnings.length, 1);
  executor.stop();
});

test('the handler deadline includes time waiting behind an earlier switch request', async (t) => {
  let release;
  let calls = 0;
  const c = setup(t, async () => {
    calls++;
    await new Promise(resolve => {
      release = resolve;
    });
  });
  const first = assert.rejects(c.on.handleSetRequest(false));
  const second = assert.rejects(c.on.handleSetRequest(true));
  await flush();
  assert.equal(calls, 1);
  t.mock.timers.tick(7000);
  await flush();
  await Promise.all([first, second]);
  release();
  await flush();
  assert.equal(calls, 1);
  assert.equal(c.warnings.length, 2);
});

test('a read keeps its own deadline when another write is queued later', async (t) => {
  const releases = [];
  const c = setup(t, async () => {
    await new Promise(resolve => releases.push(resolve));
  });
  const first = c.on.handleSetRequest(false);
  await flush();
  const read = assert.rejects(c.on.handleGetRequest(), error =>
    error === c.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  t.mock.timers.tick(6000);
  const second = c.on.handleSetRequest(true);
  releases[0]();
  await first;
  await flush();
  t.mock.timers.tick(1000);
  await flush();
  await read;
  releases[1]();
  await second;
  assert.equal(c.warnings.length, 0);
});
