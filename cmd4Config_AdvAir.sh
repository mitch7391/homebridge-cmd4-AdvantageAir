#!/bin/bash
#
# This script is to generate a complete cmd4 config.json file needed for the cmd4-advantageair plugin
#
# usage:
#       First, identify the IP address of your AdvantageAir (AA) system
#       then on a Terminal on the machine where the homebridge is running
#       run this script as follow:
#
#       ./cmd4Config_AdvAir.sh and you will be asked to input your AA ip address
#
#       or you can pass your AA ip address as an argument:
#
#       ./cmd4Config_AdvAir.sh "your AA ip address"
# e.g.  ./cmd4Config_AdvAir.sh "192.168.0.31"
#
#       A config json file in the form "cmd4Config_AdvAir_xxxxx.json" will be generated.
#       xxxxx is the name of your AA system.
#       
#       You can copy this config json file in its entirety into cmd4 plugin or if you know 
#       what you are doing you can do some edits, like changing some names or deleting some accessories
#       you do not need, etc.
#
#       NOTE:  If you need to 'flip' the GarageDoorOpener, you have to add that in yourself.
# 
IP="$1"
if [ -z "${IP}" ]; then
   until [ -n "${IP}" ]; do 
      echo "Please enter your AdvantageAir system IP address (xxx.xxx.xxx.xxx):"
      read -r INPUT
      if expr "$INPUT" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
         IP="$INPUT"
      else
         echo ""
         echo "Wrong format for an IP address! Please enter again!"
         echo ""
      fi
   done
fi
#
name=""
configFileName=""
hasAircons=false
hasLights=false
hasThings=false
#

function cmd4Header()
{
   { echo "{"
     echo "    \"platform\": \"Cmd4\","
     echo "    \"name\": \"Cmd4\","
     echo "    \"debug\": false,"
     echo "    \"outputConstants\": false,"
     echo "    \"statusMsg\": true,"
     echo "    \"timeout\": 60000,"
     echo "    \"stateChangeResponseTime\": 0,"
     echo "    \"constants\": ["
     echo "        {"
     echo "            \"key\": \"\${IP}\","
     echo "            \"value\": \"${IP}\""
     echo "        }"
     echo "    ],"
     echo "    \"queueTypes\": ["
     echo "        {"
     echo "            \"queue\": \"A\","
     echo "            \"queueType\": \"WoRm2\""
     echo "        }"
     echo "    ],"
     echo "   \"accessories\": ["
   } > "$configFileName"
}
 
function cmd4LightbulbNoDimmer()
{
   local name="$1"
   { echo "        {"
     echo "            \"type\": \"Lightbulb\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"'light:$name' \${IP}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4LightbulbWithDimmer()
{
   local name="$1"
   { echo "        {"
     echo "            \"type\": \"Lightbulb\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"brightness\": 80,"
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"brightness\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"'light:${name}' \${IP}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4GarageDoorOpener()
{
   local name="$1"
   { echo "        {"
     echo "            \"type\": \"GarageDoorOpener\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"obstructionDetected\": \"FALSE\","
     echo "            \"currentDoorState\": 1,"
     echo "            \"targetDoorState\": 1,"
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"currentDoorState\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"targetDoorState\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"'thing:${name}' \${IP}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4VentLightbulb()
{
   local name="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"Lightbulb\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"brightness\": 50,"
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"brightness\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"$zoneStr \${IP}${ac_l}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4TimerLightbulb()
{
   local name="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"Lightbulb\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"brightness\": 0,"
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"brightness\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"timer \${IP}${ac_l}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4Thermostat()
{
   local airconName="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"Thermostat\","
     echo "            \"displayName\": \"${airconName}\","
     echo "            \"currentHeatingCoolingState\": \"OFF\","
     echo "            \"targetHeatingCoolingState\": \"OFF\","
     echo "            \"currentTemperature\": 24,"
     echo "            \"targetTemperature\": 24,"
     echo "            \"temperatureDisplayUnits\": \"CELSIUS\","
     echo "            \"name\": \"${airconName}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"currentHeatingCoolingState\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"targetHeatingCoolingState\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"currentTemperature\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"targetTemperature\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"\${IP}${ac_l}\","
   } >> "$configFileName"
}

function cmd4Fan()
{
   local fanName="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"Fan\","
     echo "            \"displayName\": \"${fanName}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"rotationSpeed\": 100,"
     echo "            \"name\": \"${fanName}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"rotationSpeed\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"\${IP}${ac_l}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4FanSwitch()
{
   local fanName="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"Switch\","
     echo "            \"displayName\": \"${fanName}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"name\": \"${fanName}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"\${IP}${ac_l}\","
   } >> "$configFileName"
}

function cmd4FanLinkTypes()
{
   local fanSpeedName="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "            \"linkedTypes\": ["
     echo "                {"
     echo "                    \"type\": \"Fan\","
     echo "                    \"displayName\": \"${fanSpeedName}\","
     echo "                    \"on\": \"TRUE\","
     echo "                    \"rotationSpeed\": 100,"
     echo "                    \"name\": \"${fanSpeedName}\","
     echo "                    \"manufacturer\": \"Advantage Air Australia\","
     echo "                    \"model\": \"${sysType}\","
     echo "                    \"serialNumber\": \"${tspModel}\","
     echo "                    \"queue\": \"A\","
     echo "                    \"polling\": ["
     echo "                        {"
     echo "                            \"characteristic\": \"on\""
     echo "                        },"
     echo "                        {"
     echo "                            \"characteristic\": \"rotationSpeed\""
     echo "                        }"
     echo "                    ],"
     echo "                    \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "                    \"state_cmd_suffix\": \"\${IP} fanSpeed${ac_l}\""
     echo "                }"
     echo "            ]"
     echo "        },"
   } >> "$configFileName"
}

function cmd4TempSensor()
{
   local name="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"TemperatureSensor\","
     echo "            \"subType\": \"TempSensor${b}\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"currentTemperature\": 25,"
     echo "            \"statusLowBattery\": \"BATTERY_LEVEL_LOW\","
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"currentTemperature\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"statusLowBattery\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"$zoneStr \${IP}${ac_l}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4Switch()
{
   local name="$1"
   local ac_l=" ${ac}"
   
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"Switch\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"A\","
     echo "            \"polling\": true,"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"$zoneStr \${IP}${ac_l}\""
     echo "        },"
   } >> "$configFileName"
}

function cmd4Footer()
{
   cp "${configFileName}" "${configFileName}.temp"
   sed '$ d' "${configFileName}.temp" > "${configFileName}" 
   rm "${configFileName}.temp"
   #                               
   { echo "        }"
     echo "    ]"                      
     echo "}"
   } >> "$configFileName"
}

# main starts here

echo ""
echo "Fetching data from your AdvantageAir system (${IP}), this might take up to 15 seconds.... "

myAirData=$(curl -s -g --max-time 15 --fail --connect-timeout 15 "http://${IP}:2025/getSystemData")
#
if [ -z "$myAirData" ]; then
   echo ""
   echo "ERROR: either your AdvantageAir system is inacessible or your IP address is WRONG!"
   exit 1
fi
#
name=$(echo "$myAirData"|jq -e ".system.name" | sed 's/ /_/g' | sed s/[\'\"]//g)
configFileName="cmd4Config_AdvAir_${name}.json"
#
echo ""
echo "In the process of creating \"${configFileName}\". It might take up to 2 minutes...."
#
sysType=$(echo "$myAirData" | jq -e ".system.sysType" | sed 's/ /_/g' | sed 's/\"//g')
tspModel=$(echo "$myAirData" | jq -e ".system.tspModel" | sed 's/ /_/g' | sed 's/\"//g')

hasAircons=$(echo "$myAirData"|jq -e ".system.hasAircons")
hasLights=$(echo "$myAirData"|jq -e ".system.hasLights")
hasThings=$(echo "$myAirData"|jq -e ".system.hasThings")

# firstly, paste the cmd4 config header
if [[ "${hasAircons}" || "${hasLights}" || "${hasThings}" ]]; then
   cmd4Header
fi

# Aircon systems
if [ "$hasAircons" ]; then
   for (( a=1;a<=4;a++ )); do
      ac=$( printf "ac%1d" "$a" )
      aircon=$(echo "$myAirData" | jq -e ".aircons.${ac}.info")
      if [ "${aircon}" != "null" ]; then
         name=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.name" | sed 's/ /_/g' | sed 's/\"//g')
         cmd4Thermostat "${name}"
         cmd4FanLinkTypes "${name} FanSpeed"
         cmd4Fan "${name} Fan"
         cmd4TimerLightbulb "${name} Timer"
         #
         nZones=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.noOfZones")
         for (( b=1;b<=nZones;b++ )); do
            zoneStr=$( printf "z%02d" "$b" )
            name=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.name" | sed 's/\"//g')
            rssi=$(echo "$myAirData" | jq -e ".aircons.${ac}.zones.${zoneStr}.rssi")
            if [ "${rssi}" = "0" ]; then
               cmd4VentLightbulb "$name"
            else
               cmd4Switch "$name"
            fi
         done
         for (( b=1;b<=nZones;b++ )); do
            zoneStr=$( printf "z%02d" "$b" )
            name=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.name" | sed 's/\"//g')
            rssi=$(echo "$myAirData" | jq -e ".aircons.${ac}.zones.${zoneStr}.rssi")
            if [ "${rssi}" != "0" ]; then
               cmd4TempSensor "${name} Temperature"
            fi
         done
      fi
   done      
fi

# Lightings
if [ "$hasLights" ]; then
   echo "$myAirData" | jq -e ".myLights.lights" | grep \"id\" | cut -d":" -f2 | sed s/[,]//g | while read -r id; 
   do 
      name=$(echo "$myAirData" | jq -e ".myLights.lights.${id}.name" | sed s/\"//g) 
      value=$(echo "$myAirData" | jq -e ".myLights.lights.${id}.value ")
      if [ "${value}" = "null" ]; then
         cmd4LightbulbNoDimmer "${name}"
      else
         cmd4LightbulbWithDimmer "${name}"
      fi
   done
fi

# Things - Garage or Gate only for now 
if [ "$hasThings" ]; then
   echo "$myAirData" | jq -e ".myThings.things" | grep \"id\" | cut -d":" -f2 | sed s/[,]//g | while read -r id; 
   do 
      name=$(echo "$myAirData" | jq -e ".myThings.things.${id}.name" | sed s/\"//g) 
      cmd4GarageDoorOpener "${name}"
   done
fi

# lastly, if $configFileName was created then delete the last line and paste the footer 
if [ -f "${configFileName}" ]; then
   cmd4Footer
   echo ""
   echo "${configFileName} created sucessfully!"
else
   echo ""
   echo "There is something wrong! the config json file \"${configFileName}\" was not created!" 
fi
