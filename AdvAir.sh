#!/bin/bash

######################################################################################################################################################################
######################################################################################################################################################################
#                                                                                                                                                                    #
# A massive thank you to John Talbot of homebridge-cmd4 for all his work on improving this shell script and the improvements to homebridge-cmd4 to cater further to  #
# the Advantage Air controller and all of it's Homebridge users!                                                                                                     #
#                                                                                                                                                                    #
# A massive thanks also to @uswong for his ideas and contributions to adding 'rotationSpeed' to the Fan accessory and a "linkedType" 'Fan Speed' to the Thermostat   #
# accessory for speed control (low/medium/high/auto). I am very pleased with the work and I think a lot of users will be too!                                        #
#                                                                                                                                                                    #
######################################################################################################################################################################
######################################################################################################################################################################

# Lets be explicit
typeset -i a argSTART argEND

#
# Passed in required Args
#
argEND=$#
IP=""
PORT="2025"
device=""
io=""
characteristic=""
value="1"

#
# Global returned data
#
myAirData=""
jqResult=""
rc=1
declare -a idArray_g

#
# For optional args and arg parsing
#

# Default zone
zone=""
zoneSpecified=false
fanSpecified=false
argSTART=4
logErrors=true
noSensors=true
fanSpeed=false
fspeed="low"

# By default selfTest is off
selfTest="TEST_OFF"

# Define the aircon system "ac1", "ac2", etc,  default to "ac1" if not explicitly specified
ac="ac1"


# Define some variables for zone open checking
zoneOpen=0

# For timer capability
timerEnabled=false

# For flip capability for things' open/close, up/down mode
flipEnabled=false

#for lights and things (like garage, etc) controls
lightSpecified=false
thingSpecified=false

#Temporary files
QUERY_AIRCON_LOG_FILE="/tmp/queryCachedAirCon_calls.log"
QUERY_IDBYNAME_LOG_FILE="/tmp/queryIdByName.log"
MY_AIRDATA_FILE="/tmp/myAirData.txt"
MY_AIR_CONSTANTS_FILE="/tmp/myAirConstants.txt"
ZONEOPEN_FILE="/tmp/zoneOpen.txt"

function showHelp()
{
   local rc="$1"
   cat <<'   HELP_EOF'
   Usage:
     AdvAir.sh Get < AccessoryName > < characteristic > [ Options ]
   or
     AdvAir.sh Set < AccessoryName > < characteristic > < value > [ Options ]
   Where Options maybe any of the following in any order:
     z01, z02, z03 ...  The zone to Set or Query
     XXX.XXX.XXX.XXX    The IP address of the AirCon to talk to
     fanSpeed           If the accessory is used to control the fan speed
     timer              To use a Lightbulb accessory as a timer
   Additional test options to the above are:
     TEST_OFF           The default
     TEST_ON            For npm run test
     TEST_CMD4          In ones config.json and dev test data must be available.
   HELP_EOF
   exit "$rc"
}
function logError()
{
   if [ "$logErrors" != true ]; then
      return
   fi
   local comment="$1"
   local rc="$2"
   local result="$3"
   local data1="$4"
   local data2="$5"
   local dt
   dt=$(date +%s)
   local fileName="/tmp/AirconError-$dt.txt"
   { echo "$io $device $characteristic"
     echo "${comment}"
     echo "return code: $rc"
     echo "result: $result"
     echo "data1: $data1"
     echo "data2: $data2"
   } > "$fileName"
}
function getFileStatDtFsize()
{
   local fileName="$1"
   # This script is to determine the creatine time of a file using 'stat' command and calculate the age of the file in seconds
   # and also get the file size in bytes
   # 'stat' command has different parameters in MacOS
   # The return variables of this script: t0 = last changed time of the file since Epoch
   #                                      t1 = current time in since Epoch
   #                                      dt = the age of the file in seconds since last changed
   #                                      fSize = the size of the file in bytes
   case "$OSTYPE" in
      darwin*)
         t0=$( stat -r "$fileName" | awk '{print $11}' )  # for Mac users
      ;;
      *)
         t0=$( stat -c %Z "$fileName" )
      ;;
   esac
   t1=$(date '+%s')
   dt=$((t1 - t0))
   fSize=$(find "$fileName" -ls | awk '{print $7}')
}

# NOTE: ONLY queryAirConWithIteration CALLS THIS !!!
function queryCachedAirCon()
{
   local url="$1"
   local exitOnFail="$2"
   local forceFetch="$3"

   local lockFile="${MY_AIRDATA_FILE}.lock"
   local dateFile="${MY_AIRDATA_FILE}.date"

   t0=$(date '+%s')
   echo "queryCachedAirCon_calls $t0 $io $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"

   # If the lock file is there, then return as Iteration will handle this
   if [ -f "$lockFile" ]; then
      rc=1
      return
   fi

   # The dateFile is only valid if there is an MY_AIRDATA_FILE
   local useFileCache=false
   local doFetch=false
   local dt=0

   # The dateFile and MY_AIRDATA_FILE must exit together to check
   # for a valid date stamp
   if [[ -f "$dateFile" && -f "$MY_AIRDATA_FILE" ]]; then
      tf=$(cat "$dateFile")
      dt=$(( t0 - tf ))
      if [ "$dt" -gt 90 ]; then
         useFileCache=false
      else
         useFileCache=true
      fi
echo "queryCachedAirCon_calls tf:$tf t0:$t0 dt:$dt useFileCache:$useFileCache" >> "$QUERY_AIRCON_LOG_FILE"
   fi

   if [ "$forceFetch" = true ] || [ "$useFileCache" = false ]; then
      doFetch=true
   fi

   echo "queryCachedAirCon_calls doFetch:$doFetch useFileCache:$useFileCache forceFetch:$forceFetch" >> "$QUERY_AIRCON_LOG_FILE"
   if [ "$doFetch" = true ]; then
      touch "$lockFile"

      # Remove the old dataFile when fetching
      if [ -f "$dateFile" ]; then
         rm "$dateFile"
      fi
      # Remove the old MY_AIRDATA_FILE when fetching
      if [ -f "$MY_AIRDATA_FILE" ]; then
         rm "$MY_AIRDATA_FILE"
      fi
      # fetch is true so get our My_AIRDATA_FILE by $url

      echo "queryCachedAirCon_curl1 $t0 $doFetch $dt $io $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"
      myAirData=$( curl -s -g "$url")
      rc=$?
      if [ "$rc" = "0" ]; then
         #Need to parse for good size
         parseMyAirDataWithJq ".aircons.$ac.info"
         if [ "$rc" = "0" ]; then
           echo "$t0" > "$dateFile"
           # Only create the MY_AIRDATA_FILE if it is valid
           echo "$myAirData" > "$MY_AIRDATA_FILE"
         else
           # just in case
           unset myAirData
         fi
      fi
      rm "$lockFile"
   else # doFetch = false
      myAirData=$( cat "$MY_AIRDATA_FILE" )
      rc=0
   fi

# echo " zarf queryCachedAirCon resd MY_AIRDATA_FILE rc: $rc"


   # Delete the log if it is > 15 MB
   # du is POSIX portable, but gives size in kbytes
   # fSize=$(du "$QUERY_AIRCON_LOG_FILE" | cut -f1)
   # fSize=$(ls -l "$QUERY_AIRCON_LOG_FILE" | awk '{print $5}')
   fSize=$(find "$QUERY_AIRCON_LOG_FILE" -ls | awk '{print $7}')
   if [ "$fSize" -gt 15728640 ];then
      rm "$QUERY_AIRCON_LOG_FILE"
   fi

   if [ "$rc" != "0" ]; then
      if [ "$exitOnFail" = "1" ]; then
         # The result cannot be trusted with a bad return code
         # Do not output to stderr as this defeats the purpose
         # of squashing error messages
         logError "getValue_curl failed" "$rc" "$device" "$characteristic" "$url"
         exit $rc
      fi
   fi
}

function setAirConUsingIteration()
{
   local url="$1"
   local keepDel="$2"
   # if $keepDel = "" or <= "1", delete the $MY_AIRDATA_FILE after the 'curl' command.
   # $keepDel >=2 means there is/are more set command(s) coming after this one, $MY_AIRDATA_FILE will be kept for now

   # This script is purely used to 'Set' the AA system
   # The $MY_AIRDATA_FILE cache file will be deleted after the 'Set' command is completed
   # However, if there is a series of 'Set' commands, only delete the $MY_AIRDATA_FILE after the last 'Set' command
   # This is to cater for the situation where one light accessory can be asscicated with 2 physical lights or more

   if [ "$selfTest" = "TEST_ON" ]; then
      # For Testing, you can compare whats sent
      echo "Setting url: $url";
   fi

   # Try 5 times, the last returning the error found.
   for i in 0 1 2 3 4
   do
      if [ "$selfTest" = "TEST_ON" ]; then
         echo "Try $i"
      fi
      local exitOnFail="0"
      if [ "$i" = "4" ]; then
         exitOnFail="1"
      fi

      t2=$(date '+%s')
      curl --fail -s -g "$url"
      rc=$?
      echo "setAirCon_curl rc:$rc t2:$t2 io:$io keepDel:$keepDel device:$device characteristic:$characteristic url:$url" >> "$QUERY_AIRCON_LOG_FILE"


      # keepDel is not needed if after finishing sets a new Get of systemData is done
      # if [ "$keepDel" = "" ] || [ "$keepDel" -le "1" ]; then
      #    if [ -f "$MY_AIRDATA_FILE" ]; then rm "$MY_AIRDATA_FILE"; fi
      # fi

      if [ "$rc" == "0" ]; then
         return
      fi

      if [ "$exitOnFail" = "1" ]; then
         # The result cannot be trusted with a bad return code
         # Do not output to stderr as this defeats the purpose
         # of squashing error messages
         logError "curl failed" "$rc" "$io" "$keepDel" "$url"
         exit $rc
      fi
   done
}

function parseMyAirDataWithJq()
{
   local jqPath="$1"
   local exitOnFail="$2"
   # Understanding jq options
   # -e                  (Upon bad data, exit with return code )
   # Updates global variable jqResult
   jqResult=$( echo "$myAirData" | jq -e "$jqPath" )
   rc=$?
   if [ "$rc" = "1" ] && [ "$jqResult" = false ]; then   # "false" is an acceptable answer
      rc=0
   fi
   if [ "$rc" != "0" ]; then
      if [ "$exitOnFail" = "1" ]; then
         # The result cannot be trusted with a bad return code
         # Do not output to stderr as this defeats the purpose
         # of squashing error messages
         logError "jq failed" "$rc" "$jqResult" "$io $device $characteristic" "$jqPath"
         echo "parseMyAirDataWithJQ failed rc=$rc jqResult=$jqResult $io $device $characteristic $jqPath" >> "$QUERY_AIRCON_LOG_FILE"
         exit $rc
      fi
   fi
   if [ "$selfTest" = "TEST_ON" ]; then
      # For Testing, you can compare whats sent
      echo "Parsing for jqPath: $jqPath";
   fi

}

function  queryAirConWithIterations()
{
   local url="$1"
   local forceFetch="$2"

   # Try 5 times, the last returning the error found.
   for i in 0 1 2 3 4
   do
      if [ "$selfTest" = "TEST_ON" ]; then
         echo "Try $i"
      fi
      local exitOnFail="0"
      if [ "$i" = "4" ]; then
         exitOnFail="1"
      fi
      # Updates global variable myAirData
      queryCachedAirCon "$url" "$exitOnFail" "$forceFetch"
      if [ "$rc" = "0" ]; then
         break
      else
         sleep 1.2
      fi
   done
}

function createMyAirConstantsFile()
{
   # Create a system-wide $MY_AIRDATA_CONSTANTS_FILE cache file if not present
   # Only call this function after a queryAirConWithIterations call
   # get the number of zones
   parseMyAirDataWithJq ".aircons.$ac.info.noOfZones"
   nZones=$jqResult
   # Check if any zones have "rssi" value != 0  if so, set noSensors=false
   for (( a=1;a<=nZones;a++ ))
   do
      zoneStr=$( printf "z%02d" "$a" )
      parseMyAirDataWithJq ".aircons.$ac.zones.$zoneStr.rssi"
      if [ "$jqResult" != 0 ]; then
         noSensors=false
         break
      fi
   done
   # parse the first constant zone from myAirData
   parseMyAirDataWithJq ".aircons.$ac.info.constant1"
   cZone=$( printf "z%02d" "$jqResult" )
   echo "$noSensors $cZone $nZones" > "$MY_AIR_CONSTANTS_FILE"
}

function queryIdByName()
{
   local path="$1"
   local name="$2"

   # This script is to extract the ID(s) of a light by its name or a thing (garage, blinds, etc) by its name
   # A name may be associated with 2 or more physcial lights/things hence 2 or more IDs`
   # A name can contain up to 4 words separated by space(s) but AA system has a limit of 12 characters including the space
   # The recommendation for a light/thing's name is to try not to use space as word separator to avoid any ambiguity:
   #     e.g. Two lights with names "Bath 2 DL", "Bath 2 Ex DL" will have ambiguity issue. When scanning for "Bath 2 DL",
   #     the IDs for both lights will be extracted because both lights contain the words "Bath", "2" and "DL".
   #     To resolve this kind of ambiguity, use underscore instead of space as word separator. When underscore is used instead
   #     space, multi-words name will become a single word name. In this example, the two light names will become "Bath_2_DL",
   #     "Bath_2_Ex_DL" and they will have no ambiguity issue.
   # If the name contains 4 words separated by a space, then it needs to be separated for ID scanning purposes.

   local name1 name2 name3 name4
   local ids=""

   name1=$(echo "$name"|cut -d" " -f1)
   name2=$(echo "$name"|cut -d" " -f2)
   name3=$(echo "$name"|cut -d" " -f3)
   name4=$(echo "$name"|cut -d" " -f4)

   # Obtain the unique ID by its name from a MY_AIRDATA_FILE, Which is updated every "Set" or after 2 minutes of every "Get"

   # Scan for the unique IDs of lights or things by their names using jq command.
   # Each name might be associated with more than 1 light/thing hence can have more than 1 ID. As such the ID(s) is/are output to an array "$idArray_g"
   if [ "$path" = "light" ]; then
      ids=$( echo "${myAirData}" | jq -e ".myLights.lights[]|select(.name|test(\"$name1\"))|select(.name|test(\"$name2\"))|select(.name|test(\"$name3\"))|select(.name|test(\"$name4\"))|.id" )
      rc=$?
   elif [ "$path" = "thing" ]; then
      ids=$( echo "${myAirData}" | jq -e ".myThings.things[]|select(.name|test(\"$name1\"))|select(.name|test(\"$name2\"))|select(.name|test(\"$name3\"))|select(.name|test(\"$name4\"))|.id" )
      rc=$?
   else
      rc=5
   fi

   if [ "$ids" != "" ];then
      eval "idArray_g=($ids)"
   fi

   # for diagnostic purpuses
   t6=$(date '+%s')
   echo "queryIdByName_jq $t6 ${io} rc=$rc path=$path $characteristic id=${ids} name=$name" >> "$QUERY_IDBYNAME_LOG_FILE"
   # Delete the log if it is > 15 MB
   fSize=$(find "$QUERY_IDBYNAME_LOG_FILE" -ls | awk '{print $7}')
   if [ "$fSize" -gt 15728640 ];then
      rm "$QUERY_IDBYNAME_LOG_FILE"
   fi

   if [ "$rc" != "0" ]; then
      # The result cannot be trusted with a bad return code
      # Output to stderr only after 5 tries
      logError "queryIdByName_jq failed" "$rc" "id=${ids}" "${path}" "$name"
      echo "queryIdByName_jq_failed $t6 ${io}${i} rc=$rc path=$path $characteristic id=${ids} name=$name" >> "$QUERY_IDBYNAME_LOG_FILE"
      exit $rc
   fi
}

# main starts here
if [ $argEND -le 1 ]; then
   showHelp 199
fi
if [ $argEND -ge 1 ]; then
   io=$1
   if [ $argEND -ge 2 ]; then
      device=$2
   else
      echo "Error - No device given for io: ${io}"
      exit 1
   fi
   if [ $argEND -ge 3 ]; then
      characteristic=$3
   else
      echo "Error - No Characteristic given for io: ${io} ${device}"
      exit 1
   fi
   if [ "$io" = "Get" ]; then
      argSTART=4
   elif [[ "$io" == "Set" ]]; then
      argSTART=5
      if [ $argEND -ge 4 ]; then
         value=$4
      else
         echo "Error - No value given to Set: ${io}"
         exit 1
      fi
   else
      echo "Error - Invalid io: ${io}"
      exit 1
   fi
fi
# For any unprocessed arguments
if [ $argEND -ge $argSTART ]; then
   # Scan the remaining options
   for (( a=argSTART;a<=argEND;a++ ))
   do
      # convert argument number to its value
      v=${!a}
      optionUnderstood=false
      # Check the actual option against patterns
      case ${v} in
         TEST_OFF)
            # Standard production usage
            selfTest=${v}
            optionUnderstood=true
            # Note: Only bash 4.0 has fallthrough and it's not portable.
            ;;
         TEST_ON)
            # For npm run test
            selfTest=${v}
            # PORT="3025"
            PORT="2025"
            optionUnderstood=true
            ;;
         TEST_CMD4)
            # With Cmd4, but using test data. Causes no echo on try
            selfTest=${v}
            optionUnderstood=true
            ;;
         fanSpeed)
            # If the accessory is used to control the fan speed
            fanSpeed=true
            optionUnderstood=true
            ;;
         timer)
            # For timer capability
            timerEnabled=true
            optionUnderstood=true
            ;;
         flip)
            # To flip open/close, up/down mode for garage or gate
            flipEnabled=true
            optionUnderstood=true
            ;;
         ac1)
            # Specify the aircon system 1, if not defined, ac="ac1"
            ac="ac1"
            optionUnderstood=true
            ;;
         ac2)
            # Specify the aircon system 2, if not defined, ac="ac1"
            ac="ac2"
            optionUnderstood=true
            ;;
         ac3)
            # Specify the aircon system 3, if not defined, ac="ac1"
            ac="ac3"
            optionUnderstood=true
            ;;
         ac4)
            # Specify the aircon system 4, if not defined, ac="ac1"
            ac="ac4"
            optionUnderstood=true
            ;;
         ac5)
            # Specify the aircon system 5, if not defined, ac="ac1"
            ac="ac5"
            optionUnderstood=true
            ;;
         *)
            #
            # See if the option starts with a 'z' for zone
            #
            first="$(printf '%s' "$v" | cut -c1 )"
            if [ "$first" = z ]; then
               zone=${v}
               zoneSpecified=true
               optionUnderstood=true
            fi
            #
            # See if the option starts with a "light" for lightings
            #
            first5=${v:0:5}
            if [ "$first5" = light ]; then
               length=$((${#v} - 6))
               lightName="${v:6:$length}"
               lightSpecified=true
               optionUnderstood=true
            fi
            #
            # See if the option starts with a "thing" for garage, blinds, etc
            #
            if [ "$first5" = thing ]; then
               length=$((${#v} - 6))
               thingName="${v:6:$length}"
               thingSpecified=true
               optionUnderstood=true
            fi
            #
            # See if the option is in the format of an IP
            #
            if expr "$v" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
               IP="$v"
               if [ "$selfTest" = "TEST_ON" ]; then
                  echo "Using IP: $v"
               fi
               optionUnderstood=true
            fi
            if [ "$optionUnderstood" = false ]; then
               echo "Unknown Option: ${v}"
               showHelp 1
            fi
      esac
   done
fi
# Fan accessory is the only accessory without identification constant, hence give it an identification "fanSpecified"
if [ $zoneSpecified = false ] && [ $fanSpeed = false ] && [ $timerEnabled = false ] && [ $lightSpecified = false ] && [ $thingSpecified = false ]; then
   fanSpecified=true
fi
# For "Get" Directives
if [ "$io" = "Get" ]; then

   # Get the systemData, but not forceably
   queryAirConWithIterations "http://$IP:2025/getSystemData" false

   # Create a system-wide $MY_AIRDATA_CONSTANTS_FILE cache file if not present␣
   if [ ! -f "$MY_AIR_CONSTANTS_FILE" ]; then createMyAirConstantsFile; fi

   case "$characteristic" in
      # Gets the current temperature.
      CurrentTemperature )
         # check whether Temperature Sensors are used in this system and also check the constant zone for this system

         # Read the system-wide constants from $MY_AIR_CONSTANTS_FILE cache file
         myAirConstants=$( cat "$MY_AIR_CONSTANTS_FILE" )
         noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
         cZone=$( echo "$myAirConstants" | awk '{print $2}' )

         if [ "$noSensors" = false ] && [ $zoneSpecified = false ]; then
            # Use constant zone for Thermostat temperature reading
            parseMyAirDataWithJq ".aircons.$ac.zones.$cZone.measuredTemp"
         elif [ $zoneSpecified = true ]; then
            # Use zone for Temperature Sensor temp reading
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.measuredTemp"
         elif [ "$noSensors" = true ]; then
            # Uses the set temperature as the measured temperature in lieu of having sensors.
            parseMyAirDataWithJq ".aircons.$ac.info.setTemp"
         fi
         echo "$jqResult"
         exit 0
      ;;
      # Gets the target temperature.
      TargetTemperature )
         # Updates global variable jqResult
         parseMyAirDataWithJq ".aircons.$ac.info.setTemp"
         echo "$jqResult"
         exit 0
      ;;
      # Makes the target Control Unit state the current Control Unit state.
      TargetHeatingCoolingState | CurrentHeatingCoolingState )
         # Set to Off if the zone is closed or the Control Unit is Off.
         # Updates global variable jqResult
         # parseMyAirDataWithJq ".aircons.$ac.info.state"
         if [  "$jqResult" = '"off"' ]; then
            echo 0
            exit 0
         else
            # Get the current mode of the Control Unit. Off=0, Heat=1, Cool=2.
            # Updates global variable jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.mode"
            mode="$jqResult"
            case "$mode" in
               '"heat"' )
                  # Thermostat in Heat Mode.
                  echo 1
                  exit 0
               ;;
               '"cool"' )
                  # Thermostat in Cool Mode.
                 echo 2
                 exit 0
               ;;
               '"vent"' )
                  # Fan mode, set Thermostat to Off and Fan to On.
                  echo 0
                  exit 0
               ;;
               '"dry"' )
                  # No support for a dry mode by Apple, set to Off.
                  echo 0
                  exit 0
               ;;
               * )
                  # If anything unexpected is retruned than the above, return value Off.
                  echo 0
                  exit 0
               ;;
            esac
         fi
      ;;
      # for garage door opener: get the value from MyPlace (100=open, 0=close) (in Homekit 0=open, 1=close)
      TargetDoorState | CurrentDoorState )
         if [ $thingSpecified = true ]; then
            queryIdByName "thing" "$thingName"
            parseMyAirDataWithJq ".myThings.things.\"${idArray_g[0]}\".value"
            if [ "$jqResult" = 100 ]; then
               if [ $flipEnabled = true ]; then echo 1; else echo 0; fi
               exit 0
            else
               if [ $flipEnabled = true ]; then echo 0; else echo 1; fi
               exit 0
            fi
         fi
      ;;
      On )
         if [ $fanSpecified = true ]; then
            # Return value of Off if the zone is closed or the Control Unit is Off.
            # Updates global variable jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.state"
            if [  "$jqResult" = '"off"' ]; then
               echo 0
               exit 0
            else
               # Get the current mode of the Control Unit. Fan can only be On or Off; if not Vent, set all other modes to Off.
               # Updates global variable jqResult
               parseMyAirDataWithJq ".aircons.$ac.info.mode"
               mode="$jqResult"
               case "$mode" in
                  '"heat"' )
                     # Fan does not support Heat Mode.
                     echo 0
                     exit 0
                  ;;
                  '"cool"' )
                     # Fan does not support Cool Mode.
                     echo 0
                     exit 0
                  ;;
                  '"vent"' )
                     # Set Fan to On.
                     echo 1
                     exit 0
                  ;;
                  '"dry"' )
                     # Fan does not support Dry Mode.
                     echo 0
                     exit 0
                  ;;
                  * )
                     # If anything unexpected is retruned than the above, set to Off.
                     echo 0
                     exit 0
                  ;;
               esac
            fi
         elif [ $zoneSpecified = true ]; then
            #damper open/closed = Switch on/off = 1/0
            # Change to On just so we can leave it here for now
            # and it will not get called
            # Updates global variable jqResult
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.state"
            if [ "$jqResult" = '"open"' ]; then
               echo 1
               exit 0
            else
               echo 0
               exit 0
            fi
         # get the timer current setting
         elif [ $timerEnabled = true ]; then
            # parseMyAirDataWithJq ".aircons.$ac.info.state"
            # If the aircon state is "off", check that whether it has a countDownToOn timer set
            if [ "$jqResult" = '"off"' ]; then
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOn"
               # If "countDownToOn" is 0 then switch the timer off
               if [ "$jqResult" = '0' ]; then
                  echo 0
                  exit 0
               else
                  # If "countDownToOn" is not 0, switch on the timer
                  echo 1
                  exit 0
               fi
            # If the aircon state is "on", check that whether it has a countDownToOff timer set
            else
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOff"
               if [ "$jqResult" = "0" ]; then
                  # If "countDownToOff" is 0 then switch the timer off
                  echo 0
                  exit 0
               else
                  # If "contDownToOff" is not 0 then switch on the timer
                  echo 1
                  exit 0
               fi
            fi
         elif [ $fanSpeed = true ]; then
            # Set the "Fan Speed" accessory to "on" at all time
               echo 1
               exit 0
         elif [ $lightSpecified = true ]; then
            queryIdByName "light" "$lightName"
            parseMyAirDataWithJq ".myLights.lights.\"${idArray_g[0]}\".state"
            if [ "$jqResult" = '"on"' ]; then
               echo 1
               exit 0
            else
               echo 0
               exit 0
            fi
         fi
      ;;  # End of On
      #Light Bulb service used for controlling damper % open
      Brightness )
         # get the zone damper % information
         if [ $zoneSpecified = true ]; then
            # Get the zone damper % open
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.value"
            echo "$jqResult"
            exit 0
         # Get the timer setting
         elif [ $timerEnabled = true ]; then
            # parseMyAirDataWithJq ".aircons.$ac.info.state"
            # Get the timer countDowqnToOff value if the state of the aircon is "on"
            if [ "$jqResult" = '"on"' ]; then
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOff"
               echo $((jqResult / 10))
               exit 0
            # Get the timer countDownToOn value if the state of the aircon is "off"
            else
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOn"
               echo $((jqResult / 10))
               exit 0
            fi
         # get the lights dim level
         elif [ $lightSpecified = true ]; then
            queryIdByName "light" "$lightName"
            parseMyAirDataWithJq ".myLights.lights.\"${idArray_g[0]}\".value"
            echo "$jqResult"
            exit 0
         fi
      ;;
      # Fan service for controlling fan speed (low, medium and high)
      RotationSpeed )
         # Update the current fan speed
         parseMyAirDataWithJq ".aircons.$ac.info.fan"
         if [ "$jqResult" = '"low"' ]; then
            #25% as low speed
            echo 25
            exit 0
         elif [ "$jqResult" = '"medium"' ]; then
            #50% as medium speed
            echo 50
            exit 0
         elif [ "$jqResult" = '"high"' ]; then
            #90% as high speed
            echo 90
            exit 0
         else
            # one other possibility is "autoAA/auto", then echo 100
            echo 100
            exit 0
         fi
      ;;
      #Temp Sensor Fault Status = no fault/fault = 0/1-2
      StatusLowBattery )
         # Updates global variable jqResult
         parseMyAirDataWithJq ".aircons.$ac.zones.$zone.error"
         if [ "$jqResult" = '0' ]; then
            echo 0
            exit 0
         else
            echo 1
            exit 0
         fi
       ;;  # End of StatusLowBattery
   esac
fi
# For "Set" Directives
if [ "$io" = "Set" ]; then

   # Get the systemData, requiring the latest
   queryAirConWithIterations "http://$IP:2025/getSystemData" true

   case "$characteristic" in
      TargetHeatingCoolingState )
         case "$value" in
            0 )
               # Shut Off Control Unit.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{state:off}}}"

               # Get the systemData, requiring the latest for future "Get" or "Set"
               queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            ;;
            1 )
               # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{state:on,mode:heat}}}"

               # Get the systemData, requiring the latest for future "Get" or "Set"
               queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            ;;
            2 )
               # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{state:on,mode:cool}}}"

               # Get the systemData, requiring the latest for future "Get" or "Set"
               queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            ;;
         esac
      ;;
      TargetTemperature )
         # check whether Temperature Senors are used in this system from a cache file
         myAirConstants=$( cat "$MY_AIR_CONSTANTS_FILE" )
         noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
         if [ "$noSensors" = true ]; then
            # Only sets temperature to master temperature in the app
            setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{setTemp:$value}}}"
            exit 0
         else
            # Sets all zones to the current master thermostat's temperature value. All 10 allowable zones have been added just in case and do not need removing.
            setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{setTemp:$value},zones:{z01:{setTemp:$value},z02:{setTemp:$value},z03:{setTemp:$value},z04:{setTemp:$value},z05:{setTemp:$value},z06:{setTemp:$value},z07:{setTemp:$value},z08:{setTemp:$value},z09:{setTemp:$value},z10:{setTemp:$value}}}}"
            exit 0
         fi

         # Get the systemData, requiring the latest for future "Get" or "Set"
         queryAirConWithIterations "http://$IP:2025/getSystemData" true

      ;;
      TargetDoorState )
         # set the value of the garage door (100=open, 0=close) to MyPlace, (0=open, 1=close for Homekit)
         if [ $thingSpecified = true ]; then
            queryIdByName "thing" "$thingName"
            length=${#idArray_g[@]}
            if [ $flipEnabled = true ]; then value=$((value-1)); value=${value#-}; fi

            if [ "$value" = "1" ]; then
               for ((a=0;a<length;a++))
                  do
                     keepDel=$((length - a))
                     setAirConUsingIteration "http://$IP:$PORT/setThing?json={id:\"${idArray_g[a]}\",value:0}" "$keepDel"
                  done

                  # Get the systemData, requiring the latest for future "Get" or "Set"
                  queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            else
               for ((a=0;a<length;a++))
                  do
                     keepDel=$((length - a))
                     setAirConUsingIteration "http://$IP:$PORT/setThing?json={id:\"${idArray_g[a]}\",value:100}" "$keepDel"
                  done

                  # Get the systemData, requiring the latest for future "Get" or "Set"
                  queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            fi
         fi
      ;;
      On )
         # Uses the On characteristic for Fan/Vent mode.
         if [ $fanSpecified = true ]; then
            if [ "$value" = "1" ]; then
               # Sets Control Unit to On, sets to Fan mode aqnd fan speed will default to last used.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
            else
               # Shut Off Control Unit.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{state:off}}}"
            fi

            # Get the systemData, requiring the latest for future "Get" or "Set"
            queryAirConWithIterations "http://$IP:2025/getSystemData" true

            exit 0

         # Uses the On characteristic for zone switches.
         elif [ $zoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{zones:{$zone:{state:open}}}}"

               # Get the systemData, requiring the latest for future "Get" or "Set"
               queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            else
               # Ensures that at least one zone is open at all time to protect the aircon system before closing any zone:
               # > if the only zone open is the constant zone, leave it open and set it to 100%.
               # > if the constant zone is already closed, and the only open zone is set to close,
               #  the constant zone will open and set to 100% while closing that zone.

               # retrieve the constant zone number of zones from from the cache file
               myAirConstants=$( cat "$MY_AIR_CONSTANTS_FILE" )
               cZone=$( echo "$myAirConstants" | awk '{print $2}' )
               nZones=$( echo "$myAirConstants" | awk '{print $3}' )

               # Check how many zones are open
               if [ -f "$ZONEOPEN_FILE" ]; then
                  getFileStatDtFsize "$ZONEOPEN_FILE"
                  if [ "$dt" -ge 10 ]; then rm "$ZONEOPEN_FILE"; fi
               fi
               if [ -f "$ZONEOPEN_FILE" ]; then
                  zoneOpen=$( cat "$ZONEOPEN_FILE" )
                  zoneOpen=$((zoneOpen - 1))
                  echo "$zoneOpen" > "$ZONEOPEN_FILE"
               else
                  for (( a=1;a<=nZones;a++ ))
                  do
                     zoneStr=$( printf "z%02d" "$a" )
                     parseMyAirDataWithJq ".aircons.$ac.zones.$zoneStr.state"
                     if [ "$jqResult" = '"open"' ]; then
                        zoneOpen=$((zoneOpen + 1))
                     fi
                  done
               fi

               if [ "$zoneOpen" -gt 1 ]; then
                  # If there are more than 1 zone open, it is safe to close this zone.
                  # keep the number of zoneOpen in a temporary file to be used up to 10 seconds
                  echo "$zoneOpen" > "$ZONEOPEN_FILE"
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{zones:{$zone:{state:close}}}}"

                  # Get the systemData, requiring the latest for future "Get" or "Set"
                  queryAirConWithIterations "http://$IP:2025/getSystemData" true

                  exit 0
               elif [ "$zone" = "$cZone" ]; then
                  # If only 1 zone open and is the constant zone. do not close but set to  100%
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{zones:{$zone:{value:100}}}}"

                  # Get the systemData, requiring the latest for future "Get" or "Set"
                  queryAirConWithIterations "http://$IP:2025/getSystemData" true

                  exit 0
               else
                  # If only 1 zone open and is not the constant zone, open the constant zone and close this zone
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{zones:{$cZone:{state:open},$zone:{state:close}}}}" "2"
                  # Set the constant zone to 100%
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{zones:{$cZone:{value:100}}}}"

                  # Get the systemData, requiring the latest for future "Get" or "Set"
                  queryAirConWithIterations "http://$IP:2025/getSystemData" true

                  exit 0
               fi
            fi
         # setting the timer
         elif [ $timerEnabled = true ]; then
            if [ "$value" = "0" ]; then
               # Set both "countDownToOn" and "countDownToOff" to 0, otherwise do nothing
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{countDownToOn:0}}}" "2"
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{countDownToOff:0}}}"

               # Get the systemData, requiring the latest for future "Get" or "Set"
               queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            else
               # Do nothing
               exit 0
            fi
         # fanSpeed is always on, so there is on/off function but issue "exit 0" to let cmd4 know that action is satisfied
         elif [ $fanSpeed = true ]; then
            exit 0
         # setting the state of the light
         elif [ $lightSpecified = true ]; then
            queryIdByName "light" "$lightName"
            length=${#idArray_g[@]}
            if [ "$value" = "1" ]; then
               for ((a=0;a<length;a++))
               do
                  keepDel=$((length - a))
                  setAirConUsingIteration "http://$IP:$PORT/setLight?json={id:\"${idArray_g[a]}\",state:on}" "$keepDel"
               done

               # Get the systemData, requiring the latest for future "Get" or "Set"
               queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            else
               for ((a=0;a<length;a++))
               do
                  keepDel=$((length - a))
                  setAirConUsingIteration "http://$IP:$PORT/setLight?json={id:\"${idArray_g[a]}\",state:off}" "$keepDel"
               done

               # Get the systemData, requiring the latest for future "Get" or "Set"
               queryAirConWithIterations "http://$IP:2025/getSystemData" true

               exit 0
            fi
         fi
      ;;
      #Light Bulb service for used controlling damper % open and timer
      Brightness )
         if [ $zoneSpecified = true ]; then
            # Round the $value to its nearst 5%
            damper=$(($(($((value + 2)) / 5)) * 5))
            setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{zones:{$zone:{value:$damper}}}}"

            # Get the systemData, requiring the latest for future "Get" or "Set"
            queryAirConWithIterations "http://$IP:2025/getSystemData" true

            exit 0
         elif [ $timerEnabled = true ]; then
            # Make 1% to 10 minutes and capped at a max of 720 minutes
            timerInMinutes=$((value * 10))
            timerInMinutes=$((timerInMinutes < 720? timerInMinutes : 720))

            parseMyAirDataWithJq ".aircons.$ac.info.state"
            if [ "$jqResult" = '"on"' ]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{countDownToOff:$timerInMinutes}}}"
            else
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{countDownToOn:$timerInMinutes}}}"
            fi

            # Get the systemData, requiring the latest for future "Get" or "Set"
            queryAirConWithIterations "http://$IP:2025/getSystemData" true

            exit 0

         # Set light brightness
         elif [ $lightSpecified = true ]; then
            queryIdByName "light" "$lightName"
            length=${#idArray_g[@]}
            for ((a=0;a<length;a++))
            do
               keepDel=$((length - a))
               setAirConUsingIteration "http://$IP:$PORT/setLight?json={id:\"${idArray_g[a]}\",value:$value}" "$keepDel"
            done

            # Get the systemData, requiring the latest for future "Get" or "Set"
            queryAirConWithIterations "http://$IP:2025/getSystemData" true

            exit 0
         fi
      ;;
      # Fan service for controlling fan speed (0-33%:low, 34-67%:medium, 68-99%:high, 100%:autoAA/auto)
      RotationSpeed )
         # fspeed=$value (0-33%:low, 34-67%:medium, 68-99%:high, 100%:autoAA/auto)
         if [ "$value" -le 33 ]; then
            fspeed="low"
         elif [ "$value" -ge 34 ] && [ "$value" -le 67 ]; then
            fspeed="medium"
         elif [ "$value" -ge 68 ] && [ "$value" -le 99 ]; then
            fspeed="high"
         else
            # 'ezfan' users have 'autoAA' and regular users have 'auto'. But 'autoAA' works for all, so hardcoded to 'autoAA'
            fspeed="autoAA"
         fi
         setAirConUsingIteration "http://$IP:$PORT/setAircon?json={ac1:{info:{fan:$fspeed}}}"

         # Get the systemData, requiring the latest for future "Get" or "Set"
         queryAirConWithIterations "http://$IP:2025/getSystemData" true

         exit 0
      ;;
   esac
fi
echo "Unhandled $io $device $characteristic" >&2
exit 150
