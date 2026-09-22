import type { AirconData } from './systemData.js';

export type FanMode = 'vent' | 'dry';

export class ModeFanCommandError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ModeFanCommandError';
  }
}

export type ModeFanPlan = {
  kind: 'unchanged';
  mode: FanMode;
  on: boolean;
} | {
  kind: 'command';
  mode: FanMode;
  on: boolean;
  patch: { info: { state: 'off' } | { state: 'on'; mode: FanMode } };
};

function validate(aircon: AirconData, mode: FanMode): void {
  if (mode !== 'vent' && mode !== 'dry') {
    throw new ModeFanCommandError('Fan mode must be ventilation or dry.');
  }
  if (aircon.info.state !== 'on' && aircon.info.state !== 'off') {
    throw new ModeFanCommandError('Air conditioner power state is unavailable.');
  }
}

/** The mode accessory is On only when the unit is powered on in that mode. */
export function modeFanIsOn(aircon: AirconData, mode: FanMode): boolean {
  validate(aircon, mode);
  if (aircon.info.state === 'off') {
    return false;
  }
  if (!['heat', 'cool', 'vent', 'dry'].includes(aircon.info.mode as string)) {
    throw new ModeFanCommandError('Air conditioner mode is unavailable.');
  }
  return aircon.info.mode === mode;
}

/** Plan only; the coordinator must replan against fresh state before sending. */
export function planModeFan(aircon: AirconData, mode: FanMode, on: boolean): ModeFanPlan {
  validate(aircon, mode);
  if (typeof on !== 'boolean') {
    throw new ModeFanCommandError('Fan power requests must be boolean.');
  }
  if (on) {
    return aircon.info.state === 'on' && aircon.info.mode === mode
      ? { kind: 'unchanged', mode, on }
      : { kind: 'command', mode, on, patch: { info: { state: 'on', mode } } };
  }
  // Turning off an inactive mode must not stop another active HVAC mode.
  return modeFanIsOn(aircon, mode)
    ? { kind: 'command', mode, on, patch: { info: { state: 'off' } } }
    : { kind: 'unchanged', mode, on };
}
