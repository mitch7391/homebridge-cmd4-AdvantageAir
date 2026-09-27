import type { AirconData } from './systemData.js';
import { ZoneCommandError } from './zoneCommand.js';

export class MyZoneCommandError extends ZoneCommandError {
  constructor(message: string) {
    super(message);
    this.name = 'MyZoneCommandError';
  }
}

export type MyZoneStep = 'open' | 'select' | 'target';

export interface MyZoneProgress {
  name: string;
  zoneName: string;
  step: MyZoneStep;
  outcome: 'confirmed' | 'unchanged' | 'failed';
  reason?: string;
}

export interface MyZonePlan {
  zoneNumber: number;
  temperature: number;
  open: boolean;
  selected: boolean;
  targetMatches: boolean;
}

/** Zero is installer-disabled MyZone, not a selectable reference zone. */
export function activeMyZoneNumber(aircon: AirconData): number {
  const number = aircon.info.myZone;
  if (typeof number !== 'number' || !Number.isSafeInteger(number) || number <= 0) {
    throw new MyZoneCommandError('MyZone selection requires installer-configured MyZone operation.');
  }
  const matches = Object.values(aircon.zones).filter(zone => zone.number === number);
  if (matches.length !== 1) {
    throw new MyZoneCommandError('The active MyZone number is missing or ambiguous.');
  }
  const type = matches[0].type;
  if (typeof type !== 'number' || !Number.isInteger(type) || type <= 0) {
    throw new MyZoneCommandError('The active MyZone is not a temperature-controlled zone.');
  }
  return number;
}

/** Preserve an existing zone target exactly; thermostat input rounding does not apply here. */
export function myZoneTarget(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 16 || value > 32) {
    throw new MyZoneCommandError('The MyZone target must be a finite temperature from 16 to 32 °C.');
  }
  return value;
}

/** Plan from observations without changing the snapshot or deriving numbers from keys. */
export function planMyZoneSelection(aircon: AirconData, zoneKey: string): MyZonePlan {
  const active = activeMyZoneNumber(aircon);
  if (typeof zoneKey !== 'string' || !/^z\d+$/.test(zoneKey) || !Object.hasOwn(aircon.zones, zoneKey)) {
    throw new MyZoneCommandError('The requested MyZone address is unavailable.');
  }
  const zone = aircon.zones[zoneKey];
  if (typeof zone.type !== 'number' || !Number.isInteger(zone.type) || zone.type <= 0) {
    throw new MyZoneCommandError('MyZone requires a temperature-controlled zone.');
  }
  const number = zone.number;
  if (typeof number !== 'number' || !Number.isSafeInteger(number) || number <= 0
    || Object.values(aircon.zones).filter(candidate => candidate.number === number).length !== 1) {
    throw new MyZoneCommandError('The requested MyZone number is invalid or ambiguous.');
  }
  if (zone.state !== 'open' && zone.state !== 'close') {
    throw new MyZoneCommandError('The requested MyZone open/closed state is unavailable.');
  }
  const temperature = myZoneTarget(zone.setTemp);
  return {
    zoneNumber: number,
    temperature,
    open: zone.state === 'open',
    selected: active === number,
    targetMatches: aircon.info.setTemp === temperature,
  };
}
