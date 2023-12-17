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
PORT=""
device=""
io=""
characteristic=""
value="1"

#
# Global returned data
#
myAirData=""
jqResult=""
fanState=0
coolState=0
heatState=0
rc=1
declare -a idArray_g

#
# For optional args and arg parsing
#

# Default values
zone=""
zoneSpecified=false
myZoneSpecified=false
fanSpecified=false
fanTimerSpecified=false
coolTimerSpecified=false
heatTimerSpecified=false
argSTART=4
logErrors=true
debugSpecified=false
fanSpeed=false
sameAsCached=false
myZoneAssigned=false
fspeed="low"
lightName=""
lightID=""
thingName=""
thingID=""

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
FANTIMER_STATE_FILE="fanTimer.txt"
COOLTIMER_STATE_FILE="coolTimer.txt"
HEATTIMER_STATE_FILE="heatTimer.txt"
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
   local result="$2"
   local data1="$3"
   local data2="$4"
   local sfx
   local file
   local count
   sfx="$rc-$io-$device-$characteristic"
   sfx=${sfx// /_}
   local fileName="${tmpSubDir}/AAerror-${sfx}.txt"
   file=$(find "${fileName}"* 2>&1|grep -v find)
   #
   # append a counter to the file so that the number of same error is logged
   if [ -f "${file}" ]; then
      count=$(echo "${file}" | cut -d'#' -f2)
      count=$((count + 1))
   else
      count=1
   fi
   rm -f "${file}"
   #
   fileName="${fileName}#${count}"
   { echo "$io $device $characteristic"
     echo "${comment}"
     echo "return code: $rc"
     echo "result: $result"
     echo "data1: $data1"
     echo "data2: $data2"
   } > "$fileName"

   if [ "${io}" = "Set" ]; then
      logQueryAirConDiagnostic "Unhandled $io $device $characteristic $value rc=$rc - this accessory is most likely offline"
   elif [ "${io}" = "Get" ]; then
      logQueryAirConDiagnostic "Unhandled $io $device $characteristic rc=$rc - this accessory is most likely offline!"
   fi
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
      logQueryAirConDiagnostic "queryCachedAirCon_copy  $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"

      # To test the logic, issue this comment
      if [ "$selfTest" = "TEST_ON" ]; then
         echo "Fetching myAirData from cached file"
      fi

   elif [ "$doFetch" = true ]; then
      echo "$t0" > "$lockFile"
      queryType="curl"
      myAirData=$( curl --fail -s -g "$url")
      rc=$?
      if [ "$rc" = "0" ]; then
         #Need to parse to ensure the json file is not empty
         parseMyAirDataWithJq ".aircons.$ac.info" "${exitOnFail}"
         if [ "$rc" = "0" ]; then
            t2=$(date '+%s') 
            echo "$t2" > "$dateFile"  # overwrite $dateFile
            #if $myAirData is not the same as the cached file, overwrite it with the new $myAirData 
            if [ -f "$MY_AIRDATA_FILE" ]; then isMyAirDataSameAsCached; fi
            if [ $sameAsCached = false ]; then echo "$myAirData" > "$MY_AIRDATA_FILE"; fi
            dt=$((t2 - t0))  # time-taken for curl command to complete
            logQueryAirConDiagnostic "queryCachedAirCon_curl  $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"
         else
            echo "{}" > "$MY_AIRDATA_FILE"
            echo "$t2" > "$dateFile" 
            logQueryAirConDiagnostic "queryCachedAirCon_curl_invalid $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"
            # just in case
            unset myAirData
         fi
      else
         echo "{}" > "$MY_AIRDATA_FILE"
         echo "$t2" > "$dateFile" 
         logQueryAirConDiagnostic "queryCachedAirCon_curl_failed $t0 $t2 $dt $useFileCache rc=$rc itr=$iteration $io $device $characteristic $url"
         unset myAirData
      fi
      rm "$lockFile"

   elif [ "$doFetch" = false ]; then
      queryType="cache"
      myAirData=$( cat "$MY_AIRDATA_FILE" )
      rc=$?
   fi

   if [ "$rc" != "0" ]; then
      if [ "$exitOnFail" = "1" ]; then
         logError "getValue_${queryType} failed" "" "" "$url"
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

   if [ "$myAirData_cached" = "$myAirData" ]; then
      sameAsCached=true
      return
   elif [ "$myAirData_cached" = "{}" ]; then
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
      curlResult=$(curl --fail -s -g "$url")
      rc=$?
      curlResult=$(echo "${curlResult}" | grep false)
      if [[ "$rc" = "0" && -n "${curlResult}" ]]; then rc=5; fi 

      logQueryAirConDiagnostic "setAirCon_curl $t3 rc=$rc itr=$i $io $device $characteristic $value $url"

      if [ "$rc" = "0" ]; then
         # update $MY_AIRDATA_FILE directly instead of fetching a new copy from AdvantageAir controller after a set command
         updateMyAirDataCachedFile "$url"
         myAirData=$( cat "$MY_AIRDATA_FILE" )
         echo "$t3" > "$dateFile"
         return
      fi

      if [ "$exitOnFail" = "1" ]; then
         logQueryAirConDiagnostic "setAirCon_curl_failed $t3 rc=$rc $io $device $characteristic $value $url"
         logError "SetAirCon_curl failed" "" "$io" "$url"
         exit $rc
      fi

      sleep 1.0
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
   setNumber=$(echo "$setJqPath"|grep 'value\|setTemp\|countDownTo\|myZone')
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
   if [ "$rc" = "0" ]; then
      echo "$updatedMyAirData" > "$MY_AIRDATA_FILE"
      logQueryAirConDiagnostic "setAirCon_setJson $t3 rc=$rc $io $device $characteristic $jqPath"
      if [ "$selfTest" = "TEST_ON" ]; then
         # For Testing, you can compare whats sent
         echo "Setting json: $jqPath"
      fi
   else
      logQueryAirConDiagnostic "setAirCon_setJson_failed $t3 rc=$rc $io $device $characteristic $jqPath"
      logError "setAirCon_setJson jq failed" "$jqPath" "" "$url"
      exit $rc
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
      if [ "$selfTest" = "TEST_ON" ]; then
         # For Testing, you can compare whats sent
         echo "Parsing for jqPath failed: $jqPath";
      fi
      if [ "$exitOnFail" = "1" ]; then
         logQueryAirConDiagnostic "parseMyAirDataWithJq_failed rc=$rc jqResult=$jqResult $io $device $characteristic $jqPath"
         logError "jq failed" "$rc" "$jqResult" "" "$jqPath"
         exit $rc
      fi
   else
      if [ "$selfTest" = "TEST_ON" ]; then
         # For Testing, you can compare whats sent
         echo "Parsing for jqPath: $jqPath";
      fi
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
      logQueryIdByNameDiagnostic "queryIdByName_jq_failed $t4 rc=$rc $io path=$path $characteristic id=${ids} name=$name"
      logError "queryIdByName_jq failed" "${ids}" "${path}" "$name"
      if [ "$selfTest" = "TEST_ON" ]; then
         echo "Parsing id for \"$path:$name\" failed"
      fi
      exit $rc
   fi

   # This is good to test for
   if [ "$selfTest" = "TEST_ON" ]; then
      echo "path: $path name: $name ids=${ids[0]}"
   fi
}

function openZoneInFullWithZoneOpenCounter()
{
   Zone="$1"
   setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$Zone:{state:open}}}}"
   # update the number of zoneOpen in a temporary file to be used up to 10 seconds
   zoneOpen=$((zoneOpen + 1))
   echo "$zoneOpen" > "$ZONEOPEN_FILE"
   parseMyAirDataWithJq ".aircons.$ac.zones.${Zone}.rssi" "1"
   if [ "${jqResult}"  = "0" ]; then
      setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$Zone:{value:100}}}}"
   fi
}

function closeZoneWithZoneOpenCounter()
{
   Zone="$1"
   setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$Zone:{state:close}}}}"
   # update the number of zoneOpen in a temporary file to be used up to 10 seconds
   zoneOpen=$((zoneOpen - 1))
   echo "$zoneOpen" > "$ZONEOPEN_FILE"
}

function setMyZoneToAnOpenedZoneWithTempSensorWithPriorityToCzones()
{
   # set myZone to an open zone with priority to an open cZone.  
   # Note: this routine is only called for the case where zoneOpen > noOfConstants.

   for cZone in $cZone1 $cZone2 $cZone3; do
      if [[ "${cZone}" != "z00" && "${cZone}" != "${zone}" ]]; then
         parseMyAirDataWithJq ".aircons.$ac.zones.${cZone}.state" "1"
         if [ "${jqResult}" = '"open"' ]; then
            parseMyAirDataWithJq ".aircons.$ac.zones.${cZone}.rssi" "1"
            if [ "${jqResult}" != "0" ]; then
               myZone="${cZone}"
               myZoneValue=$((10#$( echo "${myZone}" | cut -d"z" -f2 ))) 
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{myZone:$myZoneValue}}}"
               myZoneAssigned=true
               return
            fi
         fi
      fi
   done

   # if all cZones are closed then assign myZone to a next open zone
   for ((Zone=1; Zone<=nZones; Zone++)); do
      ZoneStr=$( printf "z%02d" "${Zone}" )
      if [[ "${ZoneStr}" != "${zone}" && "${ZoneStr}" != "${cZone1}" && "${ZoneStr}" != "${cZone2}" && "${ZoneStr}" != "${cZone3}" ]]; then
         parseMyAirDataWithJq ".aircons.$ac.zones.${ZoneStr}.state" "1"
         if [ "${jqResult}" = '"open"' ]; then
            parseMyAirDataWithJq ".aircons.$ac.zones.${ZoneStr}.rssi" "1"
            if [ "${jqResult}" != "0" ]; then
               myZone="${ZoneStr}"
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{myZone:$Zone}}}"
               myZoneAssigned=true
               return
            fi
         fi
      fi
   done
}

function openAclosedCzone()
{
   # Open up a closed cZone 
   # Note: this routine is only called for the case where zoneOpen = noOfConstants.

   for cZone in $cZone1 $cZone2 $cZone3; do
      if [ "${cZone}" != "z00" ]; then
         parseMyAirDataWithJq ".aircons.$ac.zones.${cZone}.state" "1"
         if [ "${jqResult}" = '"close"' ]; then
            openZoneInFullWithZoneOpenCounter "${cZone}"
            return
         fi
      fi
   done
}

function openAclosedZoneWithTempSensorWithPriorityToCzones()
{
   # Open up a closed zone with temperature sensor

   for cZone in $cZone1 $cZone2 $cZone3; do
      if [[ "${cZone}" != "z00" && "${cZone}" != "${zone}" ]]; then
         parseMyAirDataWithJq ".aircons.$ac.zones.${cZone}.state" "1"
         if [ "${jqResult}" = '"close"' ]; then
            parseMyAirDataWithJq ".aircons.$ac.zones.${cZone}.rssi" "1"
            if [ "${jqResult}" != "0" ]; then
               openZoneInFullWithZoneOpenCounter "${cZone}"
               return
            fi
         fi
      fi
   done

   for ((Zone=1; Zone<=nZones; Zone++)); do
      ZoneStr=$( printf "z%02d" "${Zone}" )
      if [[ "${ZoneStr}" != "${zone}" && "${ZoneStr}" != "${cZone1}" && "${ZoneStr}" != "${cZone2}" && "${ZoneStr}" != "${cZone3}" ]]; then
         parseMyAirDataWithJq ".aircons.$ac.zones.${ZoneStr}.state" "1"
         if [ "${jqResult}" = '"close"' ]; then
            parseMyAirDataWithJq ".aircons.$ac.zones.${ZoneStr}.rssi" "1"
            if [ "${jqResult}" != "0" ]; then
               openZoneInFullWithZoneOpenCounter "${ZoneStr}"
               return
            fi
         fi
      fi
   done
}

function queryTimerStateFile()
{
   TIMER_STATE_FILE="$1"

   if [ -f "${TIMER_STATE_FILE}" ]; then
      state=$(cat "${TIMER_STATE_FILE}")
      rc=$?
   else
      state="{\"timeToOn\":0,\"timeToOff\":0,\"setTime\":0}"
      rc=$?
      echo "$state" > "$TIMER_STATE_FILE"
   fi

   if [ "$selfTest" = "TEST_ON" ]; then
      echo "Query the state file: ${TIMER_STATE_FILE}"
   fi

   timeToOn=$(echo "$state" | jq -e ".timeToOn")
   timeToOff=$(echo "$state" | jq -e ".timeToOff")
   setTime=$(echo "$state" | jq -e ".setTime")

   # Get the current state of the fan
   parseMyAirDataWithJq ".aircons.$ac.info.state" "1"
   acState="${jqResult}"
   parseMyAirDataWithJq ".aircons.$ac.info.mode" "1"
   acMode="${jqResult}"
   if [ $fanTimerSpecified = true ]; then
      if [[ "${acState}" = '"on"' && "${acMode}" = '"vent"' ]]; then
         fanState=1
      else
         fanState=0
      fi
      logQueryAirConDiagnostic "queryFanTimer           ${t0} ${t0} fanState=${fanState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   elif [ $coolTimerSpecified = true ]; then
      if [[ "${acState}" = '"on"' && "${acMode}" = '"cool"' ]]; then
         coolState=1
      else
         coolState=0
      fi
      logQueryAirConDiagnostic "queryCoolTimer          ${t0} ${t0} coolState=${coolState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   elif [ $heatTimerSpecified = true ]; then
      if [[ "${acState}" = '"on"' && "${acMode}" = '"heat"' ]]; then
         heatState=1
      else
         heatState=0
      fi
      logQueryAirConDiagnostic "queryHeatTimer          ${t0} ${t0} heatState=${heatState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   fi
}

function updateTimer()
{
   State="$1"
   Mode="$2"
   TIMER_STATE_FILE="$3"

   if [ "$selfTest" = "TEST_ON" ]; then
      t0=$((setTime + 2)) 
   fi

   # Update fan timer
   if [[ "$timeToOn" = "0" && "$timeToOff" = "0" ]]; then # no update required
      echo ""
      return
   elif [[ "${State}" = "1" && "${timeToOn}" != "0" ]]; then # reset timer
      timeToOn=0
      setTime=${t0}
   elif [[ "${State}" = "1" && "$timeToOff" != "0" ]]; then # update timer
      timeToOff=$((timeToOff - t0 + setTime))
      timeToOff=$((timeToOff > 30? timeToOff : 0))
      setTime=${t0}
      if [ "$timeToOff" = "0" ]; then # turn off the fan
         setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:off}}}"
      fi
   elif [[ "${State}" = "0" && "$timeToOff" != "0" ]]; then # reset timer
      timeToOff=0
      setTime=${t0}
   elif [[ "${State}" = "0" && "$timeToOn" != "0" ]]; then # update timer
      timeToOn=$((timeToOn - t0 + setTime))
      timeToOn=$((timeToOn > 30? timeToOn : 0))
      setTime=${t0}
      if [ "$timeToOn" = "0" ]; then # turn on the fan, cool or heat
         setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{state:on,mode:$Mode}}}"
      fi
   fi

   if [ "$selfTest" = "TEST_ON" ]; then
      echo "Update the timer for ${Mode} with timeToOn: ${timeToOn} and timeToOff: ${timeToOff}" 
   fi

   # Diagnostic logging
   if [ $fanTimerSpecified = true ]; then
      logQueryAirConDiagnostic "updateFanTimer          ${t0} ${t0} fanState=${fanState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   elif [ $coolTimerSpecified = true ]; then
      logQueryAirConDiagnostic "updateCoolTimer         ${t0} ${t0} coolState=${coolState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   elif [ $heatTimerSpecified = true ]; then
      logQueryAirConDiagnostic "updateHeatTimer         ${t0} ${t0} heatState=${heatState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   fi

   updateTimerStateFile "${TIMER_STATE_FILE}"
}

function updateTimerStateFile()
{
   TIMER_STATE_FILE="$1"

   updatedState=$(jq -ec ".timeToOn=$timeToOn" "$TIMER_STATE_FILE" | jq -ec ".timeToOff=$timeToOff" | jq -ec ".setTime=$setTime")
   rc=$?
   echo "$updatedState" > "$TIMER_STATE_FILE"

   # Diagnostic logging
   if [ "${io}" = "Get" ]; then
      prefix="update"
      space=""
   else
      prefix="set"
      space="e  "
   fi

   if [ "$selfTest" = "TEST_ON" ]; then
      echo "Update the timer state file: ${TIMER_STATE_FILE} with timeToOn: ${timeToOn} and timeToOff: ${timeToOff}" 
   fi

   if [ $fanTimerSpecified = true ]; then
      logQueryAirConDiagnostic "${prefix}FanTimerStateFil${space}  ${t0} ${t0} fanState=${fanState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   elif [ $coolTimerSpecified = true ]; then
      logQueryAirConDiagnostic "${prefix}CoolTimerStateFil${space} ${t0} ${t0} coolState=${coolState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
   elif [ $heatTimerSpecified = true ]; then
      logQueryAirConDiagnostic "${prefix}HeatTimerStateFil${space} ${t0} ${t0} heatState=${heatState} ${timeToOn} ${timeToOff} ${setTime} $io $device $characteristic"
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
   elif [[ "$io" = "Set" ]]; then
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
         fanTimer )
            fanTimerSpecified=true
            optionUnderstood=true
            ;;
         coolTimer )
            coolTimerSpecified=true
            optionUnderstood=true
            ;;
         heatTimer )
            heatTimerSpecified=true
            optionUnderstood=true
            ;;
         flip)
            # To flip open/close, up/down mode for garage or gate
            flipEnabled=true
            optionUnderstood=true
            ;;
         myZone=*)
            # For myZone setting                                 
            myZoneSpecified=true
            myZoneValue=$(echo "$v" | cut -d"=" -f2)
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
            # See if the option starts with a "light" or "ligID" for lightings
            #
            first5=${v:0:5}
            if [ "$first5" = light ]; then
               lightName="${device}"
               lightSpecified=true
               optionUnderstood=true
            elif [ "$first5" = ligID ]; then
               lightID="${v:6:7}"
               lightName="${device}"
               lightSpecified=true
               optionUnderstood=true
            fi
            #
            # See if the option starts with a "thing" or "thiID" for garage, blinds, etc
            #
            if [ "$first5" = thing ]; then
               thingName="${device}"
               thingSpecified=true
               optionUnderstood=true
            elif [ "$first5" = thiID ]; then
               thingID="${v:6:7}"
               thingName="${device}"
               thingSpecified=true
               optionUnderstood=true
            fi
            #
            # See if the option is in the format of an IP
            #
            if expr "$v" : '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*[:0-9]*[-a-z]*$' >/dev/null; then
               IP=$(echo "$v"|cut -d":" -f1|cut -d"-" -f1)
               PORT=$(echo "$v"|cut -d":" -f2)
               if ! expr "$PORT" : '[0-9]*$' > /dev/null; then
                  PORT=2025
               fi
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
FANTIMER_STATE_FILE="${tmpSubDir}/${FANTIMER_STATE_FILE}.${ac}"
COOLTIMER_STATE_FILE="${tmpSubDir}/${COOLTIMER_STATE_FILE}.${ac}"
HEATTIMER_STATE_FILE="${tmpSubDir}/${HEATTIMER_STATE_FILE}.${ac}"
ZONEOPEN_FILE="${tmpSubDir}/${ZONEOPEN_FILE}.${ac}"

# Fan accessory is the only accessory without identification constant, hence
# give it an identification "fanSpecified"
if [[ $myZoneSpecified = false && $zoneSpecified = false && $fanSpeed = false && $timerEnabled = false && $lightSpecified = false && $thingSpecified = false && $fanTimerSpecified = false && $coolTimerSpecified = false && $heatTimerSpecified = false ]]; then
   fanSpecified=true
fi

# set the current time
t0=$(date '+%s')

# For "Get" Directives
if [ "$io" = "Get" ]; then

   # Get the systemData, but not forcefully
   queryAirConWithIterations "http://$IP:$PORT/getSystemData" false

   case "$characteristic" in
      # Gets the current temperature.
      CurrentTemperature )
         # check whether a zone is defined, if so, use the measuredTemp of this zone
         # if not, check myZone is defined, if so, use the measuredTemp of myZone 
         # if not, check rssi is defined for cZone1, if so, use measuredTemp of cZone1 
         # if not again, use setTemp   

         if [ $zoneSpecified = true ]; then
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.measuredTemp" "1"
            echo "$jqResult"
            exit 0
         fi
         parseMyAirDataWithJq ".aircons.$ac.info.myZone" "1"
         myZone=$( printf "z%02d" "$jqResult" )
         if [ "${myZone}" != "z00" ]; then 
            parseMyAirDataWithJq ".aircons.$ac.zones.$myZone.measuredTemp" "1"
            echo "$jqResult"
            exit 0
         fi
         parseMyAirDataWithJq ".aircons.$ac.info.constant1" "1"
         cZone1=$( printf "z%02d" "$jqResult" )
         parseMyAirDataWithJq ".aircons.$ac.zones.$cZone1.rssi" "1"
         if [ "${jqResult}" != "0" ]; then
            parseMyAirDataWithJq ".aircons.$ac.zones.$cZone1.measuredTemp" "1"
            echo "$jqResult"
            exit 0
         else 
            parseMyAirDataWithJq ".aircons.$ac.info.setTemp" "1"
            echo "$jqResult"
            exit 0
         fi
      ;;
      # Gets the target temperature.
      TargetTemperature )
         # Updates global variable jqResult
         parseMyAirDataWithJq ".aircons.$ac.info.myZone" "1"
         myZone=$( printf "z%02d" "$jqResult" )
         if [ "${myZone}" != "z00" ]; then 
            parseMyAirDataWithJq ".aircons.$ac.zones.$myZone.setTemp" "1"
            echo "$jqResult"
            exit 0
         else
            parseMyAirDataWithJq ".aircons.$ac.info.setTemp" "1"
            echo "$jqResult"
            exit 0
         fi
      ;;
      # Makes the target Control Unit state the current Control Unit state.
      TargetHeatingCoolingState | CurrentHeatingCoolingState )
         # Set to Off if the zone is closed or the Control Unit is Off.
         # Updates global variable jqResult
         parseMyAirDataWithJq ".aircons.$ac.info.state" "1"
         if [  "$jqResult" = '"off"' ]; then
            echo 0
            exit 0
         else
            # Get the current mode of the Control Unit. Off=0, Heat=1, Cool=2.
            # Updates global variable jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.mode" "1"
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
            if [ -z "${thingID}" ]; then
               queryIdByName "thing" "$thingName"
            else
               eval "idArray_g=(${thingID})"
            fi
            parseMyAirDataWithJq ".myThings.things.\"${idArray_g[0]}\".value" "1"
            if [ "$jqResult" = 100 ]; then
               if [ $flipEnabled = true ]; then echo 1; else echo 0; fi
               exit 0
            else
               if [ $flipEnabled = true ]; then echo 0; else echo 1; fi
               exit 0
            fi
         fi
      ;;
      Active )
         # use Fanv2 Active characteristic for zone open or close
         if [ $zoneSpecified = true ]; then
            # Damper open/closed = Switch on/off = 1/0
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.state" "1"
            if [ "$jqResult" = '"open"' ]; then
               echo 1
               exit 0
            else
               echo 0
               exit 0
            fi
         fi
      ;;
      SwingMode )
         # use Fanv2 SwingMode characteristic for myZone open or close
         if [ $zoneSpecified = true ]; then
            # Check which zone is myZone
            myZoneValue=$(( 10#$( echo "${zone}" | cut -d'z' -f2 ) ))
            parseMyAirDataWithJq ".aircons.$ac.info.myZone" "1"
            if [ "$jqResult" = "$myZoneValue" ]; then
               echo 1
               exit 0
            else
               echo 0
               exit 0
            fi
         fi
      ;;
      On )
         if [ $fanSpecified = true ]; then
            # Return value of Off if the zone is closed or the Control Unit is Off.
            # fanSpecified is true when no zone (z01) given or timer given
            # Updates global variable jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.state" "1"
            if [  "$jqResult" = '"off"' ]; then
               echo 0
               exit 0
            else
               # Get the current mode of the Control Unit. Fan can only be On
               # or Off; if not Vent, set all other modes to Off.
               # Updates global variable jqResult
               parseMyAirDataWithJq ".aircons.$ac.info.mode" "1"
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
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.state" "1"
            if [ "$jqResult" = '"open"' ]; then
               echo 1
               exit 0
            else
               echo 0
               exit 0
            fi
         elif [ $myZoneSpecified = true ]; then
            # Check which zone is myZone               
            parseMyAirDataWithJq ".aircons.$ac.info.myZone" "1"
            if [ "$jqResult" = "$myZoneValue" ]; then
               echo 1
               exit 0
            else
               echo 0
               exit 0
            fi
         # get the fan timer current setting
         elif [ $fanTimerSpecified = true ]; then
            queryTimerStateFile "${FANTIMER_STATE_FILE}"
            if [[ "$timeToOn" = "0" && "$timeToOff" = "0" ]]; then
               echo 0
               exit 0
            elif [[ "$fanState" = "1" && "$timeToOff" != "0" ]]; then
               echo 1
               exit 0
            elif [[ "$fanState" = "0" && "$timeToOn" != "0" ]]; then
               echo 1
               exit 0
            fi
         # get the cool timer current setting
         elif [ $coolTimerSpecified = true ]; then
            queryTimerStateFile "${COOLTIMER_STATE_FILE}"
            if [[ "$timeToOn" = "0" && "$timeToOff" = "0" ]]; then
               echo 0
               exit 0
            elif [[ "$coolState" = "1" && "$timeToOff" != "0" ]]; then
               echo 1
               exit 0
            elif [[ "$coolState" = "0" && "$timeToOn" != "0" ]]; then
               echo 1
               exit 0
            fi
         # get the heat timer current setting
         elif [ $heatTimerSpecified = true ]; then
            queryTimerStateFile "${HEATTIMER_STATE_FILE}"
            if [[ "$timeToOn" = "0" && "$timeToOff" = "0" ]]; then
               echo 0
               exit 0
            elif [[ "$heatState" = "1" && "$timeToOff" != "0" ]]; then
               echo 1
               exit 0
            elif [[ "$heatState" = "0" && "$timeToOn" != "0" ]]; then
               echo 1
               exit 0
            fi
         # get the timer current setting
         elif [ $timerEnabled = true ]; then
            parseMyAirDataWithJq ".aircons.$ac.info.state" "1"
            airconState=$jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.countDownToOn" "1"
            countDownToOn=$jqResult
            parseMyAirDataWithJq ".aircons.$ac.info.countDownToOff" "1"
            countDownToOff=$jqResult

            if [[ "$countDownToOn" = "0" && "$countDownToOff" = "0" ]]; then
               echo 0
               exit 0
            fi
            if [[ "$countDownToOn" != "0" && "$airconState" = '"on"' ]]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOn:0}}}"
               echo 0
               exit 0
            fi
            if [[ "$countDownToOff" != "0" && "$airconState" = '"on"' ]]; then
               echo 1
               exit 0
            fi
            if [[ "$countDownToOn" != "0" && "$airconState" = '"off"' ]]; then
               echo 1
               exit 0
            fi
            if [[ "$countDownToOff" != "0" && "$airconState" = '"off"' ]]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOff:0}}}"
               echo 0
               exit 0
            fi
         elif [ $fanSpeed = true ]; then
            # Set the "Fan Speed" accessory to "on" at all time
               echo 1
               exit 0
         elif [ $lightSpecified = true ]; then
            if [ -z "${lightID}" ]; then 
               queryIdByName "light" "$lightName"
            else
               eval "idArray_g=(${lightID})"
            fi
            parseMyAirDataWithJq ".myLights.lights.\"${idArray_g[0]}\".state" "1"
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
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.value" "1"
            echo "$jqResult"
            exit 0
         # Get the fan timer setting - 10% = 1 hour
         elif [ $fanTimerSpecified = true ]; then
            queryTimerStateFile "${FANTIMER_STATE_FILE}"
            updateTimer "${fanState}" "vent" "${FANTIMER_STATE_FILE}"
            value=$((timeToOn > timeToOff? timeToOn : timeToOff))
            value=$(((value / 360) + (value % 360 > 0)))
            echo $((value > 1? value : 1))
            exit 0
         # Get the cool timer setting - 10% = 1 hour
         elif [ $coolTimerSpecified = true ]; then
            queryTimerStateFile "${COOLTIMER_STATE_FILE}"
            updateTimer "${coolState}" "cool" "${COOLTIMER_STATE_FILE}"
            value=$((timeToOn > timeToOff? timeToOn : timeToOff))
            value=$(((value / 360) + (value % 360 > 0)))
            echo $((value > 1? value : 1))
            exit 0
         # Get the heat timer setting - 10% = 1 hour
         elif [ $heatTimerSpecified = true ]; then
            queryTimerStateFile "${HEATTIMER_STATE_FILE}"
            updateTimer "${heatState}" "heat" "${HEATTIMER_STATE_FILE}"
            value=$((timeToOn > timeToOff? timeToOn : timeToOff))
            value=$(((value / 360) + (value % 360 > 0)))
            echo $((value > 1? value : 1))
            exit 0
         # Get the AA timer setting - 10% = 1 hour
         elif [ $timerEnabled = true ]; then
            parseMyAirDataWithJq ".aircons.$ac.info.state" "1"
            # Get the timer countDowqnToOff value if the state of the aircon is "on"
            if [ "$jqResult" = '"on"' ]; then
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOff" "1"
               timerInPercentage=$(((jqResult / 6) + (jqResult % 6 > 0)))
               timerInPercentage=$((timerInPercentage < 100? timerInPercentage : 100)) 
               echo $((timerInPercentage > 1? timerInPercentage : 1))
               exit 0
            # Get the timer countDownToOn value if the state of the aircon is "off"
            else
               parseMyAirDataWithJq ".aircons.$ac.info.countDownToOn" "1"
               timerInPercentage=$(((jqResult / 6) + (jqResult % 6 > 0)))
               timerInPercentage=$((timerInPercentage < 100? timerInPercentage : 100)) 
               echo $timerInPercentage
               exit 0
            fi
         # get the lights dim level
         elif [ $lightSpecified = true ]; then
            if [ -z "${lightID}" ]; then
               queryIdByName "light" "$lightName"
            else
               eval "idArray_g=(${lightID})"
            fi
            parseMyAirDataWithJq ".myLights.lights.\"${idArray_g[0]}\".value" "1"
            echo "$jqResult"
            exit 0
         fi
      ;;
      # Fan service for controlling fan speed (low, medium and high)
      RotationSpeed )
         # get the zone damper % information
         if [ $zoneSpecified = true ]; then
            # Get the zone damper % open
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.value" "1"
            echo "$jqResult"
            exit 0
         else
            # Update the current fan speed
            parseMyAirDataWithJq ".aircons.$ac.info.fan" "1"
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
         fi
      ;;
      #Temp Sensor Fault Status = no fault/fault = 0/1-2
      StatusLowBattery )
         # Updates global variable jqResult
         parseMyAirDataWithJq ".aircons.$ac.zones.$zone.error" "1"
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
         parseMyAirDataWithJq ".aircons.$ac.zones.$zone.error" "1"
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
         setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{setTemp:$value}}}"
         # if myZone is defined, set the target temperature to the defined myZone
         parseMyAirDataWithJq ".aircons.$ac.info.myZone" "1"
         myZone=$( printf "z%02d" "$jqResult" )
         if [ "${myZone}" != "z00" ]; then 
            setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$myZone:{setTemp:$value}}}}"
         else
            # if myZone is not defined, set the target temperature to all zones with temperature sensors
            parseMyAirDataWithJq ".aircons.$ac.info.noOfZones" "1"
            nZones="${jqResult}"
            for (( a=1;a<=nZones;a++ )); do
               zoneStr=$( printf "z%02d" "$a" )
               parseMyAirDataWithJq ".aircons.$ac.zones.$zoneStr.rssi" "1"
               rssi="${jqResult}"
               if [ "${rssi}" != "0" ]; then
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zoneStr:{setTemp:$value}}}}"
               fi
            done
         fi
         exit 0
      ;;
      TargetDoorState )
         # Set the value of the garage door (100=open, 0=close) to MyPlace,
         # (0=open, 1=close for Homekit)
         if [ $thingSpecified = true ]; then
            if [ -z "${thingID}" ]; then
               queryIdByName "thing" "$thingName"
            else
               eval "idArray_g=(${thingID})"
            fi
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
      Active )
         # Uses the Fanv2 Active characteristic for zone switches.
         if [ $zoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{state:open}}}}"
               rm -f "$ZONEOPEN_FILE"
               exit 0
            else
               # Ensures that at least ${noOfConstants} zone is/are open at all time to protect
               # the aircon system before closing any zone:
               # > if the only zone(s) open is/are the constant zone(s), leave it open (and set it to 100%).
               # > if the constant zone(s) is/are in close state, and to close this zone will reduce the number
               # > of zones open below ${noOfConstants}, then one constant zone will open (and set to 100%) before
               # > closing this zone.

               # retrieve myZone, nZones, noOfConstants, cZone1, cZone2 and cZone3 from $myAirData
               parseMyAirDataWithJq ".aircons.$ac.info.myZone" "1"
               myZone=$( printf "z%02d" "$jqResult" )
               parseMyAirDataWithJq ".aircons.$ac.info.noOfZones" "1"
               nZones="${jqResult}"
               parseMyAirDataWithJq ".aircons.$ac.info.noOfConstants" "1"
               noOfConstants="${jqResult}"
               parseMyAirDataWithJq ".aircons.$ac.info.constant1" "1"
               cZone1=$( printf "z%02d" "$jqResult" )
               parseMyAirDataWithJq ".aircons.$ac.info.constant2" "1"
               cZone2=$( printf "z%02d" "$jqResult" )
               parseMyAirDataWithJq ".aircons.$ac.info.constant3" "1"
               cZone3=$( printf "z%02d" "$jqResult" )

               # Check how many zones are currently open
               if [ -f "$ZONEOPEN_FILE" ]; then
                  getFileStatDt "$ZONEOPEN_FILE"
                  if [ "$dt" -ge 10 ]; then rm "$ZONEOPEN_FILE"; fi
               fi
               if [ -f "$ZONEOPEN_FILE" ]; then
                  zoneOpen=$( cat "$ZONEOPEN_FILE" )
               else
                  for (( a=1;a<=nZones;a++ ))
                  do
                     zoneStr=$( printf "z%02d" "$a" )
                     parseMyAirDataWithJq ".aircons.$ac.zones.$zoneStr.state" "1"
                     if [ "$jqResult" = '"open"' ]; then
                        zoneOpen=$((zoneOpen + 1))
                     fi
                  done
               fi

               if [ "$zoneOpen" -gt "${noOfConstants}" ]; then
                  # If there are more than "$noOfConstants" zones open, it is safe to close this zone.
                  # BUT if this zone is myZone then set myZone to an open cZone or if all cZones are
                  # closed, set myZone to a next open zone before closing this zone.
                  if [ "${zone}" = "${myZone}" ]; then
                     setMyZoneToAnOpenedZoneWithTempSensorWithPriorityToCzones
                     if [ "$myZoneAssigned" = false ]; then
                        openAclosedZoneWithTempSensorWithPriorityToCzones
                        setMyZoneToAnOpenedZoneWithTempSensorWithPriorityToCzones
                     fi
                  fi
                  closeZoneWithZoneOpenCounter "${zone}"
                  exit 0
               elif [[ "$zone" = "$cZone1" || "$zone" = "$cZone2" || "$zone" = "$cZone3" ]]; then
                  # If only "$noOfConstants" zones open and the zone to close is one of the constant zones, do not
                  # close but set to 100%
                  parseMyAirDataWithJq ".aircons.$ac.zones.$zone.rssi" "1"
                  if [ "${jqResult}" = "0" ]; then
                     setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{value:100}}}}"
                  fi
                  exit 0
               else
                  # If only "$noOfConstants" zones open and the zone to close is not a cZone but a myZone, then open a
                  # closed zone with temperature sensor with priority to cZones and set myZone to it before closing this
                  # zone. If the zone to close is also not a myZone, then just open a closed cZone before closing this zone.
                  if [ "${zone}" = "${myZone}" ]; then
                     openAclosedZoneWithTempSensorWithPriorityToCzones
                     setMyZoneToAnOpenedZoneWithTempSensorWithPriorityToCzones
                  else
                     openAclosedCzone
                  fi
                  closeZoneWithZoneOpenCounter "${zone}"
                  exit 0
               fi
            fi
         fi
      ;;
      SwingMode )
         # Uses the Fanv2 SwingMode characteristic for myZone switches.
         if [ $zoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               # Before setting myZone open the zone if it is currently closed
               myZoneValue=$(( 10#$( echo "${zone}" | cut -d'z' -f2 ) ))
               parseMyAirDataWithJq ".aircons.$ac.zones.$zone.state" "1"
               if [ "${jqResult}" = '"close"' ]; then
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{state:open}}}}"
               fi
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{myZone:$myZoneValue}}}"
               # when the myZone is changed, update the setTemp of the aircon to be same as active myZone
               parseMyAirDataWithJq ".aircons.$ac.zones.$zone.setTemp" "1"
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{setTemp:$jqResult}}}"
               exit 0
            else
               # do nothing
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

         # Uses the On characteristic for myZone switches.
         elif [ $myZoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               # Before setting myZone open the zone if it is currently closed
               zone=$( printf "z%02d" "${myZoneValue}" )
               parseMyAirDataWithJq ".aircons.$ac.zones.$zone.state" "1"
               if [ "${jqResult}" = '"close"' ]; then
                  setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{state:open}}}}"
               fi
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{myZone:$myZoneValue}}}"
               # when the myZone is changed, update the setTemp of the aircon to be same as active myZone
               parseMyAirDataWithJq ".aircons.$ac.zones.$zone.setTemp" "1"
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{setTemp:$jqResult}}}"
               exit 0
            else
               # do nothing
               exit 0
            fi  
              
         # Uses the On characteristic for zone switches.
         elif [ $zoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{state:open}}}}"
               rm -f "$ZONEOPEN_FILE"
               exit 0
            else
               # Ensures that at least ${noOfConstants} zone is/are open at all time to protect
               # the aircon system before closing any zone:
               # > if the only zone(s) open is/are the constant zone(s), leave it open (and set it to 100%).
               # > if the constant zone(s) is/are in close state, and to close this zone will reduce the number
               # > of zones open below ${noOfConstants}, then one constant zone will open (and set to 100%) before 
               # > closing this zone.

               # retrieve myZone, nZones, noOfConstants, cZone1, cZone2 and cZone3 from $myAirData
               parseMyAirDataWithJq ".aircons.$ac.info.myZone" "1"
               myZone=$( printf "z%02d" "$jqResult" )
               parseMyAirDataWithJq ".aircons.$ac.info.noOfZones" "1"
               nZones="${jqResult}"
               parseMyAirDataWithJq ".aircons.$ac.info.noOfConstants" "1"
               noOfConstants="${jqResult}"
               parseMyAirDataWithJq ".aircons.$ac.info.constant1" "1"
               cZone1=$( printf "z%02d" "$jqResult" )
               parseMyAirDataWithJq ".aircons.$ac.info.constant2" "1"
               cZone2=$( printf "z%02d" "$jqResult" )
               parseMyAirDataWithJq ".aircons.$ac.info.constant3" "1"
               cZone3=$( printf "z%02d" "$jqResult" )

               # Check how many zones are currently open
               if [ -f "$ZONEOPEN_FILE" ]; then
                  getFileStatDt "$ZONEOPEN_FILE"
                  if [ "$dt" -ge 10 ]; then rm "$ZONEOPEN_FILE"; fi
               fi
               if [ -f "$ZONEOPEN_FILE" ]; then
                  zoneOpen=$( cat "$ZONEOPEN_FILE" )
               else
                  for (( a=1;a<=nZones;a++ ))
                  do
                     zoneStr=$( printf "z%02d" "$a" )
                     parseMyAirDataWithJq ".aircons.$ac.zones.$zoneStr.state" "1"
                     if [ "$jqResult" = '"open"' ]; then
                        zoneOpen=$((zoneOpen + 1))
                     fi
                  done
               fi

               if [ "$zoneOpen" -gt "${noOfConstants}" ]; then
                  # If there are more than "$noOfConstants" zones open, it is safe to close this zone.
                  # BUT if this zone is myZone then set myZone to an open cZone or if all cZones are
                  # closed, set myZone to a next open zone before closing this zone.
                  if [ "${zone}" = "${myZone}" ]; then 
                     setMyZoneToAnOpenedZoneWithTempSensorWithPriorityToCzones
                     if [ "$myZoneAssigned" = false ]; then
                        openAclosedZoneWithTempSensorWithPriorityToCzones
                        setMyZoneToAnOpenedZoneWithTempSensorWithPriorityToCzones
                     fi
                  fi
                  closeZoneWithZoneOpenCounter "${zone}"
                  exit 0
               elif [[ "$zone" = "$cZone1" || "$zone" = "$cZone2" || "$zone" = "$cZone3" ]]; then
                  # If only "$noOfConstants" zones open and the zone to close is one of the constant zones, do not
                  # close but set to 100%
                  parseMyAirDataWithJq ".aircons.$ac.zones.$zone.rssi" "1"
                  if [ "${jqResult}" = "0" ]; then
                     setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{value:100}}}}"
                  fi
                  exit 0
               else
                  # If only "$noOfConstants" zones open and the zone to close is not a cZone but a myZone, then open a
                  # closed zone with temperature sensor with priority to cZones and set myZone to it before closing this
                  # zone. If the zone to close is also not a myZone, then just open a closed cZone before closing this zone. 
                  if [ "${zone}" = "${myZone}" ]; then 
                     openAclosedZoneWithTempSensorWithPriorityToCzones
                     setMyZoneToAnOpenedZoneWithTempSensorWithPriorityToCzones
                  else
                     openAclosedCzone
                  fi
                  closeZoneWithZoneOpenCounter "${zone}"
                  exit 0
               fi
            fi
         # setting the fan timer
         elif [ $fanTimerSpecified = true ]; then
            if [ "$value" = "1" ]; then # do nothing
               exit 0
            else
               fanState=0
               timeToOn=0
               timeToOff=0
               setTime=${t0}
               updateTimerStateFile "${FANTIMER_STATE_FILE}"
               exit 0
            fi
         # setting the cool timer
         elif [ $coolTimerSpecified = true ]; then
            if [ "$value" = "1" ]; then # do nothing
               exit 0
            else
               fanState=0
               timeToOn=0
               timeToOff=0
               setTime=${t0}
               updateTimerStateFile "${COOLTIMER_STATE_FILE}"
               exit 0
            fi
         # setting the heat timer
         elif [ $heatTimerSpecified = true ]; then
            if [ "$value" = "1" ]; then # do nothing
               exit 0
            else
               fanState=0
               timeToOn=0
               timeToOff=0
               setTime=${t0}
               updateTimerStateFile "${HEATTIMER_STATE_FILE}"
               exit 0
            fi
         # setting the AA timer
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
            if [ -z "${lightID}" ]; then
               queryIdByName "light" "$lightName"
            else
               eval "idArray_g=(${lightID})"
            fi
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
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.rssi" "1"
            rssi="${jqResult}"
            if [ "${rssi}" = "0" ]; then
               # Round the $value to its nearest 5%
               damper=$(($(($((value + 2)) / 5)) * 5))
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{value:$damper}}}}"
            fi
            exit 0
         # settting the fan timer - 10% = 1 hr
         elif [ $fanTimerSpecified = true ]; then
            queryTimerStateFile "${FANTIMER_STATE_FILE}"
            if [ "$fanState" = "1" ]; then
               timeToOn=0
               timeToOff=$((value * 360))
               setTime=${t0}
            else
               timeToOn=$((value * 360))
               timeToOff=0
               setTime=${t0}
            fi
            updateTimerStateFile "${FANTIMER_STATE_FILE}"
            exit 0
         # settting the cool timer - 10% = 1 hr
         elif [ $coolTimerSpecified = true ]; then
            queryTimerStateFile "${COOLTIMER_STATE_FILE}"
            if [ "$coolState" = "1" ]; then
               timeToOn=0
               timeToOff=$((value * 360))
               setTime=${t0}
            else
               timeToOn=$((value * 360))
               timeToOff=0
               setTime=${t0}
            fi
            updateTimerStateFile "${COOLTIMER_STATE_FILE}"
            exit 0
         # settting the heat timer - 10% = 1 hr
         elif [ $heatTimerSpecified = true ]; then
            queryTimerStateFile "${HEATTIMER_STATE_FILE}"
            if [ "$heatState" = "1" ]; then
               timeToOn=0
               timeToOff=$((value * 360))
               setTime=${t0}
            else
               timeToOn=$((value * 360))
               timeToOff=0
               setTime=${t0}
            fi
            updateTimerStateFile "${HEATTIMER_STATE_FILE}"
            exit 0
         # settting the AA timer - 10% = 1 hr
         elif [ $timerEnabled = true ]; then
            # Make 10% to 1 hour (1% = 6 minutes) and capped at a max of 600 minutes
            timerInMinutes=$((value * 6))
            parseMyAirDataWithJq ".aircons.$ac.info.state" "1"
            if [ "$jqResult" = '"on"' ]; then
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOff:$timerInMinutes}}}"
            else
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{info:{countDownToOn:$timerInMinutes}}}"
            fi
            exit 0

         # Set light brightness
         elif [ $lightSpecified = true ]; then
            if [ -z "${lightID}" ]; then
               queryIdByName "light" "$lightName"
            else
               eval "idArray_g=(${lightID})"
            fi
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
         if [ $zoneSpecified = true ]; then
            parseMyAirDataWithJq ".aircons.$ac.zones.$zone.rssi" "1"
            rssi="${jqResult}"
            if [ "${rssi}" = "0" ]; then
               # Round the $value to its nearest 5%
               damper=$(($(($((value + 2)) / 5)) * 5))
               setAirConUsingIteration "http://$IP:$PORT/setAircon?json={$ac:{zones:{$zone:{value:$damper}}}}"
            fi
            exit 0
         else
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
         fi
      ;;
   esac
fi
echo "Unhandled $io $device $characteristic" >&2
exit 150
