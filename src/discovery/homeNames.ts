import type { SystemData } from '../api/systemData.js';
import { discoverDevices } from './discoverDevices.js';

export type HomeNameResolver = (identity: string) => string | undefined;

export function homeBaseName(value: unknown): string {
  return typeof value === 'string' && value.trim() ? value.trim() : 'Aircon';
}

export function detailedDebug(platform: unknown, controller: unknown): boolean {
  return platform === true || controller === true;
}

interface ControllerNames {
  label: string;
  base: string;
  aircons?: Array<{ identity: string; airconKey: string }>;
}

/** Presentation-only names. No controller data, identities or configuration are modified. */
export class HomeNames {
  private readonly controllers = new Map<number, ControllerNames>();
  private accepted = new Map<string, string>();
  private diagnostic?: string;

  constructor(private readonly warn: (message: string) => void) {}

  configure(index: number, label: string, base: unknown): void {
    this.controllers.set(index, { label, base: homeBaseName(base) });
  }

  readonly resolve: HomeNameResolver = identity => this.accepted.get(identity);

  update(index: number, data: SystemData): boolean {
    const controller = this.controllers.get(index);
    if (!controller) {
      return false;
    }
    try {
      controller.aircons = discoverDevices(data).filter(device => device.kind === 'aircon')
        .sort((a, b) => a.airconKey.localeCompare(b.airconKey, 'en', { numeric: true })
          || (a.airconKey < b.airconKey ? -1 : a.airconKey > b.airconKey ? 1 : 0));
    } catch {
      // Accessory managers retain their existing discovery-error handling.
      controller.aircons = undefined;
      return false;
    }
    const entries = [...this.controllers.entries()].sort(([a], [b]) => a - b);
    if (entries.some(([, item]) => !item.aircons)) {
      return false;
    }
    const proposed = new Map<string, string>();
    const owners = new Map<string, string>();
    for (const [controllerIndex, item] of entries) {
      for (const [airconIndex, aircon] of item.aircons!.entries()) {
        const name = airconIndex === 0 ? item.base : `${item.base} ${airconIndex + 1}`;
        const key = name.trim().toLowerCase();
        const location = `controller ${controllerIndex + 1} (${item.label}), ${aircon.airconKey}`;
        const previous = owners.get(key);
        if (previous) {
          const message = `Home accessory naming conflict: "${name}" resolves for both ${previous} and ${location}. `
            + 'Choose distinct Names in plugin settings. Previously accepted accessory names are retained.';
          if (message !== this.diagnostic) {
            this.warn(message);
          }
          this.diagnostic = message;
          return false;
        }
        // Existing duplicate-controller handling remains responsible for duplicate identities.
        if (proposed.has(aircon.identity)) {
          return false;
        }
        owners.set(key, location);
        proposed.set(aircon.identity, name);
      }
    }
    this.diagnostic = undefined;
    const changed = proposed.size !== this.accepted.size
      || [...proposed].some(([identity, name]) => this.accepted.get(identity) !== name);
    // Commit only after validating the entire platform's discovered set.
    this.accepted = proposed;
    return changed;
  }
}
