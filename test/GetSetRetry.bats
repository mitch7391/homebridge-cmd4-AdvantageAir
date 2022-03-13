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

@test "AdvAir ( PassOn5 - Retry ) Test Get CurrentTemperature" {
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

@test "AdvAir ( PassOn1 - No Retry ) Test Get CurrentTemperature" {
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

@test "AdvAir ( PassOn3 - Retry ) Test Get CurrentTemperature" {
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

@test "AdvAir ( FailOn5 - Retry ) Test Get CurrentTemperature" {
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


@test "AdvAir ( PassOn5 - Retry ) Test Set On 1" {
   # Old returned "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
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
   assert_equal "${lines[10]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "${lines[11]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[12]}" "Try 0"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 14

}

# ezone (Cannot use compare as old does not allow IP and IP is now mandatory
@test "AdvAir ( PassOn3 - Retry ) Test Set On 1" {
   # old returned "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/failedAirConRetrieveSystemData.txt"
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
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
   assert_equal "${lines[6]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "${lines[7]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[8]}" "Try 0"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 10
}

@test "AdvAir ( FaillOn5 - Retry ) Test Set On 1" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/failedAirConRetrieveSystemData.txt"
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
@test "AdvAir ( PassOn1 - No Retry ) Test Set On 1 z01" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Fan On 1 z01 127.0.0.1 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{zones:{z01:{state:open}}}}"
   assert_equal "${lines[3]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}
