import type { SystemData } from './systemData.js';

export interface SystemDataReader {
  getSystemData(): Promise<SystemData>;
}

export interface ControllerPollState {
  data?: SystemData;
  lastSuccessAt?: number;
  lastAttemptAt?: number;
  lastAttemptFailed: boolean;
}

export class ControllerPoller {
  private timer?: ReturnType<typeof setTimeout>;
  private started = false;
  private stopped = false;

  private currentState: ControllerPollState = {
    lastAttemptFailed: false,
  };

  constructor(
    private readonly client: SystemDataReader,
    private readonly intervalMs = 30000,
    private readonly onUpdate?: (state: ControllerPollState) => void,
  ) {
    if (
      !Number.isInteger(intervalMs)
      || intervalMs < 1
      || intervalMs > 2147483647
    ) {
      throw new Error('Polling interval must be a positive supported integer.');
    }
  }

  get state(): ControllerPollState {
    return structuredClone(this.currentState);
  }

  start(): void {
    if (this.started || this.stopped) {
      return;
    }

    this.started = true;
    void this.poll();
  }

  stop(): void {
    this.stopped = true;

    if (this.timer !== undefined) {
      clearTimeout(this.timer);
      this.timer = undefined;
    }
  }

  private async poll(): Promise<void> {
    this.currentState = {
      ...this.currentState,
      lastAttemptAt: Date.now(),
    };

    try {
      const data = await this.client.getSystemData();

      if (this.stopped) {
        return;
      }

      this.currentState = {
        data,
        lastAttemptAt: this.currentState.lastAttemptAt,
        lastSuccessAt: Date.now(),
        lastAttemptFailed: false,
      };
    } catch {
      if (this.stopped) {
        return;
      }

      this.currentState = {
        ...this.currentState,
        lastAttemptFailed: true,
      };
    } finally {
      if (!this.stopped) {
        try {
          this.onUpdate?.(this.state);
        } catch {
          // An observer failure must not interrupt controller polling.
        }

        if (!this.stopped) {
          this.timer = setTimeout(() => {
            this.timer = undefined;
            void this.poll();
          }, this.intervalMs);
        }
      }
    }
  }
}
