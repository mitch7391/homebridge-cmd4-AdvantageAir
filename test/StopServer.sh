#!/bin/bash
# The above line put there to make shellcheck happy

if [ -z "$TMPDIR" ]; then TMPDIR="/tmp"; fi
echo "in stopServer" >> "${TMPDIR}"/AA-001/AirConServer.out
curl -s -g "http://localhost:2025/quit" >> "${TMPDIR}"/AA-001/AirConServer.out 2>&1
rc=$?
if [ "$rc" != 0 ]; then
   echo "Setup: Stopping failed rc: $rc" >> "${TMPDIR}"/AA-001/AirConServer.out
   echo "Stopping of AirConServer failed rc: $rc"
else
   echo "Setup: Curl has Stoped daemon rc: $rc" >> "${TMPDIR}"/AA-001/AirConServer.out
   echo "Curl has Stoped AirConServer daemon successfully rc: $rc"
fi
sudo rm -r $TMPDIR/AA-001
