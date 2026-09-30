import type { API, Characteristic, PlatformAccessory } from 'homebridge';
import { TIMER_DEFAULT_SECONDS, TIMER_MAX_SECONDS, timerDuration } from '../api/timerCommand.js';
import { ZoneCommandError } from '../api/zoneCommand.js';

export interface TimerValveOptions {
  read: () => { active: boolean; inUse: boolean; remaining: number };
  request: (active: boolean, seconds: number, replace?: boolean) => void;
  persist: () => void;
  warn: (message: string) => void;
}

export class TimerValveAccessory {
  private readonly readings: Array<[Characteristic, () => number]>;

  constructor(private readonly api: API, accessory: PlatformAccessory, options: TimerValveOptions) {
    const { Service, Characteristic, Perms } = api.hap;
    const service = accessory.getService(Service.Valve) ?? accessory.addService(Service.Valve, accessory.displayName);
    service.setCharacteristic(Characteristic.ValveType, Characteristic.ValveType.GENERIC_VALVE);
    service.setCharacteristic(Characteristic.IsConfigured, Characteristic.IsConfigured.CONFIGURED);
    const active = service.getCharacteristic(Characteristic.Active);
    const inUse = service.getCharacteristic(Characteristic.InUse);
    const remaining = service.getCharacteristic(Characteristic.RemainingDuration)
      .setProps({ minValue: 0, maxValue: TIMER_MAX_SECONDS, minStep: 60 });
    const duration = service.getCharacteristic(Characteristic.SetDuration);
    if (duration.value === 0) {
      duration.updateValue(TIMER_DEFAULT_SECONDS);
    }
    duration.setProps({ minValue: TIMER_DEFAULT_SECONDS, maxValue: TIMER_MAX_SECONDS, minStep: 60 });
    let selected = TIMER_DEFAULT_SECONDS;
    try {
      selected = timerDuration(accessory.context.advantageAirTimerDuration);
    } catch {
      // A new or old cache without a valid selection starts at the native minimum.
    }
    this.readings = [
      [active, () => options.read().active ? 1 : 0],
      [inUse, () => options.read().inUse ? 1 : 0],
      [remaining, () => options.read().remaining],
      [duration, () => selected],
    ];
    for (const [characteristic, read] of this.readings) {
      characteristic.onGet(() => {
        try {
          return read();
        } catch {
          throw this.unavailable();
        }
      });
    }
    for (const characteristic of [active, duration]) {
      characteristic.setProps({ perms: [...new Set([...characteristic.props.perms, Perms.WRITE_RESPONSE])] });
    }
    const refuse = (error: unknown): never => {
      const reason = error instanceof ZoneCommandError ? error.message : 'The timer request could not be accepted.';
      try {
        options.warn(`Timer command refused for "${accessory.displayName}": ${reason}`);
      } catch {
        // Logging cannot change the HomeKit response.
      }
      throw this.unavailable();
    };
    active.onSet(value => {
      if (value !== 0 && value !== 1) {
        throw new api.hap.HapStatusError(api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
      }
      try {
        options.request(value === 1, selected);
        return options.read().active ? 1 : 0;
      } catch (error) {
        return refuse(error);
      }
    });
    duration.onSet(value => {
      if (typeof value !== 'number') {
        throw new api.hap.HapStatusError(api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
      }
      try {
        const normalized = timerDuration(value);
        if (options.read().active) {
          options.request(true, normalized, true);
        }
        selected = normalized;
        accessory.context.advantageAirTimerDuration = selected;
        options.persist();
        return selected;
      } catch (error) {
        return refuse(error);
      }
    });
  }

  update(): void {
    for (const [characteristic, read] of this.readings) {
      try {
        characteristic.updateValue(read());
      } catch {
        characteristic.updateValue(this.unavailable());
      }
    }
  }

  private unavailable(): Error {
    return new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  }
}
