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
AAdebug="$3"
AAIP2="$4"
AAname2="$5"
AAdebug2="$6"
AAIP3="$7"
AAname3="$8"
AAdebug3="$9"
fanSetup="${10}"
zoneSetup="${11}"
timerSetup="${12}"
ADVAIR_SH_PATH="${13}"

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
cmd4ConfigMiscKeys="cmd4Config.json.miscKeys"
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
   local debugCmd4="false"

   if [ "${debug}" = "true" ]; then
      debugCmd4="true"
   fi

   { echo "{"
     echo "    \"platform\": \"Cmd4\","
     echo "    \"name\": \"Cmd4\","
     echo "    \"debug\": ${debugCmd4},"
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
   local debugA=""

   if [ "${debug}" = "true" ]; then
      debugA="-debug"
   fi

   { echo "        {"
     echo "            \"key\": \"${ip}\","
     echo "            \"value\": \"${IPA}${debugA}\""
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
   local suffix="$3"
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
     echo "            \"state_cmd_suffix\": \"${suffix} ${ip}${ac_l}\""
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
   noOfPlatforms=$(( $( jq ".platforms|keys" "${configJson}" | wc -w) - 2 ))
   cmd4PlatformName=$(echo "${cmd4Platform}"|cut -d'"' -f4)
   for ((i=0; i<noOfPlatforms; i++)); do
      plaftorm=$( jq ".platforms[${i}].platform" "${configJson}" )
      if [ "${plaftorm}" = "\"${cmd4PlatformName}\"" ]; then
         jq --indent 4 ".platforms[${i}]" "${configJson}" > "${cmd4ConfigJson}"
         jq --indent 4 "del(.platforms[${i}])" "${configJson}" > "${configJson}.Cmd4less"
         break
      fi
   done
}

function extractCmd4ConfigNonAAandAccessoriesNonAA()
{
   AAaccessories=""
   count=0
   presenceOfAccessories=$(jq ".accessories" "${cmd4ConfigJson}")
   if [ "${presenceOfAccessories}" != "null" ]; then
      noOfAccessories=$(( $( jq ".accessories|keys" "${cmd4ConfigJson}" | wc -w) - 2 ))
      for (( i=0; i<noOfAccessories; i++ )); do
         cmd4StateCmd=$( jq ".accessories[${i}].state_cmd" "${cmd4ConfigJson}" | grep -n "homebridge-cmd4-advantageair" )

         # save the ${i} n a string for use to delete the AA accessories from ${cmd4ConfigJson}
         if [ "${cmd4StateCmd}" != "" ]; then
            if [ "${AAaccessories}" = "" ]; then
               AAaccessories="${i}" 
            else
               AAaccessories="${AAaccessories},${i}"
            fi
         else   # create the non-AA accessories
            count=$(( count + 1 ))
            if [ "${count}" -eq 1 ]; then
               jq --indent 4 ".accessories[${i}]" "${cmd4ConfigJson}" > "${cmd4ConfigAccessoriesNonAA}"
            else
               sed '$d' "${cmd4ConfigAccessoriesNonAA}" > "${cmd4ConfigAccessoriesNonAA}.tmp"
               mv "${cmd4ConfigAccessoriesNonAA}.tmp" "${cmd4ConfigAccessoriesNonAA}"
               echo "}," >> "${cmd4ConfigAccessoriesNonAA}"
               jq --indent 4 ".accessories[${i}]" "${cmd4ConfigJson}" >> "${cmd4ConfigAccessoriesNonAA}"
            fi
         fi
      done
   fi

   # delete the AA accessories to create ${cmd4ConfigNonAA} for use later
   if [ "${AAaccessories}" = "" ]; then
      cp "${cmd4ConfigJson}" "${cmd4ConfigNonAA}"
   else
      jq --indent 4 "del(.accessories[${AAaccessories}])" "${cmd4ConfigJson}" > "${cmd4ConfigNonAA}"
   fi

   # check that there are non-AA accessories, if not, remove the file
   if [ -f "${cmd4ConfigAccessoriesNonAA}" ]; then
      validFile=$(head -n 1 "${cmd4ConfigAccessoriesNonAA}")
      if [ "${validFile}" = "" ]; then rm "${cmd4ConfigAccessoriesNonAA}"; fi
   fi
}

function extractNonAAconstants()
{
   count=0
   noOfConstans=$(( $( jq ".constants|keys" "${cmd4ConfigNonAA}" | wc -w) - 2 ))
   for ((i=0; i<noOfConstans; i++)); do
      key=$( jq ".constants[${i}].key" "${cmd4ConfigNonAA}" )
      key=${key//\"/}
      keyUsed=$(grep -n "${key}" "${cmd4ConfigAccessoriesNonAA}"|grep -v 'key'|head -n 1|cut -d":" -f1)
      if [ -n "${keyUsed}" ]; then
         count=$(( count + 1 ))
         if [ "${count}" -eq 1 ]; then
            jq --indent 4 ".constants[${i}]" "${cmd4ConfigNonAA}" > "${cmd4ConfigConstantsNonAA}"
         else
            sed '$d' "${cmd4ConfigConstantsNonAA}" > "${cmd4ConfigConstantsNonAA}.tmp"
            mv "${cmd4ConfigConstantsNonAA}.tmp" "${cmd4ConfigConstantsNonAA}"
            echo "}," >> "${cmd4ConfigConstantsNonAA}"
            jq --indent 4 ".constants[${i}]" "${cmd4ConfigNonAA}" >> "${cmd4ConfigConstantsNonAA}"
         fi
      fi
   done
   if [ -f "${cmd4ConfigConstantsNonAA}" ]; then
      validFile=$(head -n 1 "${cmd4ConfigConstantsNonAA}")
      if [ "${validFile}" = "" ]; then rm "${cmd4ConfigConstantsNonAA}"; fi
   fi
}

function extractNonAAqueueTypes()
{
   count=0
   noOfQueues=$(( $( jq ".queueTypes|keys" "${cmd4ConfigNonAA}" | wc -w) - 2 ))
   for ((i=0; i<noOfQueues; i++)); do
      queue=$( jq ".queueTypes[${i}].queue" "${cmd4ConfigNonAA}" )
      queueUsed=$(grep -n "${queue}" "${cmd4ConfigAccessoriesNonAA}"|head -n 1)
      if [ -n "${queueUsed}" ]; then
         count=$(( count + 1 ))
         if [ "${count}" -eq 1 ]; then
            jq --indent 4 ".queueTypes[${i}]" "${cmd4ConfigNonAA}" > "${cmd4ConfigQueueTypesNonAA}"
         else
            sed '$d'  "${cmd4ConfigQueueTypesNonAA}" > "${cmd4ConfigQueueTypesNonAA}.tmp"
            mv "${cmd4ConfigQueueTypesNonAA}.tmp" "${cmd4ConfigQueueTypesNonAA}"
            echo "}," >> "${cmd4ConfigQueueTypesNonAA}"
            jq --indent 4 ".queueTypes[${i}]" "${cmd4ConfigNonAA}" >> "${cmd4ConfigQueueTypesNonAA}"
         fi
      fi
   done
   if [ -f "${cmd4ConfigQueueTypesNonAA}" ]; then
      validFile=$(head -n 1 "${cmd4ConfigQueueTypesNonAA}")
      if [ "${validFile}" = "" ]; then rm "${cmd4ConfigQueueTypesNonAA}"; fi
   fi
}

function extractCmd4MiscKeys()
{
   # Extract any misc Cmd4 Keys used for non-AA accessories
   count=0
   keys=$( jq ".|keys" "${cmd4ConfigNonAA}" )
   noOfKeys=$(( $(echo "${keys}" | wc -w) - 2 ))
   for ((i=0; i<noOfKeys; i++)); do
      key=$( echo "${keys}" | jq ".[${i}]" )
      key=${key//\"/}
      if [[ "${key}" != "platform" && "${key}" != "name" && "${key}" != "debug" && "${key}" != "outputConstants" && "${key}" != "statusMsg" && "${key}" != "timeout" && "${key}" != "stateChangeResponseTime" && "${key}" != "constants" && "${key}" != "queueTypes" && "${key}" != "accessories" ]]; then
         count=$(( count + 1 ))
         miscKey=$( echo "${keys}" | jq ".[${i}]" )
         if [ "${count}" -eq 1 ]; then echo "{" >> "${cmd4ConfigMiscKeys}"; fi
         if [ "${count}" -gt 1 ]; then echo "," >> "${cmd4ConfigMiscKeys}"; fi
         echo "${miscKey}:" >> "${cmd4ConfigMiscKeys}"
         jq --indent 4 ".${miscKey}" "${cmd4ConfigNonAA}" >> "${cmd4ConfigMiscKeys}"
      fi
   done
   if [ -f "${cmd4ConfigMiscKeys}" ]; then
      validFile=$(head -n 1 "${cmd4ConfigMiscKeys}")
      if [ -z "${validFile}" ]; then
         rm -f "${cmd4ConfigMiscKeys}"
      else
         # reformat it to proper json and then remove the "{" and "}" at the begining and the end of the file
         echo "}" >> "${cmd4ConfigMiscKeys}"
         jq --indent 4 '.' "${cmd4ConfigMiscKeys}" | sed '1d;$d' > "${cmd4ConfigMiscKeys}".tmp
         mv "${cmd4ConfigMiscKeys}".tmp "${cmd4ConfigMiscKeys}"
      fi
   fi
}

function extractNonAAaccessoriesrConstantsQueueTypesMisc()
{
   # extract non-AA config and non-AA accessories from ${cmd4ConfigJson}
   extractCmd4ConfigNonAAandAccessoriesNonAA

   # extract non-AA constants and non-AA queueTypes                            
   if [ -f "${cmd4ConfigAccessoriesNonAA}" ]; then
      extractNonAAconstants
      extractNonAAqueueTypes
   fi

   # extract some misc. keys existing in Cmd4
   extractCmd4MiscKeys
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
   if [ -f "${cmd4ConfigMiscKeys}" ]; then cat "${cmd4ConfigMiscKeys}" >> "${cmd4ConfigJsonAAwithNonAA}"; fi
   cmd4Footer "${cmd4ConfigJsonAAwithNonAA}"
}

function writeToHomebridgeConfigJson()
{
   # Writing the created "${cmd4ConfigJsonAAwithNonAA}" to "${configJson}.Cmd4less" to create "${configJsonNew}"
   # before copying to Homebridge config.json

   jq --argjson cmd4Config "$(<"${cmd4ConfigJsonAAwithNonAA}")" --indent 4 '.platforms += [$cmd4Config]' "${configJson}.Cmd4less" > "${configJsonNew}"
   rc=$?
   if [ "${rc}" != "0" ]; then
      echo "${TRED}${BOLD}ERROR: Writing of created Cmd4 config to config.json.new failed!${TNRM}"
      echo "${TLBL}${BOLD}INFO: Instead you can copy/paste the content of \"${cmd4ConfigJsonAA}\" into Cmd4 JASON Config editor.${TNRM}"
      cleanUp
      exit 1
   fi

   # Copy the "${configJsonNew}" to Homebridge config.json
   case $UIversion in
      customUI )
         cp "${configJsonNew}" "${homebridgeConfigJson}"
         rc=$?
         rm -f "${homebridgeConfigJson%/*}/copyEnhancedCmd4PriorityPollingQueueJs.sh"
      ;;
      nonUI )
         sudo cp "${configJsonNew}" "${homebridgeConfigJson}"
         rc=$?
         sudo rm -f "${homebridgeConfigJson%/*}/copyEnhancedCmd4PriorityPollingQueueJs.sh"
      ;;
   esac
   if [ "${rc}" = "0" ]; then
      # copy and use the enhanced version of Cmd4PriorityPollingQueue.js if available and Cmd4 version is v7.0.0-beta2 or v7.0.1
      copyEnhancedCmd4PriorityPollingQueueJs
   fi
}

function getGlobalNodeModulesPathForFile()
{
   file="$1"
   fullPath=""    

   for ((tryIndex = 1; tryIndex <= 8; tryIndex ++)); do
      case $tryIndex in  
         1)
            foundPath=$(find /var/lib/hoobs 2>&1|grep -v find|grep -v System|grep -v cache|grep node_modules|grep cmd4-advantageair|grep "/${file}$") 
            fullPath=$(echo "${foundPath}"|head -n 1)
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         2)
            foundPath=$(npm root -g)
            fullPath="${foundPath}/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return    
            else
               fullPath=""
            fi
         ;;
         3)
            fullPath="/var/lib/homebridge/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return   
            else
               fullPath=""
            fi
         ;;
         4)
            fullPath="/var/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return   
            else
               fullPath=""
            fi
         ;;
         5)
            fullPath="/usr/local/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         6)
            fullPath="/usr/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         7)
            fullPath="/opt/homebrew/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         8)
            fullPath="/opt/homebridge/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
      esac
   done
}

function getHomebridgeConfigJsonPath()
{
   fullPath=""
   # Typicall HOOBS installation has its config.json root path same as the root path of "AdvAir.sh"
   # The typical full path to the "AdvAir.sh" script is .../hoobs/<bridge>/node_modules/homebridge-cmd4-advantageair/AdvAir.sh
   # First, determine whether this is a HOOBS installation
   Hoobs=$( echo "$ADVAIR_SH_PATH" | grep "/hoobs/" )
   if [ -n "${Hoobs}" ]; then
      fullPath="${ADVAIR_SH_PATH%/*/*/*}/config.json"
      if [ -f "${fullPath}" ]; then
         checkForCmd4PlatformNameInFile
         if [ -z "${cmd4PlatformNameFound}" ]; then
            fullPath=""
         fi
         return
      fi
   fi

   for ((tryIndex = 1; tryIndex <= 6; tryIndex ++)); do
      case $tryIndex in
         1)
            # Typical RPi, Synology NAS installations have this path to config.json
            fullPath="/var/lib/homebridge/config.json"
            if [ -f "${fullPath}" ]; then
               checkForCmd4PlatformNameInFile
               if [ -n "${cmd4PlatformNameFound}" ]; then
                  return
               else
                  fullPath=""
               fi
            fi
         ;;
         2)
            # Typical Mac installation has this path to config.json
            fullPath="$HOME/.homebridge/config.json"
            if [ -f "${fullPath}" ]; then
               checkForCmd4PlatformNameInFile
               if [ -n "${cmd4PlatformNameFound}" ]; then
                  return
               else
                  fullPath=""
               fi
            fi
         ;;
         3)
            foundPath=$(find /usr/local/lib 2>&1|grep -v find|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
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
         4)
            foundPath=$(find /usr/lib 2>&1|grep -v find|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
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
            foundPath=$(find /var/lib 2>&1|grep -v find|grep -v hoobs|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
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
            foundPath=$(find /opt 2>&1|grep -v find|grep -v hoobs|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
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
            cmd4PlatformName=$(echo "${cmd4Platform1}"|cut -d'"' -f4)
            cmd4PlatformNameFound=$(grep -n "\"${cmd4PlatformName}\"" "${fullPath}"|cut -d":" -f1)
            if [ -n "${cmd4PlatformNameFound}" ]; then
               return
            fi
         ;;
         2)
            cmd4PlatformName=$(echo "${cmd4Platform2}"|cut -d'"' -f4)
            cmd4PlatformNameFound=$(grep -n "\"${cmd4PlatformName}\"" "${fullPath}"|cut -d":" -f1)
            if [ -n "${cmd4PlatformNameFound}" ]; then
               return
            fi
         ;;
      esac
   done
}

function copyEnhancedCmd4PriorityPollingQueueJs()
{
   # if the enhanced version of "Cmd4PriorityPollingQueue.txt" is present and Cmd4 version is v7.0.0-beta2 or v7.0.1, 
   # then use this enhanced verison.
   getGlobalNodeModulesPathForFile "Cmd4PriorityPollingQueue.txt"
   if [ -n "${fullPath}" ]; then
      fullPath_txt="${fullPath}"
      fullPath_package="${fullPath%/*/*}/homebridge-cmd4/package.json"
      # check the Cmd4 version
      Cmd4_version="$(jq '.version' "${fullPath_package}")"
      if expr "${Cmd4_version}" : '"7.0.[0-1][-a-z0-9]*"' >/dev/null; then
         fullPath_js="${fullPath%/*/*}/homebridge-cmd4/Cmd4PriorityPollingQueue.js"
         sudo cp "${fullPath_txt}" "${fullPath_js}"
         rc1=$?
         if [ "${rc1}" = "0" ]; then
            echo "${TLBL}INFO: An enhanced version of ${BOLD}\"Cmd4PriorityPollingQueue.js\"${TNRM}${TLBL} was located and copied to Cmd4 plugin.${TNRM}"
            echo ""
         else
            { echo "#!/bin/bash" 
              echo ""
              echo "sudo cp ${fullPath_txt} ${fullPath_js}"
              echo "exit 0"
            } > "copyEnhancedCmd4PriorityPollingQueueJs.sh"
            chmod +x "copyEnhancedCmd4PriorityPollingQueueJs.sh"
         fi
      fi
  fi
}
 
function cleanUp()
{
   # cleaning up
   rm -f "${configJson}"
   rm -f "${configJson}.Cmd4less"
   rm -f "${cmd4ConfigJson}"
   rm -f "${cmd4ConfigConstantsAA}"
   rm -f "${cmd4ConfigQueueTypesAA}"
   rm -f "${cmd4ConfigAccessoriesAA}"
   rm -f "${cmd4ConfigNonAA}"
   rm -f "${cmd4ConfigConstantsNonAA}"
   rm -f "${cmd4ConfigQueueTypesNonAA}"
   rm -f "${cmd4ConfigAccessoriesNonAA}"
   rm -f "${cmd4ConfigMiscKeys}"
   rm -f "${cmd4ConfigJsonAAwithNonAA}"
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
            AAdebug="false"
            read -r -p "${TYEL}Enable debug? (y/n, default=n): ${TNRM}" INPUT
            if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" || "${INPUT}" = "true" ]]; then AAdebug="true"; fi
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
            AAdebug2="false"
            read -r -p "${TYEL}Enable debug? (y/n, default=n): ${TNRM}" INPUT
            if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" || "${INPUT}" = "true" ]]; then AAdebug2="true"; fi
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
               AAdebug3="false"
               read -r -p "${TYEL}Enable debug? (y/n, default=n): ${TNRM}" INPUT
               if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" || "${INPUT}" = "true" ]]; then AAdebug3="true"; fi
            else
               echo ""
               echo "${TNRM}${TPUR}WARNING: Wrong format for an IP address! Please enter again!${TNRM}"
               echo ""
            fi
         done
      fi

      echo ""
      read -r -p "${TYEL}Set up your \"Fan\" as \"FanSwitch\"? (y/n, default=n):${TNRM} " INPUT
      if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" ]]; then
         fanSetup="fanSwitch"
      else
         fanSetup="fan"
      fi

      read -r -p "${TYEL}Set up your Zone Control using \"Lightbulb\" as proxy? (y/n, default=n):${TNRM} " INPUT
      if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" ]]; then
         zoneSetup="Lightbulb"
      else
         zoneSetup="Switch"
      fi

      read -r -p "${TYEL}Include extra fancy timers to turn-on the Aircon in specific mode: Cool, Heat or Vent? (y/n, default=n):${TNRM} " INPUT
      if [[ "${INPUT}" = "y" || "${INPUT}" = "Y" ]]; then
         timerSetup="includeFancyTimers"
      else
         timerSetup="noFancyTimers"
      fi
      echo ""
      echo "${TLBL}INFO: fanSetup=${fanSetup}${TNRM}"
      echo "${TLBL}INFO: zoneSetup=${zoneSetup}${TNRM}"
      echo "${TLBL}INFO: timerSetup=${timerSetup}${TNRM}"
      echo ""

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
      debug="${AAdebug}"
      queue="AAA"
   fi
   if [ "${n}" = "2" ]; then 
      ip="\${AAIP2}"
      IPA="${AAIP2}"
      nameA="${AAname2}"
      debug="${AAdebug2}"
      queue="AAB"
   fi
   if [ "${n}" = "3" ]; then 
      ip="\${AAIP3}"
      IPA="${AAIP3}"
      nameA="${AAname3}"
      debug="${AAdebug3}"
      queue="AAC"
   fi
  
   if [[ "${n}" = "1" && "${UIversion}" = "nonUI" ]]; then
      echo ""
      if [ "${noOfTablets}" = "1" ]; then echo "${TLBL}${BOLD}INFO: This process may take up to 1 minute!${TNRM}"; fi
      if [ "${noOfTablets}" = "2" ]; then echo "${TLBL}${BOLD}INFO: This process may take up to 2 minutes!${TNRM}"; fi
      if [ "${noOfTablets}" = "3" ]; then echo "${TLBL}${BOLD}INFO: This process may take up to 3 minutes!${TNRM}"; fi
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
            cmd4TimerLightbulb "${cmd4ConfigAccessoriesAA}" "${nameA} Timer" "timer"
            if [ "${timerSetup}" = "includeFancyTimers" ]; then
               cmd4TimerLightbulb "${cmd4ConfigAccessoriesAA}" "${nameA} Fan Timer" "fanTimer"
               cmd4TimerLightbulb "${cmd4ConfigAccessoriesAA}" "${nameA} Cool Timer" "coolTimer"
               cmd4TimerLightbulb "${cmd4ConfigAccessoriesAA}" "${nameA} Heat Timer" "heatTimer"
            fi
            #
            nZones=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.noOfZones")
            myZoneValue=$(echo "$myAirData" | jq -e ".aircons.${ac}.info.myZone")
            for (( b=1;b<=nZones;b++ )); do
               zoneStr=$( printf "z%02d" "$b" )
               name=$(echo "$myAirData" |jq -e ".aircons.${ac}.zones.${zoneStr}.name" | sed 's/\"//g')
               rssi=$(echo "$myAirData" | jq -e ".aircons.${ac}.zones.${zoneStr}.rssi")
               if [ "${rssi}" = "0" ]; then
                  cmd4ZoneLightbulb "${cmd4ConfigAccessoriesAA}" "$name Zone"
               elif [ "${zoneSetup}" = "Lightbulb" ]; then
                  cmd4ZoneLightbulb "${cmd4ConfigAccessoriesAA}" "$name Zone-T"
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
extractNonAAaccessoriesrConstantsQueueTypesMisc

# Assemble a complete Cmd4 configuration file for the specified AA devices(s) with the extracted 
# non-AA related Cmd4 devices
assembleCmd4ConfigJsonAAwithNonAA

# Write the assembled AA + non-AA Cmd4 configuration into the Homebridge config.json
writeToHomebridgeConfigJson

if [ "${rc}" = "0" ]; then
   echo "${TGRN}${BOLD}DONE! Restart Homebridge/HOOBS for the created config to take effect OR run CheckConfig prior (recommended)${TNRM}" 
   rm -f "${cmd4ConfigJsonAA}"
   if [ "${UIversion}" = "nonUI" ]; then
      echo ""
      echo "${TYEL}To run CheckConfig, please copy/paste and run the following command to check whether the Cmd4 configuration meets all the requirements${TNRM}"
      echo "${ADVAIR_SH_PATH%/*}/CheckConfig.sh"
   fi
else
   # Copying of the new config.json to homebridge config.json failed so restore the homebridge config.json from backup
   if [ "${UIversion}" = "nonUI" ]; then
     sudo cp "${configJson}" "${homebridgeConfigJson}"
   else
     cp "${configJson}" "${homebridgeConfigJson}"
   fi
   echo "${TRED}${BOLD}ERROR: Copying of \"${cmd4ConfigJsonAA}\" to Homebridge config.json failed! Original config.json restored.${TNRM}"
   echo "${TLBL}${BOLD}INFO: Instead you can copy/paste the content of \"${cmd4ConfigJsonAA}\" into Cmd4 JASON Config editor.${TNRM}"
fi

cleanUp
exit 0
