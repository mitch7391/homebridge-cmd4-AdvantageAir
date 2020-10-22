#!/bin/bash

# IP address
ip="192.168.0.173:2025"

if [ "$1" = "Get" ]; then
  case "$3" in

    CurrentTemperature )
      echo $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.measuredTemp')
      ;;

    TargetTemperature )
      echo $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.setTemp')
      ;;

    TemperatureDisplayUnits )
      echo 0
      ;;

    TargetHeatingCoolingState | CurrentHeatingCoolingState )
      
      if [ $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.state') = '"close"' ]; then
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
      
      if [ $(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.'"$4"'.state') = '"close"' ]; then
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
        
     # Check later if I can just do this with $5 and save on two lines
     constZone1State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.z01.state')
     constZone2State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.z06.state')
        
     case "$4" in
       0 )
        
	if ["$constZone1State" = "open" && "$constZone2State" = "open"]; then
          curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"close"}}}}
        
	else       
          curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
        fi
        ;;

       1 )
        curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"heat"}",""zones":{"$5":{"state":"open"}}}}
        ;;

       2 )
        curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"cool"}",""zones":{"$5":{"state":"open"}}}}
	;;
     esac
     ;;

   TargetTemperature )
     
     case "$5" in
       "z01" )
          curl -g http://$ip/setAircon?json={"ac1":{"info":{"setTemp":"$4"}",""zones":{"z01":{"setTemp":"$4"}",""z02":{"setTemp":"$4"}",""z03":{"setTemp":"$4"}}}}
          ;;
       
       "z06" )
	  curl -g http://$ip/setAircon?json={"ac1":{"info":{"setTemp":"$4"}",""zones":{"z04":{"setTemp":"$4"}",""z05":{"setTemp":"$4"}",""z06":{"setTemp":"$4"}}}}
          ;;

    On )
     
     if [ "$4" = "true" ]; then
       curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"on"",""mode":"vent"",""fan":"auto"}",""zones":{"$5":{"state":"open"}}}}
     
     else
       # Check later if I can just do this with $5 and save on two lines
       constZone1State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.z01.state')
       constZone2State=$(curl -s http://$ip/getSystemData | jq '.aircons.ac1.zones.z06.state')
       
       if ["$constZone1State" = "open" && "$constZone2State" = "open"]; then  
         curl -g http://$ip/setAircon?json={"ac1":{"zones":{"$5":{"state":"close"}}}}
       else
         curl -g http://$ip/setAircon?json={"ac1":{"info":{"state":"off"}}}
       fi
       ;;
     fi
     ;;
  esac
fi

exit 0
