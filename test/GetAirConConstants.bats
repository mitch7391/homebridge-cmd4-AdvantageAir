setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}
before()
{
   rm -f "${TMPDIR}/AA-001/AirConServer.out"
}

beforeEach()
{
   rm -f "${TMPDIR}/AA-001/myAirData.txt"*
   rm -f "${TMPDIR}/AA-001/myAirConstants.txt"*
   if [ ! -d "${TMPDIR}/AA-001" ]; then mkdir "${TMPDIR}/AA-001"; fi
}

@test "AdvAir Test Get CurrentTemperature MyAirConstants" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[7]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir Test Write MyAirConstants with NoSensor Data" {
   # The old scripts return 0 because it does not real1ze noSensors
   before
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/oneZonePassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.zones.z02.rssi"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z03.rssi"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.zones.z04.rssi"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z05.rssi"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z06.rssi"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.info.setTemp"
   # The noSensors fixes this
   assert_equal "${lines[12]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 13
   myAirConstants=$( cat "${TMPDIR}/AA-001/myAirConstants.txt.ac1" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "true"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "true z01 6"
}

@test "AdvAir Test Read Cached MyAirConstants with NoSensor Data" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/oneZonePassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.zones.z02.rssi"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z03.rssi"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.zones.z04.rssi"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z05.rssi"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z06.rssi"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.info.setTemp"
   assert_equal "${lines[12]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 13
   # Running the same command again, will use the cached myAirConstants
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.setTemp"
   assert_equal "${lines[3]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
   myAirConstants=$( cat "${TMPDIR}/AA-001/myAirConstants.txt.ac1" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "true"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "true z01 6"
}

@test "AdvAir Test Write MyAirConstants with Sensor Data" {
   before
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   # The noSensors fixes this
   assert_equal "${lines[7]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
   myAirConstants=$( cat "${TMPDIR}/AA-001/myAirConstants.txt.ac1" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "false"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "false z01 6"
}

@test "AdvAir Test Read Cached MyAirConstants with Sensor Data" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[7]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
   # Running the same command again, will use the cached myAirConstants
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[3]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
   myAirConstants=$( cat "${TMPDIR}/AA-001/myAirConstants.txt.ac1" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "false"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "false z01 6"
}
