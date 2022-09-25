#!/bin/bash
#
# This script is to generate a complete Cmd4 configuration file needed for the cmd4-advantageair plugin
# This script can handle up to 3 independent AdvantageAir (AA) systems
#
# This script can be invoked in two ways:  
# 1. from homebridge customUI
#    a. click "SETTING" on cmd4-advantageair plugin and 
#    b. at the bottom of the SETTING page, define your AdvantageAir Device(s), then clikc SAVE
#    c. click "SETTING" again and 
#    d. check the checkbox if you want the fan to be setup as fanSwitch
#    e. click "CONFIG CREATOR" button 
#
# 2. from a terminal
#    a. find out where the bash script "ConfigCreator.sh" is installed (please see plugin wiki for details)  
#    b. run the bash script ConfigCreator.sh 
#    c. Enter the name and IP address of your AdvantageAir system(s) - up to 3 systems can be processed
#    d. you can choose whether you want the fan to be setup as fanSwitch or not
#    e. you might need to enter the path to AdvAir.sh if it is not found by the script. 
#    f. you might also need to enter the path to the Homebridge config.json file if it is not found by the script.
#      
# Once the Cmd4 configuration file is generated and copied to Homebridge config.json and if you know
# what you are doing you can do some edits on the Cmd4 configuration file in Cmd4 Config Editor
# Click SAVE when you are done.
#
# NOTE:  If you need to 'flip' the GarageDoorOpener, you have to add that in yourself.
# 
UIversion="customUI"

AAIP="$1"
AAname="$2"
AAIP2="$3"
AAname2="$4"
AAIP3="$5"
AAname3="$6"
fanSetup="$7"
ADVAIR_SH_PATH="$8"

# define the possible names for cmd4 platform
cmd4Platform=""
cmd4Platform1="\"platform\": \"Cmd4\""
cmd4Platform2="\"platform\": \"homebridge-cmd4\""

# define some other variables
name=""
hasAircons=false
hasLights=false
hasThings=false

# define some file variables
homebridgeConfigJson=""           # homebridge config.json
configJson="config.json.copy"     # a working copy of homebridge config.json
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

# fun color stuff
BOLD=$(tput bold)
TRED=$(tput setaf 1)
TGRN=$(tput setaf 2)
TYEL=$(tput setaf 3)
TPUR=$(tput setaf 5)
TLBL=$(tput setaf 6)
TNRM=$(tput sgr0)


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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
     echo "            \"state_cmd_suffix\": \"${zoneStr} ${ip}${ac_l}\""
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
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
     echo "                    \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
     echo "                    \"state_cmd_suffix\": \"${ip} fanSpeed${ac_l}\""
     echo "                }"
     echo "            ]"
     echo "        },"
   } >> "$1"
}

function cmd4myZoneSwitch()
{
   local myZoneName="$2"
   local ac_l=" ${ac}"
  
   if [ "${ac_l}" = " ac1" ]; then ac_l=""; fi

   { echo "        {"
     echo "            \"type\": \"Switch\","
     echo "            \"displayName\": \"${myZoneName}\","
     echo "            \"on\": \"FALSE\","
     echo "            \"name\": \"${myZoneName}\","
     echo "            \"manufacturer\": \"Advantage Air Australia\","
     echo "            \"model\": \"${sysType}\","
     echo "            \"serialNumber\": \"${tspModel}\","
     echo "            \"queue\": \"$queue\","
     echo "            \"polling\": ["
     echo "                {"
     echo "                    \"characteristic\": \"on\""
     echo "                }"
     echo "            ],"
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
     echo "            \"state_cmd_suffix\": \"myZone=${zone} ${ip}${ac_l}\""
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
     echo "            \"state_cmd_suffix\": \"${zoneStr} ${ip}${ac_l}\""
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
     echo "            \"state_cmd\": \"'${ADVAIR_SH_PATH}'\","
     echo "            \"state_cmd_suffix\": \"${zoneStr} ${ip}${ac_l}\""
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
   case  $UIversion in
      customUI )
         DIR=$(pwd) 
         homebridgeConfigJson="${DIR}/config.json"
         if [ -f "${homebridgeConfigJson}" ]; then
            # expand the json just in case it is in compact form
            jq --indent 4 '.' "${homebridgeConfigJson}" > "${configJson}"
            checkForPlatformCmd4InHomebridgeConfigJson
            if [ -z "${validFile}" ]; then
               echo "ERROR: no Cmd4 Config found in \"${homebridgeConfigJson}\"! Please ensure that Homebridge-Cmd4 plugin is installed"
               exit 1
            fi
         else
            echo "ERROR: no Homebridge config.json found in \"${DIR}\"! Please copy \"${cmd4ConfigJsonAA}\" to cmd4 JASON Config manually."
            cleanUp
            exit 1
         fi
      ;;
      nonUI )
         INPUT=""
         homebridgeConfigJson=""
         getHomebridgeConfigJsonPath
         if [ "${fullPath}" != "" ]; then homebridgeConfigJson="${fullPath}"; fi 
 
         # if no config.json file found, ask user to input the full path
         if [ -z "${homebridgeConfigJson}" ]; then
            homebridgeConfigJson=""
            echo ""
            echo "${TPUR}WARNING: No Homebridge config.json file located by the script!${TNRM}"
            echo ""
            until [ -n "${INPUT}" ]; do
               echo "${TYEL}Please enter the full path of your Homebridge config.json file,"
               echo "otherwise just hit enter to abort copying \"${cmd4ConfigJsonAA}\" to Homebridge config.json."
               echo "The config.json path should be in the form of /*/*/*/config.json ${TNRM}"
               read -r -p "${BOLD}> ${TNRM}" INPUT
               if [ -z "${INPUT}" ]; then
                  echo "${TPUR}WARNING: No Homebridge config.json file specified"
                  echo "         Copying of ${cmd4ConfigJsonAA} to Homebridge config.json was aborted"
                  echo ""
                  echo "${TLBL}${BOLD}INFO: Please copy/paste the ${cmd4ConfigJsonAA} into Cmd4 JASON Config Editor manually${TNRM}"
                  cleanUp
                  exit 1
               elif expr "${INPUT}" : '[./a-zA-Z0-9]*/config.json$' >/dev/null; then
                  if [ -f "${INPUT}" ]; then
                     homebridgeConfigJson="${INPUT}"
                     break
                  else
                     echo ""
                     echo "${TPUR}WARNING: No such file exits!${TNRM}"
                     echo ""
                     INPUT=""
                  fi
               else
                  echo ""
                  echo "${TPUR}WARNING: Wrong format for file path for Homebridge config.json!${TNRM}"
                  echo ""
                  INPUT=""
               fi
           done
         fi
         if [ -f "${homebridgeConfigJson}" ]; then
            if [ -z "${INPUT}" ]; then
               echo ""
               echo "${TLBL}INFO: The Homebridge config.json found: ${homebridgeConfigJson}${TNRM}"
               echo ""
            else
               echo ""
               echo "${TLBL}INFO: The Homebridge config.json specified: ${homebridgeConfigJson}${TNRM}"
               echo ""
            fi
            # expand the json just in case it is in compact form
            jq --indent 4 '.' "${homebridgeConfigJson}" > "${configJson}"
            checkForPlatformCmd4InHomebridgeConfigJson
            if [ -z "${validFile}" ]; then
               echo ""
               echo "${TRED}ERROR: no Cmd4 Config found in \"${homebridgeConfigJson}\"! Please ensure that Homebridge-Cmd4 plugin is installed${TNRM}"
               echo "${TLBL}INFO: ${cmd4ConfigJsonAA} was created but not copied to Homebridge-Cmd4 JASON Config Editor!"
               echo "      Please copy/paste the ${cmd4ConfigJsonAA} into Cmd4 JASON Config Editor manually${TNRM}"
               cleanUp
               exit 1
            fi
         fi
      ;;
   esac
}

function extractCmd4ConfigFromConfigJson()
{
   cmd4Line1=$(grep -n "${cmd4Platform}" "${configJson}" | cut -d":" -f1)
   # for the case that the cmd4 platform is at the very top 
   cmd4Line0=$(grep -n '"platforms":' "${configJson}" | cut -d":" -f1)
   cmd4Line0=$((cmd4Line0 + 1))
   grep -n '      }' "${configJson}" | grep -v '           }' | cut -d":" -f1 | while read -r line;
   do
      if [ "${line}" -gt "${cmd4Line1}" ]; then
         cmd4Line2="${line}"
         # extract those lines pertaining to cmd4
         sed -n "${cmd4Line0},${cmd4Line2}p" "${configJson}" | sed 's/^        //g' > "${cmd4ConfigJson}"
         # remove those lines pertaining to cmd4 for later use
         sed "${cmd4Line0},${cmd4Line2}d" "${configJson}" > "${configJson}.Cmd4less"
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
            platformLine=$(grep -n "${cmd4Platform}" "${cmd4ConfigMiscNonAA}"|cut -d":" -f1)
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
   # Writing the created "${cmd4ConfigJsonAAwithNonAA}" to "${configJson}.Cmd4less" to create "${configJsonNew}"
   # before copying to Homebridge config.json
   
   # Save the last few lines including the portion with "disabledPlugins" if presence then remove those lines + 1
   nLine=$(wc -l < "${configJson}.Cmd4less")
   disabledPluginsLine=$(grep -n '"disabledPlugins":' "${configJson}.Cmd4less" | cut -d":" -f1)
   if [ "${disabledPluginsLine}" = "" ]; then disabledPluginsLine=nLine; fi
   tail -n $((nLine - disabledPluginsLine + 2)) "${configJson}.Cmd4less" > "${configJson}.tail"
   head -n $((disabledPluginsLine - 3)) "${configJson}.Cmd4less" > "${configJsonNew}"

   # Append a line with a curly closing bracket and a comma, getting ready to accept next set of config  
   echo "        }," >> "${configJsonNew}"

   # Put 8 spaces at the beginning of the ${cmd4ConfigJsonAAwithNonAA} file created earlier before merging with
   # Homebridge config.json
   sed -e 's/^/        /' "${cmd4ConfigJsonAAwithNonAA}" > "${cmd4ConfigJsonAAwithNonAA}.tmp"

   # Append the modified Cmd4 config.json to "${configJsonNew}"    
   cat "${cmd4ConfigJsonAAwithNonAA}.tmp" >> "${configJsonNew}"

   # Append the saved last few lines including the portion with "disabledPlugins" if presence
   cat "${configJson}.tail" >> "${configJsonNew}"

   # Copy the "${configJsonNew}" to Homebridge config.json
   case $UIversion in 
      customUI )
         cp "${configJsonNew}" "${homebridgeConfigJson}" 
         rc=$?
      ;;
      nonUI )
         sudo cp "${configJsonNew}" "${homebridgeConfigJson}"
         rc=$?
      ;;
   esac

   # cleaning up
   rm -f "${configJson}.Cmd4less"
   rm -f "${configJson}.tail"
   rm -f "${cmd4ConfigJsonAAwithNonAA}.tmp"
}

function getGlobalNodeModulesPathForFile()
{
   file="$1"
   fullPath=""    

   for ((tryIndex = 1; tryIndex <= 6; tryIndex ++)); do
      case $tryIndex in  
         1)
            foundPath=$(find /var/lib/hoobs "${file}" 2>&1|grep -v find|grep -v System|grep -v cache|grep node_modules|grep cmd4-advantageair|grep "${file}") 
            fullPath=$(echo "${foundPath}"|head -n 1)
            if [ -f "${fullPath}" ]; then
               return
            fi
         ;;
         2)
            foundPath=$(npm root -g)
            fullPath="${foundPath}/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return    
            fi
         ;;
         3)
            fullPath="/var/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return   
            fi
         ;;
         4)
            fullPath="/usr/local/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            fi
         ;;
         5)
            fullPath="/usr/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            fi
         ;;
         6)
            fullPath="/opt/homebrew/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            fi
         ;;
      esac
   done
}

function getHomebridgeConfigJsonPath()
{
   fullPath=""

   for ((tryIndex = 1; tryIndex <= 6; tryIndex ++)); do
      case $tryIndex in
         1)
            # HOOBS has multiple bridges and hence has multiple config.json files, need to scan all config.json file for the Cmd4 plugin
            foundPath=$(find /var/lib/hoobs -name config.json 2>&1|grep -v find|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep config.json)
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
         2)
            fullPath="/var/lib/homebridge/config.json"
            if [ -f "${fullPath}" ]; then
               return
            fi
         ;;
         3)
            fullPath="$HOME/.homebridge/config.json"
            if [ -f "${fullPath}" ]; then
               return
            fi
         ;;
         4)
            foundPath=$(find /usr/local/lib -name config.json 2>&1|grep -v find|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep config.json)
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
         5)
            foundPath=$(find /usr/lib -name config.json 2>&1|grep -v find|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep config.json)
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
         6)
            foundPath=$(find /var/lib -name config.json 2>&1|grep -v find|grep -v hoobs|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep config.json)
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
      esac
   done
}

function checkForPlatformCmd4InHomebridgeConfigJson()
{
   validFile=""
   for ((tryIndex = 1; tryIndex <= 2; tryIndex ++)); do
      case $tryIndex in
         1)
            validFile=$(grep -n "${cmd4Platform1}" "${configJson}"|cut -d":" -f1)
            if [ -n "${validFile}" ]; then
               cmd4Platform="${cmd4Platform1}"
               return
            fi
         ;;
         2)
            validFile=$(grep -n "${cmd4Platform2}" "${configJson}"|cut -d":" -f1)
            if [ -n "${validFile}" ]; then
               cmd4Platform="${cmd4Platform2}"
               return
            fi
         ;;
      esac
   done
}

function checkForCmd4PlatformNameInFile()
{
   cmd4PlatformNameFound=""

   for ((Index = 1; Index <= 2; Index ++)); do
      case $Index in
         1)
            cmd4PlatformName=$(echo "${cmd4Platform1}"|cut -c13-50)
            cmd4PlatformNameFound=$(grep -n "${cmd4PlatformName}" "${fullPath}"|cut -d":" -f1)
            if [ -n "${cmd4PlatformNameFound}" ]; then
               return
            fi
         ;;
         2)
            cmd4PlatformName=$(echo "${cmd4Platform2}"|cut -c13-50)
            cmd4PlatformNameFound=$(grep -n "${cmd4PlatformName}" "${fullPath}"|cut -d":" -f1)
            if [ -n "${cmd4PlatformNameFound}" ]; then
               return
            fi
         ;;
      esac
   done
}

 
function cleanUp()
{
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
   rm -f "${configJson}"
   rm -f "${configJsonNew}"
}

# main starts here

if [ -z "${ADVAIR_SH_PATH}" ]; then UIversion="nonUI"; fi

case $UIversion in
   customUI )
      if expr "${AAIP}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
         echo ""
      else
         echo "WARNING: the specified IP address ${AAIP} is in wrong format"
         exit 1
      fi

      if [[ -n "${AAIP2}" && "${AAIP2}" != "undefined" ]]; then 
         if expr "${AAIP2}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
           echo "" 
         else
            echo "WARNING: the specified IP address ${AAIP2} is in wrong format"
            exit 1
         fi
      else
         AAIP2=""
         AAname2=""
      fi

      if [[ -n "${AAIP3}" && "${AAIP3}" != "undefined" ]]; then 
         if expr "$5" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
            echo ""
         else
            echo "WARNING: the specified IP address ${AAIP3} is in wrong format"
            exit 1
         fi
      else
         AAIP3=""
         AAname3=""
      fi
   ;;
   nonUI )
      AAIP=""
      AAIP2=""
      AAIP3=""

      until [ -n "${AAIP}" ]; do
         echo "${TYEL}Please enter the name (default: Aircon) and IP address of your AdvanatageAir system:"
         read -r -p "Name: ${TNRM}" AAname
         if [ -z "${AAname}" ]; then AAname="Aircon"; fi
         read -r -p "${TYEL}IP address (xxx.xxx.xxx.xxx): ${TNRM}" INPUT
         if expr "${INPUT}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
            AAIP="${INPUT}"
         else
            echo ""
            echo "${TPUR}WARNING: Wrong format for an IP address! Please enter again!${TNRM}"
            echo ""
         fi
      done
      until [ -n "${AAIP2}" ]; do
         echo ""
         echo "${TYEL}Please enter the name and IP address of your 2nd AdvantageAir System if any. Just hit 'enter' if none:"
         read -r -p "Name: ${TNRM}" AAname2
         if [ -z "${AAname2}" ]; then
            break
         fi
         read -r -p "${TYEL}IP address (xxx.xxx.xxx.xxx): ${TNRM}" INPUT
         if expr "${INPUT}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
            AAIP2="${INPUT}"
         else
            echo ""
            echo "${TPUR}WARNING: Wrong format for an IP address! Please enter again!${TNRM}"
            echo ""
         fi
      done
      if [ -n "${AAIP2}" ]; then
         until [ -n "${AAIP3}" ]; do
            echo ""
            echo "${TYEL}Please enter the name and IP address of your 3rd AdvantageAir System if any. Just hit 'enter' if none:"
            read -r -p "Name: ${TNRM}" AAname3
            if [ -z "${AAname3}" ]; then
               break
            fi
            read -r -p "${TYEL}IP address (xxx.xxx.xxx.xxx): ${TNRM}" INPUT
            if expr "${INPUT}" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' >/dev/null; then
               AAIP3="${INPUT}"
            else
               echo ""
               echo "${TNRM}${TPUR}WARNING: Wrong format for an IP address! Please enter again!${TNRM}"
               echo ""
            fi
         done
      fi

      echo ""
      read -r -p "${TYEL}Do you want to set up your \"Fan\" as \"FanSwitch\"? (y/n):${TNRM} " INPUT
      if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" ]]; then
         fanSetup="fanSwitch"
      else
         fanSetup="fan"
      fi
      echo ""
      echo "${TLBL}INFO: fanSetup=${fanSetup}${TNRM}"

      # get the full path to AdvAir.sh
      ADVAIR_SH_PATH=""
      getGlobalNodeModulesPathForFile "AdvAir.sh"
      if [ -n "${fullPath}" ]; then
         ADVAIR_SH_PATH=${fullPath}
         echo "${TLBL}INFO: AdvAir.sh found: ${ADVAIR_SH_PATH}${TNRM}"
      fi

      if [ -z "${ADVAIR_SH_PATH}" ]; then
         ADVAIR_SH_PATH=""
         until [ -n "${ADVAIR_SH_PATH}" ]; do
            echo ""
            echo "${TYEL}Please enter the full path of where the AdvAir.sh is installed in your system"
            echo "The file path format should be : /*/*/*/node_modules/homebridge-cmd4-advantageair/AdvAir.sh${TNRM}"
            read -r -p "${BOLD}> ${TNRM}" INPUT
            if expr "${INPUT}" : '/[a-zA-Z0-9/_]*/node_modules/homebridge-cmd4-advantageair/AdvAir.sh$' >/dev/null; then
               if [ -f "${INPUT}" ]; then
                  ADVAIR_SH_PATH=${INPUT}
                  echo ""
                  echo "${TLBL}INFO: AdvAir.sh specified: ${ADVAIR_SH_PATH}${TNRM}"
                  break
               else
                  echo ""
                  echo "${TPUR}WARNING: file ${INPUT} not found${TNRM}"
               fi
            else
               echo ""
               echo "${TPUR}WARNING: file ${INPUT} is in wrong format${TNRM}"
            fi
         done
      fi
   ;;
esac

if [ -n "${AAIP}" ]; then noOfTablets=1; fi
if [ -n "${AAIP2}" ]; then noOfTablets=2; fi
if [ -n "${AAIP3}" ]; then noOfTablets=3; fi

for ((n=1; n<=noOfTablets; n++)); do

   if [ "${n}" = "1" ]; then 
      ip="\${AAIP}"
      IPA="${AAIP}"
      nameA="${AAname}"
      queue="AAA"
   fi
   if [ "${n}" = "2" ]; then 
      ip="\${AAIP2}"
      IPA="${AAIP2}"
      nameA="${AAname2}"
      queue="AAB"
   fi
   if [ "${n}" = "3" ]; then 
      ip="\${AAIP3}"
      IPA="${AAIP3}"
      nameA="${AAname3}"
      queue="AAC"
   fi
  
   if [[ "${n}" = "1" && "${UIversion}" = "nonUI" ]]; then
      echo ""
      if [ "${noOfTablets}" = "1" ]; then echo "${TLBL}INFO: This process may take up to 1 minute!${TNRM}"; fi
      if [ "${noOfTablets}" = "2" ]; then echo "${TLBL}INFO: This process may take up to 2 minutes!${TNRM}"; fi
      if [ "${noOfTablets}" = "3" ]; then echo "${TLBL}INFO: This process may take up to 3 minutes!${TNRM}"; fi
   fi

   if [ "${UIversion}" = "nonUI" ]; then
      echo "${TLBL}INFO: Fetching and processing data from your AdvantageAir system (${nameA} ${IPA}).... ${TNRM}"
   fi

   myAirData=$(curl -s -g --max-time 45 --fail --connect-timeout 45 "http://${IPA}:2025/getSystemData")
   #
   if [ -z "$myAirData" ]; then
      echo "${TRED}ERROR: AdvantageAir system is inaccessible or your IP address ${IPA} is invalid!${TNRM}"
      exit 1
   fi


   if [ "${n}" = "1" ]; then 
      #nameA=$(echo "$myAirData"|jq -e ".system.name" | sed 's/ /_/g' | sed s/[\'\"]//g)
      cmd4ConfigJsonAA="cmd4Config_AA_${nameA}.json"
      cmd4ConfigJsonAAwithNonAA="${cmd4ConfigJsonAA}.withNonAA"
   fi
   #
   sysType=$(echo "$myAirData" | jq -e ".system.sysType" | sed 's/ /_/g' | sed 's/\"//g')
   if [ -z "${sysType}" ]; then
      echo "${TRED}ERROR: jq failed! Please make sure that jq is installed!${TNRM}"
      exit 1
   fi
   tspModel=$(echo "$myAirData" | jq -e ".system.tspModel" | sed 's/ /_/g' | sed 's/\"//g')

   hasAircons=$(echo "$myAirData"|jq -e ".system.hasAircons")
   noOfAircons=$(echo "$myAirData"|jq -e ".system.noOfAircons")
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
   if [ "$hasAircons" = true ]; then
      for (( a=1;a<=noOfAircons;a++ )); do
         ac=$( printf "ac%1d" "$a" )
         aircon=$(echo "$myAirData" | jq -e ".aircons.${ac}.info")
         if [ "${aircon}" != "null" ]; then
            if [ "${a}" -ge "2" ]; then nameA="${nameA}_${ac}"; fi
            #name=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.name" | sed 's/ /_/g' | sed 's/\"//g')
            cmd4Thermostat "${cmd4ConfigAccessoriesAA}" "${nameA}"
            cmd4FanLinkTypes "${cmd4ConfigAccessoriesAA}" "${nameA} FanSpeed"
            if [ "${fanSetup}" = "fan" ]; then
               cmd4Fan "${cmd4ConfigAccessoriesAA}" "${nameA} Fan"
            else
               cmd4FanSwitch "${cmd4ConfigAccessoriesAA}" "${nameA} Fan"
               cmd4FanLinkTypes "${cmd4ConfigAccessoriesAA}" "${nameA} FanSpeed"
            fi
            cmd4TimerLightbulb "${cmd4ConfigAccessoriesAA}" "${nameA} Timer"
            #
            nZones=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.noOfZones")
            myZoneValue=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.myZone")
            for (( b=1;b<=nZones;b++ )); do
               zoneStr=$( printf "z%02d" "$b" )
               name=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.name" | sed 's/\"//g')
               rssi=$(echo "$myAirData" | jq -e ".aircons.${ac}.zones.${zoneStr}.rssi")
               if [ "${rssi}" = "0" ]; then
                  cmd4ZoneLightbulb "${cmd4ConfigAccessoriesAA}" "$name Zone"
               else
                  cmd4ZoneSwitch "${cmd4ConfigAccessoriesAA}" "$name Zone"
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
            if [ "${myZoneValue}" != "0" ]; then
               for (( b=1;b<=nZones;b++ )); do
                  zone="${b}"
                  zoneStr=$( printf "z%02d" "${zone}" )
                  rssi=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.rssi")
                  if [ "${rssi}" != "0" ]; then
                     name=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.name" | sed 's/\"//g')
                     cmd4myZoneSwitch "${cmd4ConfigAccessoriesAA}" "myZone ${name}"
                  fi   
               done
            fi
         fi
      done      
   fi

   # Lightings
   if [ "$hasLights" = true ]; then
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
   if [ "$hasThings" = true ]; then
      echo "$myAirData" | jq -e ".myThings.things" | grep \"id\" | cut -d":" -f2 | sed s/[,]//g | while read -r id; 
      do 
         name=$(echo "$myAirData" | jq -e ".myThings.things.${id}.name" | sed s/\"//g) 
         cmd4GarageDoorOpener "${cmd4ConfigAccessoriesAA}" "${name}"
      done
   fi

done

# Now write the created ${cmd4ConfigJsonAA} to ${HomebridgeConfigJson} replacing all 
# existing AA-related configuration 

# Assemble a complete Cmd4 configuration file for the specified AA device(s)
assembleCmd4ConfigJson

# Read the existing Homebridge config.json file
readHomebridgeConfigJson

# Extract all non-AA related Cmd4 devices
extractCmd4ConfigFromConfigJson
extractNonAAconstantsQueueTypesAccessoriesMisc

# Assemble a complete Cmd4 configuration file for the specified AA devices(s) with the extracted 
# non-AA related Cmd4 devices
assembleCmd4ConfigJsonAAwithNonAA

# Write the assembled AA + non-AA Cmd4 configuration into the Homebridge config.json
writeToHomebridgeConfigJson

if [ "${rc}" = "0" ]; then
   echo "${TGRN}${BOLD}DONE! Restart Homebridge/HOOBS for the created config to take effect OR run CheckConfig prior (recommended)${TNRM}" 
   rm -f "${cmd4ConfigJsonAA}"
   cleanUp
   if [ "${UIversion}" = "nonUI" ]; then
      getGlobalNodeModulesPathForFile "CheckConfig.sh"
      check1="${fullPath}"
      echo ""
      echo "${TYEL}To run CheckConfig, please copy/paste and run the following two commands to check whether the Cmd4 configuration meets all the requirements${TNRM}"
      echo "check1=\"${check1}\""
      echo "\$check1"
   fi
else
   echo "${TRED}${BOLD}ERROR: Copying of \"${cmd4ConfigJsonAA}\" to Homebridge config.json failed!${TNRM}"
   echo "${TLBL}${BOLD}INFO: Instead you can copy/paste the content of \"${cmd4ConfigJsonAA}\" into Cmd4 JASON Config editor.${TNRM}"
   cleanUp
fi
