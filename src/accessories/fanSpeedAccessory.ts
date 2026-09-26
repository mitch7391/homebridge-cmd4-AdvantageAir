import type { API, PlatformAccessory, Service } from 'homebridge';
import { fanSetting } from '../api/fanCommand.js';
import { ThermostatCommandError } from '../api/thermostatCommand.js';
import { ZoneCommandError } from '../api/zoneCommand.js';

export class FanSpeedAccessory {
  private readonly service: Service;

  constructor(
    private readonly api: API,
    accessory: PlatformAccessory,
    private readonly getSpeed: () => number,
    setSpeed: (percentage: number) => void,
    warn: (message: string) => void,
  ) {
    const { Service, Characteristic, Perms } = api.hap;
    this.service = accessory.getServiceById(Service.Fan, 'fan-speed')
      ?? accessory.addService(Service.Fan, `${accessory.displayName} FanSpeed`, 'fan-speed');
    accessory.getService(Service.Thermostat)?.addLinkedService(this.service);
    const on = this.service.getCharacteristic(Characteristic.On);
    on.setProps({ perms: [...new Set([...on.props.perms, Perms.WRITE_RESPONSE])] })
      .onGet(() => {
        this.read();
        return true;
      })
      .onSet(value => {
        if (typeof value !== 'boolean') {
          throw new api.hap.HapStatusError(api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
        }
        this.read();
        // Legacy FanSpeed is speed-only. Its required On field never controls power.
        return true;
      });
    const speed = this.service.getCharacteristic(Characteristic.RotationSpeed);
    speed.setProps({ minValue: 0, maxValue: 100, minStep: 1,
      perms: [...new Set([...speed.props.perms, Perms.WRITE_RESPONSE])] })
      .onGet(() => this.read())
      .onSet(value => {
        if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > 100) {
          throw new api.hap.HapStatusError(api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
        }
        const setting = fanSetting(value);
        try {
          setSpeed(setting.percentage);
          return setting.percentage;
        } catch (error) {
          const reason = error instanceof ThermostatCommandError || error instanceof ZoneCommandError
            ? error.message : 'The fan request could not be accepted.';
          try {
            warn(`Fan command refused for "${accessory.displayName}" (${setting.fan}): ${reason}`);
          } catch {
            // Logging must not change the HomeKit error response.
          }
          throw this.unavailable();
        }
      });
  }

  update(): void {
    const { Characteristic } = this.api.hap;
    try {
      const speed = this.read();
      this.service.updateCharacteristic(Characteristic.On, true);
      this.service.updateCharacteristic(Characteristic.RotationSpeed, speed);
    } catch {
      this.service.updateCharacteristic(Characteristic.On, this.unavailable());
      this.service.updateCharacteristic(Characteristic.RotationSpeed, this.unavailable());
    }
  }

  private read(): number {
    try {
      const value = this.getSpeed();
      if (![25, 50, 90, 100].includes(value)) {
        throw this.unavailable();
      }
      return value;
    } catch {
      throw this.unavailable();
    }
  }

  private unavailable(): Error {
    return new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  }
}
