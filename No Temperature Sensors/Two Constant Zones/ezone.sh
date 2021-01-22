#!/bin/bash

# IP Address / Port:
ip="192.168.0.173:2025"
# Constant Zone 1:
cz1=z01
# Constant Zone 2:
cz2=z06

if [ "$1" = "Get" ]; then
  case "$3" in
    # Gets the current temperature. Uses the set temperature as the measured temperature in lieu of having sensors.
    CurrentTemperature )
      curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.setTemp'
    ;;
    # Gets the target temperature.
    TargetTemperature )
      curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.setTemp'
    ;;
    # Sets display units to Celsius.
    TemperatureDisplayUnits )
      echo 0
    ;;

    # Makes the target Control Unit state the current Control Unit state.
    TargetHeatingCoolingState | CurrentHeatingCoolingState )
      # Set to Off if the zone is closed or the Control Unit is Off.
      if [ "$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.state')" = '"close"' ] || [ "$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.state')" = '"off"' ]; then
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
      if [ "$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.state')" = '"close"' ] || [ "$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.state')" = '"off"' ]; then
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
        esac
      fi
    ;;
    esac
fi

if [ "$1" = "Set" ]; then
  case "$3" in

   TargetHeatingCoolingState )

     case "$5" in
	$cz1 )

           case "$4" in
            0 )
              # Checks state of other constant zone before deciding to shut zone or shut off Control Unit.
              cz2State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'$cz2'.state')
              case "$cz2State" in
                '"open"' )
                        # Close Zone.
                        curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"close"}}}}
                ;;

                '"close"' )
                         # Shut Off Control Unit.
                         curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
                ;;
              esac
            ;;

            1 )
              # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
              curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"heat"}",""zones":{"$5":{"state":"open"}}}}
            ;;

            2 )
              # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
              curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"cool"}",""zones":{"$5":{"state":"open"}}}}
            ;;
          esac
       ;;


       $cz2 )

           case "$4" in
            0 )
              # Checks state of other constant zone before deciding to shut zone or shut off Control Unit.
	      cz1State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'$cz1'.state')
              case "$cz1State" in
                '"open"' )
                        # Close Zone.
                        curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"close"}}}}
                ;;

                '"close"' )
                         # Shut Off Control Unit.
                         curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
                ;;
              esac
            ;;

            1 )
              # Turn On Control Unit, Set Mode to Heat, Open Current Zone.
              curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"heat"}",""zones":{"$5":{"state":"open"}}}}
            ;;

            2 )
              # Turn On Control Unit, Set Mode to Cool, Open Current Zone.
              curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"cool"}",""zones":{"$5":{"state":"open"}}}}
            ;;
          esac
       ;;
     esac
   ;;


   TargetTemperature )

     case "$5" in
       $cz1 )
          # All zones associated with Constant Zone 1 (e.g all first storey zones); you may need to add or remove some.
          curl -g http://$ip/setAircon?json={"ac1":{"info":{"setTemp":"$4"}",""zones":{"z01":{"setTemp":"$4"}",""z02":{"setTemp":"$4"}",""z03":{"setTemp":"$4"}}}}
       ;;

       $cz2 )
          # All zones associated with Constant Zone 2 (e.g all second storey zones); you may need to add or remove some.
	  curl -g http://$ip/setAircon?json={"ac1":{"info":{"setTemp":"$4"}",""zones":{"z04":{"setTemp":"$4"}",""z05":{"setTemp":"$4"}",""z06":{"setTemp":"$4"}}}}
       ;;
     esac
    ;;

    On )

    if [ "$4" = "true" ]; then
       # Sets Control Unit to On, sets to Fan mode and Auto; opens the zone. Apple does not support 'low', 'medium' and 'high' fan modes.
       curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"vent"",""fan":"auto"}",""zones":{"$5":{"state":"open"}}}}

    else
       case "$5" in
	 $cz1 )
            # Checks state of other constant zone before deciding to shut zone or shut off Control Unit.
            cz2State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'$cz2'.state')
            case "$cz2State" in
              '"open"' )
                      # Close Zone.
                      curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"close"}}}}
              ;;

              '"close"' )
                       # Shut Off Control Unit.
                       curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
              ;;
            esac
         ;;

         $cz2 )
            # Checks state of other constant zone before deciding to shut zone or shut off Control Unit.
            cz1State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'$cz1'.state')
            case "$cz1State" in
              '"open"' )
                      # Close Zone.
                      curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"close"}}}}
              ;;

              '"close"' )
                       # Shut Off Control Unit.
                       curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
              ;;
            esac
         ;;
       esac
     fi
    ;;
  esac
fi

exit 0
