import type { AirconData } from './systemData.js';
import { fanSpeedPercentage } from '../accessories/legacyState.js';
import { ThermostatCommandError } from './thermostatCommand.js';

export type FanSpeed = 'low' | 'medium' | 'high' | 'autoAA';

/** Legacy speed bands; zero means Low, not power off. */
export function fanSetting(value: number): { fan: FanSpeed; percentage: number } {
  if (!Number.isInteger(value) || value < 0 || value > 100) {
    throw new ThermostatCommandError('Fan speed must be a whole percentage from 0 to 100.');
  }
  if (value <= 33) {
    return { fan: 'low', percentage: 25 };
  }
  if (value <= 67) {
    return { fan: 'medium', percentage: 50 };
  }
  if (value < 100) {
    return { fan: 'high', percentage: 90 };
  }
  return { fan: 'autoAA', percentage: 100 };
}

export function planFanSpeed(aircon: AirconData, percentage: number) {
  const setting = fanSetting(percentage);
  // Unknown observed speed cannot be treated as a successful no-op.
  const observed = fanSpeedPercentage(aircon);
  return { ...setting, unchanged: observed === setting.percentage };
}
