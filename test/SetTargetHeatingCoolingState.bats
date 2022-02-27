
setup()
{
   load './test/setup'
   _common_setup
}

load 'test/startServer'
load 'test/stopServer'

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

@test "AdvAir ( StartServer )" {
   before
   stopServer
   rc=$?
   assert_equal "$rc" 0
   # Do not use 'run' here as it would always spit output to stdout. Maybe later?
   startServer
   rc=$?
   assert_equal "$rc" 0
}


@test "AdvAir ( ezone inline ) Test PassOn1 Set TargetHeatingCoolingState 1" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Set Blah TargetHeatingCoolingState 1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:heat}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Set Blah TargetHeatingCoolingState 1 127.0.0.1 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   # No longer the same
   assert_equal "${lines[1]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:heat}}}"
   assert_equal "${lines[2]}" "Try 0"
   assert_equal "$status" "$e_status"
}

@test "AdvAir ( StopServer )" {
   stopServer
}

