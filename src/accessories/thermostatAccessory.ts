import type { API, Characteristic, CharacteristicValue, PlatformAccessory } from 'homebridge';
import type { ThermostatMode } from './legacyState.js';
import { ThermostatCommandError } from '../api/thermostatCommand.js';
import { ZoneCommandError } from '../api/zoneCommand.js';

export interface ThermostatOptions {
  getCurrentMode: () => ThermostatMode;
  getTargetMode: () => ThermostatMode;
  getCurrentTemperature: () => number;
  getTargetTemperature: () => number;
  /** Synchronous admission; the coordinator confirms execution later. */
  setTargetMode: (mode: ThermostatMode) => void;
  setTargetTemperature: (temperature: number) => void;
  warn: (message: string) => void;
}

export class ThermostatAccessory {
  private readonly readings: Array<[Characteristic, () => number]>;

  constructor(
    private readonly api: API,
    private readonly accessory: PlatformAccessory,
    private readonly options: ThermostatOptions,
  ) {
    const { Service, Characteristic } = api.hap;
    const service = accessory.getService(Service.Thermostat)
      ?? accessory.addService(Service.Thermostat, accessory.displayName);
    const currentMode = service.getCharacteristic(Characteristic.CurrentHeatingCoolingState);
    const targetMode = service.getCharacteristic(Characteristic.TargetHeatingCoolingState)
      .updateValue(this.unavailable())
      .setProps({ validValues: [0, 1, 2], minValue: 0, maxValue: 2 });
    const currentTemperature = service.getCharacteristic(Characteristic.CurrentTemperature);
    const targetTemperature = service.getCharacteristic(Characteristic.TargetTemperature)
      .updateValue(this.unavailable())
      .setProps({ minValue: 16, maxValue: 32, minStep: 1 });
    this.readings = [
      [currentMode, () => this.mode(this.options.getCurrentMode())],
      [targetMode, () => this.mode(this.options.getTargetMode())],
      [currentTemperature, () => this.temperature(this.options.getCurrentTemperature(), currentTemperature)],
      [targetTemperature, () => this.temperature(this.options.getTargetTemperature(), targetTemperature)],
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
    targetMode.onSet(value => {
      if (value !== 0 && value !== 1 && value !== 2) {
        throw this.invalid();
      }
      const mode = value === 0 ? 'off' : value === 1 ? 'heat' : 'cool';
      this.accept(`mode ${mode}`, () => this.options.setTargetMode(mode));
    });
    targetTemperature.onSet(value => {
      this.validateTarget(value);
      this.accept(`target temperature ${value} °C`, () => this.options.setTargetTemperature(value as number));
    });
    // This initial legacy layout displays Celsius. No controller write is needed.
    service.getCharacteristic(Characteristic.TemperatureDisplayUnits)
      .setProps({ validValues: [0], minValue: 0, maxValue: 0 })
      .onGet(() => Characteristic.TemperatureDisplayUnits.CELSIUS)
      .onSet(value => {
        if (value !== Characteristic.TemperatureDisplayUnits.CELSIUS) {
          throw this.invalid();
        }
      })
      .updateValue(Characteristic.TemperatureDisplayUnits.CELSIUS);
  }

  update(): void {
    // A failed sensor reading must not fabricate or hide a valid target value.
    for (const [characteristic, read] of this.readings) {
      try {
        characteristic.updateValue(read());
      } catch {
        characteristic.updateValue(this.unavailable());
      }
    }
  }

  private mode(value: ThermostatMode): number {
    if (value === 'off') {
      return 0;
    }
    if (value === 'heat') {
      return 1;
    }
    if (value === 'cool') {
      return 2;
    }
    throw this.unavailable();
  }

  private temperature(value: number, characteristic: Characteristic): number {
    if (!Number.isFinite(value)
      || (characteristic.props.minValue !== undefined && value < characteristic.props.minValue)
      || (characteristic.props.maxValue !== undefined && value > characteristic.props.maxValue)) {
      throw this.unavailable();
    }
    return value;
  }

  private validateTarget(value: CharacteristicValue): void {
    if (typeof value !== 'number' || !Number.isInteger(value) || value < 16 || value > 32) {
      throw this.invalid();
    }
  }

  private accept(target: string, request: () => void): void {
    try {
      request();
    } catch (error) {
      const reason = error instanceof ThermostatCommandError || error instanceof ZoneCommandError
        ? error.message : 'The thermostat request could not be accepted.';
      try {
        this.options.warn(`Thermostat command refused for "${this.accessory.displayName}" (${target}): ${reason}`);
      } catch {
        // Logging cannot change the HomeKit error response.
      }
      throw this.unavailable();
    }
  }

  private unavailable(): Error {
    return new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
  }

  private invalid(): Error {
    return new this.api.hap.HapStatusError(this.api.hap.HAPStatus.INVALID_VALUE_IN_REQUEST);
  }
}
