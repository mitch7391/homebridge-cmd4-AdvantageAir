#!/bin/bash

# IP address
ip="192.168.0.172:2025"

if [ "$1" = "Get" ]; then
  case "$3" in
    CurrentTemperature )
      echo $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.measuredTemp')
      ;;

    #Temp Sensor Fault Status = fault/no fault = 0/1-2
    StatusFault )
      if  [ $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.error') = '0' ]; then
        echo 0
      else
        echo 1
      fi
      ;;

    #damper open/closed = switch on/off = 1/0
    On )
      if [ $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.state') = '"open"' ]; then
        echo 1
      else
        echo 0
      fi
      ;;
    esac
fi

if [ "$1" = "Set" ]; then
  case "$3" in
    On )
      if [ "$4" = "true" ]; then
        curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"open"}}}}
      else
        curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"close"}}}}
      fi
      ;;
    esac
fi


exit 0
