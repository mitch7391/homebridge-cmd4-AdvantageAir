import type { AirconData, JsonObject } from './systemData.js';
import { ZoneCommandError } from './zoneCommand.js';

export function requirePercentageZone(zone: JsonObject | undefined): asserts zone is JsonObject {
  if (!zone || zone.type !== 0) {
    throw new ZoneCommandError('The zone is not currently percentage-controlled.');
  }
}

/** Read the stored value, including while closed; never substitute a guessed percentage. */
export function zonePercentage(zone: JsonObject): number {
  requirePercentageZone(zone);
  const value = zone.value;
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 5 || value > 100 || value % 5 !== 0) {
    throw new ZoneCommandError('Zone percentage is unavailable or outside the supported increments.');
  }
  return value;
}

/** Zero belongs to the state control and must never become a value write. */
export function normalizeZonePercentage(value: number): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 1 || value > 100) {
    throw new ZoneCommandError('Zone percentage requests must be whole numbers from 1 to 100.');
  }
  return Math.max(5, Math.round(value / 5) * 5);
}

export function planZonePercentage(aircon: AirconData, zoneKey: string, value: number) {
  const percentage = normalizeZonePercentage(value);
  if (typeof zoneKey !== 'string' || !Object.hasOwn(aircon.zones, zoneKey)) {
    throw new ZoneCommandError('The requested zone is not present.');
  }
  const zone = aircon.zones[zoneKey];
  const current = zonePercentage(zone);
  return { percentage, unchanged: current === percentage };
}
