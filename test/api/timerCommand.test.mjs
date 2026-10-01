import assert from 'node:assert/strict';
import test from 'node:test';
import { nativeTimer, planTimer, timerDuration, timerMatches, validateTimerWrite } from '../../dist/api/timerCommand.js';
import { AdvantageAirClient, AirconCommandRejectedError } from '../../dist/api/advantageAirClient.js';

const aircon = (info = {}) => ({ info: { state: 'on', countDownToOn: 0, countDownToOff: 0, ...info }, zones: {} });

test('timer duration accepts integer minutes from 1 to 720 and rounds partial minutes upward', () => {
  for (const [input, expected] of [[60, 60], [61, 120], [90, 120], [1740, 1740], [1800, 1800], [1801, 1860],
    [2700, 2700], [10801, 10860], [12600, 12600], [43199, 43200], [43200, 43200]]) {
    assert.equal(timerDuration(input), expected);
  }
  for (const bad of [0, 1, 59, -1, 43201, 1800.5, NaN, Infinity, '1800', undefined]) {
    assert.throws(() => timerDuration(bad));
  }
});

test('timer reads observed whole remaining minutes including one minute and zero', () => {
  assert.deepEqual(nativeTimer(aircon()), { field: undefined, remaining: 0 });
  assert.deepEqual(nativeTimer(aircon({ countDownToOff: 1 })), { field: 'countDownToOff', remaining: 60 });
  assert.deepEqual(nativeTimer(aircon({ state: 'off', countDownToOn: 73 })), { field: 'countDownToOn', remaining: 4380 });
});

test('timer refuses malformed, missing, contradictory or fractional countdowns', () => {
  for (const info of [{ countDownToOn: undefined }, { countDownToOff: '30' }, { countDownToOff: 0.5 },
    { countDownToOff: -1 }, { countDownToOff: 721 }, { countDownToOn: 1, countDownToOff: 1 },
    { countDownToOn: 30 }, { state: 'off', countDownToOff: 30 }, { state: 'invalid' }]) {
    assert.throws(() => nativeTimer(aircon(info)));
  }
});

test('timer planning chooses opposite power and cancellation never contains a power change', () => {
  assert.deepEqual(planTimer(aircon(), true, 1800), { kind: 'command', field: 'countDownToOff', minutes: 30 });
  assert.deepEqual(planTimer(aircon({ state: 'off' }), true, 43200), { kind: 'command', field: 'countDownToOn', minutes: 720 });
  assert.deepEqual(planTimer(aircon({ countDownToOff: 29 }), false, 1800), { kind: 'command', field: 'countDownToOff', minutes: 0 });
  assert.deepEqual(planTimer(aircon({ state: 'off', countDownToOn: 1 }), false, 1800),
    { kind: 'command', field: 'countDownToOn', minutes: 0 });
  assert.deepEqual(planTimer(aircon(), false, 1800), { kind: 'unchanged' });
});

test('repeated timer Active does not restart, explicit duration edit can replace', () => {
  const running = aircon({ countDownToOff: 29 });
  assert.deepEqual(planTimer(running, true, 1800), { kind: 'unchanged' });
  assert.deepEqual(planTimer(running, true, 3600, true), { kind: 'command', field: 'countDownToOff', minutes: 60 });
  assert.deepEqual(planTimer(aircon({ countDownToOff: 60 }), true, 3600, true), { kind: 'unchanged' });
  assert.throws(() => planTimer(running, 1, 1800));
});

test('timer confirmation accepts one minute boundary, not expiry, wrong direction or larger drift', () => {
  for (const minutes of [30, 29]) {
    assert.equal(timerMatches(aircon({ countDownToOff: minutes }), 'countDownToOff', 30), true);
  }
  for (const minutes of [0, 28, 31]) {
    assert.equal(timerMatches(aircon({ countDownToOff: minutes }), 'countDownToOff', 30), false);
  }
  assert.equal(timerMatches(aircon({ state: 'off', countDownToOn: 30 }), 'countDownToOff', 30), false);
  assert.equal(timerMatches(aircon({ state: 'off' }), 'countDownToOff', 0), true);
});

test('timer transport is countdown-only, serialized, validates before sending and propagates rejection/cancellation', async t => {
  const writes = [];
  let reply = '{}';
  t.mock.method(globalThis, 'fetch', async url => {
    assert.equal(url.pathname, '/setAircon');
    writes.push(JSON.parse(url.searchParams.get('json')));
    return { ok: true, status: 200, text: async () => reply };
  });
  const client = new AdvantageAirClient({ ipAddress: '192.0.2.1' });
  await Promise.all([client.requestTimer('ac2', 'countDownToOn', 720), client.requestTimer('ac2', 'countDownToOn', 0)]);
  assert.deepEqual(writes, [{ ac2: { info: { countDownToOn: 720 } } }, { ac2: { info: { countDownToOn: 0 } } }]);
  for (const [ac, field, minutes] of [['bad', 'countDownToOn', 30], ['ac1', 'state', 0], ['ac1', 'countDownToOff', -1],
    ['ac1', 'countDownToOff', 1.5], ['ac1', 'countDownToOff', 721], ['ac1', 'countDownToOff', '30']]) {
    await assert.rejects(client.requestTimer(ac, field, minutes));
  }
  const cancelled = new globalThis.AbortController();
  cancelled.abort();
  await assert.rejects(client.requestTimer('ac1', 'countDownToOff', 30, cancelled.signal));
  assert.equal(writes.length, 2);
  reply = 'false';
  await assert.rejects(client.requestTimer('ac1', 'countDownToOff', 30), AirconCommandRejectedError);
  assert.equal(writes.length, 3);
});

test('timer policy supports each integer minute and preserves cancellation as a separate command', () => {
  for (let minutes = 1; minutes <= 720; minutes++) {
    assert.equal(timerDuration(minutes * 60), minutes * 60);
    validateTimerWrite('countDownToOn', minutes);
    validateTimerWrite('countDownToOff', minutes);
  }
  validateTimerWrite('countDownToOff', 0);
  assert.throws(() => timerDuration(0));
  assert.throws(() => validateTimerWrite('countDownToOff', 1440));
});

test('one-minute start requires a positive countdown in the selected direction; zero confirms cancellation only', () => {
  for (const [state, field] of [['on', 'countDownToOff'], ['off', 'countDownToOn']]) {
    assert.equal(timerMatches(aircon({ state, [field]: 1 }), field, 1), true);
    assert.equal(timerMatches(aircon({ state }), field, 1), false);
    assert.equal(timerMatches(aircon({ state }), field, 0), true);
    assert.equal(timerMatches(aircon({ state, [field]: 1 }), field, 2), true);
    assert.deepEqual(planTimer(aircon({ state }), true, 60), { kind: 'command', field, minutes: 1 });
  }
});

test('timer transport sends exact off-picker native durations without normalization', async t => {
  const writes = [];
  t.mock.method(globalThis, 'fetch', async url => {
    writes.push(JSON.parse(url.searchParams.get('json')));
    return { ok: true, status: 200, text: async () => '{}' };
  });
  const client = new AdvantageAirClient({ ipAddress: '192.0.2.1' });
  for (const minutes of [1, 29, 45, 210, 720, 0]) {
    await client.requestTimer('ac1', 'countDownToOff', minutes);
  }
  assert.deepEqual(writes, [1, 29, 45, 210, 720, 0].map(minutes => ({ ac1: { info: { countDownToOff: minutes } } })));
});
