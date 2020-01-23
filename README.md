# cmd4-E-Zone-MyAir
A shell script to integrate E-zone/MyAir controller by Advantage Air/Ambience Air into Homekit using the Homebridge plug-in cmd4

## Installation:
1. Install [Homebridge](https://github.com/nfarina/homebridge).
2. Install [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4) plug-in.
3. Edit <B>ezone.sh</B> and <B>zones.sh</B> with the IP address of your E-Zone/MyAir controller.
4. Copy <B>ezone.sh</B> and <B>zones.sh</B> to a subdirectory of your <B>.homebridge</B> directory; e.g. <B>.homebridge/Cmd4Scripts/ezone.sh</B>. Mine is located in <B>/home/pi/ezone.sh</B>.
5. <B>OR</B> if you are less savvy like me, you can create the script in your homedrive of your raspberry pi using `sudo nano ezone.sh` and pasting the contents inside, then saving. Its pathway will be <B>/home/pi/ezone.sh</B>. Do the same for <B>zones.sh</B>.
6. Install <B>jq</B>; `sudo apt-get install jq`. Make sure 'curl' is installed (it should already be installed).
7. Edit your homebridge <B>config.json</B> using the sample included.
8. Restart Homebridge.

## About:
Due to the current limitations in Homekit, multi-zoned ducted air conditioners are not represented as a single accessory. Our work around here is two create multiple accessories:
1. A Thermostat with modes <B>OFF/HEAT/COOL</B> using the E-Zone/MyAir 'constant' zone (usually zone 1) as the measured temperature for feedback. <B><I>NOTE:</B></I> <B>AUTO</B> mode in Homekit is not used in E-zone/MyAir, so it will set the controller to <B>OFF</B>. Setting <B>DRY</B> mode from the controller will then represent in Homekit as <B>OFF</B>. 
2. A simple Fan with modes <B>OFF/ON</B> (for the time being) for the controller's <B>FAN</B> mode. <B><I>NOTE:</B></I> Turning the Fan accessory on in Homekit will turn off the Thermostat accessory, and turning the Thermostat accessory on in homekit will turn off the Fan Accessory. When the Fan is turned on in Homekit, it will also execute the <B>AUTO</B> mode in the E-zone/MyAir app, just to keep it simple for now.
3. Temperature Sensors with feedback from each zone. These also include the <B>FAULT</B> status in the accessory, this is determined by the error codes produced by the controller. <B><I>NOTE:</B></I> According to the Advantage Air developers there is only one fault code; which is used for low battery, dead battery and loss of connection to sensor. I could not get any further information about this and have only seen one fault myself.
4. Switches with feedback to open and close each zone. <B><I>NOTE: I do not recommend adding your 'constant' zone (usually zone 1) as a Switch in Homekit as this zone is not meant to be turned off. I am not responsible for any damage to your ducting if you do manage to shut this zone (not sure it is possible, but just in case) and run the air conditioner.</B></I>

## Further Notes:
1. I have only tested this on my own E-zone controller, but the API is exactly the same for MyAir; that is actually where I was able to get the commands and learn how to structure them properly. The API can be found [here](http://advantageair.proboards.com/) once you have registered.
2. I am not very savvy with all of this coding work and had a lot of help and direction; this was a learning curve for me but I plan to keep working on this and improving it.

## Special Thanks:
1. None of this would have been possible without the patience and kindness of TimofeyK; who did not have to help me at all, but worked through my script and errors, and put up with my stupid questions. Check out his shell script for the [Daikin Airbase](https://github.com/TimofeyK/cmd4-Daikin-Airbase) controller using cmd4 as well if you have a Daikin.
2. Also I would not have been able to get any of this working without John Talbot's [homebridge-cmd4](https://github.com/ztalbot2000/homebridge-cmd4), which these shell scripts rely on.
3. Lastly all of the people on the [r/homebridge](https://www.reddit.com/r/homebridge/) who piped up with little bits of help and my Fiancée who has put up with what has become an obsession to get our air conditioner in Homekit. 
