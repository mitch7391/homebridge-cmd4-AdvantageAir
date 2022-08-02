#!/bin/bash
#
# This script is to generate a complete Cmd4 configuration file needed for the cmd4-advantageair plugin
# This script can handle up to 3 separate AdvantageAir (AA) systems
#
# usage:
#       First, identify the IP address(es) of your AdvantageAir system(s)
#       then on a Terminal on the machine where the Homebridge is running
#       run this script as follow:
#
#       ./ConfigCreator.sh and you will be asked to input your AA ip address(es)
#
#       or you can pass your AA ip address(es) as an argument:
#
#       ./ConfigCreator.sh "your first AA ip address" "your second AA ip address" "your third AA ip address"
# e.g.  ./ConfigCreator.sh "192.168.0.31" "192.168.0.173" "127.0.0.1"
#
#       Ingore the second or third argument if you do not have second or third AA systems.
#
#       A Cmd4 configuration file  "cmd4Config_AA_xxxxx.json" will be created, where xxxxx is the name of
#       your first AA system.
#       
#       If your Homebridge machine is a Raspberry Pi (RPi) or a Mac, then the created configuration file will be
#       copied to Homebridge Cmd4 JASON Config Editor automatically.
#      
#       If your Homebridge machine is not a RPi or a Mac, then you have to copy this configuration file in its
#       entirety into Homebridge Cmd4 JASON Config Editor manually, then click SAVE. 
#       If you know what you are doing you can do some edits on this configuration file in the JASON Config Editor,
#       like changing some names or deleting some accessories you do not need, etc, click SAVE when you are done.
#
#       NOTE:  If you need to 'flip' the GarageDoorOpener, you have to add that in yourself.
# 

AAIP="$1"
AAIP2="$2"
AAIP3="$3"

# define some variables
name=""

hasAircons=false
hasLights=false
hasThings=false

# define some file variables
homebridgeConfigJson=""

configJson="config.json"          # homebridge config.json
cmd4ConfigJson="cmd4Config.json"  # Homebridge-Cmd4 config.json

cmd4ConfigJsonAA="cmd4Config_AA.json"

cmd4ConfigConstantsAA="cmd4Config.json.AAconstants"
cmd4ConfigQueueTypesAA="cmd4Config.json.AAqueueTypes"
cmd4ConfigAccessoriesAA="cmd4Config.json.AAaccessories"

cmd4ConfigJsonAAwithNonAA="${cmd4ConfigJsonAA}.withNonAA"

cmd4ConfigNonAA="cmd4Config.json.nonAA"
cmd4ConfigConstantsNonAA="cmd4Config.json.nonAAconstants"
cmd4ConfigQueueTypesNonAA="cmd4Config.json.nonAAqueueTypes"
cmd4ConfigAccessoriesNonAA="cmd4Config.json.nonAAaccessories"
cmd4ConfigMiscNonAA="cmd4Config.json.nonAAmisc"

configJsonNew="${configJson}.new"     # new homebridge config.json

if [ -z "${AAIP}" ]; then
   until [ -n "${AAIP}" ]; do 
      echo "Please enter your AdvantageAir system IP address (xxx.xxx.xxx.xxx):"
      read -r INPUT
      if expr "${INPUT}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
         AAIP="${INPUT}"
      else
         echo ""
         echo "ERROR: Wrong format for an IP address! Please enter again!"
         echo ""
      fi
   done
   # enter the IP address of your second AA tablet if any
   until [ -n "${AAIP2}" ]; do 
      echo "Please enter your second AdvantageAir system IP address (xxx.xxx.xxx.xxx) if any. Just hit 'enter' if none:"
      read -r INPUT
      if [ -z "${INPUT}" ]; then
         break
      else
         if expr "${INPUT}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
            AAIP2="${INPUT}"
         else
            echo ""
            echo "ERROR: Wrong format for an IP address! Please enter again!"
            echo ""
         fi
      fi
   done
   # enter the IP address of your third AA tablet if any
   if [ -n "${AAIP2}" ]; then
      until [ -n "${AAIP3}" ]; do 
         echo "Please enter your third AdvantageAir system IP address (xxx.xxx.xxx.xxx) if any. Just hit 'enter' if none:"
         read -r INPUT
         if [ -z "${INPUT}" ]; then
            break
         else
            if expr "${INPUT}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
               AAIP3="${INPUT}"
            else
               echo ""
               echo "ERROR: Wrong format for an IP address! Please enter again!"
               echo ""
            fi
         fi
      done
   fi
fi
if [ -n "${AAIP}" ]; then noOfTablets=1; fi
if [ -n "${AAIP2}" ]; then noOfTablets=2; fi
if [ -n "${AAIP3}" ]; then noOfTablets=3; fi

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
   } > "$1"
}

function cmd4ConstantsHeader()
{
   { echo "    \"constants\": ["
   } > "$1"
}

function cmd4Constants()
{
   { echo "        {"
     echo "            \"key\": \"${ip}\","
     echo "            \"value\": \"${IPA}\""
     echo "        },"
   } >> "$1"
}

function cmd4QueueTypesHeader()
{
   { echo "    \"queueTypes\": ["
   } > "$1"
}

function cmd4QueueTypes()
{
   { echo "        {"
     echo "            \"queue\": \"${queue}\","
     echo "            \"queueType\": \"WoRm2\""
     echo "        },"
   } >> "$1"
}

function cmd4AccessoriesHeader()
{
   { echo "    \"accessories\": ["
   } > "$1"
}

function cmd4ConstantsQueueTypesAccessoriesMiscFooter()
{
   cp "$1" "$1.temp"
   sed '$ d' "$1.temp" > "$1" 
   rm "$1.temp"
   
   { echo "        }"
     echo "    ],"
   } >> "$1"
}

 
function cmd4LightbulbNoDimmer()
{
   local name="$2"
   { echo "        {"
     echo "            \"type\": \"Lightbulb\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"'light:$name' ${ip}\""
     echo "        },"
   } >> "$1"
}

function cmd4LightbulbWithDimmer()
{
   local name="$2"
   { echo "        {"
     echo "            \"type\": \"Lightbulb\","
     echo "            \"displayName\": \"${name}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"brightness\": 80,"
     echo "            \"name\": \"${name}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"brightness\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"'light:${name}' ${ip}\""
     echo "        },"
   } >> "$1"
}

function cmd4GarageDoorOpener()
{
   local name="$2"
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
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"currentDoorState\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"targetDoorState\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"'thing:${name}' ${ip}\""
     echo "        },"
   } >> "$1"
}

function cmd4ZoneLightbulb()
{
   local name="$2"
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
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"brightness\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"$zoneStr ${ip}${ac_l}\""
     echo "        },"
   } >> "$1"
}

function cmd4TimerLightbulb()
{
   local name="$2"
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
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"brightness\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"timer ${ip}${ac_l}\""
     echo "        },"
   } >> "$1"
}

function cmd4Thermostat()
{
   local airconName="$2"
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
     echo "            \"queue\": \"$queue\","
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
     echo "            \"state_cmd_suffix\": \"${ip}${ac_l}\","
   } >> "$1"
}

function cmd4Fan()
{
   local fanName="$2"
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
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"rotationSpeed\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"${ip}${ac_l}\""
     echo "        },"
   } >> "$1"
}

function cmd4FanSwitch()
{
   local fanName="$2"
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
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"${ip}${ac_l}\","
   } >> "$1"
}

function cmd4FanLinkTypes()
{
   local fanSpeedName="$2"
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
     echo "                    \"queue\": \"$queue\","
     echo "                    \"polling\": ["
     echo "                        {"
     echo "                            \"characteristic\": \"on\""
     echo "                        },"
     echo "                        {"
     echo "                            \"characteristic\": \"rotationSpeed\""
     echo "                        }"
     echo "                    ],"
     echo "                    \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "                    \"state_cmd_suffix\": \"${ip} fanSpeed${ac_l}\""
     echo "                }"
     echo "            ]"
     echo "        },"
   } >> "$1"
}

function cmd4ZoneTempSensor()
{
   local name="$2"
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
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"currentTemperature\""
     echo "                },"
     echo "                {"
     echo "                    \"characteristic\": \"statusLowBattery\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"$zoneStr ${ip}${ac_l}\""
     echo "        },"
   } >> "$1"
}

function cmd4ZoneSwitch()
{
   local name="$2"
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
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": true,"
     echo "            \"state_cmd\": \"'/usr/local/lib/node_modules/homebridge-cmd4-advantageair/AdvAir.sh'\","
     echo "            \"state_cmd_suffix\": \"$zoneStr ${ip}${ac_l}\""
     echo "        },"
   } >> "$1"
}

function cmd4Footer()
{
   lastLine=$(tail -n 1 "$1")
   squareBracket=$(echo "${lastLine}"|grep "]") 

   cp "$1" "$1.temp"
   sed '$ d' "$1.temp" > "$1" 
   rm "$1.temp"
   #                               
   if [ -n "${squareBracket}" ]; then
      { echo "    ]"                      
        echo "}"
      } >> "$1"
   else
      { echo "    }"                      
        echo "}"
      } >> "$1"
   fi
}

function readHomebridgeConfigJson()
{
   configJson="${configJson}.backup.${t0}"

   # first find the Homebridge Config Json file and make a copy
   homebridgeConfigJson=$(find / -name 'config.json' 2>&1 |grep -v find|grep -v cmd4|grep -v System|grep homebridge)
   echo ""
   echo "Homebridge config.json: ${homebridgeConfigJson}"
   if [ -n "${homebridgeConfigJson}" ]; then
      validFile=$(grep -n '"platform": "Cmd4"' "${homebridgeConfigJson}"|cut -d":" -f1)
      if [ -n "${validFile}" ]; then
         # make a backup copy of the original Config Json file
         cp "${homebridgeConfigJson}" "${configJson}" 
         echo "         A backup copy: ${configJson}"
      else
         echo ""
         echo "ERROR: no Cmd4 Config found in \"${homebridgeConfigJson}\"! Please ensure that Homebridge-Cmd4 plugin is installed"
         echo "INFO:  the created ${cmd4ConfigJsonAA} is not copied to Homebridge-Cmd4 JASON Config Editor!"
         exit 7
      fi
   else
      echo ""
      echo "ERROR: no Homebridge config.json found!"
      echo "INFO:  the created ${cmd4ConfigJsonAA} was unable to be copied to Homebridge-Cmd4 JASON Config Editor!"
      exit 7
   fi
}

function extractCmd4ConfigFromConfigJson()
{
   cmd4Line1=$(grep -n '"platform": "Cmd4"' "${configJson}" | cut -d":" -f1)
   grep -n '      }' "${configJson}" | grep -v '           }' | cut -d":" -f1 | while read -r line;
   do
      if [ "${line}" -gt "${cmd4Line1}" ]; then
         cmd4Line2="${line}"
         # extract those lines pertaining to cmd4
         sed -n "${cmd4Line0},${cmd4Line2}p" "${configJson}" | sed 's/^        //g' > "${cmd4ConfigJson}"
         # remove those lines pertaining to cmd4 for later use
         sed "${cmd4Line0},${cmd4Line2}d" "${configJson}" > "${configJson}.tmp"
         return
      else
         cmd4Line0=$((line + 1))
      fi
   done
}

function extractNonAAdevices()
{
   cp "${cmd4ConfigJson}" "${cmd4ConfigNonAA}"
   AAline=$(grep -n 'state_cmd' "${cmd4ConfigNonAA}"|grep 'cmd4-advantageair'|cut -d":" -f1|head -n 1)

   until [ -z "${AAline}" ]; do
      grep -n '"type":' "${cmd4ConfigNonAA}"|grep -v '                    "type":'|cut -d":" -f1|sort -nr|while read -r line;
      do
         line1=$((line - 1)) 
         if [ "${line1}" -lt "${AAline}" ]; then
            AAline1="${line1}" 
            grep -n '        }' "${cmd4ConfigNonAA}"|grep -v '           }'|cut -d":" -f1|while read -r AAline2;
            do
               if [ "${AAline2}" -gt "${AAline1}" ]; then 

                  # log the deletion
                  #deviceType=$(sed -n "${line}p" "${cmd4ConfigNonAA}")
                  #AAline3=$((AAline+1))
                  #deviceSuffix=$(sed -n "${AAline3}p" "${cmd4ConfigNonAA}"|cut -d":" -f2)
                  #echo "Deleted AA device:${deviceType}${deviceSuffix}"

                  sed "${AAline1},${AAline2}d" "${cmd4ConfigNonAA}" > "${cmd4ConfigNonAA}.tmp"
                  mv "${cmd4ConfigNonAA}.tmp"  "${cmd4ConfigNonAA}"

                  break 
               fi
            done
            break
         fi
      done
      AAline=$(grep -n 'state_cmd' "${cmd4ConfigNonAA}"|grep 'cmd4-advantageair'|cut -d ":" -f1|head -n 1)
   done
}

function extractNonAAconstants()
{
   constantsLine=$(grep -n '    "constants":' "${cmd4ConfigNonAA}"|cut -d":" -f1)
   grep -n '],' "${cmd4ConfigNonAA}"|grep -v '     ]'|cut -d":" -f1|while read -r line;
   do
      if [ "${line}" -gt "${constantsLine}" ]; then
         line1=$((constantsLine + 1))
         line2=$((line - 1))
         sed -n "${line1},${line2}p" "${cmd4ConfigNonAA}" > "${cmd4ConfigConstantsNonAA}"
         break
      fi
   done

   if [ -f "${cmd4ConfigConstantsNonAA}" ]; then
      grep -n 'key' "${cmd4ConfigConstantsNonAA}"|cut -d":" -f3|cut -d "\"" -f2|while read -r key;
      do
         keyUsed=$(grep -n "$key" "${cmd4ConfigNonAA}"|grep -v 'key'|head -n 1|cut -d":" -f1)
         if [ -z "${keyUsed}" ]; then
            line=$(grep -n "${key}" "${cmd4ConfigConstantsNonAA}"|cut -d":" -f1)
            line1=$((line - 1))
            line2=$((line + 2))
            sed "${line1},${line2}d" "${cmd4ConfigConstantsNonAA}" > "${cmd4ConfigConstantsNonAA}.tmp"
            mv "${cmd4ConfigConstantsNonAA}.tmp" "${cmd4ConfigConstantsNonAA}"
            line=$(head -n 1 "${cmd4ConfigConstantsNonAA}")
            if [ "${line}" = "" ]; then rm -f "${cmd4ConfigConstantsNonAA}"; fi
         fi
      done
   fi
}

function extractNonAAqueueTypes()
{
   queueTypesLine=$(grep -n '    "queueTypes":' "${cmd4ConfigNonAA}"|cut -d":" -f1)
   grep -n '],' "${cmd4ConfigNonAA}"|grep -v '     ]'|cut -d":" -f1|while read -r line;
   do
      if [ "${line}" -gt "${queueTypesLine}" ]; then
         line1=$((queueTypesLine + 1))
         line2=$((line - 1))
         sed -n "${line1},${line2}p" "${cmd4ConfigNonAA}" > "${cmd4ConfigQueueTypesNonAA}"
         break
      fi
   done

   if [ -f "${cmd4ConfigQueueTypesNonAA}" ]; then
      accessoriesLine=$(grep -n '"accessories":' "${cmd4ConfigNonAA}"|grep -v '     "accessories":'|cut -d":" -f1)
      grep 'queue' "${cmd4ConfigQueueTypesNonAA}"|grep -v 'queueType'|cut -d":" -f1,2|while read -r queue;
      do
         queueLine=$(grep -n "${queue}" "${cmd4ConfigNonAA}"|cut -d":" -f1|sort -nr|head -n 1)
         if [ "${queueLine}" -lt "${accessoriesLine}" ]; then
            line=$(grep -n "${queue}" "${cmd4ConfigQueueTypesNonAA}"|cut -d":" -f1)
            line1=$((line - 1))
            line2=$((line + 2))
            sed "${line1},${line2}d" "${cmd4ConfigQueueTypesNonAA}" > "${cmd4ConfigQueueTypesNonAA}.tmp"
            mv "${cmd4ConfigQueueTypesNonAA}.tmp" "${cmd4ConfigQueueTypesNonAA}"
            line=$(head -n 1 "${cmd4ConfigQueueTypesNonAA}")
            if [ "${line}" = "" ]; then rm -f "${cmd4ConfigQueueTypesNonAA}"; fi
         fi
      done
   fi
}

function extractNonAAaccessoriesMisc()
{
   lastLine=$(wc -l "${cmd4ConfigNonAA}"|cut -d" " -f1)
   accessoriesLine=$(grep -n '"accessories":' "${cmd4ConfigNonAA}"|grep -v '     "accessories":'|cut -d":" -f1)
   grep -n ']' "${cmd4ConfigNonAA}"|grep -v '      ]'|cut -d":" -f1|while read -r endLine;
   do
      if [ "${endLine}" -gt "${accessoriesLine}" ]; then
         line1=$((accessoriesLine + 1))
         line2=$((endLine - 1))
         nLines=$((line2 - line1))
         if [ "${nLines}" -gt 0 ]; then
            sed -n "${line1},${line2}p" "${cmd4ConfigNonAA}" > "${cmd4ConfigAccessoriesNonAA}"
         fi
         # extract whatever between the end of the last accessory and the end of the file as "Misc non-AA" if any
         line1=$((endLine + 1))
         line2=$((lastLine - 1))
         nLines=$((line2 - line1))
         if [ "${nLines}" -gt 0 ]; then
            sed -n "${line1},${line2}p" "${cmd4ConfigNonAA}" > "${cmd4ConfigMiscNonAA}"
            platformLine=$(grep -n '"platform": "Cmd4"' "${cmd4ConfigMiscNonAA}"|cut -d":" -f1)
            if [ -n "${platformLine}" ]; then
               sed -i "${platformLine}d" "${cmd4ConfigMiscNonAA}" 
               validFile=$(head -n 1 "${cmd4ConfigMiscNonAA}")
               if [ -z "${validFile}" ]; then rm -f "${cmd4ConfigMiscNonAA}";fi
            fi
         fi
         break
      fi
   done
}

function extractNonAAconstantsQueueTypesAccessoriesMisc()
{
   # extract non-AA devices by removing all the AA devices in cmd4${configJson}
   extractNonAAdevices

   # extract non-AA constants                                           
   extractNonAAconstants

   # extract non-AA quueTypes
   extractNonAAqueueTypes

   # extract non-AA accessories and some misc. stuff existing in Cmd4
   extractNonAAaccessoriesMisc
}

function assembleCmd4ConfigJson()
{
   cmd4Header "${cmd4ConfigJsonAA}"
   cat "${cmd4ConfigConstantsAA}" >> "${cmd4ConfigJsonAA}"
   cmd4ConstantsQueueTypesAccessoriesMiscFooter "${cmd4ConfigJsonAA}"
   cat "${cmd4ConfigQueueTypesAA}" >> "${cmd4ConfigJsonAA}"
   cmd4ConstantsQueueTypesAccessoriesMiscFooter "${cmd4ConfigJsonAA}"
   cat "${cmd4ConfigAccessoriesAA}" >> "${cmd4ConfigJsonAA}"
   cmd4ConstantsQueueTypesAccessoriesMiscFooter "${cmd4ConfigJsonAA}"
   cmd4Footer "${cmd4ConfigJsonAA}"
}

function assembleCmd4ConfigJsonAAwithNonAA()
{
   cmd4Header "${cmd4ConfigJsonAAwithNonAA}"
   cat "${cmd4ConfigConstantsAA}" >> "${cmd4ConfigJsonAAwithNonAA}"
   if [ -f "${cmd4ConfigConstantsNonAA}" ]; then cat "${cmd4ConfigConstantsNonAA}" >> "${cmd4ConfigJsonAAwithNonAA}"; fi
   cmd4ConstantsQueueTypesAccessoriesMiscFooter "${cmd4ConfigJsonAAwithNonAA}"
   cat "${cmd4ConfigQueueTypesAA}" >> "${cmd4ConfigJsonAAwithNonAA}"
   if [ -f "${cmd4ConfigQueueTypesNonAA}" ]; then cat "${cmd4ConfigQueueTypesNonAA}" >> "${cmd4ConfigJsonAAwithNonAA}"; fi
   cmd4ConstantsQueueTypesAccessoriesMiscFooter "${cmd4ConfigJsonAAwithNonAA}"
   cat "${cmd4ConfigAccessoriesAA}" >> "${cmd4ConfigJsonAAwithNonAA}"
   if [ -f "${cmd4ConfigAccessoriesNonAA}" ]; then cat "${cmd4ConfigAccessoriesNonAA}" >> "${cmd4ConfigJsonAAwithNonAA}"; fi
   cmd4ConstantsQueueTypesAccessoriesMiscFooter "${cmd4ConfigJsonAAwithNonAA}"
   if [ -f "${cmd4ConfigMiscNonAA}" ]; then cat "${cmd4ConfigMiscNonAA}" >> "${cmd4ConfigJsonAAwithNonAA}"; fi
   cmd4Footer "${cmd4ConfigJsonAAwithNonAA}"
}

function writeToHomebridgeConfigJson()
{
   # writing the created ${cmd4ConfigJsonAA} to Homebriege Config JSON Editor
   echo ""
   echo "Now copying the created \"${cmd4ConfigJsonAA}\" to Homebridge config.json" 
   
   configJsonNew="${configJsonNew}.${t0}"

   # save the last few lines including the portion with "disabledPlugins" if presence then remove those lines + 1
   nLine=$(wc -l < "${configJson}.tmp")
   disabledPluginsLine=$(grep -n '"disabledPlugins":' "${configJson}.tmp" | cut -d":" -f1)
   if [ "${disabledPluginsLine}" = "" ]; then disabledPluginsLine=nLine; fi
   tail -n $((nLine - disabledPluginsLine + 2)) "${configJson}.tmp" > "${configJson}.tail"
   head -n $((disabledPluginsLine - 3)) "${configJson}.tmp" > "${configJsonNew}"

   # append a line
   echo "        }," >> "${configJsonNew}"

   # put 8 spaces at the beginning of the ${cmd4ConfigJsonAA} file created earlier before merging with Homebridge
   # config.json
   sed -e 's/^/        /' "${cmd4ConfigJsonAAwithNonAA}" > "${cmd4ConfigJsonAAwithNonAA}.tmp"

   # append the modified Cmd4 config.json to ${homebridgeConfigJson}    
   cat "${cmd4ConfigJsonAAwithNonAA}.tmp" >> "${configJsonNew}"

   # append the saved last few lines including the portion with "disabledPlugins" if presence
   cat "${configJson}.tail" >> "${configJsonNew}"

   # copy the new config.json to homebridge directory
   sudo cp "${configJsonNew}" "${homebridgeConfigJson}"

   # cleaning up
   rm -f "${configJson}.tmp"
   rm -f "${configJson}.tail"
   rm -f "${cmd4ConfigJsonAAwithNonAA}.tmp"
}

# main starts here

for ((n=1; n<=noOfTablets; n++)); do

   if [ "${n}" = "1" ]; then 
      ip="\${AAIP}"
      IPA=${AAIP}
      queue="AAA"
   fi
   if [ "${n}" = "2" ]; then 
      ip="\${AAIP2}"
      IPA=${AAIP2}
      queue="AAB"
   fi
   if [ "${n}" = "3" ]; then 
      ip="\${AAIP3}"
      IPA=${AAIP3}
      queue="AAC"
   fi

   if [ "${n}" = "1" ]; then
      echo "In the process of creating the Cmd4 configuration file for your AdvantageAir system(s)."
      echo "It may take up to 2 minutes...."
   fi
   echo "Fetching and processing data from your AdvantageAir system (${IPA}).... "

   myAirData=$(curl -s -g --max-time 15 --fail --connect-timeout 15 "http://${IPA}:2025/getSystemData")
   #
   if [ -z "$myAirData" ]; then
      echo ""
      echo "ERROR: either your AdvantageAir system is inacessible or your IP address ${IPA} is invalid!"
      exit 1
   fi


   if [ "${n}" = "1" ]; then 
      name=$(echo "$myAirData"|jq -e ".system.name" | sed 's/ /_/g' | sed s/[\'\"]//g)
      cmd4ConfigJsonAA="cmd4Config_AA_${name}.json"
      cmd4ConfigJsonAAwithNonAA="${cmd4ConfigJsonAA}.withNonAA"
   fi
   #
   sysType=$(echo "$myAirData" | jq -e ".system.sysType" | sed 's/ /_/g' | sed 's/\"//g')
   tspModel=$(echo "$myAirData" | jq -e ".system.tspModel" | sed 's/ /_/g' | sed 's/\"//g')

   hasAircons=$(echo "$myAirData"|jq -e ".system.hasAircons")
   hasLights=$(echo "$myAirData"|jq -e ".system.hasLights")
   hasThings=$(echo "$myAirData"|jq -e ".system.hasThings")

   # Create the ${cmd4ConfigConstantsAA}, ${cmd4ConfigQueueTypesAA} and ${cmd4ConfigAccessoriesAA}
   if [ "${n}" = "1" ] && [[ "${hasAircons}" || "${hasLights}" || "${hasThings}" ]]; then
      cmd4ConstantsHeader "${cmd4ConfigConstantsAA}"
      cmd4QueueTypesHeader "${cmd4ConfigQueueTypesAA}"
      cmd4AccessoriesHeader "${cmd4ConfigAccessoriesAA}"
   fi
   
   # Append the body of AA constants and queueTypes
   cmd4Constants "${cmd4ConfigConstantsAA}"
   cmd4QueueTypes "${cmd4ConfigQueueTypesAA}"

   # Create the $cmd4ConfigAccessories
   # Aircon systems
   if [ "$hasAircons" ]; then
      for (( a=1;a<=4;a++ )); do
         ac=$( printf "ac%1d" "$a" )
         aircon=$(echo "$myAirData" | jq -e ".aircons.${ac}.info")
         if [ "${aircon}" != "null" ]; then
            name=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.name" | sed 's/ /_/g' | sed 's/\"//g')
            cmd4Thermostat "${cmd4ConfigAccessoriesAA}" "${name}"
            cmd4FanLinkTypes "${cmd4ConfigAccessoriesAA}" "${name} FanSpeed"
            cmd4Fan "${cmd4ConfigAccessoriesAA}" "${name} Fan"
            cmd4TimerLightbulb "${cmd4ConfigAccessoriesAA}" "${name} Timer"
            #
            nZones=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.noOfZones")
            for (( b=1;b<=nZones;b++ )); do
               zoneStr=$( printf "z%02d" "$b" )
               name=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.name" | sed 's/\"//g')
               rssi=$(echo "$myAirData" | jq -e ".aircons.${ac}.zones.${zoneStr}.rssi")
               if [ "${rssi}" = "0" ]; then
                  cmd4ZoneLightbulb "${cmd4ConfigAccessoriesAA}" "$name"
               else
                  cmd4ZoneSwitch "${cmd4ConfigAccessoriesAA}" "$name"
               fi
            done
            for (( b=1;b<=nZones;b++ )); do
               zoneStr=$( printf "z%02d" "$b" )
               name=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.name" | sed 's/\"//g')
               rssi=$(echo "$myAirData" | jq -e ".aircons.${ac}.zones.${zoneStr}.rssi")
               if [ "${rssi}" != "0" ]; then
                  cmd4ZoneTempSensor "${cmd4ConfigAccessoriesAA}" "${name} Temperature"
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
            cmd4LightbulbNoDimmer "${cmd4ConfigAccessoriesAA}" "${name}"
         else
            cmd4LightbulbWithDimmer "${cmd4ConfigAccessoriesAA}" "${name}"
         fi
      done
   fi

   # Things - Garage or Gate only for now 
   if [ "$hasThings" ]; then
      echo "$myAirData" | jq -e ".myThings.things" | grep \"id\" | cut -d":" -f2 | sed s/[,]//g | while read -r id; 
      do 
         name=$(echo "$myAirData" | jq -e ".myThings.things.${id}.name" | sed s/\"//g) 
         cmd4GarageDoorOpener "${cmd4ConfigAccessoriesAA}" "${name}"
      done
   fi

done

#Now write the created ${cmd4ConfigJsonAA} to ${HomebridgeConfigJson} for RPi and Mac

t0=$(date '+%s')

cmd4ConfigJsonAA="${cmd4ConfigJsonAA}.${t0}"
assembleCmd4ConfigJson

echo ""
echo "Cmd4 configuration file has now been created successfully: ${cmd4ConfigJsonAA}"
echo ""
echo "This newly created config can be copied to Homebridge config.json automatically"
echo "The existing Cmd4 configuration pertaining to AdvantageAir system(s) will be overwritten by this new one"
echo "Do you want to proceed? (y/n)" 
read -r INPUT
if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" ]]; then
   readHomebridgeConfigJson
   if [ -n "${configJson}" ]; then
      extractCmd4ConfigFromConfigJson
      extractNonAAconstantsQueueTypesAccessoriesMisc
      assembleCmd4ConfigJsonAAwithNonAA
      writeToHomebridgeConfigJson
      echo ""
      echo "DONE! You should find the newly created \"${cmd4ConfigJsonAA}\" in Homebridge Cmd4 JASON Config Editor"
      echo "All you need to do now is to reatart Homebridge"
   else
      echo ""
      echo "ERROR: No Homebridge config.json found!"
      echo "       The created \"${cmd4ConfigJsonAA}\" cannot be copied to Homebridge config.json"
      echo "       Please copy the content of the file \"${cmd4ConfigJsonAA}\" to Homebridge Cmd4 JASON Config Editor"
   fi
else
      echo ""
      echo "All done now!  please copy the content of the file \"${cmd4ConfigJsonAA}\" to Homebridge Cmd4 JASON Config Editor"
      echo "SAVE it then reatart Homebridge"
fi
  
# Finally cleaning up
rm -f "${cmd4ConfigConstantsAA}"
rm -f "${cmd4ConfigConstantsNonAA}"
rm -f "${cmd4ConfigQueueTypesAA}"
rm -f "${cmd4ConfigQueueTypesNonAA}"
rm -f "${cmd4ConfigAccessoriesAA}"
rm -f "${cmd4ConfigAccessoriesNonAA}"
rm -f "${cmd4ConfigMiscNonAA}"
rm -f "${cmd4ConfigJsonAAwithNonAA}"
rm -f "${cmd4ConfigNonAA}"
rm -f "${cmd4ConfigJson}"

exit 0
