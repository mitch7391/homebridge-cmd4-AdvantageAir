<p align="center">
<img src="https://github.com/homebridge/branding/raw/master/logos/homebridge-wordmark-logo-vertical.png" width="150">
<img src="Screenshots/AdvAirLogo.png" width="220">
</p>

<span align="center">
  
[![npm](https://badgen.net/npm/v/homebridge-cmd4-advantageair/latest?icon=npm&label)](https://www.npmjs.com/package/homebridge-cmd4-advantageair)
[![npm](https://badgen.net/npm/dt/homebridge-cmd4-advantageair?label=downloads)](https://www.npmjs.com/package/homebridge-cmd4-advantageair)
[![verified-by-homebridge](https://badgen.net/badge/homebridge/verified/purple)](https://github.com/homebridge/homebridge/wiki/Verified-Plugins)
  
</span>

# homebridge-cmd4-AdvantageAir

Catered shell script to integrate air conditioner control units by Advantage Air into Homekit using the plug-in [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4). 

No affiliation with Advantage Air.

## Supported Control Units:
* Air Conditioning:
  * [e-zone](https://apps.apple.com/au/app/e-zone/id925994857)
  * [MyAir](https://apps.apple.com/au/app/myair/id481563583)
  * [MyAir4](https://apps.apple.com/au/app/myair4/id925994861)
  * MyAir5 - Appears to use the same app as MyPlace.
  * [MyPlace](https://apps.apple.com/au/app/myplace/id996398299)
  * [zone10e](https://apps.apple.com/au/app/zone10e/id1076850364)

<I><B> Note: </B> [zone10](https://apps.apple.com/au/app/zone10/id510581478) and [MyAir3](https://apps.apple.com/au/app/myair3/id645762642) do not appear to work with this plug-in. </I>

* Extras:
  * [MyPlace](https://apps.apple.com/au/app/myplace/id996398299)
     - [x] Lights 
     - [x] Garage Door
     - [x] Gate
     - [ ] Motion Sensors
     - [ ] Blinds

<I><B> Note: </B> Config for these extras can be found [here](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki/Config-Creation#myplace-extras). </I>


## How It Looks:
### Air Conditioning - Thermostat Mode (with Fan Speed) and Fan or FanSwitch Mode:
<p align="left">
<img src="Screenshots/Aircon.png" width="295" height="640">
<img src="Screenshots/Fan.png" width="295" height="640">
<img src="Screenshots/Aircon_fanSwitch.png" width="295" height="640">
</p>

### Air Conditioning - Zone Control and Temperature Sensors:
<p align="left">
<img src="Screenshots/Room.png" width="295" height="640">
<img src="Screenshots/Sensors.png" width="295" height="640">
</p>

### Air Conditioning - Zone Control without Temperature Sensors: 
<p align="left">
<img src="Screenshots/NoSensors.png" width="295" height="640">
<img src="Screenshots/ZoneControl.png" width="295" height="640">
</p>

### MyPlace Extras - Lights: 
<p align="left">
<img src="Screenshots/MyPlaceLights.png" width="295" height="640">
<img src="Screenshots/MyPlaceLightsControl.png" width="295" height="640">
</p>

### MyPlace Extras - Garage Door / Gate: 
<p align="left">
<img src="Screenshots/GarageDoorControl.png" width="295" height="640">
</p>
<I><B> Note: </B> Garage Door / Gate will appear in Apple CarPlay. </I>

## Installation:
### Raspbian/HOOBS/macOS/NAS:
1. Install Homebridge via these instructions for [Raspbian](https://github.com/homebridge/homebridge/wiki/Install-Homebridge-on-Raspbian), [HOOBS](https://support.hoobs.org/docs) or [macOS](https://github.com/homebridge/homebridge/wiki/Install-Homebridge-on-macOS).
2. Install the [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4) plug-in via the Homebridge UI ['plugins'](https://github.com/oznu/homebridge-config-ui-x#plugin-screen) tab search function. Once installed, a pop-up box with a small config in it will appear. Do not edit anything and make sure you click `SAVE`.

     <p align="left">
     <img width="800px" src="Screenshots/cmd4Install.png">
     </p>

3. Install `homebridge-cmd4-AdvantageAir` plug-in via the Homebridge UI 'plugins' tab search function.

     <p align="left">
     <img width="800px" src="Screenshots/cmd4AdvAirInstall.png">
     </p>

4. Install <B>jq</B> via your Homebridge UI terminal or through ssh: 
```shell
# Raspbian/Hoobs:
sudo apt-get install jq

# macOS:
brew install jq

# Synology NAS:
apt-get install jq

# QNAP NAS:
apk add jq
```
5. Check if <B>curl</B> is installed (it should already be):
```
curl -V
```
6. If <B>curl</B> does not return a version number, install via:
```shell
# Raspbian/Hoobs:
sudo apt-get install curl

# macOS:
brew install curl

# Synology NAS:
apt-get install curl

# QNAP NAS:
apk add curl
``` 
7. Automatically create your Homebridge `config.json`:
* Homebridge users with access to the Homebridge web UI can jump ahead to `Step 8`.
* Homebridge users without access to the Homebridge web UI can use the following [terminal instructions](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki/Config-Creation#homebridge-terminal-instructions).
* HOOBS users do not have access to our Homebridge UI (for now!) and will have to use the following [terminal instructions](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki/Config-Creation#hoobs-terminal-instructions).

8. Go to the 'plugins' tab in Homebridge UI and locate your newly installed `homebridge-cmd4-AdvantageAir`. Click `SETTINGS` and it should launch the 'Advantage Air Configuration Creator'.
     <p align="left">
     <img width="800px" src="Screenshots/AdvAirConfigCreator.png">
     </p>

9. Scroll down to the 'AdvantageAir Device Settings' area and fill out the `Name` and `IP Address` fields (if you have more than one Advantage Air tablet, you can click `Add new device` to setup the others), and then click `SAVE`. It will close the UI and you will need to open it once more as per Step 8.
10. Tick/untick the the following checkboxes, then press the `CONFIG CREATOR` button; your Advantage Air config has now been created!
    <p align="left">
    <img width="584px" src="Screenshots/Checkbox_fan-as-fanswitch.png">
    </p>
    "FanSwitch" setup allows the current fanSpeed to be displayed on Homekit tile when the Aircon is On and is in Cool, Heat or Dry (Auto) mode.
    <p align="left">
    <img width="420px" src="Screenshots/FanSwitch_setup.png">
    </p>

    <p align="left">
    <img width="584px" src="Screenshots/Checkbox_lightbulb-as-proxy.png">
    </p>
    This will use "Lightbulb" instead of "Switch" accessory as proxy for Zone Control.  This only affects Aircon system with temperature sensors. The advantage of using "Lightbulb" accessory as proxy is to have the zone % open shown on the Homekit tile eventhough it is not users controllable.
    <p align="left">
    <img width="584px" src="Screenshots/Lightbulb_as_proxy.png">
    </p>

    <p align="left">
    <img width="480px" src="Screenshots/Checkbox_fancy-timers.png">
    </p>    
            This will generate extra timers to turn-on the Aircon in specidic mode: Heat, Cool or Vent.

    
11. Click `CHECK CONFIGURATION`. It will check over your installation and config to make sure you have everything correct. On a success it will say `Passed`; if something is incorrect, an error message will pop up telling you what it is that you have missed and need to fix.

     <p align="left">
     <img width="360px" src="Screenshots/AdvAirShellCheckPassed.png">
     </p>

     <p align="left">
     <img width="800px" src="Screenshots/AdvAirShellCheckError.png">
     </p>

12. Optionally, if you have Cmd4 v7.0.0-beta2 or v7.0.1 installed, you could make use of the optimised version of Cmd4PriorityPollingQueue.js module by running the following script to get some improvement in performance:

     `<config.json storage path>/copyEnhancedCmd4PriorityPollingQueueJS.sh`

     `<config.json storage path>` is the directory path where "config.json" is stored.  For Raspbian installation, it is typically `/var/lib/homebridge`.  For Mac users, it is typically `$HOME/.homebridge`. For HOOBS users, it is typically `/var/lib/hoobs/<bridge>`.

### Windows OS
I have not successfully set this up on a Windows OS Homebridge server yet. If you have and want to contribute; please reach out and let me know how you did it. Otherwise I strongly suggest you buy a dedicated Raspberry Pi for Homebridge.


## Further Notes
You can read more about this project and how to create your config on the [Wiki](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki) page.


## How You Can Help:
* Open Issues/Tickets.
* Report Bugs/Errors.
* Suggest Improvements and Features you would like to see!
* Help test the beta releases! See the [Wiki](https://github.com/mitch7391/homebridge-cmd4-AdvantageAir/wiki#beta-testing) to find out how to 'sign up'.  
* Create a fork, add or fix something yourself and create a Pull Request to be merged back into this project and released!
* Let me know if you have a Control Unit or App that works that is not confirmed in my [Supported List](https://github.com/mitch7391/cmd4-AdvantageAir#supported-control-units)!
* Let me know if you can figure out how to get this running on Windows 10/11 Homebridge.
* Feel free to let me know you are loving the project by give me a `Star`! It is nice to have an idea how many people use this project! 


## Special Thanks:
1. The evolution, improvements and continuously tireless work of [John Talbot](https://github.com/ztalbot2000), who has not only improved these shell scripts beyond measure and created the Homebridge UI integration; but continues to improve [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4) to further cater to this work and my end users.
2. The hard work and valued coding experince of [Ung Sing Wong](https://github.com/uswong) that has led to the many amazing features in a short space of time; and no doubt more to come in the future!
3. This would never have kicked off without the patience and kindness of [TimofeyK](https://github.com/TimofeyK) helping out a new starter find his feet.
4. Lastly, but certainly not least, is my beautiful Wife who has put up with what has become an obsession of mine to get our air conditioner and many other devices into Homekit. May she forever be misunderstood by Siri for my amusement...


## LICENSE:
This plugin is distributed under the MIT license. See [LICENSE](https://github.com/mitch7391/cmd4-E-Zone-MyAir/blob/master/LICENSE) for details.
