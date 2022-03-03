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
   if [ -f "/tmp/AirConServer.out" ]; then
      rm "/tmp/AirConServer.out"
   fi
}

beforeEach()
{
   if [ -f "/tmp/myAirData.txt" ]; then
      rm "/tmp/myAirData.txt"
   fi
   if [ -f "/tmp/myAirData.txt.date" ]; then
      rm "/tmp/myAirData.txt.date"
   fi
   if [ -f "/tmp/myAirData.txt.lock" ]; then
      rm "/tmp/myAirData.txt.lock"
   fi
   if [ -f "/tmp/myAirConstants.txt" ]; then
      rm "/tmp/myAirConstants.txt"
   fi
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature" {
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
   assert_equal "${lines[2]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
}

@test "AdvAir - Test Write MyAirConstants with NoSensor Data" {
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
   # The noSensors fixes this
   assert_equal "${lines[2]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
   myAirConstants=$( cat "/tmp/myAirConstants.txt" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "true"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "true z01 6"
}

@test "AdvAir - Test Read Cached MyAirConstants with NoSensor Data" {
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
   assert_equal "${lines[2]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
   # Running the same command again, will use the cached myAirConstants
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
   myAirConstants=$( cat "/tmp/myAirConstants.txt" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "true"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "true z01 6"
}

@test "AdvAir - Test Write MyAirConstants with Sensor Data" {
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
   # The noSensors fixes this
   assert_equal "${lines[2]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
   myAirConstants=$( cat "/tmp/myAirConstants.txt" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "false"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "false z01 6"
}

@test "AdvAir - Test Read Cached MyAirConstants with Sensor Data" {
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
   assert_equal "${lines[2]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
   # Running the same command again, will use the cached myAirConstants
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
   myAirConstants=$( cat "/tmp/myAirConstants.txt" )
   noSensors=$( echo "$myAirConstants" | awk '{print $1}' )
   cZone=$( echo "$myAirConstants" | awk '{print $2}' )
   nZones=$( echo "$myAirConstants" | awk '{print $3}' )
   # Format is "$noSensors $cZone $nZones"
   assert_equal "$noSensors" "false"
   assert_equal "$cZone" "z01"
   assert_equal "$nZones" "6"
   assert_equal "$myAirConstants" "false z01 6"
}
