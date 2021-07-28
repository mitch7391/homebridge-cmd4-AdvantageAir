#!/bin/bash

# A big thank you to John Talbot of homebridge-cmd4 for all his work on improving this shell script and the improvements to homebridge-cmd4 to cater further for the E-Zone/MyAir controller.

# IP Address / Port:
IP="192.168.0.173:2025"

# Passed in Args
length=$#
device=""
io=""
characteristic=""

# By default selfTest is off
selfTest="0"

# Global returned data
myAirData=""
jqResult=""
rc=1


if [ $length -le 1 ]; then
   echo "Usage: $0 Get < AccessoryName > < characteristic >"
   echo "Usage: $0 Set < AccessoryName > < characteristic > < Value >"
   exit 199
fi


if [ $length -ge 1 ]; then
    io=$1
fi
if [ $length -ge 2 ]; then
    device=$2
fi
if [ $length -ge 3 ]; then
    characteristic=$3
fi


logErrors="true"

function logError()
{
   if [ "$logErrors" != "true" ]; then
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


   # Updates global variable myAirData
   if [ "$selfTest" = "0" ]; then
      myAirData=$( curl --max-time 2 --fail --connect-timeout 2 -s -g "$url" )
      rc=$?
   else
      myAirData=$( cat "getSystemData.txt${iteration}" )
      rc=$?
   fi

   if [ "$exitOnFail" = "1" ]; then
      if [ "$rc" != "0" ]; then
         # The result cannot be trusted with a bad return code
         # Do not output to stderr as this defeats the purpose
         # of squashing error messages
         logError "curl failed" "$rc" "$myAirData" "$url" ""
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
   jqResult=$(echo "$myAirData" | jq -e "$jqPath")
   rc=$?

   if [ "$exitOnFail" = "1" ]; then
      if [ "$rc" != "0" ]; then
         # The result cannot be trusted with a bad return code
         # Do not output to stderr as this defeats the purpose
         # of squashing error messages
         logError "jq failed" "$rc" "$jqResult" "$myAirData" "$jqPath"
         exit $rc
      fi
   fi
}

function queryAndParseAirCon()
{
   local url="$1"
   local jqPath="$2"

   # Try 5 times, the last returning the error found.
   for i in 1 2 3 4 5
   do
      if [ "$selfTest" = "1" ]; then
         echo "Try $i"
      fi

      local exitOnFail="0"
      if [ "$i" = "5" ]; then
         exitOnFail="1"
      fi
      # Updates global variable myAirData
      queryAirCon "$url" "$exitOnFail" "$i"

      if [ "$rc" = "0" ]; then
         # Updates global variable jqResult
         parseMyAirDataWithJq "$jqPath" "$exitOnFail"

         if [ "$jqResult" = "0" ]; then
            break
         else
            sleep 0.3
         fi
      else
         sleep 0.3
      fi

   done
}

# For "Get" Directives
if [ "$io" = "Get" ]; then

   if [ $length -ge 4 ]; then
      selfTest=$5
   fi

   case "$characteristic" in
      # Gets the current temperature.
      CurrentTemperature )
         # Updates global variable jqResult
         queryAndParseAirCon "http://$IP/getSystemData"  '.aircons.ac1.zones.z01.setTemp'

         stdbuf -o0 -e0 echo "$jqResult"

         exit 0
      ;;

      # Gets the target temperature.
      TargetTemperature )
         # Updates global variable jqResult
         queryAndParseAirCon "http://$IP/getSystemData" '.aircons.ac1.info.setTemp'

         stdbuf -o0 -e0 echo "$jqResult"

         exit 0
      ;;

      # Sets display units to Celsius.
      TemperatureDisplayUnits )
         stdbuf -o0 -e0 echo 0

         exit 0
      ;;

      # Makes the target Control Unit state the current Control Unit state.
      TargetHeatingCoolingState | CurrentHeatingCoolingState )
         # Set to Off if the zone is closed or the Control Unit is Off.
         # Updates global variable jqResult
         queryAndParseAirCon "http://$IP/getSystemData" '.aircons.ac1.info.state'

         if [  "$jqResult" = '"off"' ]; then
            stdbuf -o0 -e0 echo 0

            exit 0
         else
            # Get the current mode of the Control Unit. Off=0, Heat=1, Cool=2.
            # Updates global variable jqResult
            parseMyAirDataWithJq '.aircons.ac1.info.mode'
            mode="$jqResult"

            case "$mode" in
               '"heat"' )
                  # Thermostat in Heat Mode.
                  stdbuf -o0 -e0 echo 1

                  exit 0
               ;;

               '"cool"' )
                  # Thermostat in Cool Mode.
                 stdbuf -o0 -e0 echo 2

                 exit 0
               ;;

               '"vent"' )
                  # Fan mode, set Thermostat to Off and Fan to On.
                  stdbuf -o0 -e0 echo 0

                  exit 0
               ;;

               '"dry"' )
                  # No support for a dry mode by Apple, set to Off.
                  stdbuf -o0 -e0 echo 0

                  exit 0
               ;;

               * )
                  # If anything unexpected is retruned than the above, return value Off.
                  stdbuf -o0 -e0 echo 0

                  exit 0
               ;;
            esac
         fi
      ;;

      #Fan Accessory
      On )
         # Return value of Off if the zone is closed or the Control Unit is Off.
         # Updates global variable jqResult
         queryAndParseAirCon "http://$IP/getSystemData" '.aircons.ac1.info.state'

         if [  "$jqResult" = '"off"' ]; then
            stdbuf -o0 -e0 echo 0

            exit 0
         else
            # Get the current mode of the Control Unit. Fan can only be On or Off; if not Vent, set all other modes to Off.
            # Updates global variable jqResult
            parseMyAirDataWithJq '.aircons.ac1.info.mode'
            mode="$jqResult"

            case "$mode" in
               '"heat"' )
                  # Fan does not support Heat Mode.
                  stdbuf -o0 -e0 echo 0

                  exit 0
               ;;

               '"cool"' )
                  # Fan does not support Cool Mode.
                  stdbuf -o0 -e0 echo 0

                  exit 0
               ;;

               '"vent"' )
                  # Set Fan to On.
                  stdbuf -o0 -e0 echo 1

                  exit 0
               ;;

               '"dry"' )
                  # Fan does not support Dry Mode.
                  stdbuf -o0 -e0 echo 0

                  exit 0
               ;;

               * )
                  # If anything unexpected is retruned than the above, set to Off.
                  stdbuf -o0 -e0 echo 0

                  exit 0
               ;;
            esac
         fi
      ;;
   esac
fi


# For "Set" Directives
if [ "$io" = "Set" ]; then
   value="1"
   if [ $length -ge 4 ]; then
      value=$4
   else
      echo "No value specified for set" >&2
      exit 199
   fi

   case "$characteristic" in
      TargetHeatingCoolingState )
         case "$value" in
            0 )
               # Shut Off Control Unit.
               queryAirCon "http://$IP/setAircon?json={ac1:{info:{state:off}}}" "1" "0"

               exit 0
            ;;
            1 )
               # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
               queryAirCon "http://$IP/setAircon?json={ac1:{info:{state:on,mode:heat}}}" "1" "0"

               exit 0
            ;;
            2 )
               # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
               queryAirCon "http://$IP/setAircon?json={ac1:{info:{state:on,mode:cool}}}" "1" "0"

               exit 0
            ;;
         esac
      ;;

      TargetTemperature )
         # Sets all zones to the current 'master' thermostat's value. All 10 allowable zones have been added just in case and do not need removing.
         queryAirCon "http://$IP/setAircon?json={ac1:{info:{setTemp:$value},zones:{z01:{setTemp:$value},z02:{setTemp:$value},z03:{setTemp:$value},z04:{setTemp:$value},z05:{setTemp:$value},z06:{setTemp:$value},z07:{setTemp:$value},z08:{setTemp:$value},z09:{setTemp:$value},z10:{setTemp:$value}}}}" "1" "0"

         exit 0
      ;;

      On )
         if [ "$4" = "1" ]; then
            # Sets Control Unit to On, sets to Fan mode and Auto; opens the zone. Apple does not support 'low', 'medium' and 'high' fan modes.
            queryAirCon "http://$IP/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}" "1" "0"

            exit 0
         else
            # Shut Off Control Unit.
            queryAirCon "http://$IP/setAircon?json={ac1:{info:{state:off}}}" "1" "0"

            exit 0
         fi
      ;;
   esac
fi


echo "Unhandled $io $device $characteristic" >&2

exit 150
