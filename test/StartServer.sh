#!/bin/bash

if [ -z "$TMPDIR" ]; then TMPDIR="/tmp"; fi
sudo rm -rf "${TMPDIR}/AA-001"
mkdir "${TMPDIR}/AA-001"
chmod +xxx "${TMPDIR}/AA-001"
touch "${TMPDIR}/AA-001/AirConServer.out"
echo  "In startServer" >> "${TMPDIR}"/AA-001/AirConServer.out

# Start a new AirConServer for a simulated big Aircon system
echo "Setup: Starting daemon" >> "${TMPDIR}"/AA-001/AirConServer.out
# Just to make sure that commander is installed
if [ ! -d "node_modules/commander" ]; then
   npm i commander
fi
node ./AirConServer.js >> "${TMPDIR}/AA-001/AirConServer.out" 2>&1 &
rc=$?
if [ "$rc" != 0 ]; then
   echo "Setup: Starting Daemon failed rc: $rc" >> "${TMPDIR}"/AA-001/AirConServer.out
   echo "Starting AirConServer Daemon failed rc: $rc" >> "${TMPDIR}"/AA-001/AirConServer.out
fi
sleep 3
echo "Setup: Daemon shold be started rc: $rc" >> "${TMPDIR}"/AA-001/AirConServer.out
echo "AirConServer Daemon shold be started rc: $rc"

# load the myAirData for MyPlace_Simulated system
curl -s -g "http://localhost:2025/reInit"
curl -s -g "http://localhost:2025?load=testData/$1"
if [ "$rc" != 0 ]; then
   echo "Data Loading: failed rc: $rc" >> "${TMPDIR}"/AA-001/AirConServer.out
   echo "Data Loading: failed rc: $rc"
else
   echo "Data Loading sucessful" >> "${TMPDIR}"/AA-001/AirConServer.out
   echo "Data Loading sucessful"
   echo "myAirData=$1"
fi
