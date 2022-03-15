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

# fanSpecified = true because no zone (z01) specified
@test "AdvAir ( PassOn1 ) Test Set On 1 - Default: fanSpecified = true, zoneSpecified = false" {
   # old returned "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Fan On 1 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # No longer the same
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "${lines[3]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

# fanSpecified = true because no zone (z01) specified
@test "AdvAir ( FailOn5 ) Test Set On 1 - Default: fanSpecified = true, zoneSpecified = false" {
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


# fanSpecified = false because zone (z01) specified
@test "AdvAir ( PassOn1 ) Test Set On 1 z01 - fanSpecified = false, zoneSpecified = true" {
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

# fanSpecified = false because zone (z01) specified
@test "AdvAir ( PassOn1 ) Test Set On 1 z01 - fanSpecified = false, timerSpecified = true" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Fan On 0 timer 127.0.0.1 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # AdvAir.sh Set both "countDownToOn" and "countDownToOff" to 0
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{countDownToOn:0}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{countDownToOff:0}}}"
   assert_equal "${lines[5]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[6]}" "Try 0"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}


# fanSpecified = false because zone (z01) specified
@test "AdvAir ( FailOn5 ) Test Set On 1 z01 - fanSpecified = false, zoneSpecified = true" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/failedAirConRetrieveSystemData.txt"
   run ../AdvAir.sh Set Fan On 1 z01 127.0.0.1 TEST_ON
   assert_equal "$status" "1"
   # AdvAir.sh does a get first
   # The new air will fail after the first 5
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
