import type { AirconData } from './systemData.js';
import { ZoneCommandError } from './zoneCommand.js';

export class TimerCommandError extends ZoneCommandError {}

export type TimerField = 'countDownToOn' | 'countDownToOff';
export const TIMER_MIN_SECONDS = 60;
export const TIMER_MAX_SECONDS = 43200;
export const TIMER_DEFAULT_SECONDS = 1800;

/** Native integer minutes; tablet picker steps do not restrict API durations. */
export function timerDuration(seconds: number): number {
  if (typeof seconds !== 'number' || !Number.isInteger(seconds) || seconds < TIMER_MIN_SECONDS || seconds > TIMER_MAX_SECONDS) {
    throw new TimerCommandError('Timer duration must be whole seconds from 1 minute to 12 hours.');
  }
  return Math.ceil(seconds / 60) * 60;
}

export function validateTimerWrite(field: TimerField, minutes: number): void {
  if ((field !== 'countDownToOn' && field !== 'countDownToOff')
    || typeof minutes !== 'number' || !Number.isInteger(minutes)
    || minutes < 0 || minutes > 720) {
    throw new TimerCommandError('Invalid native timer command.');
  }
}

export function nativeTimer(aircon: AirconData): { field: TimerField | undefined; remaining: number } {
  const { state, countDownToOn: on, countDownToOff: off } = aircon.info;
  const valid = (value: unknown): value is number => typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= 720;
  if ((state !== 'on' && state !== 'off') || !valid(on) || !valid(off) || on > 0 && off > 0
    || state === 'on' && on > 0 || state === 'off' && off > 0) {
    throw new TimerCommandError('Native timer state is unavailable or inconsistent.');
  }
  return { field: on > 0 ? 'countDownToOn' : off > 0 ? 'countDownToOff' : undefined, remaining: (on + off) * 60 };
}

export function planTimer(aircon: AirconData, active: boolean, seconds: number, replace = false):
  { kind: 'unchanged' } | { kind: 'command'; field: TimerField; minutes: number } {
  if (typeof active !== 'boolean' || typeof replace !== 'boolean') {
    throw new TimerCommandError('Invalid timer activation.');
  }
  const duration = timerDuration(seconds);
  const observed = nativeTimer(aircon);
  if (!active) {
    return observed.field ? { kind: 'command', field: observed.field, minutes: 0 } : { kind: 'unchanged' };
  }
  // Repeated Active=1 must not reset a running timer. An explicit duration edit may replace it.
  if (observed.field && (!replace || observed.remaining === duration)) {
    return { kind: 'unchanged' };
  }
  return { kind: 'command', field: aircon.info.state === 'on' ? 'countDownToOff' : 'countDownToOn', minutes: duration / 60 };
}

/** Called only within the coordinator's 15-second execution window: at most one minute boundary. */
export function timerMatches(aircon: AirconData, field: TimerField, minutes: number): boolean {
  const observed = nativeTimer(aircon);
  if (minutes === 0) {
    return observed.remaining === 0;
  }
  // Zero can confirm cancellation only, never a one-minute start.
  return observed.remaining > 0 && observed.field === field
    && (observed.remaining === minutes * 60 || minutes > 1 && observed.remaining === (minutes - 1) * 60);
}
