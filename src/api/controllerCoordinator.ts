import type { ControllerPollState } from './controllerPoller.js';
import type { SystemData } from './systemData.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { planZoneSwitch, ZoneCommandError } from './zoneCommand.js';
import { zoneIsOpen } from '../accessories/legacyState.js';
import { ControllerBusyError } from './systemData.js';
import { ZoneCommandRejectedError } from './advantageAirClient.js';

export interface ControllerClient {
  getSystemData(signal?: AbortSignal): Promise<SystemData>;
  getFreshSystemData(signal?: AbortSignal): Promise<SystemData>;
  requestZoneState(aircon: string, zone: string, state: 'open' | 'close', signal?: AbortSignal): Promise<unknown>;
}

interface Intent {
  identity: string;
  on: boolean;
  generation: number;
  name: string;
  expires: number;
  finished: boolean;
  timer: ReturnType<typeof setTimeout>;
}

/** One owner for polling, desired state and physical command execution. */
export class ControllerCoordinator {
  private state: ControllerPollState = { lastAttemptFailed: false };
  private started = false;
  private stopped = false;
  private running = false;
  private timer?: ReturnType<typeof setTimeout>;
  private operation?: AbortController;
  private generation = 0;
  private readonly queued = new Map<string, Intent>();
  private readonly desired = new Map<string, Intent>();
  private readonly faults = new Set<string>();

  constructor(
    private readonly client: ControllerClient,
    private readonly onUpdate: (state: ControllerPollState) => void,
    private readonly warn: (message: string) => void,
  ) {}

  start(): void {
    if (this.started || this.stopped) {
      return;
    }
    this.started = true;
    void this.run();
  }

  stop(): void {
    this.stopped = true;
    clearTimeout(this.timer);
    this.operation?.abort();
    for (const intent of this.desired.values()) {
      clearTimeout(intent.timer);
    }
    this.desired.clear();
    this.queued.clear();
  }

  readZone(identity: string): boolean {
    this.available();
    const pending = this.desired.get(identity);
    if (pending) {
      return pending.on;
    }
    if (this.faults.has(identity)) {
      throw new ZoneCommandError('The zone command could not be confirmed.');
    }
    const zone = this.locate(this.state.data!, identity);
    return zoneIsOpen(this.state.data!.aircons[zone.airconKey].zones[zone.zoneKey]);
  }

  /** Acknowledges local admission, not controller execution or confirmation. */
  requestZone(identity: string, on: boolean): void {
    this.available();
    const zone = this.locate(this.state.data!, identity);
    planZoneSwitch(this.state.data!.aircons[zone.airconKey], zone.zoneKey, on);
    if (this.desired.get(identity)?.on === on) {
      return;
    }
    if (!this.desired.has(identity) && this.desired.size >= 64) {
      throw new ZoneCommandError('Too many pending zone requests. Try again after they finish.');
    }
    const previous = this.desired.get(identity);
    if (previous) {
      clearTimeout(previous.timer);
    }
    const intent: Intent = {
      identity, on, name: `${zone.name} Zone`, generation: ++this.generation,
      expires: Date.now() + 30000,
      finished: false,
      timer: setTimeout(() => this.expire(intent), 30000),
    };
    this.desired.set(identity, intent);
    // Map replacement preserves queue position, giving other rooms a turn.
    this.queued.set(identity, intent);
    this.faults.delete(identity);
    this.emit();
    clearTimeout(this.timer);
    // Defer execution until the HAP setter has accepted the desired value.
    queueMicrotask(() => void this.run());
  }

  private available(): void {
    const at = this.state.lastSuccessAt;
    if (!this.started || this.stopped || !this.state.data || at === undefined
      || Date.now() < at || Date.now() - at >= 90000) {
      throw new ZoneCommandError('Fresh controller data is unavailable.');
    }
  }

  private locate(data: SystemData, identity: string) {
    const zone = discoverDevices(data).find(item => item.kind === 'zone' && item.identity === identity);
    if (!zone || zone.kind !== 'zone') {
      throw new ZoneCommandError('The requested zone identity is unavailable.');
    }
    const type = data.aircons[zone.airconKey].zones[zone.zoneKey].type;
    if (typeof type !== 'number' || !Number.isInteger(type) || type <= 0) {
      throw new ZoneCommandError('The zone no longer supports this switch layout.');
    }
    return zone;
  }

  private emit(): void {
    if (!this.stopped) {
      try {
        this.onUpdate(structuredClone(this.state));
      } catch {
        // An observer must not break scheduling or strand accepted requests.
      }
    }
  }

  private observe(data: SystemData): void {
    if (this.stopped) {
      return;
    }
    this.state = {
      data: structuredClone(data), lastAttemptAt: Date.now(),
      lastSuccessAt: Date.now(), lastAttemptFailed: false,
    };
    this.faults.clear();
    this.emit();
  }

  private expire(intent: Intent): void {
    if (this.desired.get(intent.identity) !== intent || this.stopped) {
      return;
    }
    this.queued.delete(intent.identity);
    this.fail(intent, 'The accepted zone request expired before completion.');
  }

  private finish(intent: Intent): void {
    intent.finished = true;
    if (this.desired.get(intent.identity) === intent) {
      clearTimeout(intent.timer);
      this.desired.delete(intent.identity);
    }
    this.emit();
  }

  private fail(intent: Intent, reason: string): void {
    if (this.stopped || intent.finished) {
      return;
    }
    if (this.desired.get(intent.identity) === intent) {
      this.faults.add(intent.identity);
    }
    this.finish(intent);
    try {
      this.warn(`Zone command failed for "${intent.name}": ${reason}`);
    } catch {
      // A logging callback must not interrupt cleanup or queued work.
    }
  }

  private async run(): Promise<void> {
    if (this.running || this.stopped || !this.started) {
      return;
    }
    this.running = true;
    try {
      if (this.queued.size === 0) {
        await this.poll();
      }
      while (!this.stopped && this.queued.size > 0) {
        const intent = this.queued.values().next().value!;
        this.queued.delete(intent.identity);
        if (this.desired.get(intent.identity) === intent && Date.now() < intent.expires) {
          await this.execute(intent);
        }
      }
    } finally {
      this.running = false;
      if (!this.stopped) {
        this.timer = setTimeout(() => void this.run(), 30000);
      }
    }
  }

  private async poll(): Promise<void> {
    try {
      await this.bounded(10000, async signal => {
        const data = await this.client.getSystemData(signal);
        signal.throwIfAborted();
        this.observe(data);
      });
    } catch {
      if (!this.stopped) {
        this.state = { ...this.state, lastAttemptAt: Date.now(), lastAttemptFailed: true };
        this.emit();
      }
    }
  }

  private async execute(intent: Intent): Promise<void> {
    let sent = false;
    try {
      await this.bounded(Math.min(15000, intent.expires - Date.now()), async signal => {
        const data = await this.client.getFreshSystemData(signal);
        signal.throwIfAborted();
        this.observe(data);
        const zone = this.locate(data, intent.identity);
        const plan = planZoneSwitch(data.aircons[zone.airconKey], zone.zoneKey, intent.on);
        // A newer unsent intent replaces this one even during preflight.
        if (this.desired.get(intent.identity) !== intent) {
          return;
        }
        if (plan.kind === 'unchanged') {
          this.finish(intent);
          return;
        }
        signal.throwIfAborted();
        sent = true;
        // A failed/ambiguous transport must never result in resending the write.
        try {
          await this.client.requestZoneState(zone.airconKey, zone.zoneKey, plan.requestedState, signal);
        } catch (error) {
          if (error instanceof ZoneCommandRejectedError) {
            throw new ZoneCommandError('Controller rejected the zone command.');
          }
          // Delivery is ambiguous. Reconcile by reading; never resend.
        }
        signal.throwIfAborted();
        while (true) {
          await this.wait(signal);
          let current: SystemData;
          try {
            current = await this.client.getFreshSystemData(signal);
          } catch (error) {
            signal.throwIfAborted();
            if (error instanceof ControllerBusyError) {
              continue;
            }
            throw new ZoneCommandError('Controller data could not be read while confirming the zone.');
          }
          signal.throwIfAborted();
          const currentZone = this.locate(current, intent.identity);
          this.observe(current);
          if (zoneIsOpen(current.aircons[currentZone.airconKey].zones[currentZone.zoneKey]) === intent.on) {
            this.finish(intent);
            return;
          }
        }
      });
    } catch (error) {
      if (this.stopped) {
        return;
      }
      this.fail(intent, error instanceof ZoneCommandError ? error.message : 'The controller did not confirm the requested zone state.');
      if (sent) {
        // Do not apply dependent intentions after an unreconciled physical write.
        for (const queued of this.queued.values()) {
          this.fail(queued, 'Cancelled because a preceding controller command could not be confirmed.');
        }
        this.queued.clear();
      }
    }
  }

  private async bounded(ms: number, work: (signal: AbortSignal) => Promise<void>): Promise<void> {
    const controller = new AbortController();
    this.operation = controller;
    const timer = setTimeout(() => controller.abort(), Math.max(0, ms));
    let abort = () => {};
    const cancelled = new Promise<never>((_, reject) => {
      abort = () => reject(new ZoneCommandError('The controller operation expired before confirmation.'));
      controller.signal.addEventListener('abort', abort, { once: true });
    });
    try {
      await Promise.race([work(controller.signal), cancelled]);
    } finally {
      clearTimeout(timer);
      controller.signal.removeEventListener('abort', abort);
      if (this.operation === controller) {
        this.operation = undefined;
      }
    }
  }

  private wait(signal: AbortSignal): Promise<void> {
    signal.throwIfAborted();
    return new Promise((resolve, reject) => {
      let abort = () => {};
      const timer = setTimeout(() => {
        signal.removeEventListener('abort', abort);
        resolve();
      }, 1000);
      abort = () => {
        clearTimeout(timer);
        reject(new ZoneCommandError('The controller operation expired before confirmation.'));
      };
      signal.addEventListener('abort', abort, { once: true });
    });
  }
}
