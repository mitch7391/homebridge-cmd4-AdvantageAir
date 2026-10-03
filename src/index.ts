import type { API } from 'homebridge';

import { AdvantageAirPlatform } from './platform.js';
import { LegacyCompatibilityPlatform } from './legacyCompatibility.js';
import { LEGACY_PLATFORM_NAME, PLATFORM_NAME, PLUGIN_NAME } from './settings.js';

/**
 * Register the Advantage Air platform with Homebridge.
 */
export default (api: API) => {
  api.registerPlatform(PLUGIN_NAME, PLATFORM_NAME, AdvantageAirPlatform);
  api.registerPlatform(PLUGIN_NAME, LEGACY_PLATFORM_NAME, LegacyCompatibilityPlatform);
};
