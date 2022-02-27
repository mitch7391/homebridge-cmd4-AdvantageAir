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


@test "AdvAir ( ezone inline ) Test PassOn5 Set On 1" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Set Fan On 1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/dataPassOn5/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn5/getSystemData.txt4"
   run ./compare/AdvAir.sh Set Fan On 1 127.0.0.1 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   # No longer the same
   assert_equal "${lines[5]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "${lines[6]}" "Try 0"
   assert_equal "$status" "$e_status"

}

# ezone (Cannot use compare as old does not allow IP and IP is now mandatory
@test "AdvAir ( ezone inline ) Test PassOn3 Set On 1" {
   skip
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/ezone.txt Set Fan On 1 TEST_ON
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/dataPassOn3/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn3/getSystemData.txt2"
   run ./compare/AdvAir.sh Set Fan On 1 127.0.0.1 TEST_ON
   # No longer the same
   assert_equal "${lines[0]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "$status" "$e_status"
}

@test "AdvAir ( ezone inline ) Test FailOn5 Set On 1" {
   skip
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/ezone.txt Set Fan On 1 TEST_ON
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   curl -s -g "http://localhost:$PORT?load=testData/dataFailOn5/getSystemData.txt0"
   run ./compare/AdvAir.sh Set Fan On 1 127.0.0.1 TEST_ON
   # No longer the same
   assert_equal "${lines[0]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "$status" "$e_status"

}


# zones (Cannot use compare as old does not allow IP and IP is now mandatory
@test "AdvAir ( zones inline ) Test PassOn1 Set On 1 z01" {
   skip
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/zones.txt Set Fan On 1 z01 TEST_ON
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{zones:{z01:{state:open}}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Set Fan On 1 z01 127.0.0.1 TEST_ON
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "$status" "$e_status"
}

@test "AdvAir ( zones inline ) Test PassOn3 Set On 1 z01" {
   skip
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/zones.txt Set Fan On 1 z01 TEST_ON
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{zones:{z01:{state:open}}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/dataPassOn3/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn3/getSystemData.txt2"
   run ./compare/AdvAir.sh Set Fan On 1 z01 127.0.0.1 TEST_ON
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "$status" "$e_status"
}

@test "AdvAir ( zones inline ) Test PassOn5 Set On 1 z01" {
   skip
   ln -s ./testData/dataPassOn5 ./data
   run ./compare/zones.txt Set Fan On 1 z01 TEST_ON
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{zones:{z01:{state:open}}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/dataPassOn5/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn5/getSystemData.txt4"
   run ./compare/AdvAir.sh Set Fan On 1 z01 127.0.0.1 TEST_ON
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "$status" "$e_status"
}

@test "AdvAir ( zones inline ) Test FailOn5 Set On 1 z01" {
   skip
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/zones.txt Set Fan On 1 z01 TEST_ON
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{zones:{z01:{state:open}}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataFailOn5/getSystemData.txt0"
   run ./compare/AdvAir.sh Set Fan On 1 z01 127.0.0.1 TEST_ON
   assert_equal "$status" "$e_status"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[0]}" "${e_lines[0]}"
}

@test "AdvAir ( StopServer )" {
   stopServer
}

