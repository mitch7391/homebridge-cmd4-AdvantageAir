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
   echo "Usage: $0 Get < AccessoryName > < characteristic > < Zone >"
   echo "Usage: $0 Set < AccessoryName > < characteristic > < Value > < Zone >"
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
   zone="z01"
   if [ $length -ge 4 ]; then
      zone=$4
   else
      echo "No zone specified for get" >&2
      exit 199
   fi

   if [ $length -ge 5 ]; then
      selfTest=$5
   fi

   case "$characteristic" in
      #damper open/closed = switch on/off = 1/0
      On )
         # Updates global variable jqResult
         queryAndParseAirCon "http://$IP/getSystemData" '.aircons.ac1.zones.'"$zone"'.state'

         if [ "$jqResult" = '"open"' ]; then
            stdbuf -o0 -e0 echo 1

            exit 0
         else
            stdbuf -o0 -e0 echo 0

            exit 0
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

   zone="z01"
   if [ $length -ge 5 ]; then
      zone=$5
   else
      echo "No zone specified for set" >&2
      exit 199
   fi

   case "$characteristic" in
      On )
         if [ "$value" = "1" ]; then
            queryAirCon "http://$IP/setAircon?json={ac1:{zones:{$zone:{state:open}}}}" "1" "0"

            exit 0
         else
            queryAirCon "http://$IP/setAircon?json={ac1:{zones:{$zone:{state:close}}}}" "1" "0"

            exit 0
         fi
      ;;
   esac
fi


echo "Unhandled $io $device $characteristic" >&2

exit 150
