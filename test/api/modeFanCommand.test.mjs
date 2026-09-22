import assert from 'node:assert/strict';
import test from 'node:test';
import { modeFanIsOn, planModeFan, ModeFanCommandError } from '../../dist/api/modeFanCommand.js';

const snapshot = (state, mode) => ({
  info: { state, mode, fan: 'auto', setTemp: 24, myZone: 0 },
  zones: { z01: { state: 'open', value: 70, setTemp: 24 } },
});

test('Vent and Dry display On only for their own active mode', () => {
  for (const selected of ['vent', 'dry']) {
    for (const mode of ['heat', 'cool', 'vent', 'dry']) {
      assert.equal(modeFanIsOn(snapshot('on', mode), selected), mode === selected);
      assert.equal(modeFanIsOn(snapshot('off', mode), selected), false);
    }
  }
});

test('enabling either mode combines power and selection without changing speed or temperatures', () => {
  for (const selected of ['vent', 'dry']) {
    for (const state of ['on', 'off']) {
      for (const mode of ['heat', 'cool', 'vent', 'dry']) {
        const data = snapshot(state, mode);
        const before = globalThis.structuredClone(data);
        assert.deepEqual(planModeFan(data, selected, true), state === 'on' && mode === selected
          ? { kind: 'unchanged', mode: selected, on: true }
          : { kind: 'command', mode: selected, on: true, patch: { info: { state: 'on', mode: selected } } });
        assert.deepEqual(data, before);
      }
    }
  }
});

test('disabling a mode powers off only that active mode and preserves the stored mode', () => {
  for (const selected of ['vent', 'dry']) {
    for (const state of ['on', 'off']) {
      for (const mode of ['heat', 'cool', 'vent', 'dry']) {
        const data = snapshot(state, mode);
        const before = globalThis.structuredClone(data);
        assert.deepEqual(planModeFan(data, selected, false), state === 'on' && mode === selected
          ? { kind: 'command', mode: selected, on: false, patch: { info: { state: 'off' } } }
          : { kind: 'unchanged', mode: selected, on: false });
        assert.deepEqual(data, before);
      }
    }
  }
});

test('invalid requests and uncertain active state cannot produce a shutdown command', () => {
  for (const mode of ['cool', 'heat', 'auto', null, undefined]) {
    assert.throws(() => planModeFan(snapshot('on', 'cool'), mode, true), ModeFanCommandError);
    assert.throws(() => modeFanIsOn(snapshot('on', 'cool'), mode), ModeFanCommandError);
  }
  for (const on of [0, 1, 'true', null, undefined]) {
    assert.throws(() => planModeFan(snapshot('on', 'vent'), 'vent', on), ModeFanCommandError);
  }
  for (const mode of ['vent', 'dry']) {
    assert.throws(() => planModeFan(snapshot('unknown', mode), mode, true), ModeFanCommandError);
    assert.throws(() => planModeFan(snapshot('on', 'unknown'), mode, false), ModeFanCommandError);
    assert.throws(() => modeFanIsOn(snapshot('on', 'unknown'), mode), ModeFanCommandError);
    assert.deepEqual(planModeFan(snapshot('off', 'unknown'), mode, false), { kind: 'unchanged', mode, on: false });
  }
});
