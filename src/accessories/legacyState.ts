import type { AirconData, JsonObject } from '../api/systemData.js';

export class UnavailableStateError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UnavailableStateError';
  }
}

function airconIsOn(aircon: AirconData): boolean {
  switch (aircon.info.state) {
  case 'on':
    return true;
  case 'off':
    return false;
  default:
    throw new UnavailableStateError('Air conditioner power state is unavailable.');
  }
}

/**
 * The separate fan represents ventilation mode, not general fan operation.
 */
export function ventilationIsOn(aircon: AirconData): boolean {
  if (!airconIsOn(aircon)) {
    return false;
  }

  switch (aircon.info.mode) {
  case 'vent':
    return true;
  case 'heat':
  case 'cool':
  case 'dry':
    return false;
  default:
    throw new UnavailableStateError('Air conditioner mode is unavailable.');
  }
}

/**
 * Legacy presentation: 100 percent represents automatic fan speed.
 */
export function fanSpeedPercentage(aircon: AirconData): number {
  switch (aircon.info.fan) {
  case 'low':
    return 25;
  case 'medium':
    return 50;
  case 'high':
    return 90;
  case 'auto':
  case 'autoAA':
    return 100;
  default:
    throw new UnavailableStateError('Fan speed is unavailable.');
  }
}

/**
 * Zone position is independent of air conditioner power.
 */
export function zoneIsOpen(zone: JsonObject): boolean {
  switch (zone.state) {
  case 'open':
    return true;
  case 'close':
    return false;
  default:
    throw new UnavailableStateError('Zone state is unavailable.');
  }
}

export function zoneTemperature(zone: JsonObject): number {
  if (
    typeof zone.measuredTemp !== 'number'
    || !Number.isFinite(zone.measuredTemp)
  ) {
    throw new UnavailableStateError('Zone temperature is unavailable.');
  }

  return zone.measuredTemp;
}

function selectedTemperatureZone(aircon: AirconData): JsonObject {
  const myZone = aircon.info.myZone;

  if (
    typeof myZone !== 'number'
    || !Number.isInteger(myZone)
    || myZone < 0
  ) {
    throw new UnavailableStateError('Temperature-control zone selection is unavailable.');
  }

  const zoneNumber = myZone > 0 ? myZone : aircon.info.constant1;

  if (
    typeof zoneNumber !== 'number'
    || !Number.isInteger(zoneNumber)
    || zoneNumber < 1
  ) {
    throw new UnavailableStateError('No temperature reference zone is available.');
  }

  const matches = Object.values(aircon.zones).filter(
    zone => zone.number === zoneNumber,
  );

  if (matches.length !== 1) {
    throw new UnavailableStateError('Temperature reference zone cannot be identified uniquely.');
  }

  return matches[0];
}

export function thermostatCurrentTemperature(aircon: AirconData): number {
  const zone = selectedTemperatureZone(aircon);

  if (
    typeof zone.type !== 'number'
    || !Number.isInteger(zone.type)
    || zone.type <= 0
    || zone.error !== 0
    || zone.tempSensorClash === true
  ) {
    throw new UnavailableStateError('Temperature reference sensor is unavailable.');
  }

  return zoneTemperature(zone);
}

export function thermostatTargetTemperature(aircon: AirconData): number {
  const myZone = aircon.info.myZone;

  if (
    typeof myZone !== 'number'
    || !Number.isInteger(myZone)
    || myZone < 0
  ) {
    throw new UnavailableStateError('Temperature-control zone selection is unavailable.');
  }

  const temperature = myZone > 0
    ? selectedTemperatureZone(aircon).setTemp
    : aircon.info.setTemp;

  if (
    typeof temperature !== 'number'
    || !Number.isFinite(temperature)
    || temperature < 16
    || temperature > 32
  ) {
    throw new UnavailableStateError('Target temperature is unavailable or outside the supported range.');
  }

  return temperature;
}

export type ThermostatMode = 'off' | 'heat' | 'cool';

/**
 * Maps the selected controller mode to the legacy thermostat presentation.
 * This does not describe actual compressor activity or send any commands.
 */
export function thermostatTargetMode(aircon: AirconData): ThermostatMode {
  if (!airconIsOn(aircon)) {
    return 'off';
  }

  switch (aircon.info.mode) {
  case 'heat':
    return 'heat';
  case 'cool':
    return 'cool';
  case 'vent':
  case 'dry':
    return 'off';
  default:
    throw new UnavailableStateError('Thermostat mode is unavailable.');
  }
}
