import type { API, Characteristic, PlatformAccessory } from 'homebridge';
import { fanSetting } from '../api/fanCommand.js';
import { ModeFanCommandError } from '../api/modeFanCommand.js';
import { ThermostatCommandError } from '../api/thermostatCommand.js';
import { ZoneCommandError } from '../api/zoneCommand.js';

export interface ModeFanOptions {
  getOn: () => boolean;
  setOn: (on: boolean) => void;
  getSpeed: () => number;
  setSpeed: (percentage: number) => void;
  warn: (message: string) => void;
}

export class ModeFanAccessory {
  private readonly readings: Array<[Characteristic, () => boolean | number]>;

  constructor(private readonly api: API, accessory: PlatformAccessory, options: ModeFanOptions) {
    const { Service, Characteristic, Perms } = api.hap;
    const service = accessory.getService(Service.Fan) ?? accessory.addService(Service.Fan, accessory.displayName);
    const on = service.getCharacteristic(Characteristic.On);
    const speed = service.getCharacteristic(Characteristic.RotationSpeed);
    const readOn = () => {
      const value = options.getOn();
      if (typeof value !== 'boolean') {
        throw this.unavailable();
      }
      return value;
    };
    const readSpeed = () => {
      const value = options.getSpeed();
      if (![25, 50, 90, 100].includes(value)) {
        throw this.unavailable();
      }
      return value;
    };
    this.readings = [[on, readOn], [speed, readSpeed]];
    for (const [characteristic, read] of this.readings) {
      characteristic.setProps({ perms: [...new Set([...characteristic.props.perms, Perms.WRITE_RESPONSE])] })
        .onGet(() => {
          try {
            return read();
          } catch {
            throw this.unavailable();
          }
        });
    }
    const refuse = (error: unknown, target: string): never => {
      const reason = error instanceof ModeFanCommandError || error instanceof ThermostatCommandError || error instanceof ZoneCommandError
        ? error.message : 'The fan request could not be accepted.';
      try {
        options.warn(`Fan command refused for "${accessory.displayName}" (${target}): ${reason}`);
      } catch {
        // Logging must not change the HomeKit error response.
      }
      throw this.unavailable();
    };
    on.onSet(value => {
      if (typeof value !== 'boolean') {
        throw new api.hap.HapStatusError(api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
      }
      try {
        options.setOn(value);
        return readOn();
      } catch (error) {
        return refuse(error, value ? 'On' : 'Off');
      }
    });
    speed.setProps({ minValue: 0, maxValue: 100, minStep: 1 }).onSet(value => {
      if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > 100) {
        throw new api.hap.HapStatusError(api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
      }
      const setting = fanSetting(value);
      try {
        options.setSpeed(setting.percentage);
        return setting.percentage;
      } catch (error) {
        return refuse(error, setting.fan === 'autoAA' ? 'Auto Mode' : setting.fan);
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
