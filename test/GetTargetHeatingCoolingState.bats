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
}

@test "AdvAir ( ezone inline ) Test PassOn5 Get TargetHeatingCoolingState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/dataPassOn5/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn5/getSystemData.txt4"
   run ./compare/AdvAir.sh Get Blah TargetHeatingCoolingState 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" "2"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get TargetHeatingCoolingState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Blah TargetHeatingCoolingState TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "2"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
}

@test "AdvAir ( ezone inline ) Test PassOn3 Get TargetHeatingCoolingState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/dataPassOn3/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn3/getSystemData.txt2"
   run ./compare/AdvAir.sh Get Blah TargetHeatingCoolingState TEST_ON 127.0.0.1 z01
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Try 1"
   assert_equal "${lines[3]}" "Try 2"
   assert_equal "${lines[4]}" "2"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir ( ezone inline ) Test FailOn5 Get TargetHeatingCoolingState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataFailOn5/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Blah TargetHeatingCoolingState TEST_ON 127.0.0.1 z01
   assert_equal "$status" 1
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Try 1"
   assert_equal "${lines[3]}" "Try 2"
   assert_equal "${lines[4]}" "Try 3"
   assert_equal "${lines[5]}" "Try 4"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6

}
