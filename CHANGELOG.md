# Change Log

All notable changes to this project will be documented in this file. This project uses [Semantic Versioning](https://semver.org/).

## 3.2.0 (2022-02-04)

Special thanks to the amazing [uswong](https://github.com/uswong) for adding these new features! Thank you to all who participated in the beta testing! 

### Notable Changes

* Zone closing check to ensure that at least one zone is open at all times as a secondary layer of protection for your ducting.
   * If you close all zones, it will open your Constant Zone damper to 100%.
* No longer require the use of `noSensors` in your `config.json`. The script determines if you have sensors or not.
* Temperature Sensor users no longer require to add zone (`z01`, `z02`, etc.) to `"state_cmd_suffix"` of Thermostat in your `config.json`. The script determines and sets it as your Constant Zone.
   * You can still set a zone if you prefer to choose a different zone to your Constant Zone. 
* Countdown timer added as a Lightbulb accessory; config can be found [here](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki/Config-Creation#timer).
   * Depending on if your Advantage Air system is on or off will determine if the countdown is to turn the system on or off when it reaches 0.
   * New constant `timer` will need to be added to the `"state_cmd_suffix"` of this accessory.
   * The Advantage Air system will only allow 720 minutes (12 hours) for a timer and the Lightbulb has 0-100% to utilise. 
      * Therefore, setting 1% will equal 10 minutes, 6% will be equal to 1 hour.
      * Setting a value higher than 72% (720 minutes), will default back to 72% on the Lightbulb.

### Other Changes

* Shell Check Tool updated for new configurations. Always check you `config.json` with this after making changes!
* Dev dependancy `nanoid` security update to `v3.1.31`.


## 3.1.0 (2022-01-18)

Special thanks to the amazing [uswong](https://github.com/uswong) for adding the new fan speed feature and fixing the zone percentage bug! Thank you to all who participated in the beta testing! 

### Notable Changes

* Fan speed added to Fan accessory via charcteristic `rotationSpeed`. See new Fan config [here](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki/Config-Creation#fan)!
   * Speeds: 1-33% (low), 34-67% (medium), 68-99% (high) and 100% ('auto' or 'ezfan').
* Fan speed added to Thermostat accessory via new `"linkedType"` config options; see new Thermostat config [here](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki/Config-Creation#thermostat-with-fan-speed). You may need to delete the [Homebridge cache](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/issues/27#issuecomment-997779309) when updating this accessory.
   * Speeds: 1-33% (low), 34-67% (medium), 68-99% (high) and 100% ('auto' or 'ezfan'). 
* New [Wiki](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki) page to help explain and create your `config.json`.
* <B>Homebridge Verified!!!</B>

### Other Changes

* Thermostat 'Fan Speed' `"linkedType"` is set to always appear on.
* If you do not opt into using fan speeds for the Fan and/or Thermostat; setting mode commands (`cool`/`heat`/`on`) will now default to the last known speed set in the Advantage Air app (low/medium/high/auto/'ezfan'). It used to always set to `auto` speed when changing modes.
* Removal of unused `statusFault` and redundant new code from `AdvAir.sh`.
* Streamlining and updates for the README. Moving of some information to the new Wiki.

### Bug Fixes

* Fix for Zone percentage (`brightness`) which would not send value to the controller if it was not rounded to 5%; value input now will round to the nearest 5%.
* Fix for users with 'ezfan' mode defaulting to 'high'; 'ezfan' mode now accepted as 100% speed.
* Dev Tests: Fix timeout issues with `server.js`.


## 3.0.3 (2021-12-29)

Welcome to our Homebridge UI integration!!! 

All the credit for this integration goes to the amazing John Talbot of [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4); I seriously cannot thank him enough! While this is still not its own independent plug-in, this integration will mimic a 'full' plug-in for Homebridge UI. This includes prompts for updates to your scripts, no longer having to edit the script and a configuration check tool to make sure you are set up correctly. Please take a look at the [README](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/tree/master#readme) for more information.

### Other Changes

* Update `node` dependencies to run on all active LTS versions of `Node.js`; at the time of writing this is, `Node.js` v14 and v16. Preparation for `Homebridge Verified`.


## 3.0.2 (2021-12-23)

Welcome to our Homebridge UI integration!!! 

All the credit for this integration goes to the amazing John Talbot of [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4); I seriously cannot thank him enough! While this is still not its own independent plug-in, this integration will mimic a 'full' plug-in for Homebridge UI. This includes prompts for updates to your scripts, no longer having to edit the script and a configuration check tool to make sure you are set up correctly. Please take a look at the [README](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/tree/master#readme) for more information.

### Bug Fixes

* Fix `Bug-Report` issue template not showing up.
* Fix broken links for NPM Badges on README.

### Other Changes

* Dev Tests: Combine `serverP1.js`, `serverP2.js` and `serverP3.js` into `server.js`.
* Update screenshots in README.


## 3.0.1 (2021-12-15)

Welcome to our Homebridge UI integration!!! 

All the credit for this integration goes to the amazing John Talbot of [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4); I seriously cannot thank him enough! While this is still not its own independent plug-in, this integration will mimic a 'full' plug-in for Homebridge UI. This includes prompts for updates to your scripts, no longer having to edit the script and a configuration check tool to make sure you are set up correctly. Please take a look at the [README](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/tree/master#readme) for more information.

### Bug Fixes

* NPM packages will not allow packages to be published if they have upper case letters in the name.


## 3.0.0 (2021-12-15)

Welcome to our Homebridge UI integration!!! 

All the credit for this integration goes to the amazing John Talbot of [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4); I seriously cannot thank him enough! While this is still not its own independent plug-in, this integration will mimic a 'full' plug-in for Homebridge UI. This includes prompts for updates to your scripts, no longer having to edit the script and a configuration check tool to make sure you are set up correctly. Please take a look at the [README](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/tree/master#readme) for more information.

### Breaking Changes

* Homebridge UI integration. While this change itself will not break your existing setup; the process of migrating over might while getting set up again if you make a mistake.
* IP address is removed from the `AdvAir.sh` script. It is now added as a constant in the `homebridge-cmd4` config and in `"state_cmd_suffix"` (see [Config_Samples](https://github.com/mitch7391/cmd4-AdvantageAir/tree/master/Config_Samples) directory). There is no longer a need for users to edit the script!

### Notable Changes

* [#9](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/issues/19): Add zone percentage control for users without temperature sensors. This is integrated as the Light Bulb acessory (see [Config_Samples](https://github.com/mitch7391/cmd4-AdvantageAir/tree/master/Config_Samples)).  

### Bug Fixes

* [#19](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/issues/19): Add `noSensors` variable to fix issue with Thermostat Get CurrentTemperature for users without temperature sensors.
* Side issue bug raised in [#9](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/issues/9): `noSensors` variable fixes issue with Thermostat Set CurrentTemperature for users without temperature sensors.

### Other Changes

* README updated: Update supported units, update screenshots, update and streamline installation instructions.
* Config samples updated: Update and streamline config samples. `noSensors` and `${IP}` added to `config.json`. Example added for users with some (but not all) zones using temperature sensors.
* Issue templates updated.
* PR template created.
* CHANGELOG created.
* Repo/Plug-in name changed from `cmd4-AdvantageAir` to `homebridge-cmd4-AdvantageAir`.
* Dev unit tests expanded and updated.


## 2.3.0 (2021-09-30)

### Notable Changes

* `config.json` changes to stop warnings in the upcoming homebridge-cmd4 v6.0.0 release.
* Characteristics now require the starting letter to be 'lower case' and not 'upper case'; this will pave the way for future work John Talbot puts in for cmd4 to have a `config-schema.json` in Homebridge UI.


## 2.2.0 (2021-09-15)

### Notable Changes

* Removed `stdbuf` dependency from scripts (could affect macOS user installs).
* Install instructions in `README` have been split into Raspbian and macOS installs; still no Windows install instructions.
* `IP Address` / `Port Number` at start of script has had the port number moved into the script commands; so users do not need to think they need to change the port number or figure it out themselves.


## 2.1.0 (2021-08-22)

### Notable Changes

* Addition of test scripts.


## 2.0.0 (2021-08-18)

### Breaking Changes

* New singular script `AdvAir.sh` to replace the need of two scripts `ezone.sh` and `zones.sh` ('Two Constant Zone' users will still have to use two scripts for now; sorry!).
* Better error handling and reporting; script will attempt 5 iterations to receive a valid reading from the control unit.
* Introduction and use of homebridge-cmd4's new `WoRm` (Write once Read many) queue designed by John Talbot to better handle interactions with Advantage Air control unit's limitations.

### Notable Changes

* Repo rename to `cmd4-AdvantageAir`; this is to more accurately capture the broader control units this API encompasses.
* Temperature Sensor Low Battery warning indications added.
* `config.json` improvements and clean-up.
* Documentation improvements in `README`.


## 1.2.0 (2021-02-08)

### Notable Changes

* New `config.json` examples added for the new polling methods of cmd4 v3.0.x.
* Updated `README`.

### Bug Fixes

* Fixed a couple of small bugs in shell scripts: use of `"true"` instead of `'1'` for `On` characteristic and double use of case `* )`.


## 1.1.0 (2021-01-22)

### Notable Changes

* Added shell scripts for users without Temperature Sensors.
* Issue templates added for `Bug Report`, `Feature Request` and `Support Request`.
* 'House Keeping' of directories for better navigation to shell scripts needed.
* Updated `README`.
