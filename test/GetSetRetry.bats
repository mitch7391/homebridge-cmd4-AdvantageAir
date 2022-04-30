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
   rm -f "/tmp/AA-001/AirConServer.out"
}

beforeEach()
{
   rm -f "/tmp/AA-001/myAirData.txt"*
   rm -f "/tmp/AA-001/myAirConstants.txt"*
   if [ ! -d "/tmp/AA-001" ]; then mkdir "/tmp/AA-001"; fi
}

@test "AdvAir Test Get CurrentTemperature ( PassOn5 - Retry )" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?repeat=4&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
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

@test "AdvAir Test Get CurrentTemperature ( PassOn1 - No Retry )" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
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

@test "AdvAir Test Get CurrentTemperature ( PassOn3 - Retry )" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?repeat=2&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
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

@test "AdvAir Test Get CurrentTemperature ( FailOn5 - Retry )" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?load=testData/failedAirConRetrieveSystemData.txt"
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


@test "AdvAir Test Set On 1 Fan ( PassOn5 - Retry )" {
   # Old returned "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?repeat=4&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Set Fan On 1 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Try 1"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[4]}" "Try 2"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[6]}" "Try 3"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[8]}" "Try 4"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[10]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "${lines[11]}" "Try 0"
   assert_equal "${lines[12]}" "Setting json: .aircons.ac1.info.state=\"on\""
   assert_equal "${lines[13]}" "Setting json: .aircons.ac1.info.mode=\"vent\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 14

}

# ezone (Cannot use compare as old does not allow IP and IP is now mandatory
@test "AdvAir Test Set On 1 Fan ( PassOn3 - Retry )" {
   # old returned "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?repeat=2&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Fan On 1 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Try 1"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[4]}" "Try 2"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info"
   # No longer the same
   assert_equal "${lines[6]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "${lines[7]}" "Try 0"
   assert_equal "${lines[8]}" "Setting json: .aircons.ac1.info.state=\"on\""
   assert_equal "${lines[9]}" "Setting json: .aircons.ac1.info.mode=\"vent\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 10
}

@test "AdvAir Test Set On 1 Fan ( FaillOn5 - Retry )" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?load=testData/failedAirConRetrieveSystemData.txt"
   run ../AdvAir.sh Set Fan On 1 127.0.0.1 TEST_ON
   # The new air will fail after the first 5
   assert_equal "$status" "1"
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Try 1"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[4]}" "Try 2"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[6]}" "Try 3"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[8]}" "Try 4"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 10
}


# zones (Cannot use compare as old does not allow IP and IP is now mandatory
@test "AdvAir Test Set On 1 z01 ( PassOn1 - No Retry )" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?repeat=1&load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Fan On 1 z01 127.0.0.1 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{state:open}}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.zones.z01.state=\"open\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}
