# Change Log

All notable changes to this project will be documented in this file. This project uses [Semantic Versioning](https://semver.org/).

## 2.3.0 (2021-09-30)

### Notable Changes

* `config.json` changes to stop warnings in the upcoming homebridge-cmd4 v6.0.0 release
* Characteristics now require the starting letter to be 'lower case' and not 'upper case'; this will pave the way for future work John Talbot puts in for cmd4 to have a `config-schema.json` in Homebridge UI


## 2.2.0 (2021-09-15)

### Notable Changes

* Removed `stdbuf` dependency from scripts (could affect macOS user installs)
* Install instructions in `README` have been split into Raspbian and macOS installs; still no Windows install instructions
* `IP Address` / `Port Number` at start of script has had the port number moved into the script commands; so users do not need to think they need to change the port number or figure it out themselves


## 2.1.0 (2021-08-22)

### Notable Changes

* Addition of test scripts


## 2.0.0 (2021-08-18)

### Breaking Changes

* New singular script `AdvAir.sh` to replace the need of two scripts `ezone.sh` and `zones.sh` ('Two Constant Zone' users will still have to use two scripts for now; sorry!)
* Better error handling and reporting; script will attempt 5 iterations to receive a valid reading from the control unit
* Introduction and use of homebridge-cmd4's new `WoRm` (Write once Read many) queue designed by John Talbot to better handle interactions with Advantage Air control unit's limitations

### Notable Changes

* Repo rename to `cmd4-AdvantageAir`; this is to more accurately capture the broader control units this API encompasses
* Temperature Sensor Low Battery warning indications added
* `config.json` improvements and clean-up
* Documentation improvements in `README`


## 1.2.0 (2021-02-08)

### Notable Changes

* New `config.json` examples added for the new polling methods of cmd4 v3.0.x.
* Updated `README`

### Bug Fixes

* Fixed a couple of small bugs in shell scripts: use of `"true"` instead of `'1'` for `On` characteristic and double use of case `* )`


## 1.1.0 (2021-01-22)

### Notable Changes

* Added shell scripts for users without Temperature Sensors
* Issue templates added for `Bug Report`, `Feature Request` and `Support Request`
* 'House Keeping' of directories for better navigation to shell scripts needed
* Updated `README`
