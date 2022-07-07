#!/bin/bash

################################################################################
#
# A massive thank you to John Talbot of homebridge-cmd4 for all his work on
# improving this shell script and the improvements to homebridge-cmd4 to cater
# further to the Advantage Air controller and all of it's Homebridge users!
#
# A massive thanks also to @uswong for his ideas and contributions to adding
# 'rotationSpeed' to the Fan accessory and a "linkedType" 'Fan Speed' to the
# Thermostat # accessory for speed control (low/medium/high/auto). I am very
# pleased with the work and I think a lot of users will be too!
#
###############################################################################

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

# Default values
zone=""
zoneSpecified=false
fanSpecified=false
argSTART=4
logErrors=true
debugSpecified=false
noSensors=true
fanSpeed=false
sameAsCached=false
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

# For lights and things (like garage, etc) controls
lightSpecified=false
thingSpecified=false

#Temporary files - the subdirectory full path will be defined later
if [ -z "${TMPDIR}" ]; then TMPDIR="/tmp"; fi
tmpSubDir="${TMPDIR}"
QUERY_AIRCON_LOG_FILE="queryCachedAirCon_calls.log"
QUERY_IDBYNAME_LOG_FILE="queryIdByName.log"
MY_AIRDATA_FILE="myAirData.txt"
MY_AIR_CONSTANTS_FILE="myAirConstants.txt"
ZONEOPEN_FILE="zoneOpen.txt"

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
   local sfx
   sfx="$rc-$io-$device-$characteristic"
   sfx=${sfx// /_}
   local fileName="${tmpSubDir}/AirconError-${sfx}.txt"
   { echo "$io $device $characteristic"
     echo "${comment}"
     echo "return code: $rc"
     echo "result: $result"
     echo "data1: $data1"
     echo "data2: $data2"
   } > "$fileName"
}

function logQueryAirConDiagnostic()
{
   if [ "$debugSpecified" != true ]; then
      return
   fi
   local str="$1"
   echo "$str" >> "$QUERY_AIRCON_LOG_FILE"

   # Delete the log if it is > 15 MB
   fSize=$(find "$QUERY_AIRCON_LOG_FILE" -ls | awk '{print $7}')
   if [ "$fSize" -gt 15728640 ];then
      rm "$QUERY_AIRCON_LOG_FILE"
   fi
}

function logQueryIdByNameDiagnostic()
{
   if [ "$debugSpecified" != true ]; then
      return
   fi
   local str="$1"
   echo "$str" >> "$QUERY_IDBYNAME_LOG_FILE"

   # Delete the log if it is > 15 MB
   fSize=$(find "$QUERY_IDBYNAME_LOG_FILE" -ls | awk '{print $7}')
   if [ "$fSize" -gt 15728640 ];then
      rm "$QUERY_IDBYNAME_LOG_FILE"
   fi
}

function getFileStatDt()
{
   local fileName="$1"
   # This script is to determine the time of a file using 'stat'
   # command and calculate the age of the file in seconds
   # The return variables of this script:
   #    tf = last changed time of the file since Epoch
   #    t0 = current time since Epoch
   #    dt = the age of the file in seconds since last changed
   case "$OSTYPE" in
      darwin*)
         tf=$( stat -r "$fileName" | awk '{print $11}' )  # for Mac users
      ;;
      *)
         tf=$( stat -c %Z "$fileName" )
      ;;
   esac
   t0=$(date '+%s')
   dt=$((t0 - tf))
}

# NOTE: ONLY queryAirConWithIterations CALLS THIS !!!
function queryCachedAirCon()
{
   local url="$1"
   local exitOnFail="$2"
   local forceFetch="$3"
   local iteration="$4"
   local queryType
   local myAirData_cached="{}"

   local lockFile="${MY_AIRDATA_FILE}.lock"
   local dateFile="${MY_AIRDATA_FILE}.date"

   t0=$(date '+%s')

   # The dateFile is only valid if there is an MY_AIRDATA_FILE
   local useFileCache=false
   local doFetch=false
   local dt=-1

   # The dateFile and MY_AIRDATA_FILE must exist together to check
   # for a valid date stamp
   if [[ -f "$dateFile" && -f "$MY_AIRDATA_FILE" ]]; then
      tf=$(cat "$dateFile")
      dt=$(( t0 - tf ))
      if [ "$dt" -le 120 ]; then
         useFileCache=true 
      elif [[ "$dt" -gt 180  &&  -f "$lockFile" ]]; then # an earlier curl may have timed out
         tlf=$(cat "$lockFile")
         dtlf=$(( t0 - tlf ))
         if [ "$dtlf" -ge 60 ]; then # earlier curl has timed out, recover and try again
            rm "$lockFile"
            rc=99
            logQueryAirConDiagnostic "queryCachedAirCon_calls_earlier_CMD4_timed_out $tf $t0 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"
            return
         fi
      fi
   fi
   logQueryAirConDiagnostic "queryCachedAirCon_calls $tf $t0 $dt $useFileCache itr=$iteration $io $device $characteristic $url" 

   if [ "$forceFetch" = true ] || [ "$useFileCache" = false ]; then
      doFetch=true
   fi

   # If $lockFile is detected, iterate until it is deleted or 60s whichever is earlier
   # The $lockfile can be there for 1s to 60s (even beyond occasionally) for a big system, with an average of ~6s
   #
   if [ -f "$lockFile" ]; then
      queryType="copy"
      tlf=$(cat "$lockFile")
      while [ -f "$lockFile" ]; do
         sleep 1.0
         t2=$(date '+%s')
         dt=$(( t2 - t0 ))
         dtlf=$(( t2 - tlf ))
         if [ "$dtlf" -ge 60 ]; then  
            # earlier CMD4 has timed out (CMD4 timeout:60000) - this rarely happen (<0.1% of the time)
            # flag it and copy the existing cached file and move on. May not have enough time to retry
            rc=98
            logQueryAirConDiagnostic "queryCachedAirCon_copy_earlier_CMD4_timed_out $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"

            # To test the logic, issue this comment
            if [ "$selfTest" = "TEST_ON" ]; then
               echo "Earlier \"curl\" to getSystemData has timed out"
            fi
            break 
         fi
      done
      myAirData=$( cat "$MY_AIRDATA_FILE" )
      rc=$?
      logQueryAirConDiagnostic "queryCachedAirCon_copy $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"

      # To test the logic, issue this comment
      if [ "$selfTest" = "TEST_ON" ]; then
         echo "Fetching myAirData from cached file"
      fi

   elif [ "$doFetch" = true ]; then
      echo "$t0" > "$lockFile"
      queryType="curl"
      myAirData=$( curl -s -g "$url")
      rc=$?
      if [ "$rc" = "0" ]; then
         #Need to parse to ensure the json file is not empty
         parseMyAirDataWithJq ".aircons.$ac.info"
         if [ "$rc" = "0" ]; then
            t2=$(date '+%s') 
            echo "$t2" > "$dateFile"  # overwrite $dateFile
            #if $myAirData is not the same as the cached file, overwrite it with the new $myAirData 
            if [ -f "$MY_AIRDATA_FILE" ]; then isMyAirDataSameAsCached; fi
            if [ $sameAsCached = false ]; then echo "$myAirData" > "$MY_AIRDATA_FILE"; fi
            dt=$((t2 - t0))  # time-taken for curl command to complete
            logQueryAirConDiagnostic "queryCachedAirCon_curl $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"
         else
            # just in case
            unset myAirData
         fi
      else
         logQueryAirConDiagnostic "queryCachedAirCon_curl_failed $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"
      fi
      rm "$lockFile"

   elif [ "$doFetch" = false ]; then
      queryType="cache"
      myAirData=$( cat "$MY_AIRDATA_FILE" )
      rc=$?
   fi

   if [ "$rc" != "0" ]; then
      if [ "$exitOnFail" = "1" ]; then
         logError "getValue_${queryType} failed" "$rc" "" "" "$url"
         exit $rc
      fi
   fi
}

function isMyAirDataSameAsCached()
{
   local aircons
   local lights
   local things
   local myAirData_cached
   local aircons_cached
   local lights_cached
   local things_cached

   myAirData_cached=$(cat "$MY_AIRDATA_FILE")

   if [ "$myAirData" = "$myAirData_cached" ]; then
      sameAsCached=true
      return
   fi
   # For aircon system with temperature sensors, "rssi" and "measuredTemp" are changing all the time
   # do not need to compare "rssi" but if "measuredTemp" is changed, cached file will be updated 
   # compare only the aircons, lights and things - all the rest does not matter
   aircons=$(echo "$myAirData"|jq -ec ".aircons[]"|sed s/rssi\":[0-9]*/rssi\":0/g)
   lights=$(echo "$myAirData"|jq -ec ".myLights.lights[]")
   things=$(echo "$myAirData"|jq -ec ".myThings.things[]")

   aircons_cached=$(echo "$myAirData_cached"|jq -ec ".aircons[]"|sed s/rssi\":[0-9]*/rssi\":0/g)
   lights_cached=$(echo "$myAirData_cached"|jq -ec ".myLights.lights[]")
   things_cached=$(echo "$myAirData_cached"|jq -ec ".myThings.things[]")

   if [[ "$aircons" = "$aircons_cached" && "$lights" = "$lights_cached" && "$things" = "$things_cached" ]]; then sameAsCached=true; fi
}

function setAirConUsingIteration()
{
   local url="$1"
   local dateFile="${MY_AIRDATA_FILE}.date"

   # This script is purely used to 'Set' the AA system and to update the MY_AIRDATA_FILE cached file

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

      t3=$(date '+%s')
      curl --fail -s -g "$url"
      rc=$?
      logQueryAirConDiagnostic "setAirCon_curl $t3 rc=$rc itr=$i $io $device $characteristic $value $url"

      if [ "$rc" == "0" ]; then
         # update $MY_AIRDATA_FILE directly instead of fetching a new copy from AdvantageAir controller after a set command
         updateMyAirDataCachedFile "$url"
         if [ "$rc" == "0" ]; then echo "$t3" > "$dateFile"; fi
         return
      fi

      if [ "$exitOnFail" = "1" ]; then
         logError "SetAirCon_curl failed" "$rc" "" "$io" "$url"
         exit $rc
      fi
   done
}

function updateMyAirDataCachedFile()
{
   local url="$1"
 
   # This script to parse the curl $url: input   - 'http://192.168.0.31:2025/setAircon?json={ac1:{zones:{z04:{state:open}}}}'
   #             into jq set path:      output  - '.aircons.ac1.zones.z04.state="open"'

   #                                     input   - 'http://192.168.0.31:2025/setAircon?json={ac1:{zones:{z04:{value:90}}}}'
   #                                     output  - '.aircons.ac1.zones.z04.value=90'

   #                                     input   - 'http://192.168.0.31:2025/setAircon?json={ac1:{info:{state:on,mode:vent}}}'
   #                                     output1 - '.aircons.ac1.info.state="on"    
   #                                     output2 - '.aircons.ac1.info.mode="vent"

   local setNumber
   local setMode 
   local jqPathToSetJson
   local jqPathToSetJsonState

   local JqHeader=${url:$((${#IP}+13)):8}
   local setJqPath=${url:$((${#IP}+13)):100}
   setNumber=$(echo "$setJqPath"|grep 'value\|setTemp\|countDownTo')
   setMode=$(echo "$setJqPath"|grep mode)

   # Strip down $jqPath by removing `"`, `{`, `}` and replace the last `:` with `=`
   # then replace the rest of `:` with `.`
   setJqPath=$(echo "$setJqPath"|sed s/[\"\{\}]//g|sed -E 's/(.*)\:/\1=/'|sed s/:/./g)
   #
   case $JqHeader in
      setAirco)
         setJqPath=${setJqPath//setAircon?json=/.aircons.}
         if [ -n "$setNumber" ]; then
            jqPathToSetJson=$setJqPath
         elif [ -n "$setMode" ]; then
            jqPathToSetJson=$(echo "$setJqPath"|sed s/state.on,//|sed 's/\(=\)\(.*\)/\1"\2"/g')
            jqPathToSetJsonState=$(echo "$jqPathToSetJson"|cut -d"=" -f1|sed s/mode/state=\"on\"/)
            updateMyAirDataCachedFileWithJq "$url" "$jqPathToSetJsonState"
         else  # value is a string
            setJqPath=${setJqPath//=/=\"}
            jqPathToSetJson=$setJqPath\"
         fi
         updateMyAirDataCachedFileWithJq "$url" "$jqPathToSetJson"
         ;;
      setLight)
         setJqPath=$(echo "$setJqPath"|sed s/setLight?json=id./.myLights.lights.\"/|sed s/,/\"./)
         if [ -n "$setNumber" ]; then 
            jqPathToSetJson=$setJqPath
         else  # value is a string
            setJqPath=${setJqPath//=/=\"}
            jqPathToSetJson=$setJqPath\"
         fi
         updateMyAirDataCachedFileWithJq "$url" "$jqPathToSetJson"
         ;;
      setThing) # value for things is always a number
         jqPathToSetJson=$(echo "$setJqPath"|sed s/setThing?json=id./.myThings.things.\"/|sed s/,/\"./)
         updateMyAirDataCachedFileWithJq "$url" "$jqPathToSetJson"
         ;;
   esac
}

function updateMyAirDataCachedFileWithJq()
{
   # this script to use jq to update the $MY_AIRDATA_FILE 

   local url="$1"
   local jqPath="$2"
   local updatedMyAirData
   #
   updatedMyAirData=$(jq -ec "$jqPath" "$MY_AIRDATA_FILE")
   rc=$?
   if [ "$rc" == "0" ]; then
      echo "$updatedMyAirData" > "$MY_AIRDATA_FILE"
      logQueryAirConDiagnostic "setAirCon_setJson $t3 rc=$rc $io $device $characteristic $jqPath"
      if [ "$selfTest" = "TEST_ON" ]; then
         # For Testing, you can compare whats sent
         echo "Setting json: $jqPath"
      fi
   else
      logError "setAirCon_setJson jq failed" "$rc" "$jqPath" "" "$url"
      logQueryAirConDiagnostic "setAirCon_setJson_failed $t3 rc=$rc $io $device $characteristic $jqPath"
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
         logError "jq failed" "$rc" "$jqResult" "" "$jqPath"
         logQueryAirConDiagnostic "parseMyAirDataWithJq_failed rc=$rc jqResult=$jqResult $io $device $characteristic $jqPath"
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
      queryCachedAirCon "$url" "$exitOnFail" "$forceFetch" "$i"
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
   # Parse the first constant zone from myAirData
   parseMyAirDataWithJq ".aircons.$ac.info.constant1"
   cZone=$( printf "z%02d" "$jqResult" )
   echo "$noSensors $cZone $nZones" > "$MY_AIR_CONSTANTS_FILE"
}

function getMyAirDataFromCachedFile()
{
   # get myAirData from $MY_AIRDATA_FILE cached file

   if [ -f "$MY_AIRDATA_FILE" ]; then
      myAirData=$(cat "$MY_AIRDATA_FILE")
      if [ "$selfTest" = "TEST_ON" ]; then
         echo "Getting myAirData.txt from cached file"
      fi
   else
      queryAirConWithIterations "http://$IP:$PORT/getSystemData" false
   fi
}

function queryIdByName()
{
   local path="$1"
   local name="$2"

   # This script is to extract the ID(s) of a light by its name or a thing
   # (garage, blinds, etc) by its name
   # A name may be associated with more than 1 physcial light/thing

   local name1 name2 name3 name4
   local ids=""

   name1=$(echo "$name"|cut -d" " -f1)
   name2=$(echo "$name"|cut -d" " -f2)
   name3=$(echo "$name"|cut -d" " -f3)
   name4=$(echo "$name"|cut -d" " -f4)

   # Obtain the unique ID by its name from a MY_AIRDATA_FILE, Which is updated
   # every "Set" command or after 2 minutes of every "Get"

   # Scan for the unique IDs of lights or things by their names using jq command.
   # Each name might be associated with more than 1 light/thing hence can have
   # more than 1 ID. As such the ID(s) is/are output to an array "$idArray_g"
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
   t4=$(date '+%s')
   logQueryIdByNameDiagnostic "queryIdByName_jq $t4 rc=$rc $io path=$path $characteristic id=${ids} name=$name"

   if [ "$rc" != "0" ]; then
      logError "queryIdByName_jq failed" "$rc" "${ids}" "${path}" "$name"
      logQueryIdByNameDiagnostic "queryIdByName_jq_failed $t4 rc=$rc $io path=$path $characteristic id=${ids} name=$name"
      exit $rc
   fi

   # This is good to test for
   if [ "$selfTest" = "TEST_ON" ]; then
      echo "path: $path name: $name ids=${ids[0]}"
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
            PORT="2025"
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
            if expr "$v" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*[-a-z]*$' >/dev/null; then
               IP=$(echo "$v"|cut -d"-" -f1)
               debug=$(echo "$v"|cut -d"-" -f2)
               if [ "$debug" = "debug" ]; then debugSpecified=true; fi

               if [ "$selfTest" = "TEST_ON" ]; then
                  echo "Using IP: $IP"
                  if [ "$debugSpecified" = true ]; then
                     echo "Diagnostic log is turned on"
                  fi
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

# Create a temporary sub-directory "${tmpSubDir}" to store the temporary files
subDir=$( echo "$IP"|cut -d"." -f4 )
tmpSubDir=$( printf "${TMPDIR}/AA-%03d" "$subDir" )
if [ ! -d "${tmpSubDir}/" ]; then mkdir "${tmpSubDir}/"; fi

# Redefine temporary files with full path
QUERY_AIRCON_LOG_FILE="${tmpSubDir}/${QUERY_AIRCON_LOG_FILE}"
QUERY_IDBYNAME_LOG_FILE="${tmpSubDir}/${QUERY_IDBYNAME_LOG_FILE}"
MY_AIRDATA_FILE="${tmpSubDir}/${MY_AIRDATA_FILE}"
MY_AIR_CONSTANTS_FILE="${tmpSubDir}/${MY_AIR_CONSTANTS_FILE}.${ac}"
ZONEOPEN_FILE="${tmpSubDir}/${ZONEOPEN_FILE}.${ac}"

# Fan accessory is the only accessory without identification constant, hence
# give it an identification "fanSpecified"
if [ $zoneSpecified = false ] && [ $fanSpeed = false ] && [ $timerEnabled = false ] && [ $lightSpecified = false ] && [ $thingSpecified = false ]; then
   fanSpecified=true
fi

# For "Get" Directives
if [ "$io" = "Get" ]; then

   # Get the systemData, but not forceably
   queryAirConWithIterations "http://$IP:$PORT/getSystemData" false

   # Create a system-wide $MY_AIRDATA_CONSTANTS_FILE cache file if not present␣
   if [[ ! -f "$MY_AIR_CONSTANTS_FILE" && -f "$MY_AIRDATA_FILE" ]]; then createMyAirConstantsFile; fi

   case "$characteristic" in
      # Gets the current temperature.
      CurrentTemperature )
         # check whether Temperature Sensors are used in this system and also
         # check the constant zone for this system

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
            # Uses the set temperature as the measured temperature in lieu of
            # having sensors.
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
         parseMyAirDataWithJq ".aircons.$ac.info.state"
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
                  # Dry mode, set Thermostat to Auto Mode as a proxy.
                  echo 3
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
      # for garage door opener: get the value from MyPlace
      # (100=open, 0=close) (in Homekit 0=open, 1=close)
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
            # fanSpecified is true when no zone (z01) given or timer given
            # Updates global variable jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.state"
            if [  "$jqResult" = '"off"' ]; then
               echo 0
               exit 0
            else
               # Get the current mode of the Control Unit. Fan can only be On
               # or Off; if not Vent, set all other modes to Off.
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
            # Damper open/closed = Switch on/off = 1/0
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
            parseMyAirDataWithJq ".aircons.$ac.info.state"
            airconState=$jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.countDownToOn"
            countDownToOn=$jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.countDownToOff"
            countDownToOff=$jqResult

            if [[ "$countDownToOn" == 0 && "$countDownToOff" == 0 ]]; then
               echo 0
               exit 0
            fi
            if [[ "$countDownToOn" != 0 && "$airconState" = '"on"' ]]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOn:0}}}"
               echo 0
               exit 0
            fi
            if [[ "$countDownToOff" != 0 && "$airconState" = '"on"' ]]; then
               echo 1
               exit 0
            fi
            if [[ "$countDownToOn" != 0 && "$airconState" = '"off"' ]]; then
               echo 1
               exit 0
            fi
            if [[ "$countDownToOff" != 0 && "$airconState" = '"off"' ]]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOff:0}}}"
               echo 0
               exit 0
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
         # Get the timer setting - 10% = 1 hour
         elif [ $timerEnabled = true ]; then
            parseMyAirDataWithJq ".aircons.$ac.info.state"
            # Get the timer countDowqnToOff value if the state of the aircon is "on"
            if [ "$jqResult" = '"on"' ]; then
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOff"
               timerInPercentage=$((jqResult / 6))
               timerInPercentage=$((timerInPercentage < 100? timerInPercentage : 100)) 
               echo $timerInPercentage
               exit 0
            # Get the timer countDownToOn value if the state of the aircon is "off"
            else
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOn"
               timerInPercentage=$((jqResult / 6))
               timerInPercentage=$((timerInPercentage < 100? timerInPercentage : 100)) 
               echo $timerInPercentage
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
       ;;
      # Temperature Sensor Fault Status. Faulted if returned value is greater than 0.
      StatusFault )
         # Updates global variable jqResult
         parseMyAirDataWithJq ".aircons.$ac.zones.$zone.error"
         if [ "$jqResult" = '0' ]; then
            echo 0
         else
            echo 1
         fi
         exit 0
       ;;  # End of StatusFault
   esac
fi
# For "Set" Directives
if [ "$io" = "Set" ]; then

   # Get the systemData, requiring the latest
   # the $MY_AIRDATA_FILE cached file is maintained up to date at all time
   getMyAirDataFromCachedFile

   case "$characteristic" in
      TargetHeatingCoolingState )
         case "$value" in
            0 )
               # Shut Off Control Unit.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:off}}}"
               exit 0
            ;;
            1 )
               # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:on,mode:heat}}}"
               exit 0
            ;;
            2 )
               # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:on,mode:cool}}}"
               exit 0
            ;;
            3 )
               # Turn On Control Unit, Set Mode to Dry.  Auto mode in Homekit as a proxy to Dry mode
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:on,mode:dry}}}"
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
            setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{setTemp:$value}}}"
            exit 0
         else
            # Sets all zones to the current master thermostat's temperature value
            myAirConstants=$( cat "$MY_AIR_CONSTANTS_FILE" )
            nZones=$( echo "$myAirConstants" | awk '{print $3}' )
            setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{setTemp:$value}}}"
            for (( a=1;a<=nZones;a++ )); do
               zoneStr=$( printf "z%02d" "$a" )
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zoneStr:{setTemp:$value}}}}"
            done
            exit 0
         fi
      ;;
      TargetDoorState )
         # Set the value of the garage door (100=open, 0=close) to MyPlace,
         # (0=open, 1=close for Homekit)
         if [ $thingSpecified = true ]; then
            queryIdByName "thing" "$thingName"
            length=${#idArray_g[@]}
            if [ $flipEnabled = true ]; then value=$((value-1)); value=${value#-}; fi

            if [ "$value" = "1" ]; then
               for ((a=0;a<length;a++))
                  do
                     setAirConUsingIteration "http://$IP:$PORT/setThing?json={id:\"${idArray_g[a]}\",value:0}"
                  done
               exit 0
            else
               for ((a=0;a<length;a++))
                  do
                     setAirConUsingIteration "http://$IP:$PORT/setThing?json={id:\"${idArray_g[a]}\",value:100}"
                  done
               exit 0
            fi
         fi
      ;;
      On )
         # Uses the On characteristic for Fan/Vent mode.
         if [ $fanSpecified = true ]; then
            if [ "$value" = "1" ]; then
               # Sets Control Unit to On, sets to Fan mode aqnd fan speed will
               # default to last used.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:on,mode:vent}}}"
            else
               # Shut Off Control Unit.
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:off}}}"
            fi
            exit 0

         # Uses the On characteristic for zone switches.
         elif [ $zoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{state:open}}}}"
               exit 0
            else
               # Ensures that at least one zone is open at all time to protect
               # the aircon system before closing any zone:
               # > if the only zone open is the constant zone, leave it open and set it to 100%.
               # > if the constant zone is already closed, and the only open zone is set to close,
               #  the constant zone will open and set to 100% while closing that zone.

               # Retrieve the constant zone number of zones from from the cache file
               myAirConstants=$( cat "$MY_AIR_CONSTANTS_FILE" )
               cZone=$( echo "$myAirConstants" | awk '{print $2}' )
               nZones=$( echo "$myAirConstants" | awk '{print $3}' )

               # Check how many zones are open
               if [ -f "$ZONEOPEN_FILE" ]; then
                  getFileStatDt "$ZONEOPEN_FILE"
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
                  # Keep the number of zoneOpen in a temporary file to be used up
                  # to 10 seconds
                  echo "$zoneOpen" > "$ZONEOPEN_FILE"
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{state:close}}}}"
                  exit 0
               elif [ "$zone" = "$cZone" ]; then
                  # If only 1 zone open and is the constant zone. do not
                  # close but set to  100%
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{value:100}}}}"
                  exit 0
               else
                  # If only 1 zone open and is not the constant zone, open the
                  # constant zone to 100% and close this zone
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$cZone:{state:open}}}}"
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$cZone:{value:100}}}}"
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{state:close}}}}"
                  exit 0
               fi
            fi
         # setting the timer
         elif [ $timerEnabled = true ]; then
            if [ "$value" = "0" ]; then
               # Set both "countDownToOn" and "countDownToOff" to 0, otherwise
               # do nothing
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOn:0}}}"
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOff:0}}}"
               exit 0
            else
               # Do nothing
               exit 0
            fi
         # fanSpeed is always on, so there is no on/off function but need to issue "exit 0"
         # to let cmd4 know that action is satisfied
         elif [ $fanSpeed = true ]; then
            exit 0
         # setting the state of the light
         elif [ $lightSpecified = true ]; then
            queryIdByName "light" "$lightName"
            length=${#idArray_g[@]}
            if [ "$value" = "1" ]; then
               for ((a=0;a<length;a++))
               do
                  setAirConUsingIteration "http://$IP:$PORT/setLight?json={id:\"${idArray_g[a]}\",state:on}"
               done
               exit 0
            else
               for ((a=0;a<length;a++))
               do
                  setAirConUsingIteration "http://$IP:$PORT/setLight?json={id:\"${idArray_g[a]}\",state:off}"
               done
               exit 0
            fi
         fi
      ;;
      #Light Bulb service for used controlling damper % open and timer
      Brightness )
         if [ $zoneSpecified = true ]; then
            # Round the $value to its nearst 5%
            damper=$(($(($((value + 2)) / 5)) * 5))
            setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{value:$damper}}}}"
            exit 0
         elif [ $timerEnabled = true ]; then
            # Make 10% to 1 hour (1% = 6 minutes) and capped at a max of 600 minutes
            timerInMinutes=$((value * 6))
            parseMyAirDataWithJq ".aircons.$ac.info.state"
            if [ "$jqResult" = '"on"' ]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOff:$timerInMinutes}}}"
            else
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOn:$timerInMinutes}}}"
            fi
            exit 0

         # Set light brightness
         elif [ $lightSpecified = true ]; then
            queryIdByName "light" "$lightName"
            length=${#idArray_g[@]}
            for ((a=0;a<length;a++))
            do
               setAirConUsingIteration "http://$IP:$PORT/setLight?json={id:\"${idArray_g[a]}\",value:$value}"
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
            # 'ezfan' users have 'autoAA' and regular users have 'auto'. But
            # 'autoAA' works for all, so hardcoded to 'autoAA'
            fspeed="autoAA"
         fi
         setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{fan:$fspeed}}}"
         exit 0
      ;;
   esac
fi
echo "Unhandled $io $device $characteristic" >&2
exit 150
