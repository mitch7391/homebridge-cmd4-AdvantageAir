<span align="center">

# cmd4-AdvantageAir

</span>

<I>Formerly: cmd-E-Zone-MyAir</I>

Catered shell scripts to integrate air conditioner control units by Advantage Air into Homekit using the plug-in [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4). 

No affiliation with Advantage Air or any of their products.

## Supported Control Units:
* Confrimed:
  * [e-zone](https://apps.apple.com/au/app/e-zone/id925994857)
  * [MyAir](https://apps.apple.com/au/app/myair/id481563583)
  * [zone10e](https://apps.apple.com/au/app/zone10e/id1076850364)
* Unconfirmed:
  * [MyAir3](https://apps.apple.com/au/app/myair3/id645762642)
  * [MyAir4](https://apps.apple.com/au/app/myair4/id925994861)
  * [MyPlace](https://apps.apple.com/au/app/myplace/id996398299)
  * [zone10](https://apps.apple.com/au/app/zone10/id510581478)

## Installation:
1. Install [Homebridge](https://github.com/homebridge/homebridge#installation).
2. Install the [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4) plug-in through the config-ui-x web UI or via terminal command: `sudo npm install -g --unsafe-perm homebridge-cmd4`. Note: you do not need to follow the extra installation steps on cmd4's page for this.
3. Navigate through the directories above to find the situation that best represents your setup! Temperature sensors? Two storey home with two constant zones?
4. Edit `ezone.sh` and `zones.sh` with the IP address of your Advantage Air controller. If you have two constant zones, then you will need to edit these at the top of `ezone.sh`
5. Copy `ezone.sh` and `zones.sh` to a subdirectory of your `.homebridge` directory; e.g. `.homebridge/Cmd4Scripts/ezone.sh`. Mine is located in `/home/pi/ezone.sh`. 
6. <B>OR</B> if you are less savvy like me, you can create the script in your homedrive of your raspberry pi using `sudo nano ezone.sh` and pasting the contents inside, then saving. Its pathway will be `/home/pi/ezone.sh`. Do the same for `zones.sh`. For HOOBS users this would create your shell scripts at the lcation: `/home/hoobs/.hoobs/ezone.sh`.
7. Install <B>jq</B>; `sudo apt-get install jq`. Make sure `curl` is installed (it should already be installed).
8. Edit your homebridge `config.json` using the samples included in each directory for your appropriate setup; this should be completed from the config-ui-x web UI.
9. Restart Homebridge.

## Screenshot:
<h3 align="center">
  <img src="https://github.com/mitch7391/cmd4-E-Zone-MyAir/blob/master/Ezone.png">
</h3>

## About:
Due to the current limitations in Homekit, multi-zoned ducted air conditioners are not represented as a single accessory. Our work around here is two create multiple accessories:
1. A Thermostat with modes <B>OFF/HEAT/COOL</B> using the E-Zone/MyAir 'constant' zone (usually zone 1 in a one 'constant zone' setup) as the measured temperature for feedback. <B><I>NOTE:</B></I> <B>AUTO</B> mode in Homekit is not used in Advantage Air controllers, so it will set the controller to <B>OFF</B>. Setting <B>DRY</B> mode from the controller will then represent in Homekit as <B>OFF</B>. 
2. A simple Fan with modes <B>OFF/ON</B> (for the time being) for the controller's <B>FAN</B> mode. <B><I>NOTE:</B></I> Turning the Fan accessory on in Homekit will turn off the Thermostat accessory, and turning the Thermostat accessory on in homekit will turn off the Fan Accessory. When the Fan is turned on in Homekit, it will also execute the <B>AUTO</B> mode in the respective Advantage Air app; just to keep it simple for now.
3. Temperature Sensors with feedback from each zone. These also include the <B>FAULT</B> status in the accessory, this is determined by the error codes produced by the controller. <B><I>NOTE:</B></I> According to the Advantage Air developers there is only one fault code; which is used for low battery, dead battery and loss of connection to sensor. I could not get any further information about this and have only seen one fault myself.
4. Versions of the shell script have been added for users who do not have the Temperature Sensors.
5. Versions of the shell script have been added for users who have two 'constant zones' (two storey house typically). According to Advantage Air only one constant zone has to be on at any time; some logic has been added to the shell scripts for two 'constant zones' to either shut off the zone or turn off the entire controller based on if the other 'constant zone' is open or not; to make sure your air conditioner and ducting are protected.
6. Switches with feedback to open and close each zone. <B><I>NOTE: I do not recommend adding your 'constant zones' (usually zone 1, but there can be a second; represented as a 'C' in the app) as a Switch in Homekit as this zone is not meant to be turned off. I am not responsible for any damage to your ducting if you do manage to shut this zone (not sure it is possible, but just in case) and run the air conditioner.</B></I>

## How to Keep Up-To-Date:
As this is not a typical homebridge plug-in, you will not get prompted to update when I add improvements. The best way to keep up-to-date is to click the `Watch` button in the top right corner and select `All Activity` or `Custom` and then `Releases`. This will ensure you get an email everytime I push a new release with new features or improvements! Feel free to give me a `Star` as well if you are happy with the work.

## Further Notes:
1. I have only tested this on my own E-zone Advantage Air controller, but the API is exactly the same for MyAir and the name devices at the begining of this README; that is actually where I was able to get the commands and learn how to structure them properly. The API can be found [here](http://advantageair.proboards.com/) once you have registered.
2. I am not very savvy with all of this coding work and had a lot of help and direction as I learn as I go; this was a learning curve for me but I plan to keep working on this and improving it.

## Potential Device Limitations:
What we have discovered from over 8 months of trying to improve performance and reduce homebridge/cmd4 log warnings: 

<I>"The air conditioner controller returns successfully incomplete system data when it is in use by the operator and also incomplete system data if any 'Set' operation is in progress. The scripts that send/receive data from the air conditioner controller must not only retry on failures, but also check the validity of the data as the incomplete system data returned presents a successful return code. Even with these features built into the scripts, Cmd4 has implemented a queuing system such that any polling or queries from HomeKit would only send a setValue when no other operation was in progress. This feature in Cmd4 is the WoRM (Write once Read many) queue. While Cmd4 can then manage all traffic to the air conditioner controller, it cannot know if someone is actually interacting with the control tablet. When interacting with the control tablet and Cmd4 is trying to send/receive data simultaneously, errors are unavoidable.  Cmd4 hides these unavoidable errors in debug mode as it retries the transaction and in this way presents a clean console that otherwise would cause panic to the operator."</I> - John Talbot.

## Special Thanks:
1. The evolution, improvements and continuously tireless work of [John Talbot](https://github.com/ztalbot2000), who has not only improved these shell scripts beyond measure; but continues to improve [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4) to further cater to this work and my end users. 
2. This would never have kicked off without the patience and kindness of [TimofeyK](https://github.com/TimofeyK) helping out a new starter.
4. Lastly, but certainly not least is my beautiful Wife who has put up with what has become an obsession of mine to get our air conditioner and many other devices into Homekit. May she forever be misunderstood by Siri for my amusement...

## LICENSE:
See [LICENSE](https://github.com/mitch7391/cmd4-E-Zone-MyAir/blob/master/LICENSE)
