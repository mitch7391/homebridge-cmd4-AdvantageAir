import { airconAccessoryName, updateAccessoryName } from './accessoryName.js';
import type { HomeNameResolver } from '../discovery/homeNames.js';
import { updateAccessoryInformation } from './accessoryInformation.js';
import type { API, PlatformAccessory } from 'homebridge';
import type { ControllerPollState } from '../api/controllerPoller.js';
import type { ControllerCoordinator } from '../api/controllerCoordinator.js';
import { nativeTimer, TimerCommandError } from '../api/timerCommand.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../settings.js';
import { TimerValveAccessory } from './timerValveAccessory.js';

export class TimerValveManager {
  private readonly handlers = new Map<string, TimerValveAccessory>();
  private present = new Set<string>();
  private stopped = false;

  constructor(
    private readonly api: API,
    private readonly accessories: Map<string, PlatformAccessory>,
    private readonly coordinator: Pick<ControllerCoordinator, 'readTimer' | 'requestTimer'>,
    private readonly warn: (message: string) => void,
    private readonly onCreated: (name: string) => void,
    private readonly resolveHomeName?: HomeNameResolver,
  ) {}

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    if (accessory.context.advantageAirTimer !== true) {
      return;
    }
    const unavailable = () => {
      throw new TimerCommandError('Waiting for valid controller data.');
    };
    new TimerValveAccessory(api, accessory, {
      read: unavailable, request: unavailable, persist: () => undefined, warn: () => undefined,
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
      const devices = discoverDevices(state.data).filter(device => {
        if (device.kind !== 'aircon') {
          return false;
        }
        try {
          nativeTimer(state.data!.aircons[device.airconKey]);
          return true;
        } catch {
          return false;
        }
      });
      this.present = new Set(devices.map(device => device.identity));
      for (const device of devices) {
        this.attach(device.identity, device.name, state.data.system.sysType);
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

  private attach(identity: string, name: string, sysType: unknown): void {
    const uuid = this.api.hap.uuid.generate(JSON.stringify([identity, 'native-timer']));
    const cached = this.accessories.get(uuid);
    const displayName = airconAccessoryName(this.resolveHomeName, identity, name, ' Timer', cached);
    if (displayName === undefined) {
      return;
    }
    const rename = (accessory: PlatformAccessory) =>
      (!this.resolveHomeName || this.resolveHomeName(identity) !== undefined)
      && updateAccessoryName(this.api, accessory, displayName,
        [[accessory.getService(this.api.hap.Service.Valve), displayName]]);
    if (this.handlers.has(uuid)) {
      const accessory = this.accessories.get(uuid);
      if (accessory) {
        const renamed = rename(accessory);
        const metadataChanged = updateAccessoryInformation(this.api, accessory, sysType);
        if (renamed || metadataChanged) {
          this.api.updatePlatformAccessories([accessory]);
        }
      }
      return;
    }
    const accessory = cached ?? new this.api.platformAccessory(displayName, uuid);
    const use = <T>(operation: () => T): T => {
      if (this.stopped || !this.present.has(identity)) {
        throw new TimerCommandError('The native timer is unavailable.');
      }
      return operation();
    };
    const handler = new TimerValveAccessory(this.api, accessory, {
      read: () => use(() => this.coordinator.readTimer(identity)),
      request: (active, seconds, replace) => use(() => this.coordinator.requestTimer(identity, active, seconds, replace)),
      persist: () => this.api.updatePlatformAccessories([accessory]),
      warn: this.warn,
    });
    const needsNames = rename(accessory);
    const metadataChanged = updateAccessoryInformation(this.api, accessory, sysType);
    const needsMarker = accessory.context.advantageAirTimer !== true;
    accessory.context.advantageAirTimer = true;
    if (cached && (needsMarker || needsNames || metadataChanged)) {
      this.api.updatePlatformAccessories([accessory]);
    }
    if (!cached) {
      this.api.registerPlatformAccessories(PLUGIN_NAME, PLATFORM_NAME, [accessory]);
      this.accessories.set(uuid, accessory);
    }
    this.handlers.set(uuid, handler);
    if (!cached) {
      try {
        this.onCreated(accessory.displayName);
      } catch {
        // A logging failure must not interrupt accessory discovery.
      }
    }
  }

  private updateHandlers(): void {
    for (const handler of this.handlers.values()) {
      handler.update();
    }
  }
}
