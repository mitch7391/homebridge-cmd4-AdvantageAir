#!/bin/bash

# IP address
ip="192.168.0.173:2025"

if [ "$1" = "Get" ]; then
  case "$3" in

    CurrentTemperature )
      echo $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.z01.measuredTemp')
      ;;

    TargetTemperature )
      echo $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.setTemp')
      ;;

    TemperatureDisplayUnits )
      echo 0
      ;;

    CurrentHeatingCoolingState | TargetHeatingCoolingState )
      if [ $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.state') = '"off"' ]; then
        echo 0
      else
       mode=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.mode')
       case "$mode" in
          '"heat"' )
          echo 1
          ;;
          '"cool"' )
          echo 2
          ;;
          '"vent"' )
          echo 0
          ;;
          '"dry"' )
          echo 0
          ;;
          * )
          echo 0
	  ;;
        esac
      fi
      ;;

    #Fan Accessory - on/off = 1/0
    On )
      if [ $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.state') = '"off"' ]; then
        echo 0
      else
         mode=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.info.mode')
       case "$mode" in
	  '"heat"' )
	  echo 0
	  ;;
	  '"cool"' )
          echo 0
	  ;;
	  '"vent"' )
	  echo 1
	  ;;
	  '"dry"' )
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
       curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
       ;;

       1 )
       curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"heat"}}}
       ;;

       2 )
       curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"cool"}}}
       ;;
     esac
   ;;

   TargetTemperature )
     curl -g http://$ip/setAircon?json={"ac1":{"info":{"setTemp":"$4"}",""zones":{"z01":{"setTemp":"$4"}",""z02":{"setTemp":"$4"}",""z03":{"setTemp":"$4"}",""z04":{"setTemp":"$4"}",""z05":{"setTemp":"$4"}",""z06":{"setTemp":"$4"}}}}
     ;;

    On )
     if [ "$4" = "true" ]; then
      curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"vent"",""fan":"auto"}}}
     else
      curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
     fi
     ;;
  esac
fi

exit 0
