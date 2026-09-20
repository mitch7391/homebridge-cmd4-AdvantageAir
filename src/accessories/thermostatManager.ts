import type { API, PlatformAccessory } from 'homebridge';
import type { ControllerPollState } from '../api/controllerPoller.js';
import type { ControllerCoordinator } from '../api/controllerCoordinator.js';
import { ThermostatCommandError } from '../api/thermostatCommand.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../settings.js';
import { ThermostatAccessory } from './thermostatAccessory.js';
import { DuplicateControllerError } from './zoneTemperatureManager.js';

type ThermostatController = Pick<ControllerCoordinator,
  'readThermostatCurrentMode' | 'readThermostatCurrentTemperature'
  | 'readThermostatMode' | 'readThermostatTemperature'
  | 'requestThermostatMode' | 'requestThermostatTemperature'>;

export class ThermostatManager {
  private static readonly owners = new WeakMap<API, Map<string, ThermostatManager>>();
  private readonly handlers = new Map<string, ThermostatAccessory>();
  private present = new Set<string>();
  private stopped = false;

  constructor(
    private readonly api: API,
    private readonly accessories: Map<string, PlatformAccessory>,
    private readonly coordinator: ThermostatController,
    private readonly warn: (message: string) => void,
    private readonly onCreated?: (name: string) => void,
  ) {}

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    if (accessory.context.advantageAirThermostat !== true) {
      return;
    }
    const unavailable = () => {
      throw new ThermostatCommandError('Waiting for valid controller data.');
    };
    new ThermostatAccessory(api, accessory, {
      getCurrentMode: unavailable, getTargetMode: unavailable,
      getCurrentTemperature: unavailable, getTargetTemperature: unavailable,
      setTargetMode: unavailable, setTargetTemperature: unavailable,
      warn: () => undefined,
    }).update();
  }

  update(state: ControllerPollState): void {
    if (this.stopped) {
      return;
    }
    try {
      if (!state.data || state.lastAttemptFailed) {
        return;
      }
      const devices = discoverDevices(state.data).filter(device => device.kind === 'aircon');
      if (devices.length > 0) {
        const id = (state.data.system.mid as string).trim();
        let owners = ThermostatManager.owners.get(this.api);
        if (!owners) {
          owners = new Map();
          ThermostatManager.owners.set(this.api, owners);
        }
        const owner = owners.get(id);
        if (owner && owner !== this) {
          throw new DuplicateControllerError();
        }
        owners.set(id, this);
      }
      this.present = new Set(devices.map(device => device.identity));
      for (const device of devices) {
        if (this.handlers.has(device.identity)) {
          continue;
        }
        const identity = device.identity;
        const uuid = this.api.hap.uuid.generate(JSON.stringify([identity, 'thermostat']));
        const cached = this.accessories.get(uuid);
        const accessory = cached ?? new this.api.platformAccessory(device.name, uuid);
        const use = <T>(operation: () => T): T => {
          if (this.stopped || !this.present.has(identity)) {
            throw new ThermostatCommandError('The air conditioner is unavailable.');
          }
          return operation();
        };
        const handler = new ThermostatAccessory(this.api, accessory, {
          getCurrentMode: () => use(() => this.coordinator.readThermostatCurrentMode(identity)),
          getTargetMode: () => use(() => this.coordinator.readThermostatMode(identity)),
          getCurrentTemperature: () => use(() => this.coordinator.readThermostatCurrentTemperature(identity)),
          getTargetTemperature: () => use(() => this.coordinator.readThermostatTemperature(identity)),
          setTargetMode: mode => use(() => this.coordinator.requestThermostatMode(identity, mode)),
          setTargetTemperature: temperature => use(() => this.coordinator.requestThermostatTemperature(identity, temperature)),
          warn: this.warn,
        });
        const needsMarker = accessory.context.advantageAirThermostat !== true;
        accessory.context.advantageAirThermostat = true;
        if (cached && needsMarker) {
          this.api.updatePlatformAccessories([accessory]);
        }
        if (!cached) {
          this.api.registerPlatformAccessories(PLUGIN_NAME, PLATFORM_NAME, [accessory]);
          this.accessories.set(uuid, accessory);
        }
        this.handlers.set(identity, handler);
        if (!cached) {
          try {
            this.onCreated?.(accessory.displayName);
          } catch {
            // A logging failure must not interrupt discovery.
          }
        }
      }
    } catch (error) {
      this.present.clear();
      throw error;
    } finally {
      this.updateHandlers();
    }
  }

  stop(): void {
    this.stopped = true;
    this.present.clear();
    this.updateHandlers();
  }

  private updateHandlers(): void {
    for (const handler of this.handlers.values()) {
      handler.update();
    }
  }
}
