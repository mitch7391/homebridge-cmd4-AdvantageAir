import { discoverDevices } from '../discovery/discoverDevices.js';
import type { SystemData } from './systemData.js';
import { planZoneSwitch, ZoneCommandError } from './zoneCommand.js';
import type { ZoneState } from './zoneCommand.js';

export interface ZoneCommandClient {
  getFreshSystemData(): Promise<SystemData>;
  requestZoneState(airconKey: string, zoneKey: string, state: ZoneState, signal?: AbortSignal): Promise<unknown>;
}

export interface ZoneCommandResult {
  outcome: 'unchanged' | 'confirmed';
  data: SystemData;
}

/** Use one executor per controller. Only this executor should submit zone writes. */
export class ZoneCommandExecutor {
  private pending: Promise<void> = Promise.resolve();
  private stopped = false;
  private readonly active = new Set<AbortController>();

  constructor(
    private readonly client: ZoneCommandClient,
    private readonly attempts = 5,
    private readonly delayMs = 1000,
  ) {
    if (!Number.isInteger(attempts) || attempts < 1 || attempts > 10
      || !Number.isInteger(delayMs) || delayMs < 1 || delayMs > 10000) {
      throw new Error('Invalid zone confirmation settings.');
    }
  }

  setZone(identity: string, on: boolean, signal?: AbortSignal): Promise<ZoneCommandResult> {
    const controller = new AbortController();
    this.active.add(controller);
    const cancel = () => controller.abort(signal?.reason);
    signal?.addEventListener('abort', cancel, { once: true });
    if (signal?.aborted) {
      cancel();
    }
    if (this.stopped) {
      controller.abort(new ZoneCommandError('Zone control has stopped.'));
    }
    const timer = setTimeout(() => {
      controller.abort(new ZoneCommandError('Zone command timed out before confirmation.'));
    }, 7000);
    let abort: () => void = () => {};
    const cancelled = new Promise<never>((resolve, reject) => {
      abort = () => reject(this.cancellationError(controller.signal));
      controller.signal.addEventListener('abort', abort, { once: true });
      if (controller.signal.aborted) {
        abort();
      }
    });
    const result = this.pending.then(() => this.execute(identity, on, controller.signal));
    // Keep actual executions serialized even if cancellation releases the caller
    // while an uncancellable read is still finishing.
    this.pending = result.then(() => undefined, () => undefined);
    return Promise.race([result, cancelled]).finally(() => {
      clearTimeout(timer);
      signal?.removeEventListener('abort', cancel);
      controller.signal.removeEventListener('abort', abort);
      this.active.delete(controller);
    });
  }

  stop(): void {
    this.stopped = true;
    for (const controller of this.active) {
      controller.abort(new ZoneCommandError('Zone control has stopped.'));
    }
  }

  private cancellationError(signal: AbortSignal): ZoneCommandError {
    return signal.reason instanceof ZoneCommandError
      ? signal.reason
      : new ZoneCommandError('Zone command was cancelled before confirmation.');
  }

  private checkRunning(signal: AbortSignal): void {
    if (this.stopped) {
      throw new ZoneCommandError('Zone control has stopped.');
    }
    if (signal.aborted) {
      throw this.cancellationError(signal);
    }
  }

  private locate(data: SystemData, identity: string) {
    const zone = discoverDevices(data).find(
      device => device.kind === 'zone' && device.identity === identity,
    );
    if (!zone || zone.kind !== 'zone') {
      throw new ZoneCommandError('The requested zone identity is unavailable.');
    }
    return zone;
  }

  private async execute(identity: string, on: boolean, signal: AbortSignal): Promise<ZoneCommandResult> {
    this.checkRunning(signal);
    if (typeof identity !== 'string' || typeof on !== 'boolean') {
      throw new ZoneCommandError('Invalid zone switch request.');
    }
    const data = await this.client.getFreshSystemData();
    this.checkRunning(signal);
    const zone = this.locate(data, identity);
    const plan = planZoneSwitch(data.aircons[zone.airconKey], zone.zoneKey, on);
    if (plan.kind === 'unchanged') {
      return { outcome: 'unchanged', data };
    }

    this.checkRunning(signal);
    await this.client.requestZoneState(zone.airconKey, zone.zoneKey, plan.requestedState, signal);
    this.checkRunning(signal);
    for (let attempt = 0; attempt < this.attempts; attempt++) {
      await this.wait(signal);
      this.checkRunning(signal);
      let current: SystemData;
      try {
        current = await this.client.getFreshSystemData();
      } catch {
        this.checkRunning(signal);
        continue;
      }
      this.checkRunning(signal);
      const currentZone = this.locate(current, identity);
      const state = current.aircons[currentZone.airconKey].zones[currentZone.zoneKey].state;
      if (state === plan.requestedState) {
        return { outcome: 'confirmed', data: current };
      }
    }
    throw new ZoneCommandError('The controller did not confirm the requested zone state.');
  }

  private wait(signal: AbortSignal): Promise<void> {
    this.checkRunning(signal);
    return new Promise((resolve, reject) => {
      let abort: () => void = () => {};
      const timer = setTimeout(() => {
        signal.removeEventListener('abort', abort);
        resolve();
      }, this.delayMs);
      abort = () => {
        clearTimeout(timer);
        signal.removeEventListener('abort', abort);
        reject(this.cancellationError(signal));
      };
      signal.addEventListener('abort', abort, { once: true });
    });
  }
}
