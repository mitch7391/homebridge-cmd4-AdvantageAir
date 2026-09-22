import { planFanSpeed, fanSetting } from './fanCommand.js';
import type { FanSpeed } from './fanCommand.js';
import type { ControllerPollState } from './controllerPoller.js';
import type { SystemData } from './systemData.js';
import { discoverDevices } from '../discovery/discoverDevices.js';
import { planZoneSwitch, ZoneCommandError } from './zoneCommand.js';
import { planThermostatMode, planThermostatTemperature, ThermostatCommandError } from './thermostatCommand.js';
import { temperatureConfirmation } from './thermostatPatch.js';
import type { ThermostatPatch } from './thermostatPatch.js';
import type { ThermostatMode } from '../accessories/legacyState.js';
import { fanSpeedPercentage, thermostatCurrentTemperature, thermostatTargetMode, thermostatTargetTemperature, zoneIsOpen } from '../accessories/legacyState.js';
import { ControllerBusyError } from './systemData.js';
import { AirconCommandRejectedError } from './advantageAirClient.js';

export interface ControllerClient {
  requestFanSpeed?(aircon: string, fan: FanSpeed, signal?: AbortSignal): Promise<unknown>;
  requestThermostatPatch?(aircon: string, patch: ThermostatPatch, signal?: AbortSignal): Promise<unknown>;
  getSystemData(signal?: AbortSignal): Promise<SystemData>;
  getFreshSystemData(signal?: AbortSignal): Promise<SystemData>;
  requestZoneState(aircon: string, zone: string, state: 'open' | 'close', signal?: AbortSignal): Promise<unknown>;
}

export type ControllerUpdateReason = 'read' | 'failure' | 'state';

export type ControllerCommandConfirmation = {
  name: string;
  outcome: 'confirmed' | 'unchanged';
  superseded: boolean;
} & Request;

type Request = { kind: 'zone'; on: boolean }
  | { kind: 'mode'; mode: ThermostatMode }
  | { kind: 'temperature'; temperature: number }
  | { kind: 'fan'; percentage: number };

type ExecutionPlan = { kind: 'unchanged' } | {
  kind: 'command';
  send: (signal: AbortSignal) => Promise<unknown>;
  matches: (data: SystemData) => boolean;
};

type Intent = Request & {
  identity: string;
  key: string;
  generation: number;
  name: string;
  expires: number;
  finished: boolean;
  timer: ReturnType<typeof setTimeout>;
};

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
    private readonly onUpdate: (state: ControllerPollState, reason: ControllerUpdateReason) => void,
    private readonly warn: (message: string) => void,
    private readonly onConfirmation?: (event: ControllerCommandConfirmation) => void,
    private readonly onSending?: (name: string, target: string) => void,
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
    const key = this.key(identity, 'zone');
    const pending = this.desired.get(key);
    if (pending?.kind === 'zone') {
      return pending.on;
    }
    if (this.faults.has(key)) {
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
    this.admit(identity, `${zone.name} Zone`, { kind: 'zone', on });
  }

  /** Legacy projection of observed power/mode, not measured compressor activity. */
  readThermostatCurrentMode(identity: string): ThermostatMode {
    this.available();
    return thermostatTargetMode(this.aircon(this.state.data!, identity).data);
  }

  readThermostatCurrentTemperature(identity: string): number {
    this.available();
    return thermostatCurrentTemperature(this.aircon(this.state.data!, identity).data);
  }

  readFanSpeed(identity: string): number {
    this.available();
    const key = this.key(identity, 'fan');
    const pending = this.desired.get(key);
    if (pending?.kind === 'fan') {
      return pending.percentage;
    }
    if (this.faults.has(key)) {
      throw new ThermostatCommandError('The fan command could not be confirmed.');
    }
    return fanSpeedPercentage(this.aircon(this.state.data!, identity).data);
  }

  requestFanSpeed(identity: string, percentage: number): void {
    this.available();
    const aircon = this.aircon(this.state.data!, identity);
    const plan = planFanSpeed(aircon.data, percentage);
    if (!this.client.requestFanSpeed) {
      throw new ThermostatCommandError('Fan transport is unavailable.');
    }
    this.admit(identity, aircon.device.name, { kind: 'fan', percentage: plan.percentage });
  }

  readThermostatMode(identity: string): ThermostatMode {
    this.available();
    const key = this.key(identity, 'mode');
    const pending = this.desired.get(key);
    if (pending?.kind === 'mode') {
      return pending.mode;
    }
    this.checkThermostatFault(key);
    return thermostatTargetMode(this.aircon(this.state.data!, identity).data);
  }

  readThermostatTemperature(identity: string): number {
    this.available();
    const key = this.key(identity, 'temperature');
    const pending = this.desired.get(key);
    if (pending?.kind === 'temperature') {
      return pending.temperature;
    }
    this.checkThermostatFault(key);
    return thermostatTargetTemperature(this.aircon(this.state.data!, identity).data);
  }

  requestThermostatMode(identity: string, mode: ThermostatMode): void {
    this.available();
    const aircon = this.aircon(this.state.data!, identity);
    planThermostatMode(aircon.data, mode);
    this.requireThermostatTransport();
    this.admit(identity, aircon.device.name, { kind: 'mode', mode });
  }

  requestThermostatTemperature(identity: string, temperature: number): void {
    this.available();
    const aircon = this.aircon(this.state.data!, identity);
    planThermostatTemperature(aircon.data, temperature);
    this.requireThermostatTransport();
    this.admit(identity, aircon.device.name, { kind: 'temperature', temperature });
  }

  private checkThermostatFault(key: string): void {
    if (this.faults.has(key)) {
      throw new ThermostatCommandError('The thermostat command could not be confirmed.');
    }
  }

  private requireThermostatTransport(): void {
    if (!this.client.requestThermostatPatch) {
      throw new ThermostatCommandError('Thermostat transport is unavailable.');
    }
  }

  private key(identity: string, kind: Request['kind']): string {
    return JSON.stringify([identity, kind]);
  }

  private admit(identity: string, name: string, request: Request): void {
    const key = this.key(identity, request.kind);
    const previous = this.desired.get(key);
    if (previous && ((request.kind === 'zone' && previous.kind === 'zone' && request.on === previous.on)
      || (request.kind === 'mode' && previous.kind === 'mode' && request.mode === previous.mode)
      || (request.kind === 'fan' && previous.kind === 'fan' && request.percentage === previous.percentage)
      || (request.kind === 'temperature' && previous.kind === 'temperature' && request.temperature === previous.temperature))) {
      return;
    }
    if (!this.desired.has(key) && this.desired.size >= 64) {
      throw new ZoneCommandError('Too many pending controller requests. Try again after they finish.');
    }
    if (previous) {
      clearTimeout(previous.timer);
    }
    const intent: Intent = {
      ...request, identity, key, name, generation: ++this.generation,
      expires: Date.now() + 30000,
      finished: false,
      timer: setTimeout(() => this.expire(intent), 30000),
    };
    this.desired.set(key, intent);
    // Map replacement preserves queue position, giving other rooms a turn.
    this.queued.set(key, intent);
    this.faults.delete(key);
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
    // Sensor availability does not determine whether a zone can open or close.
    return zone;
  }

  private aircon(data: SystemData, identity: string) {
    const device = discoverDevices(data).find(item => item.kind === 'aircon' && item.identity === identity);
    if (!device || device.kind !== 'aircon') {
      throw new ThermostatCommandError('The requested air conditioner identity is unavailable.');
    }
    return { device, data: data.aircons[device.airconKey] };
  }

  private plan(data: SystemData, intent: Intent): ExecutionPlan {
    if (intent.kind === 'zone') {
      const zone = this.locate(data, intent.identity);
      const plan = planZoneSwitch(data.aircons[zone.airconKey], zone.zoneKey, intent.on);
      if (plan.kind === 'unchanged') {
        return plan;
      }
      return {
        kind: 'command',
        send: signal => this.client.requestZoneState(zone.airconKey, zone.zoneKey, plan.requestedState, signal),
        matches: current => {
          const address = this.locate(current, intent.identity);
          return zoneIsOpen(current.aircons[address.airconKey].zones[address.zoneKey]) === intent.on;
        },
      };
    }
    const aircon = this.aircon(data, intent.identity);
    if (intent.kind === 'fan') {
      const plan = planFanSpeed(aircon.data, intent.percentage);
      if (plan.unchanged) {
        return { kind: 'unchanged' };
      }
      return {
        kind: 'command',
        send: signal => this.client.requestFanSpeed!(aircon.device.airconKey, plan.fan, signal),
        matches: current => fanSpeedPercentage(this.aircon(current, intent.identity).data) === plan.percentage,
      };
    }
    if (intent.kind === 'mode') {
      const plan = planThermostatMode(aircon.data, intent.mode);
      if (plan.kind === 'unchanged') {
        return plan;
      }
      return {
        kind: 'command',
        send: signal => this.client.requestThermostatPatch!(aircon.device.airconKey, plan.patch, signal),
        matches: current => {
          const info = this.aircon(current, intent.identity).data.info;
          return intent.mode === 'off' ? info.state === 'off' : info.state === 'on' && info.mode === intent.mode;
        },
      };
    }
    const plan = planThermostatTemperature(aircon.data, intent.temperature);
    if (plan.kind === 'unchanged') {
      return plan;
    }
    const matches = temperatureConfirmation(aircon.data, plan.patch);
    return {
      kind: 'command',
      send: signal => this.client.requestThermostatPatch!(aircon.device.airconKey, plan.patch, signal),
      matches: current => matches(this.aircon(current, intent.identity).data),
    };
  }

  private emit(reason: ControllerUpdateReason = 'state'): void {
    if (!this.stopped) {
      try {
        this.onUpdate(structuredClone(this.state), reason);
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
    this.emit('read');
  }

  private expire(intent: Intent): void {
    if (this.desired.get(intent.key) !== intent || this.stopped) {
      return;
    }
    this.queued.delete(intent.key);
    this.fail(intent, 'The accepted controller request expired before completion.');
  }

  private finish(intent: Intent): void {
    intent.finished = true;
    if (this.desired.get(intent.key) === intent) {
      clearTimeout(intent.timer);
      this.desired.delete(intent.key);
    }
    this.emit();
  }

  private confirm(intent: Intent, outcome: ControllerCommandConfirmation['outcome']): void {
    if (this.stopped || intent.finished) {
      return;
    }
    const superseded = this.desired.get(intent.key) !== intent;
    this.finish(intent);
    try {
      const request: Request = intent.kind === 'zone' ? { kind: 'zone', on: intent.on }
        : intent.kind === 'mode' ? { kind: 'mode', mode: intent.mode }
          : intent.kind === 'fan' ? { kind: 'fan', percentage: intent.percentage }
            : { kind: 'temperature', temperature: intent.temperature };
      this.onConfirmation?.({ ...request, name: intent.name, outcome, superseded });
    } catch {
      // Logging must not turn a confirmed command into a failure.
    }
  }

  private describe(intent: Intent): string {
    return intent.kind === 'zone' ? (intent.on ? 'Open' : 'Closed')
      : intent.kind === 'fan' ? 'fan speed ' + (intent.percentage === 100 ? 'Auto Mode' : fanSetting(intent.percentage).fan)
        : intent.kind === 'mode' ? 'mode ' + intent.mode : 'target temperature ' + intent.temperature + ' °C';
  }

  private fail(intent: Intent, reason: string): void {
    if (this.stopped || intent.finished) {
      return;
    }
    if (this.desired.get(intent.key) === intent) {
      this.faults.add(intent.key);
    }
    this.finish(intent);
    try {
      const control = intent.kind === 'zone' ? 'Zone' : intent.kind === 'fan' ? 'Fan' : 'Thermostat';
      this.warn(`${control} command failed for "${intent.name}" (${this.describe(intent)}): ${reason}`);
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
        this.queued.delete(intent.key);
        if (this.desired.get(intent.key) === intent && Date.now() < intent.expires) {
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
        this.emit('failure');
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
        const plan = this.plan(data, intent);
        // A newer unsent intent replaces this one even during preflight.
        if (this.desired.get(intent.key) !== intent) {
          return;
        }
        if (plan.kind === 'unchanged') {
          this.confirm(intent, 'unchanged');
          return;
        }
        signal.throwIfAborted();
        try {
          this.onSending?.(intent.name, this.describe(intent));
        } catch {
          // Logging must not interrupt physical commands.
        }
        signal.throwIfAborted();
        sent = true;
        // A failed/ambiguous transport must never result in resending the write.
        try {
          await plan.send(signal);
        } catch (error) {
          if (error instanceof AirconCommandRejectedError) {
            throw new ZoneCommandError('Controller rejected the command.');
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
            throw new ZoneCommandError('Controller data could not be read while confirming the command.');
          }
          signal.throwIfAborted();
          const matches = plan.matches(current);
          this.observe(current);
          if (matches) {
            this.confirm(intent, 'confirmed');
            return;
          }
        }
      });
    } catch (error) {
      if (this.stopped) {
        return;
      }
      this.fail(intent, error instanceof ZoneCommandError || error instanceof ThermostatCommandError
        ? error.message : 'The controller did not confirm the requested state.');
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
