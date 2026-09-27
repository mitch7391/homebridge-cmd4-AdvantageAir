import type { AirconData } from './systemData.js';

export class MyZoneCommandError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MyZoneCommandError';
  }
}

export interface MyZoneSelectionPlan {
  action: 'open' | 'select' | 'temperature' | 'unchanged';
  zoneNumber: number;
  temperature: number;
}

/**
 * Plan from observed data. The coordinator resolves stable identities first.
 * Each physical step must be confirmed before planning the following step.
 */
export function planMyZoneSelection(
  aircon: AirconData,
  zoneKey: string,
): MyZoneSelectionPlan {
  const active = aircon.info.myZone;
  if (typeof active !== 'number' || !Number.isSafeInteger(active) || active <= 0) {
    throw new MyZoneCommandError('MyZone selection requires installer-enabled MyZone operation.');
  }

  const zones = Object.values(aircon.zones);
  const activeZones = zones.filter(zone => zone.number === active);
  if (activeZones.length !== 1) {
    throw new MyZoneCommandError('The active MyZone cannot be identified uniquely.');
  }

  const activeType = activeZones[0].type;
  if (typeof activeType !== 'number' || !Number.isInteger(activeType) || activeType <= 0) {
    throw new MyZoneCommandError('The active MyZone is not a temperature-controlled zone.');
  }

  const zone = Object.hasOwn(aircon.zones, zoneKey) ? aircon.zones[zoneKey] : undefined;
  if (!zone) {
    throw new MyZoneCommandError('The requested MyZone is unavailable.');
  }
  if (typeof zone.type !== 'number' || !Number.isInteger(zone.type) || zone.type <= 0) {
    throw new MyZoneCommandError('MyZone requires a temperature-controlled zone.');
  }

  const zoneNumber = zone.number;
  if (typeof zoneNumber !== 'number' || !Number.isSafeInteger(zoneNumber) || zoneNumber <= 0
    || zones.filter(candidate => candidate.number === zoneNumber).length !== 1) {
    throw new MyZoneCommandError('The requested MyZone number is invalid or ambiguous.');
  }

  if (zone.state !== 'open' && zone.state !== 'close') {
    throw new MyZoneCommandError('The requested MyZone state is unavailable.');
  }

  const temperature = zone.setTemp;
  if (typeof temperature !== 'number' || !Number.isFinite(temperature)
    || temperature < 16 || temperature > 32) {
    throw new MyZoneCommandError('The requested MyZone target must be a valid temperature from 16 to 32 °C.');
  }

  const action = zone.state === 'close' ? 'open'
    : active !== zoneNumber ? 'select'
      : aircon.info.setTemp !== temperature ? 'temperature'
        : 'unchanged';

  return { action, zoneNumber, temperature };
}
