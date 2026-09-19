import type { API, PlatformAccessory } from 'homebridge';

import type { ControllerPollState } from '../api/controllerPoller.js';
import type { ZoneCommandExecutor } from '../api/zoneCommandExecutor.js';
import { ZoneCommandError } from '../api/zoneCommand.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { PLATFORM_NAME, PLUGIN_NAME } from '../settings.js';
import { zoneIsOpen } from './legacyState.js';
import { ZoneSwitchAccessory } from './zoneSwitchAccessory.js';
import { DuplicateControllerError } from './zoneTemperatureManager.js';

export class ZoneSwitchManager {
  private static readonly owners = new WeakMap<API, Map<string, ZoneSwitchManager>>();
  private readonly handlers = new Map<string, ZoneSwitchAccessory>();
  private state: ControllerPollState = { lastAttemptFailed: false };
  private pending = 0;
  private completedAt = -Infinity;
  private stopped = false;

  constructor(
    private readonly api: API,
    private readonly accessories: Map<string, PlatformAccessory>,
    private readonly executor: Pick<ZoneCommandExecutor, 'setZone' | 'stop'>,
    private readonly warn: (message: string) => void,
  ) {}

  static prepareCachedAccessory(api: API, accessory: PlatformAccessory): void {
    if (accessory.context.advantageAirZoneSwitch !== true) {
      return;
    }
    const unavailable = () => {
      throw new ZoneCommandError('Waiting for valid controller data.');
    };
    new ZoneSwitchAccessory(api, accessory, {
      getOn: unavailable,
      setOn: async () => unavailable(),
      warn: () => undefined,
    }).update();
  }

  update(state: ControllerPollState): void {
    if (this.stopped || this.pending > 0) {
      return;
    }
    // Ignore polls that started before the most recently completed command.
    // Failed polls can contain retained data from before that command too.
    if (state.lastAttemptFailed || !state.data
      || (this.completedAt !== -Infinity
        && (typeof state.lastAttemptAt !== 'number' || state.lastAttemptAt <= this.completedAt))) {
      this.updateHandlers();
      return;
    }
    this.accept(state);
  }

  stop(): void {
    this.stopped = true;
    this.executor.stop();
    this.state = { lastAttemptFailed: true };
    this.updateHandlers();
  }

  private accept(state: ControllerPollState): void {
    try {
      const data = state.data;
      if (!data) {
        throw new ZoneCommandError('Controller data is unavailable.');
      }
      const devices = discoverDevices(data);
      if (devices.length > 0) {
        const id = (data.system.mid as string).trim();
        let owners = ZoneSwitchManager.owners.get(this.api);
        if (!owners) {
          owners = new Map();
          ZoneSwitchManager.owners.set(this.api, owners);
        }
        const owner = owners.get(id);
        if (owner && owner !== this) {
          throw new DuplicateControllerError();
        }
        owners.set(id, this);
      }
      this.state = structuredClone(state);
      for (const device of devices) {
        if (device.kind !== 'zone') {
          continue;
        }
        const zone = data.aircons[device.airconKey].zones[device.zoneKey];
        // Legacy layout uses switches for temperature-controlled zones.
        if (typeof zone.type !== 'number' || !Number.isInteger(zone.type) || zone.type <= 0) {
          continue;
        }
        if (this.handlers.has(device.identity)) {
          continue;
        }
        const uuid = this.api.hap.uuid.generate(JSON.stringify([device.identity, 'zone-switch']));
        const cached = this.accessories.get(uuid);
        const accessory = cached ?? new this.api.platformAccessory(`${device.name} Zone`, uuid);
        const handler = new ZoneSwitchAccessory(this.api, accessory, {
          getOn: () => this.read(device.identity),
          setOn: (on, signal) => this.set(device.identity, on, signal),
          warn: this.warn,
        });
        const needsMarker = accessory.context.advantageAirZoneSwitch !== true;
        accessory.context.advantageAirZoneSwitch = true;
        if (cached && needsMarker) {
          this.api.updatePlatformAccessories([accessory]);
        }
        if (!cached) {
          this.api.registerPlatformAccessories(PLUGIN_NAME, PLATFORM_NAME, [accessory]);
          this.accessories.set(uuid, accessory);
        }
        this.handlers.set(device.identity, handler);
      }
    } catch (error) {
      this.state = { lastAttemptFailed: true };
      throw error;
    } finally {
      this.updateHandlers();
    }
  }

  private read(identity: string): boolean {
    const { data, lastSuccessAt } = this.state;
    if (this.stopped || !data || typeof lastSuccessAt !== 'number'
      || !Number.isFinite(lastSuccessAt) || Date.now() < lastSuccessAt
      || Date.now() - lastSuccessAt >= 90000) {
      throw new ZoneCommandError('Fresh controller data is unavailable.');
    }
    const device = discoverDevices(data).find(item => item.kind === 'zone' && item.identity === identity);
    if (!device || device.kind !== 'zone') {
      throw new ZoneCommandError('The requested zone is unavailable.');
    }
    const zone = data.aircons[device.airconKey].zones[device.zoneKey];
    if (typeof zone.type !== 'number' || !Number.isInteger(zone.type) || zone.type <= 0) {
      throw new ZoneCommandError('The zone no longer supports this switch layout.');
    }
    return zoneIsOpen(zone);
  }

  private async set(identity: string, on: boolean, signal?: AbortSignal): Promise<void> {
    if (this.stopped) {
      throw new ZoneCommandError('Zone control has stopped.');
    }
    this.pending++;
    try {
      signal?.throwIfAborted();
      const result = await this.executor.setZone(identity, on, signal);
      signal?.throwIfAborted();
      if (this.stopped) {
        throw new ZoneCommandError('Zone control has stopped.');
      }
      const now = Date.now();
      this.accept({
        data: result.data,
        lastSuccessAt: now,
        lastAttemptAt: now,
        lastAttemptFailed: false,
      });
    } catch (error) {
      // A failed write may still have reached the controller. Require a new
      // polling response rather than exposing the pre-command cached value.
      this.state = { lastAttemptFailed: true };
      throw error;
    } finally {
      this.completedAt = Date.now();
      this.pending--;
      this.updateHandlers();
    }
  }

  private updateHandlers(): void {
    for (const handler of this.handlers.values()) {
      handler.update();
    }
  }
}
