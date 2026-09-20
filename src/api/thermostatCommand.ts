import type { AirconData } from './systemData.js';
import type { ThermostatMode } from '../accessories/legacyState.js';

export class ThermostatCommandError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ThermostatCommandError';
  }
}

export type ThermostatModePlan = {
  kind: 'unchanged';
  requestedMode: ThermostatMode;
} | {
  kind: 'command';
  requestedMode: ThermostatMode;
  patch: { info: { state: 'off' } | { state: 'on'; mode: 'heat' | 'cool' } };
};

export type ThermostatTemperaturePlan = {
  kind: 'unchanged';
  requestedTemperature: number;
} | {
  kind: 'command';
  requestedTemperature: number;
  patch: {
    info: { setTemp: number };
    zones?: Record<string, { setTemp: number }>;
  };
};

/** Plan against fresh, validated controller data; do not send or mutate it. */
export function planThermostatMode(aircon: AirconData, mode: ThermostatMode): ThermostatModePlan {
  if (mode !== 'off' && mode !== 'heat' && mode !== 'cool') {
    throw new ThermostatCommandError('Thermostat mode must be Off, Heat or Cool.');
  }
  const state = aircon.info.state;
  if (state !== 'on' && state !== 'off') {
    throw new ThermostatCommandError('Air conditioner power state is unavailable.');
  }

  if (mode === 'off') {
    // Explicit Off switches off the unit even if it is currently ventilating.
    // Do not use the thermostat display projection to decide this is a no-op.
    return state === 'off'
      ? { kind: 'unchanged', requestedMode: mode }
      : { kind: 'command', requestedMode: mode, patch: { info: { state: 'off' } } };
  }
  if (state === 'on' && aircon.info.mode === mode) {
    return { kind: 'unchanged', requestedMode: mode };
  }
  return {
    kind: 'command', requestedMode: mode,
    patch: { info: { state: 'on', mode } },
  };
}

/**
 * Legacy target-temperature behaviour: update the main target plus the active
 * myZone, or all temperature-controlled zones when myZone is disabled.
 * The coordinator must replan against fresh addressing before dispatch.
 */
export function planThermostatTemperature(aircon: AirconData, temperature: number): ThermostatTemperaturePlan {
  if (typeof temperature !== 'number' || !Number.isFinite(temperature)
    || temperature < 16 || temperature > 32) {
    throw new ThermostatCommandError('Target temperature must be a number from 16 to 32 degrees Celsius.');
  }
  const myZone = aircon.info.myZone;
  if (typeof myZone !== 'number' || !Number.isInteger(myZone) || myZone < 0) {
    throw new ThermostatCommandError('Temperature-control zone selection is unavailable.');
  }

  const entries = Object.entries(aircon.zones);
  const selected = myZone > 0
    ? entries.filter(([, zone]) => zone.number === myZone)
    : entries;
  if (myZone > 0 && selected.length !== 1) {
    throw new ThermostatCommandError('The active myZone cannot be identified uniquely.');
  }

  const targets: Record<string, { setTemp: number }> = {};
  let unchanged = aircon.info.setTemp === temperature;
  for (const [key, zone] of selected) {
    if (typeof zone.type !== 'number' || !Number.isInteger(zone.type) || zone.type < 0) {
      throw new ThermostatCommandError('Zone temperature-control capability is unavailable.');
    }
    if (zone.type === 0) {
      if (myZone > 0) {
        throw new ThermostatCommandError('The active myZone does not support temperature control.');
      }
      continue;
    }
    if (!/^z\d+$/.test(key)) {
      throw new ThermostatCommandError('Temperature-control zone addressing is invalid.');
    }
    targets[key] = { setTemp: temperature };
    unchanged = unchanged && zone.setTemp === temperature;
  }

  if (unchanged) {
    return { kind: 'unchanged', requestedTemperature: temperature };
  }
  return {
    kind: 'command', requestedTemperature: temperature,
    patch: {
      info: { setTemp: temperature },
      ...(Object.keys(targets).length > 0 ? { zones: targets } : {}),
    },
  };
}
