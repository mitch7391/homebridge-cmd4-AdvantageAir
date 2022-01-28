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

#
# For optional args and arg parsing
#

# Default zone
zone=""
zoneSpecified=false
argSTART=4
logErrors=true
noSensors=true
fanSpeed=false
fspeed="low"
# By default selfTest is off
selfTest="TEST_OFF"

# Define some variables for zone open checking
zoneArray=(z01 z02 z03 z04 z05 z06 z07 z08 z09 z10)
zoneOpen=0

# For timer capability
timerEnabled=false

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
   if [ "$selfTest" = "TEST_OFF" ]; then
      myAirData=$( curl --max-time 2 --fail --connect-timeout 2 -s -g "$url" )
      rc=$?
   else
      myAirData=$( cat "./data/getSystemData.txt${iteration}" )
      rc=$?
      # For Testing, you can compare whats sent
      if [ "$io" = "Set" ]; then
         echo "Setting url: $url";
      fi
   fi

   if [ "$rc" != "0" ]; then
      if [ "$exitOnFail" = "1" ]; then
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

   # Added to ensure that if "$jqResult = false", rc is set to 0 because $jqResult = false is an acceptable answer.
   if [ $jqResult = false ]; then
      rc=0
   fi

   if [ "$rc" != "0" ]; then
      if [ "$exitOnFail" = "1" ]; then
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
            sleep 0.3
         fi
      else
         sleep 0.3
      fi

   done
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

# For "Get" Directives
if [ "$io" = "Get" ]; then

   case "$characteristic" in
      # Gets the current temperature.
      CurrentTemperature )
         # Added to determine whether Temperature Sensors are used in this system
         queryAirCon "http://$IP:2025/getSystemData" "1" "0"
         
         # Check if any zones have "rssi" value != 0 and != "null", if so, set noSensors=false
         for (( a=0;a<=9;a++ ))
         do
         parseMyAirDataWithJq '.aircons.ac1.zones.'${zoneArray[a]}'.rssi'
            if [ $jqResult != 0 ] && [ $jqResult != "null" ]; then
               noSensors=false
               break
            fi
         done

         if [ "$noSensors" = false ] && [ $zoneSpecified = false ]; then
            # Get the constant zone info from the system
            parseMyAirDataWithJq '.aircons.ac1.info.constant1'
               if [ $jqResult != 10 ];then
                  cZone="z0$jqResult"
               else
                  cZone="z$jqResult"
               fi
            # Use constant zone for Thermostat temperature reading
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$cZone"'.measuredTemp'
         elif [ $zoneSpecified = true ]; then
            # Use zone for Temperature Sensor temp reading
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$zone"'.measuredTemp'
         elif [ "$noSensors" = true ]; then
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

      On )
         if [ $zoneSpecified = false ] && [ $fanSpeed = false ] && [ $timerEnabled = false ]; then
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

         # Added to get the timer current setting
         elif [ $timerEnabled = true ]; then
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'
            # If the aircon state is "off", set "countDownToOff" to 0
            if [ "$jqResult" = '"off"' ]; then
               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOn'
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOff:0}}}" "1" "0"
               # If "countDownToOn" is 0 then switch the timer off
               if [ "$jqResult" = '0' ]; then
                  echo 0
                  exit 0
               else
                  # If "countDownToOn" is not 0, switch on the timer
                  echo 1
                  exit 0
               fi
            else
               # If the aircon state is "on", set "countDownToOn" to 0
               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOff'
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOn:0}}}" "1" "0"
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

         fi
      ;;  # End of On

      #Light Bulb service used for controlling damper % open
      Brightness )
         # Gets the timer and zone damper % information
         if [ $zoneSpecified = true ]; then
            # Get the zone damper % open
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.zones.'"$zone"'.value'
            echo "$jqResult"
            exit 0
         elif [ $timerEnabled = true ]; then
            # Get the timer countdown value
            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'
            if [ "$jqResult" = '"on"' ]; then
               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOff'
               echo $(expr $jqResult / 10)
               exit 0
            else
               parseMyAirDataWithJq '.aircons.ac1.info.countDownToOn'
               echo $(expr $jqResult / 10)
               exit 0
            fi
         fi
      ;;

      # Fan service for controlling fan speed (low, medium and high)
      RotationSpeed )
         # Update the current fan speed
         queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.fan'
         if [ $jqResult = '"low"' ]; then
            #25% as low speed
            echo 25

            exit 0
         elif [ $jqResult = '"medium"' ]; then
            #50% as medium speed
            echo 50

            exit 0
         elif [ $jqResult = '"high"' ]; then
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
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:off}}}" "1" "0"

               exit 0
            ;;
            1 )
               # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:on,mode:heat}}}" "1" "0"

               exit 0
            ;;
            2 )
               # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:on,mode:cool}}}" "1" "0"

               exit 0
            ;;
         esac
      ;;

      TargetTemperature )

         # Added to determine whether Temperature Senors are used in this system
         queryAirCon "http://$IP:2025/getSystemData" "1" "0"

         # Check if any zones have "rssi" value != 0 and != "null", if so, set noSensors=false
         for (( a=0;a<=9;a++ ))

         do
         parseMyAirDataWithJq '.aircons.ac1.zones.'${zoneArray[a]}'.rssi'
            if [ $jqResult != 0 ] && [ $jqResult != "null" ]; then
               noSensors=false
               break
            fi
         done

         if [ $noSensors = true ]; then
            # Only sets temperature to master temperature in the app
            queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{setTemp:$value}}}" "1" "0"
            exit 0
         else
            # Sets all zones to the current master thermostat's temperature value. All 10 allowable zones have been added just in case and do not need removing.
            queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{setTemp:$value},zones:{z01:{setTemp:$value},z02:{setTemp:$value},z03:{setTemp:$value},z04:{setTemp:$value},z05:{setTemp:$value},z06:{setTemp:$value},z07:{setTemp:$value},z08:{setTemp:$value},z09:{setTemp:$value},z10:{setTemp:$value}}}}" "1" "0"
            exit 0
         fi
      ;;

      On )
         # Uses the On characteristic for Fan/Vent mode.
         if [ $zoneSpecified = false ] && [ $fanSpeed = false ] && [ $timerEnabled = false ]; then
            if [ "$value" = "1" ]; then
               # Sets Control Unit to On, sets to Fan mode aqnd fan speed will default to last used.
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:on,mode:vent}}}" "1" "0"

               exit 0
            else
               # Shut Off Control Unit.
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{state:off}}}" "1" "0"

               exit 0
            fi
         # Uses the On characteristic for zone switches.
         elif [ $zoneSpecified = true ]; then
            if [ "$value" = "1" ]; then
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{state:open}}}}" "1" "0"

               exit 0
            else
               # Ensures that at least one zone is open at all time to protect the aircon system before closing any zone:
               # > if the only zone open is the constant zone, leave it open and set it to 100%.
               # > if the constant zone is already closed, and the only open zone is set to close,
               #  the constant zone will open and set to 100% while closing that zone.

               queryAirCon "http://$IP:2025/getSystemData" "1" "0"

               # Get the constant zone info from the system
               parseMyAirDataWithJq '.aircons.ac1.info.constant1'
               if [ $jqResult != 10 ];then
                  cZone="z0$jqResult"
               else
                  cZone="z$jqResult"
               fi

               # Check how many zones are open
               for (( a=0;a<=9;a++ ))
               do
                  parseMyAirDataWithJq '.aircons.ac1.zones.'${zoneArray[a]}'.state'
                  if [ "$jqResult" = '"open"' ]; then
                     zoneOpen=$(expr $zoneOpen + 1)
                  fi
               done

               if [ $zoneOpen -gt 1 ]; then
                  # If there are more than 1 zone open, it is safe to close this zone.
                  queryAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{state:close}}}}" "1" "0"
                  exit 0
               elif [ $zone = $cZone ]; then
                  # If only 1 zone open and is the constant zone. do not close but set to  100%
                  queryAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{value:100}}}}" "1" "0"
                  exit 0
               else
                  # If only 1 zone open and is not the constant zone, open the constant zone and close this zone
                  queryAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$cZone:{state:open},$zone:{state:close}}}}" "1" "0"
                  sleep 0.5
                  # Set the constant zone to 100%
                  queryAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$cZone:{value:100}}}}" "1" "0"
                  exit 0
               fi
            fi
         # Added to include the timer capability
         elif [ $timerEnabled = true ]; then
            if [ "$value" = "0" ]; then
               # Set both "countDownToOn" and "countDownToOff" to 0, otherwise do nothing
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOn:0}}}" "1" "0"
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOff:0}}}" "1" "0"
               exit 0
            else
               # Do nothing
               exit 0
            fi
         elif [ $fanSpeed = true ]; then
            # No real on/off function but issue "exit 0" to let cmd4 know that action is satisfied

            exit 0
         fi
      ;;

      #Light Bulb service for used controlling damper % open and timer
      Brightness )
         # Modified to include the conditional statements for damper %
         if [ $zoneSpecified = true ]; then
            # Round the $value to its nearst 5%
            damper=$(expr $(expr $(expr $value + 2) / 5) \* 5)

            queryAirCon "http://$IP:2025/setAircon?json={ac1:{zones:{$zone:{value:$damper}}}}" "1" "0"
            exit 0
         # Added to include the timer capability
         elif [ $timerEnabled = true ]; then
            # Make 1% to 10 minutes and capped at a max of 720 minutes
            timerInMinutes=$(expr $value \* 10)
            timerInMinutes=$(($timerInMinutes < 720? $timerInMinutes : 720))

            queryAndParseAirCon "http://$IP:2025/getSystemData" '.aircons.ac1.info.state'
            if [ "$jqResult" = '"on"' ]; then
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOff:$timerInMinutes}}}" "1" "0"
               exit 0
            else
               queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{countDownToOn:$timerInMinutes}}}" "1" "0"
               exit 0
            fi
         fi
      ;;

      # Fan service for controlling fan speed (0-33%:low, 34-67%:medium, 68-99%:high, 100%:autoAA/auto)
      RotationSpeed )
         # fspeed=$value (0-33%:low, 34-67%:medium, 68-99%:high, 100%:autoAA/auto)
         if [ $value -le 33 ]; then
            fspeed="low"
         elif [ $value -ge 34 ] && [ $value -le 67 ]; then
            fspeed="medium"
         elif [ $value -ge 68 ] && [ $value -le 99 ]; then
            fspeed="high"
         else
            # 'ezfan' users have 'autoAA' and regular users have 'auto'. But 'autoAA' works for all, so hardcoded to 'autoAA'
            fspeed="autoAA"
         fi
         queryAirCon "http://$IP:2025/setAircon?json={ac1:{info:{fan:$fspeed}}}" "1" "0"

         exit 0
      ;;

   esac
fi

echo "Unhandled $io $device $characteristic" >&2

exit 150
