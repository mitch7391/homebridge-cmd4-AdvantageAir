#!/bin/bash

# IP Address / Port:
ip="192.168.0.172:2025"

if [ "$1" = "Get" ]; then
  case "$3" in
    # Gets the current temperature.
    CurrentTemperature )
      curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.z01.measuredTemp'
    ;;

    # Gets the target temperature.
    TargetTemperature )
      curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.setTemp'
    ;;

    # Sets display units to Celsius.
    TemperatureDisplayUnits )
      echo 0
    ;;

    # Makes the target Control Unit state the current Control Unit state.
    TargetHeatingCoolingState | CurrentHeatingCoolingState )
      # Set to Off if the zone is closed or the Control Unit is Off.
      if [ "$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.state')" = '"off"' ]; then
        echo 0

      else
       # Get the current mode of the Control Unit. Off=0, Heat=1, Cool=2.
       mode=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.mode')

       case "$mode" in
         '"heat"' )
	    # Thermostat in Heat Mode.
            echo 1
         ;;

         '"cool"' )
	   # Thermostat in Cool Mode.
           echo 2
         ;;

         '"vent"' )
	   # Fan mode, set Thermostat to Off and Fan to On.
           echo 0
         ;;

         '"dry"' )
	    # No support for a dry mode by Apple, set to Off.
            echo 0
         ;;

         * )
	   # If anything unexpected is retruned than the above, return value Off.
           echo 0
	 ;;
       esac
     fi
   ;;

    #Fan Accessory
    On )
      # Return value of Off if the zone is closed or the Control Unit is Off.
      if [ "$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.state')" = '"off"' ]; then
        echo 0

      else
         # Get the current mode of the Control Unit. Fan can only be On or Off; if not Vent, set all other modes to Off.
         mode=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.mode')

       case "$mode" in
	  '"heat"' )
	    # Fan does not support Heat Mode.
	    echo 0
	  ;;

	  '"cool"' )
	    # Fan does not support Cool Mode.
            echo 0
	  ;;

	  '"vent"' )
	    # Set Fan to On.
	    echo 1
	  ;;

	  '"dry"' )
	    # Fan does not support Dry Mode.
	    echo 0
	  ;;

	  * )
	    # If anything unexpected is retruned than the above, set to Off.
            echo 0
	  ;;
	  * )
          echo 0
	  ;;
        esac
      fi
    ;;
    esac
fi

if [ "$1" = "Set" ]; then
  case "$3" in

   TargetHeatingCoolingState )
     case "$4" in
       0 )
         # Shut Off Control Unit.
         curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
       ;;

       1 )
         # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
         curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"heat"}}}
       ;;

       2 )
         # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
         curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"cool"}}}
       ;;
     esac
   ;;

   TargetTemperature )
     # Sets all zones to the current 'master' thermostat's value. All 10 allowable zones have been added just in case and do not need removing.
     curl -g http://$ip/setAircon?json={"ac1":{"info":{"setTemp":"$4"}",""zones":{"z01":{"setTemp":"$4"}",""z02":{"setTemp":"$4"}",""z03":{"setTemp":"$4"}",""z04":{"setTemp":"$4"}",""z05":{"setTemp":"$4"}",""z06":{"setTemp":"$4"}",""z07":{"setTemp":"$4"}",""z08":{"setTemp":"$4"}",""z09":{"setTemp":"$4"}",""z10":{"setTemp":"$4"}}}}
     ;;

    On )
     if [ "$4" = "1" ]; then
        # Sets Control Unit to On, sets to Fan mode and Auto; opens the zone. Apple does not support 'low', 'medium' and 'high' fan modes.
        curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"vent"",""fan":"auto"}}}
     else
        # Shut Off Control Unit.
        curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
     fi
    ;;
  esac
fi

exit 0
