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

# Define some variables for zone open checking
zoneOpen=0

# For timer capability
timerEnabled=false

#for lights and things (like garage, etc) controls
lightSpecified=false
thingSpecified=false

#Temporary files
QUERY_AIRCON_LOG_FILE="/tmp/queryAirCon_calls.log"
CURL_INVOKED_FILE_FLAG="/tmp/curl-invoked"
MY_AIRDATA_FILE="/tmp/myAirData.txt"
MY_AIRDATA_ID_FILE="/tmp/myAirData_id.txt"
MY_AIR_CONSTANTS_FILE="/tmp/myAirConstants.txt"

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
   # The return variables of this script: t0 = creation time of the file since Epoch
   #                                      t1 = current time in since Epoch
   #                                      dt = the age of the file in seconds
   #                                      fSize = the size of the file in bytes

   case "$OSTYPE" in
      darwin*)
         t0=$( stat -r "$fileName" | awk '{print $12}' )  # for Mac users
      ;;
      *)
         t0=$( stat -c %Y "$fileName" )
      ;;
   esac

   t1=$(date '+%s')
   dt=$((t1 - t0))
   # du is POSIX portable.
   fSize=$( du "$fileName" | cut -f1 )
}

function queryAirCon()
{
   local url="$1"
   local exitOnFail="$2"
   local iteration="$3"

   # This script uses a loop instead of the curl retry options because the
   # Aircon will not return all the data when it is busy with a write operation.

   # --max-time 2        (how long in seconds EACH retry can take )
   # --connect-timeout 2 (Amount of sevonds in connevtion phase )
   # --fail              (Exit with rc=22 instead of outputting http connection error document )
   # -g                  (This option switches off the "URL globbing parser". When you set this option,
   #                      you can specify URLs that contain the letters {}[] without having them being
   #                      interpreted by curl itself.
   # -s, --silent        (Silent or quiet mode. Don't show progress meter or error messages. Makes Curl
   #                      mute. It will still output the data you ask for, potentially even to the
   #                      terminal/stdout unless you redirect it.
   # --show-error        (Show error (to stderr) even when -s is used. DO NOT USE
   #                      Cmd4 will get to stderr, "curl failed, rc=1" which is annoying

   # Modified heavily from V3.2.0 to manage the communication between Cmd4 and the AdvantageAir (AA) system:
   #
   # High level functionalities of this script:
   #
   # - Store the myAirData in a cache file ("$MY_AIRDATA_FILE") for 90 seconds before refreshing
   # - The getValue requests from Cmd4 will read the data from the cache file within the 90s cycle
   # - The cache cycle will reset whenever there is a "Set" command from Cmd4
   #
   # The purpose of this is to prevent an excessive amount of queries to the AdvantageAir System otherwise will jam the AA system and
   # make it unresponsive.

   local fileCache=false

   if [ -f "$MY_AIRDATA_FILE" ]; then

      getFileStatDtFsize "$MY_AIRDATA_FILE"

      # check if the file is less than 90s old and also check that the file size is > 2000 bytes.  File size < 2000 bytes is an
      # indication of incomplete myAirData json file.

      if [ "$dt" -le 90 ] && [ "$fSize" -gt 2000 ]; then
         fileCache=true
         myAirData=$( cat "$MY_AIRDATA_FILE" )
         rc=0

      # If $MY_AIRDATA_FILE 180s old, and /tmp/myAirData-*.txt temporary file or "$CURL_INVOKED_FILE_FLAG" proxy file or both are still in
      # /tmp directory, it means that an earlier getValue 'curl' command was actually completed but Cmd4 getValue timed out.
      # To recover, do the following:

      elif [ $dt -gt 180 ]; then

         if [ -f "$CURL_INVOKED_FILE_FLAG" ]; then
            t23=$( cat "$CURL_INVOKED_FILE_FLAG" )
            if [ -f "/tmp/myAirData-${t23[1]}.txt" ]; then mv "/tmp/myAirData-${t23[1]}.txt" "$MY_AIRDATA_FILE"; fi
         fi

         # remove the remaining temporary files and/or the proxy file if present

         rm -f /tmp/myAirData-*.txt
         rm -f "$CURL_INVOKED_FILE_FLAG"

      fi

   # If $MY_AIRDATA_FILE is not available, assign dt=-1.

   else

      dt=-1

   fi

   # log for diagnostic purposes
   t2=$(date '+%s')
   echo "queryAirCon_calls $t2 $dt $fileCache $io $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"

   if [ $fileCache = false ] && [ "$selfTest" = "TEST_OFF" ]; then # Updates global variable myAirData

      # A file "$CURL_INVOKED_FILE_FLAG" is used as as proxy to tell the sebsequuent getValue requests that there is an earlier 'curl' command
      # been issued and is still running.  If the file "$CURL_INVOKED_FILE_FLAG" is present and is <= 60s old, then the Get request will wait
      # for 2s and ckeck again every second up to a max of 62 seconds or until the proxy file is deleted whichever is earlier. The deletion
      # of the proxy file is an indication of the completion of the earlier 'curl' command and its output will be copied by the subsequent
      # getValue requests in waiting.

      # In a very rare situation when a 'Set' command was received, aircon set and the cache file $MY_AIRDATA_FILE deleted and the first
      # getValue 'curl' command after that took unusually long time and timed out, the consequence of Cmd4 timed out is /tmp/myAirData-*.txt
      # won't get renamed to $MY_AIRDATA_FILE and the "$CURL_INVOKED_FILE_FLAG" proxy file won't get deleted neither.
      #
      # To recover from this situation check whether the "$CURL_INVOKED_FILE_FLAG" proxy file is older than 45s (a confirmation of timed out situation),
      # if so and if /tmp/myAirData-*.txt temporary file is present, rename it to $MY_AIRDATA_FILE and delete the "$CURL_INVOKED_FILE_FLAG".
      #
      # if this situation happens, assign dt=-(age of "$CURL_INVOKED_FILE_FLAG") for the diagnostic log

      if [ -f "$CURL_INVOKED_FILE_FLAG" ]; then

         getFileStatDtFsize "$CURL_INVOKED_FILE_FLAG"

         if [ $dt -gt 60 ]; then

            t23=$( cat "$CURL_INVOKED_FILE_FLAG" )
            if [ -f "/tmp/myAirData-${t23[1]}.txt" ]; then mv "/tmp/myAirData-${t23[1]}.txt" "$MY_AIRDATA_FILE"; fi
            rm -f "/tmp/myAirData-*.txt"
            rm "$CURL_INVOKED_FILE_FLAG"
            dt=$((dt * -1))
            echo "queryAirCon_curl_timedOut ${t23[0]} $dt $io $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"

         else

            sleep 2.0
            while [ -f "$CURL_INVOKED_FILE_FLAG" ]
               do
                  t3=$(date '+%s')
                  dt=$((t3 - t2))
                  if [ $dt -gt 62 ]; then
                     break
                  fi
                  sleep 1.0
               done
            myAirData=$(cat "$MY_AIRDATA_FILE")
            rc=0
            t4=$(date '+%s')
            dt=$((t4 - t2))
            echo "queryAirCon_copy $t2 $t4 $dt $fileCache $io $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"

         fi

      # create a proxy file "$CURL_INVOKED_FILE_FLAG" if there isn't one there already
      # run the getValue 'curl' command and output to a temporary file - this is the prevent the file been accessed while being written
      # once curl command is completed rename the temporary file to the cache file /tmp/myairData.txt
      # then delete the proxy file "$CURL_INVOKED_FILE_FLAG" to indicate to the subsequent getValue requests that the 'curl' command has completed

   else

      t3=$(($(date '+%s') + RANDOM))
      echo "$t2 $t3" > "$CURL_INVOKED_FILE_FLAG"
      curl -o "/tmp/myAirData-$t3.txt" -s -g "$url"
      rc=$?
      t4=$(date '+%s')
      dt=$((t4 - t2))

      if [ "$rc" = "0" ]; then
         myAirData=$(cat /tmp/myAirData-$t3.txt)
         mv "/tmp/myAirData-${t3}.txt" "$MY_AIRDATA_FILE"
         rm -f "/tmp/myAirData-*.txt"
         rm "$CURL_INVOKED_FILE_FLAG"
         echo "queryAirCon_curl $t2 $t4 $dt $fileCache $io $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"
      else
         if [ -f "/tmp/myAirData-${t3}.txt" ]; then rm "/tmp/myAirData-${t3}.txt"; fi
         if [ -f "$CURL_INVOKED_FILE_FLAG" ]; then rm "$CURL_INVOKED_FILE_FLAG"; fi
         echo "queryAirCon_curl_failed $t2 $t4 $dt $fileCache $io $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"
      fi

      fi

   elif [ "$selfTest" = "TEST_ON" ]; then

      myAirData=$( cat "./data/getSystemData.txt${iteration}" )
      rc=$?
      # For Testing, you can compare whats sent
      if [ "$io" = "Set" ]; then
         echo "Setting url: $url";
      fi

   fi

   # Delete the log if it is > 15 MB
   # du is POSIX portable.
   fSize=$( du "$QUERY_AIRCON_LOG_FILE" | cut -f1 )
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

function setAirCon()
{
   local url="$1"
   local exitOnFail="$2"
   local iteration="$3"
   local keepDel="$4"     # if $keepDel = "" or <= "1", delete the $MY_AIRDATA_FILE after the 'curl' command.
   # $keepDel >=2 means there is/are more set command(s) coming after this one, $MY_AIRDATA_FILE will be kept for now

   # This script is purely used to 'Set' the AA system
   # The $MY_AIRDATA_FILE cache file will be deleted after the 'Set' command is completed
   # However, if there is a series of 'Set' commands, only delete the $MY_AIRDATA_FILE after the last 'Set' command
   # This is to cater for the situation where one light accessory can be asscicated with 2 physical lights or more

   t2=$(date '+%s')
   echo "setAirCon_curl $t2 $io$keepDel $device $characteristic $url" >> "$QUERY_AIRCON_LOG_FILE"

   curl --fail -s -g "$url"
   rc=$?

   if [ "$keepDel" = "" ] || [ "$keepDel" -le "1" ]; then
      if [ -f "$MY_AIRDATA_FILE" ]; then rm "$MY_AIRDATA_FILE"; fi
   fi

   if [ "$rc" != "0" ]; then
      if [ "$exitOnFail" = "1" ]; then
         # The result cannot be trusted with a bad return code
         # Do not output to stderr as this defeats the purpose
         # of squashing error messages
         logError "curl failed" "$rc" "$io" "$keepDel" "$url"
         exit $rc
      fi
   fi
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
}

function queryAndParseAirCon()
{
   local url="$1"
   local jqPath="$2"

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
      queryAirCon "$url" "$exitOnFail" "$i"

      if [ "$rc" = "0" ]; then
         # Updates global variable jqResult
         parseMyAirDataWithJq "$jqPath" "$exitOnFail"

         if [ "$rc" = "0" ]; then
            break
         else
            sleep 1.0
         fi
      else
         sleep 1.0
      fi

   done
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
   name1=$(echo "$name"|cut -d" " -f1)
   name2=$(echo "$name"|cut -d" " -f2)
   name3=$(echo "$name"|cut -d" " -f3)
   name4=$(echo "$name"|cut -d" " -f4)
   local ids=""

   # Obtain the unique ID by its name from a cache dataset which is set to refresaed every 12 hours.
   # Lights or things names are considered as semi constants, they don't change unless the users change them at AA MyPlace system
   # if any light's or thing's name s changed at AA MyPlace system, the config.json file needs to updated accordingly, otherwise
   # Homekit will loss its association with that light/thing.

   getFileStatDtFsize "$MY_AIRDATA_ID_FILE"

   if [ $dt -ge 43200 ]; then
      rm "$MY_AIRDATA_ID_FILE"
   fi

   if [ -f "$MY_AIRDATA_ID_FILE" ]; then
      myAirData=$(cat "$MY_AIRDATA_ID_FILE")
   else
      queryAirCon "http://$IP:2025/getSystemData" "1" "0"
      echo "$myAirData" > "$MY_AIRDATA_ID_FILE"
   fi

   # Scan for the unique IDs of lights or things by their names using jq command.
   # Each name might be associated with more than 1 light/thing hence can have more than 1 ID. As such the ID(s) is/are output to an array "$idArray_g"


   if [ "$path" = "light" ]; then
      ids=$(echo "$myAirData" | jq -e ".myLights.lights[]|select(.name|test(\"$name1\"))|select(.name|test(\"$name2\"))|select(.name|test(\"$name3\"))|select(.name|test(\"$name4\"))|.id" )
      rc=$?

   elif [ "$path" = "thing" ]; then
      ids=$( echo "$myAirData" | jq -e ".myThings.things[]|select(.name|test(\"$name1\"))|select(.name|test(\"$name2\"))|select(.name|test(\"$name3\"))|select(.name|test(\"$name4\"))|.id" )
      rc=$?

   else
      rc=2

   fi

   if [ "$ids" != "" ];then
      eval "idArray_g=($ids)"
   fi

   # for diagnostic purpuses, delete '#' from the next two lines to output the diagnostic log
   # dt=$(date '+%s')
   # echo "queryIdByName_jq $io path=$path name=$name idArray_g=${idArray_g[@]}" >> /tmp/idArray.log

   if [ "$rc" != "0" ]; then
      # The result cannot be trusted with a bad return code
      # Do not output to stderr as this defeats the purpose
      # of squashing error messages
      logError "queryIdByName_jq failed $io" "$rc" "${idArray_g[@]}" "$path" "$name"
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
            optionUnderstood=true
            ;;
         TEST_CMD4)
            # With Cmd4, but using test data. Causes no echo on try
            selfTest=${v}
            optionUnderstood=true
            ;;
            # If the accessory is used to control the fan speed
            fanSpeed)
            fanSpeed=true
            optionUnderstood=true
            ;;
            # Aded to include a timer capability
            timer)
            timerEnabled=true
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

   case "$characteristic" in

      # Gets the current temperature.
      CurrentTemperature )

         # check whether Temperature Sensors are used in this system and also check the constant zone for this system

         # System wide constants are stored in $MY_AIR_CONSTANTS_FILE which currently contains the following:
         # 1. 'noSensors' : true = this system has no temperature Sensors, false = this systme has temperature sensors
         # 2. 'cZone' : constant zone
         # 3. 'nZones': number of zones

         # If the system wide constants cache file is present, read from it otherwise create one
         if [ -f "$MY_AIR_CONSTANTS_FILE" ]; then
            myAirConstants=$( cat "$MY_AIR_CONSTANTS_FILE" )
            noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
            cZone=$( echo "$myAirConstants" | awk '{print $2}' )
         else
            queryAirCon "http://$IP:2025/getSystemData" "1" "0"

            # get the number of zones
            parseMyAirDataWithJq '.aircons.ac1.info.noOfZones'
            nZones=$jqResult

            # Check if any zones have "rssi" value != 0  if so, set noSensors=false
            for (( a=1;a<=nZones;a++ ))
            do
               zoneStr=$( printf "z%02d" "$a" )
               parseMyAirDataWithJq ".aircons.ac1.zones.$zoneStr.rssi"
               if [ "$jqResult" != 0 ]; then
                   noSensors=false
                   break
               fi
            done

            # parse the first constant zone from myAirData
            parseMyAirDataWithJq '.aircons.ac1.info.constant1'
            cZone=$( printf "z%02d" "$jqResult" )

            # write the noSensor, cZone and nZones info to a file $MY_AIR_CONSTANTS_FILE as a cache file
            # this cache file will not be refreshed automatically unless deleted or the host system rebooted

            echo "$noSensors $cZone $nZones" > "$MY_AIR_CONSTANTS_FILE"
         fi

         if [ $noSensors = false ] && [ $zoneSpecified = false ]; then
            # Use constant zone for Thermostat temperature reading
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$cZone"'.measuredTemp'
         elif [ $zoneSpecified = true ]; then
            # Use zone for Temperature Sensor temp reading
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$zone"'.measuredTemp'
         elif [ $noSensors = true ]; then
            # Uses the set temperature as the measured temperature in lieu of having sensors.
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.setTemp'
         fi

         echo "$jqResult"

         exit 0
      ;;

      # Gets the target temperature.
      TargetTemperature )
         # Updates global variable jqResult
         queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.setTemp'

         echo "$jqResult"

         exit 0
      ;;

      # Sets display units to Celsius.
      TemperatureDisplayUnits )
         echo 0

         exit 0
      ;;

      # Makes the target Control Unit state the current Control Unit state.
      TargetHeatingCoolingState | CurrentHeatingCoolingState )
         # Set to Off if the zone is closed or the Control Unit is Off.
         # Updates global variable jqResult
         queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'

         if [  "$jqResult" = '"off"' ]; then
            echo 0

            exit 0
         else
            # Get the current mode of the Control Unit. Off=0, Heat=1, Cool=2.
            # Updates global variable jqResult
            parseMyAirDataWithJq '.aircons.ac1.info.mode'
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
            #
            queryAndParseAirCon "http://$IP:2025/getSystemData" ".myThings.things.${idArray_g[0]}.value"
            if [ "$jqResult" = 100 ]; then
               echo 0
            else
               echo 1
            fi
            exit 0
         fi
      ;;

      On )
         if [ $fanSpecified = true ]; then
            # Return value of Off if the zone is closed or the Control Unit is Off.
            # Updates global variable jqResult
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'

            if [  "$jqResult" = '"off"' ]; then
               echo 0

               exit 0
            else
               # Get the current mode of the Control Unit. Fan can only be On or Off; if not Vent, set all other modes to Off.
               # Updates global variable jqResult
               parseMyAirDataWithJq '.aircons.ac1.info.mode'
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
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$zone"'.state'

            if [ "$jqResult" = '"open"' ]; then
               echo 1

               exit 0
            else
               echo 0

               exit 0
            fi

         # get the timer current setting
         elif [ $timerEnabled = true ]; then
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'

            # If the aircon state is "off", check that whether it has a countDownToOn timer set
            if [ "$jqResult" = '"off"' ]; then

               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOn'

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

               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOff'

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
            length=${#idArray_g[@]}

            # check the state of the lights based on its unique id
            queryAndParseAirCon "http://$IP:2025/getSystemData" ".myLights.lights.${idArray_g[0]}.state"

            if [ "$jqResult" = '"on"' ]; then
               echo 1
            else
               echo 0
            fi
            exit 0

         fi
      ;;  # End of On

      #Light Bulb service used for controlling damper % open
      Brightness )
         # get the zone damper % information
         if [ $zoneSpecified = true ]; then
            # Get the zone damper % open
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$zone"'.value'
            echo "$jqResult"
            exit 0

         # Get the timer setting
         elif [ $timerEnabled = true ]; then

            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'

            # Get the timer countDowqnToOff value if the state of the aircon is "on"
            if [ "$jqResult" = '"on"' ]; then
               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOff'
               echo $((jqResult / 10))
               exit 0

            # Get the timer countDownToOn value if the state of the aircon is "off"
            else
               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOn'
               echo $((jqResult / 10))
               exit 0
            fi

         # get the lights dim level
         elif [ $lightSpecified = true ]; then

            queryIdByName "light" "$lightName"
            length=${#idArray_g[@]}

            queryAndParseAirCon "http://$IP:2025/getSystemData" ".myLights.lights.${idArray_g[0]}.value"
            echo "$jqResult"
            exit 0

         fi
      ;;

      # Fan service for controlling fan speed (low, medium and high)
      RotationSpeed )
         # Update the current fan speed
         queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.fan'
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
         queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$zone"'.error'

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

   case "$characteristic" in
      TargetHeatingCoolingState )
         case "$value" in
            0 )
               # Shut Off Control Unit.
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:off}}}" "1" "0"

               exit 0
            ;;
            1 )
               # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:on,mode:heat}}}" "1" "0"

               exit 0
            ;;
            2 )
               # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:on,mode:cool}}}" "1" "0"

               exit 0
            ;;
         esac
      ;;

      TargetTemperature )

         # check whether Temperature Senors are used in this system from a cache file
         myAirConstants=$( cat "$MY_AIR_CONSTANTS_FILE" )
         # noSensors=${myAirConstants[0]}
         noSensors=$( echo "$myAirConstants" | awk '{print $1}' )

         if [ "$noSensors" = true ]; then
            # Only sets temperature to master temperature in the app
            setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{setTemp:$value}}}" "1" "0"
            exit 0
         else
            # Sets all zones to the current master thermostat's temperature value. All 10 allowable zones have been added just in case and do not need removing.
            setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{setTemp:$value},zones:{z01:{setTemp:$value},z02:{setTemp:$value},z03:{setTemp:$value},z04:{setTemp:$value},z05:{setTemp:$value},z06:{setTemp:$value},z07:{setTemp:$value},z08:{setTemp:$value},z09:{setTemp:$value},z10:{setTemp:$value}}}}" "1" "0"
            exit 0
         fi
      ;;

      TargetDoorState )

         # set the value of the garage door (100=open, 0=close) to MyPlace, (0=open, 1=close for Homekit)
         if [ $thingSpecified = true ]; then
            queryIdByName "thing" "$thingName"
            length=${#idArray_g[@]}
            if [ "$value" = "1" ]; then
               for ((a=0;a<length;a++))
                  do
                     keepDel=$((length - a))
                     setAirCon "http://$IP:2025/setThing?json={id:${idArray_g[a]},value:0}" "1" "0" "$keepDel"
                  done
            else
               for ((a=0;a<length;a++))
                  do
                     keepDel=$((length - a))
                     setAirCon "http://$IP:2025/setThing?json={id:${idArray_g[a]},value:100}" "1" "0" "$keepDel"
                  done
            fi
            exit 0
         fi
      ;;

      On )
         # Uses the On characteristic for Fan/Vent mode.
         if [ $fanSpecified = true ]; then
            if [ "$value" = "1" ]; then
               # Sets Control Unit to On, sets to Fan mode aqnd fan speed will default to last used.
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:on,mode:vent}}}" "1" "0"

               exit 0
            else
               # Shut Off Control Unit.
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:off}}}" "1" "0"

               exit 0
            fi
         # Uses the On characteristic for zone switches.
         elif [ $zoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               setAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{state:open}}}}" "1" "0"

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

               queryAirCon "http://$IP:2025/getSystemData" "1" "0"

               # Check how many zones are open
               for (( a=1;a<=nZones;a++ ))
               do
                  zoneStr=$( printf "z%02d" "$a" )
                  parseMyAirDataWithJq ".aircons.ac1.zones.$zoneStr.state"
                  if [ "$jqResult" = '"open"' ]; then
                     zoneOpen=$((zoneOpen + 1))
                  fi
               done

               if [ $zoneOpen -gt 1 ]; then
                  # If there are more than 1 zone open, it is safe to close this zone.
                  setAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{state:close}}}}" "1" "0"
                  exit 0
               elif [ "$zone" = "$cZone" ]; then
                  # If only 1 zone open and is the constant zone. do not close but set to  100%
                  setAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{value:100}}}}" "1" "0"
                  exit 0
               else
                  # If only 1 zone open and is not the constant zone, open the constant zone and close this zone
                  setAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$cZone:{state:open},$zone:{state:close}}}}" "1" "0" "2"
                  # Set the constant zone to 100%
                  setAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$cZone:{value:100}}}}" "1" "0"
                  exit 0
               fi
            fi

         # setting the timer
         elif [ $timerEnabled = true ]; then
            if [ "$value" = "0" ]; then
               # Set both "countDownToOn" and "countDownToOff" to 0, otherwise do nothing
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOn:0}}}" "1" "0" "2"
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOff:0}}}" "1" "0"
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
                     setAirCon "http://$IP:2025/setLight?json={id:${idArray_g[a]},state:on}" "1" "0" "$keepDel"
                  done
            else
               for ((a=0;a<length;a++))
                  do
                     keepDel=$((length - a))
                     setAirCon "http://$IP:2025/setLight?json={id:${idArray_g[a]},state:off}" "1" "0" "$keepDel"
                  done
            fi
            exit 0

         fi
      ;;

      #Light Bulb service for used controlling damper % open and timer
      Brightness )

         if [ $zoneSpecified = true ]; then
            # Round the $value to its nearst 5%
            damper=$(($(($((value + 2)) / 5)) * 5))

            setAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{value:$damper}}}}" "1" "0"
            exit 0

         elif [ $timerEnabled = true ]; then
            # Make 1% to 10 minutes and capped at a max of 720 minutes
            timerInMinutes=$((value * 10))
            timerInMinutes=$((timerInMinutes < 720? timerInMinutes : 720))

            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'

            if [ "$jqResult" = '"on"' ]; then
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOff:$timerInMinutes}}}" "1" "0"
               exit 0
            else
               setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOn:$timerInMinutes}}}" "1" "0"
               exit 0
            fi

         # Set light brightness
         elif [ $lightSpecified = true ]; then

            queryIdByName "light" "$lightName"
            length=${#idArray_g[@]}

            for ((a=0;a<length;a++))
               do
                  keepDel=$((length - a))
                  setAirCon "http://$IP:2025/setLight?json={id:${idArray_g[a]},value:$value}" "1" "0" "$keepDel"
               done
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
         setAirCon "http://$IP:2025/setAircon?json={ac1:{info:{fan:$fspeed}}}" "1" "0"

         exit 0
      ;;

   esac
fi

echo "Unhandled $io $device $characteristic" >&2

exit 150
