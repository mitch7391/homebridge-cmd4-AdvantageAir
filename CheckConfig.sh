#!/bin/bash
#
# This script is to check the Cmd4 configuration file for cmd4-advantageair plugin
#
# Usage ./CheckConfig.sh                                                                   
# 

# define the possible names for cmd4 platform
cmd4Platform1="\"platform\": \"Cmd4\""
cmd4Platform2="\"platform\": \"homebridge-cmd4\""

# define some file variables
homebridgeConfigJson=""           # homebridge config.json
configJson="config.json.copy"     # a working copy of homebridge config.json

# fun color stuff
BOLD=$(tput bold)
TRED=$(tput setaf 1)
#TGRN=$(tput setaf 2)
TYEL=$(tput setaf 3)
TPUR=$(tput setaf 5)
TLBL=$(tput setaf 6)
TNRM=$(tput sgr0)

function readHomebridgeConfigJson()
{
   INPUT=""
   homebridgeConfigJson=""
   getHomebridgeConfigJsonPath
   if [ "${fullPath}" != "" ]; then homebridgeConfigJson="${fullPath}"; fi 
 
   # if no config.json file found, ask user to input the full path
   if [ -z "${homebridgeConfigJson}" ]; then
      homebridgeConfigJson=""
      echo ""
      echo "${TPUR}WARNING: No valid Homebridge config.json file located by the script!${TNRM}"
      echo ""
      until [ -n "${INPUT}" ]; do
         echo "${TYEL}Please enter the full path of your Homebridge config.json file,"
         echo "The config.json path should be in the form of /*/*/*/config.json ${TNRM}"
         read -r -p "${BOLD}> ${TNRM}" INPUT
         if [ -z "${INPUT}" ]; then
            echo "${TPUR}WARNING: No Homebridge config.json file specified"
            cleanUp
            exit 1
         elif expr "${INPUT}" : '[./a-zA-Z0-9]*/config.json$' >/dev/null; then
            if [ -f "${INPUT}" ]; then
                homebridgeConfigJson="${INPUT}"
                break
            else
               echo ""
               echo "${TPUR}WARNING: No such file exits!${TNRM}"
               echo ""
               INPUT=""
            fi
         else
            echo ""
            echo "${TPUR}WARNING: Wrong format for file path for Homebridge config.json!${TNRM}"
            echo ""
            INPUT=""
         fi
      done
   fi
   if [ -f "${homebridgeConfigJson}" ]; then
      if [ -z "${INPUT}" ]; then
         echo "${TLBL}INFO: The Homebridge config.json found: ${homebridgeConfigJson}${TNRM}"
         echo ""
      else
         echo ""
         echo "${TLBL}INFO: The Homebridge config.json specified: ${homebridgeConfigJson}${TNRM}"
         echo ""
      fi
      # expand the json just in case it is in compact form
      jq --indent 4 '.' "${homebridgeConfigJson}" > "${configJson}"
      checkForPlatformCmd4InHomebridgeConfigJson
      if [ -z "${validFile}" ]; then
         echo ""
         echo "${TRED}ERROR: no Cmd4 Config found in \"${homebridgeConfigJson}\"! Please ensure that Homebridge-Cmd4 plugin is installed${TNRM}"
         cleanUp
         exit 1
      fi
   fi
}


function getGlobalNodeModulesPathForFile()
{
   file="$1"
   fullPath=""    

   for ((tryIndex = 1; tryIndex <= 8; tryIndex ++)); do
      case $tryIndex in  
         1)
            foundPath=$(find /var/lib/hoobs 2>&1|grep -v find|grep -v System|grep -v cache|grep node_modules|grep cmd4-advantageair|grep "/${file}$") 
            fullPath=$(echo "${foundPath}"|head -n 1)
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         2)
            foundPath=$(npm root -g)
            fullPath="${foundPath}/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return    
            else
               fullPath=""
            fi
         ;;
         3)
            fullPath="/var/lib/homebridge/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         4)
            fullPath="/var/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         5)
            fullPath="/usr/local/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         6)
            fullPath="/usr/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         7)
            fullPath="/opt/homebrew/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
         8)
            fullPath="/opt/homebridge/lib/node_modules/homebridge-cmd4-advantageair/${file}"
            if [ -f "${fullPath}" ]; then
               return
            else
               fullPath=""
            fi
         ;;
      esac
   done
}

function getHomebridgeConfigJsonPath()
{
   fullPath=""
   # Typicall HOOBS installation has its config.json root path same as the root path of "AdvAir.sh"
   # The typical full path to the "AdvAir.sh" script is .../hoobs/<bridge>/node_modules/hoebridge-cmd4-advantageaiadvantageairr/AdvAir.sh
   # First, determine whether this is a HOOBS installation
   Hoobs=$( echo "$ADVAIR_SH_PATH" | grep "/hoobs/" )
   if [ -n "${Hoobs}" ]; then
      fullPath="${ADVAIR_SH_PATH%/*/*/*}/config.json"
      if [ -f "${fullPath}" ]; then
         checkForCmd4PlatformNameInFile
         if [ -z "${cmd4PlatformNameFound}" ]; then
            fullPath=""
         fi 
         return
      fi
   fi

   for ((tryIndex = 1; tryIndex <= 5; tryIndex ++)); do
      case $tryIndex in
         1)
            fullPath="/var/lib/homebridge/config.json"
            if [ -f "${fullPath}" ]; then
               checkForCmd4PlatformNameInFile
               if [ -n "${cmd4PlatformNameFound}" ]; then 
                  return
               else
                  fullPath=""
               fi
            fi
         ;;
         2)
            fullPath="$HOME/.homebridge/config.json"
            if [ -f "${fullPath}" ]; then
               checkForCmd4PlatformNameInFile
               if [ -n "${cmd4PlatformNameFound}" ]; then 
                  return
               else
                  fullPath=""
               fi
            fi
         ;;
         3)
            foundPath=$(find /usr/local/lib 2>&1|grep -v find|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
         4)
            foundPath=$(find /usr/lib 2>&1|grep -v find|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
         5)
            foundPath=$(find /var/lib 2>&1|grep -v find|grep -v hoobs|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
         6)
            foundPath=$(find /opt 2>&1|grep -v find|grep -v hoobs|grep -v System|grep -v cache|grep -v hassio|grep -v node_modules|grep "/config.json$")
            noOfInstances=$(echo "${foundPath}"|wc -l)
            for ((i = 1; i <= noOfInstances; i ++)); do
               fullPath=$(echo "${foundPath}"|sed -n "${i}"p)
               if [ -f "${fullPath}" ]; then
                  checkForCmd4PlatformNameInFile   
                  if [ -n "${cmd4PlatformNameFound}" ]; then 
                     return
                  else
                     fullPath=""
                  fi
               fi
            done
         ;;
      esac
   done
}

function checkForPlatformCmd4InHomebridgeConfigJson()
{
   validFile=""
   for ((tryIndex = 1; tryIndex <= 2; tryIndex ++)); do
      case $tryIndex in
         1)
            validFile=$(grep -n "${cmd4Platform1}" "${configJson}"|cut -d":" -f1)
            if [ -n "${validFile}" ]; then
               return
            fi
         ;;
         2)
            validFile=$(grep -n "${cmd4Platform2}" "${configJson}"|cut -d":" -f1)
            if [ -n "${validFile}" ]; then
               return
            fi
         ;;
      esac
   done
}

function checkForCmd4PlatformNameInFile()
{
   cmd4PlatformNameFound=""

   for ((Index = 1; Index <= 2; Index ++)); do
      case $Index in
         1)
            cmd4PlatformName=$(echo "${cmd4Platform1}"|cut -d'"' -f4)
            cmd4PlatformNameFound=$(grep -n "\"${cmd4PlatformName}\"" "${fullPath}"|cut -d":" -f1)
            if [ -n "${cmd4PlatformNameFound}" ]; then
               return
            fi
         ;;
         2)
            cmd4PlatformName=$(echo "${cmd4Platform2}"|cut -d'"' -f4)
            cmd4PlatformNameFound=$(grep -n "\"${cmd4PlatformName}\"" "${fullPath}"|cut -d":" -f1)
            if [ -n "${cmd4PlatformNameFound}" ]; then
               return
            fi
         ;;
      esac
   done
}

 
function cleanUp()
{
   rm -f "${configJson}"
}

# main starts here

echo "${TYEL}This script is to check that the Cmd4 configuration file meets all requirements${TNRM}"
echo ""

echo "${TYEL}CheckConfig engine:${TNRM}"
# get the full path to CheckConfig.js
CHECKCONFIG_PATH=""
getGlobalNodeModulesPathForFile "CheckConfig.js"
if [ -n "${fullPath}" ]; then
   CHECKCONFIG_PATH=${fullPath}
   echo "${TLBL}INFO: CheckConfig.js found: ${CHECKCONFIG_PATH}${TNRM}"
fi

echo ""
echo "${TYEL}Essential inputs to CheckConfig engine:${TNRM}"
# get the full path to AdvAir.sh
ADVAIR_SH_PATH=""
getGlobalNodeModulesPathForFile "AdvAir.sh"
if [ -n "${fullPath}" ]; then
   ADVAIR_SH_PATH=${fullPath}
   echo "${TLBL}INFO: AdvAir.sh found: ${ADVAIR_SH_PATH}${TNRM}"
fi
if [ -z "${ADVAIR_SH_PATH}" ]; then
   ADVAIR_SH_PATH=""
   until [ -n "${ADVAIR_SH_PATH}" ]; do
      echo ""
      echo "${TYEL}Please enter the full path of where the AdvAir.sh is installed in your system"
      echo "The file path format should be : /*/*/*/node_modules/homebridge-cmd4-advantageair/AdvAir.sh${TNRM}"
      read -r -p "${BOLD}> ${TNRM}" INPUT
      if expr "${INPUT}" : '/[a-zA-Z0-9/_]*/node_modules/homebridge-cmd4-advantageair/AdvAir.sh$' >/dev/null; then
         if [ -f "${INPUT}" ]; then
            ADVAIR_SH_PATH=${INPUT}
            echo ""
            echo "${TLBL}INFO: AdvAir.sh specified: ${ADVAIR_SH_PATH}${TNRM}"
            break
         else
            echo ""
            echo "${TPUR}WARNING: file ${INPUT} not found${TNRM}"
         fi
      else
         echo ""
         echo "${TPUR}WARNING: file ${INPUT} is in wrong format${TNRM}"
      fi
   done
fi

readHomebridgeConfigJson

if [[ -f "${homebridgeConfigJson}" && -f "${ADVAIR_SH_PATH}" ]]; then
   echo "${TYEL}CheckConfig in progress.......${TNRM}"
   node "${CHECKCONFIG_PATH}" "$ADVAIR_SH_PATH" "${homebridgeConfigJson}"
   cleanUp
fi
