import type { API, PlatformAccessory } from 'homebridge';
import type { ControllerPollState } from '../api/controllerPoller.js';
import type { ControllerCoordinator } from '../api/controllerCoordinator.js';
import { ModeFanCommandError } from '../api/modeFanCommand.js';
import type { FanMode } from '../api/modeFanCommand.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../settings.js';
import { ModeFanAccessory } from './modeFanAccessory.js';

export class ModeFanManager {
  private readonly handlers = new Map<string, ModeFanAccessory>();
  private present = new Set<string>();
  private stopped = false;

  constructor(
    private readonly api: API,
    private readonly accessories: Map<string, PlatformAccessory>,
    private readonly coordinator: Pick<ControllerCoordinator, 'readModeFan' | 'requestModeFan' | 'readFanSpeed' | 'requestFanSpeed'>,
    private readonly warn: (message: string) => void,
    private readonly onCreated: (name: string) => void,
  ) {}

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    if (accessory.context.advantageAirModeFan !== 'vent' && accessory.context.advantageAirModeFan !== 'dry') {
      return;
    }
    const unavailable = () => {
      throw new ModeFanCommandError('Waiting for valid controller data.');
    };
    new ModeFanAccessory(api, accessory, {
      getOn: unavailable, setOn: unavailable, getSpeed: unavailable, setSpeed: unavailable, warn: () => undefined,
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
      this.present = new Set(devices.map(device => device.identity));
      for (const device of devices) {
        for (const mode of ['vent', 'dry'] as const) {
          this.attach(device.identity, device.name, mode);
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

  private attach(identity: string, name: string, mode: FanMode): void {
    const uuid = this.api.hap.uuid.generate(JSON.stringify([identity, 'mode-fan', mode]));
    if (this.handlers.has(uuid)) {
      return;
    }
    const cached = this.accessories.get(uuid);
    const accessory = cached ?? new this.api.platformAccessory(`${name} ${mode === 'vent' ? 'Fan' : 'Dry Mode'}`, uuid);
    const use = <T>(operation: () => T): T => {
      if (this.stopped || !this.present.has(identity)) {
        throw new ModeFanCommandError('The air conditioner is unavailable.');
      }
      return operation();
    };
    const handler = new ModeFanAccessory(this.api, accessory, {
      getOn: () => use(() => this.coordinator.readModeFan(identity, mode)),
      setOn: on => use(() => this.coordinator.requestModeFan(identity, mode, on)),
      getSpeed: () => use(() => this.coordinator.readFanSpeed(identity)),
      setSpeed: percentage => use(() => this.coordinator.requestFanSpeed(identity, percentage)),
      warn: this.warn,
    });
    const needsMarker = accessory.context.advantageAirModeFan !== mode;
    accessory.context.advantageAirModeFan = mode;
    if (cached && needsMarker) {
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
