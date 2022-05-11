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

@test "AdvAir Test Get CurrentTemperature - ac2" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemDataAc2.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01 ac2
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac2.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac2.zones.z01.measuredTemp"
   assert_equal "${lines[7]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir Test Get CurrentTemperature z01 - ac2" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemDataAc2.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01 ac2
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac2.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac2.zones.z01.measuredTemp"
   assert_equal "${lines[7]}" "25.4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir Test Get CurrentTemperature z03 - ac2" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemDataAc2.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z03 ac2
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac2.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac2.zones.z03.measuredTemp"
   assert_equal "${lines[7]}" "23.8"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir Test Get CurrentTemperature with NoSensor Data (creating new myAirConstants - ac2)" {
   # The old scripts return 0 because it does not realize noSensors
   before
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/oneZonePassingSystemDataAc2.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 ac2
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac2.zones.z02.rssi"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac2.zones.z03.rssi"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac2.zones.z04.rssi"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac2.zones.z05.rssi"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac2.zones.z06.rssi"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac2.info.constant1"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac2.info.setTemp"
   # The noSensors fixes this
   assert_equal "${lines[12]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 13
}

@test "AdvAir Test Get CurrentTemperature with NoSensor Data (with cached myAirConstants - ac2)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/oneZonePassingSystemDataAc2.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 ac2
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac2.zones.z02.rssi"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac2.zones.z03.rssi"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac2.zones.z04.rssi"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac2.zones.z05.rssi"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac2.zones.z06.rssi"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac2.info.constant1"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac2.info.setTemp"
   assert_equal "${lines[12]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 13
   # Running the same command again, will use the cached myAirConstants
   run ../AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 ac2
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info.setTemp"
   assert_equal "${lines[3]}" "21"
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
}
