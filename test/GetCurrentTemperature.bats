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

@test "AdvAir ( ezone inline ) Test PassOn5 Get CurrentTemperature" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Try 1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[5]}" "Try 2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[7]}" "Try 3"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[9]}" "Try 4"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[12]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[15]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 16
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
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[7]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir ( ezone inline ) Test PassOn3 Get CurrentTemperature" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Try 1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[5]}" "Try 2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[11]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 12
}

@test "AdvAir ( ezone inline ) Test FailOn5 Get CurrentTemperature" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/failedAirConRetrieveSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" 1
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Try 1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[5]}" "Try 2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[7]}" "Try 3"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[9]}" "Try 4"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 11
}


@test "AdvAir ( zones inline ) Test PassOn1 Get CurrentTemperature z01" {
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

@test "AdvAir ( zones inline ) Test PassOn3 Get CurrentTemperature z01" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Try 1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[5]}" "Try 2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[11]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 12
}

@test "AdvAir ( zones inline ) Test PassOn5 Get CurrentTemperature z01" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Try 1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[5]}" "Try 2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[7]}" "Try 3"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[9]}" "Try 4"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[12]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z01.measuredTemp"
   assert_equal "${lines[15]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 16
}

@test "AdvAir ( zones inline ) Test FailOn5 Get CurrentTemperature z01" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/failedAirConRetrieveSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "1"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Try 1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[5]}" "Try 2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[7]}" "Try 3"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[9]}" "Try 4"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 11
}

@test "AdvAir ( zones inline ) Test PassOn1 Get CurrentTemperature z03" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z03
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z03.measuredTemp"
   assert_equal "${lines[7]}" "23.8"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature with NoSensor Data (creating new myAirConstants" {
   # The old scripts return 0 because it does not realize noSensors
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
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature with NoSensor Data (with cached myAirConstants" {
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
}
