import type { AirconData } from './systemData.js';

export type ZoneState = 'open' | 'close';

export type ZoneSwitchPlan = {
  kind: 'unchanged';
  requestedState: ZoneState;
} | {
  kind: 'command';
  requestedState: ZoneState;
  patch: { zones: Record<string, { state: ZoneState }> };
};

export class ZoneCommandError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ZoneCommandError';
  }
}

/**
 * Plan a switch request against a validated, current aircon snapshot.
 * This does not send a command, mutate the snapshot, or confirm its outcome.
 * The caller must coordinate reads/writes and revalidate queued requests.
 */
export function planZoneSwitch(
  aircon: AirconData,
  zoneKey: string,
  on: boolean,
): ZoneSwitchPlan {
  if (typeof on !== 'boolean') {
    throw new ZoneCommandError('Zone switch requests must be boolean.');
  }

  if (typeof zoneKey !== 'string' || !Object.hasOwn(aircon.zones, zoneKey)) {
    throw new ZoneCommandError('The requested zone is not present.');
  }

  const zone = aircon.zones[zoneKey];

  if (zone.state !== 'open' && zone.state !== 'close') {
    throw new ZoneCommandError('The current zone state is unavailable.');
  }

  const requestedState: ZoneState = on ? 'open' : 'close';

  if (zone.state === requestedState) {
    return { kind: 'unchanged', requestedState };
  }

  if (!on) {
    const myZone = aircon.info.myZone;

    if (typeof myZone !== 'number' || !Number.isInteger(myZone) || myZone < 0) {
      throw new ZoneCommandError('The active myZone selection is unavailable.');
    }

    if (myZone > 0) {
      // Use reported zone numbers, not a number guessed from a zone key.
      const selected = Object.entries(aircon.zones).filter(
        ([, candidate]) => candidate.number === myZone,
      );

      if (selected.length !== 1) {
        throw new ZoneCommandError('The active myZone cannot be identified uniquely.');
      }

      if (selected[0][0] === zoneKey) {
        throw new ZoneCommandError('Select another myZone before closing this zone.');
      }
    }
  }

  // Constant-zone airflow protection belongs to the controller. Do not
  // change constants, open other rooms, or change airflow percentages here.
  return {
    kind: 'command',
    requestedState,
    patch: { zones: { [zoneKey]: { state: requestedState } } },
  };
}
