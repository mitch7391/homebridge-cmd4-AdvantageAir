import type { IndependentPlatformPlugin, Logging } from 'homebridge';

/**
 * Keeps existing helper-platform entries loadable during migration.
 * Cmd4 owns the legacy accessories and invokes AdvAir.sh independently.
 */
export class LegacyCompatibilityPlatform implements IndependentPlatformPlugin {
  constructor(log: Logging) {
    log.warn(
      'Legacy cmd4AdvantageAir compatibility only: existing Cmd4 accessories still use AdvAir.sh. '
      + 'Configure the AdvantageAir platform separately for native v4; see docs/v3-migration.md.',
    );
  }
}
