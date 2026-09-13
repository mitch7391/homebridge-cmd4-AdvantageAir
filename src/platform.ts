import type {
  API,
  DynamicPlatformPlugin,
  Logging,
  PlatformAccessory,
  PlatformConfig,
} from 'homebridge';

import { AdvantageAirClient } from './api/advantageAirClient.js';
import { ControllerPoller } from './api/controllerPoller.js';
import { DuplicateControllerError, ZoneTemperatureManager } from './accessories/zoneTemperatureManager.js';

interface ConfiguredController {
  name: string;
  debug: boolean;
  poller: ControllerPoller;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export class AdvantageAirPlatform implements DynamicPlatformPlugin {
  public readonly accessories = new Map<string, PlatformAccessory>();

  private readonly controllers: ConfiguredController[] = [];
  private launched = false;
  private stopped = false;

  constructor(
    public readonly log: Logging,
    public readonly config: PlatformConfig,
    public readonly api: API,
  ) {
    this.configureControllers(this.config.devices);

    this.api.on('didFinishLaunching', () => {
      if (this.launched || this.stopped) {
        return;
      }

      this.launched = true;

      for (const controller of this.controllers) {
        this.log.info('Starting controller polling:', controller.name);
        controller.poller.start();
      }
    });

    this.api.on('shutdown', () => {
      this.stopped = true;

      for (const controller of this.controllers) {
        controller.poller.stop();
      }
    });
  }

  configureAccessory(accessory: PlatformAccessory): void {
    this.log.debug('Loading accessory from cache:', accessory.displayName);
    this.accessories.set(accessory.UUID, accessory);
    ZoneTemperatureManager.prepareCachedAccessory(this.api, accessory);
  }

  private configureControllers(devices: unknown): void {
    if (!Array.isArray(devices) || devices.length === 0) {
      this.log.warn('No controllers configured. Add a controller in plugin settings.');
      return;
    }

    const endpoints = new Set<string>();

    for (const [index, device] of devices.entries()) {
      try {
        if (!isObject(device)) {
          throw new Error('Controller settings must be an object.');
        }

        if (typeof device.ipAddress !== 'string') {
          throw new Error('An IPv4 address is required.');
        }

        if (device.port !== undefined && typeof device.port !== 'number') {
          throw new Error('Port must be a number.');
        }

        if (device.name !== undefined && typeof device.name !== 'string') {
          throw new Error('Controller name must be text.');
        }

        if (device.debug !== undefined && typeof device.debug !== 'boolean') {
          throw new Error('Debug must be true or false.');
        }

        const ipAddress = device.ipAddress.trim();
        const port = device.port ?? 2025;
        const name = typeof device.name === 'string' && device.name.trim()
          ? device.name.trim()
          : `Controller ${index + 1}`;

        const client = new AdvantageAirClient({ ipAddress, port });
        const endpoint = `${ipAddress}:${port}`;

        if (endpoints.has(endpoint)) {
          throw new Error('This controller address and port are already configured.');
        }

        endpoints.add(endpoint);

        const debug = device.debug === true;
        let previouslyFailed = false;
        let receivedData = false;
        let accessoryUpdateFailed = false;

        const temperatureManager = new ZoneTemperatureManager(
          this.api,
          this.accessories,
        );

        const poller = new ControllerPoller(client, 30000, (state) => {
          try {
            temperatureManager.update(state);
            accessoryUpdateFailed = false;
          } catch (error) {
            if (error instanceof DuplicateControllerError) {
              poller.stop();
              this.log.error('Duplicate controller identity:', name, 'Polling stopped for this entry.');
              return;
            }

            if (!accessoryUpdateFailed) {
              this.log.error(
                'Temperature accessory update failed:',
                name,
                'Existing accessories have been retained.',
              );
            }

            accessoryUpdateFailed = true;
          }

          if (state.lastAttemptFailed) {
            if (!previouslyFailed) {
              this.log.warn(
                'Controller read failed:',
                name,
                state.data
                  ? 'Retaining previously received data; it may be stale.'
                  : 'Waiting for the first valid response.',
              );
            }

            previouslyFailed = true;
            return;
          }

          if (!state.data) {
            return;
          }

          if (previouslyFailed) {
            this.log.info('Controller communication recovered:', name);
          } else if (!receivedData) {
            this.log.info('Received first valid controller response:', name);
          }

          previouslyFailed = false;
          receivedData = true;

          if (debug) {
            const aircons = Object.values(state.data.aircons);
            const zoneCount = aircons.reduce(
              (total, aircon) => total + Object.keys(aircon.zones).length,
              0,
            );

            this.log.debug(
              'Controller read:',
              name,
              `${aircons.length} air conditioner(s), ${zoneCount} zone(s).`,
            );
          }
        });

        this.controllers.push({ name, debug, poller });
      } catch (error) {
        const reason = error instanceof Error
          ? error.message
          : 'Invalid controller settings.';

        this.log.error(`Controller entry ${index + 1} skipped: ${reason}`);
      }
    }
  }
}
