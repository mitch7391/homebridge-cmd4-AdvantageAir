import type { AirconData } from './systemData.js';
import { ThermostatCommandError } from './thermostatCommand.js';
import type { ThermostatModePlan, ThermostatTemperaturePlan } from './thermostatCommand.js';

export type ThermostatPatch = Extract<ThermostatModePlan | ThermostatTemperaturePlan, { kind: 'command' }>['patch'];

function object(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Transport accepts only the exact shapes produced by the thermostat planners. */
export function validateThermostatPatch(value: unknown): asserts value is ThermostatPatch {
  const invalid = () => {
    throw new ThermostatCommandError('Invalid thermostat command.');
  };
  if (!object(value) || !object(value.info)
    || Object.keys(value).some(key => key !== 'info' && key !== 'zones')) {
    return invalid();
  }
  const info = value.info;
  const keys = Object.keys(info);
  if (Object.hasOwn(info, 'setTemp')) {
    const temperature = info.setTemp;
    if (keys.length !== 1 || typeof temperature !== 'number' || !Number.isFinite(temperature)
      || temperature < 16 || temperature > 32) {
      return invalid();
    }
    if (Object.hasOwn(value, 'zones')) {
      if (!object(value.zones) || Object.keys(value.zones).length === 0) {
        return invalid();
      }
      for (const [key, zone] of Object.entries(value.zones)) {
        if (!/^z\d+$/.test(key) || !object(zone) || Object.keys(zone).length !== 1
          || !Object.hasOwn(zone, 'setTemp') || zone.setTemp !== temperature) {
          return invalid();
        }
      }
    }
    return;
  }
  if (Object.hasOwn(value, 'zones')) {
    return invalid();
  }
  if (keys.length === 1 && Object.hasOwn(info, 'state') && info.state === 'off') {
    return;
  }
  if (keys.length === 2 && Object.hasOwn(info, 'state') && Object.hasOwn(info, 'mode')
    && info.state === 'on' && (info.mode === 'heat' || info.mode === 'cool')) {
    return;
  }
  invalid();
}

/** Bind confirmation to the selection and zone addresses used for this write. */
export function temperatureConfirmation(
  before: AirconData,
  patch: Extract<ThermostatTemperaturePlan, { kind: 'command' }>['patch'],
): (current: AirconData) => boolean {
  const myZone = before.info.myZone;
  const temperature = patch.info.setTemp;
  const targets = Object.keys(patch.zones ?? {}).map(key => ({ key, number: before.zones[key].number }));
  return current => {
    if (current.info.myZone !== myZone) {
      throw new ThermostatCommandError('The myZone selection changed while confirming the temperature.');
    }
    if (typeof myZone === 'number' && myZone > 0
      && Object.values(current.zones).filter(zone => zone.number === myZone).length !== 1) {
      throw new ThermostatCommandError('The active myZone became ambiguous while confirming the temperature.');
    }
    for (const { key, number } of targets) {
      const zone = current.zones[key];
      if (!zone || zone.number !== number || typeof zone.type !== 'number'
        || !Number.isInteger(zone.type) || zone.type <= 0) {
        throw new ThermostatCommandError('A temperature target zone changed or became unavailable.');
      }
    }
    return current.info.setTemp === temperature
      && targets.every(({ key }) => current.zones[key].setTemp === temperature);
  };
}
