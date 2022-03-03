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

@test "AdvAir ( ezone inline ) Test Invalid Option 'BLAH'" {
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Fan On TEST_ON BLAH
   assert_equal "$status" "1"
   assert_equal "${lines[0]}" "Unknown Option: BLAH"

}

@test "AdvAir ( ezone inline ) Test IP PassOn1" {
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3

}
