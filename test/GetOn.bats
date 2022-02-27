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


@test "AdvAir ( ezone inline ) Test PassOn5 Get On" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Get Fan On TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/dataPassOn5/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn5/getSystemData.txt4"
   run ./compare/AdvAir.sh Get Fan On 127.0.0.1 TEST_ON
   assert_equal "$status" "$e_status" ]
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[1]}"
   assert_equal "${lines[2]}" "${e_lines[2]}"
   assert_equal "${lines[3]}" "${e_lines[3]}"
   assert_equal "${lines[4]}" "${e_lines[4]}"
   assert_equal "${lines[5]}" "${e_lines[5]}"

}

# ezone
@test "AdvAir ( ezone inline ) Test PassOn1 Get On" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/ezone.txt Get Fan On TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
}

@test "AdvAir ( ezone inline ) Test PassOn3 Get On" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/ezone.txt Get Fan On TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/dataPassOn3/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn3/getSystemData.txt2"
   run ./compare/AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"

}

@test "AdvAir ( ezone inline ) Test FailOn5 Get On" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/ezone.txt Get Fan On TEST_ON
   assert_equal "$status" 1
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataFailOn5/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"
   assert_equal "${lines[5]}" "${e_lines[4]}"
}


# zones
@test "AdvAir ( zones inline ) Test PassOn1 Get On z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/zones.txt Get Fan On z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "1"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Fan On TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
}

@test "AdvAir ( zones inline ) Test PassOn3 Get On z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/zones.txt Get Fan On z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "1"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/dataPassOn3/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn3/getSystemData.txt2"
   run ./compare/AdvAir.sh Get Fan On TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"

}

@test "AdvAir ( zones inline ) Test PassOn5 Get On z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   run ./compare/zones.txt Get Fan On z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" "1"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/dataPassOn5/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn5/getSystemData.txt4"
   run ./compare/AdvAir.sh Get Fan On TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"
   assert_equal "${lines[5]}" "${e_lines[4]}"
   assert_equal "${lines[6]}" "${e_lines[5]}"
}

@test "AdvAir ( zones inline ) Test FailOn5 Get On z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/zones.txt Get Fan On z01 TEST_ON
   assert_equal "$status" 1
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataFailOn5/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Fan On TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"
   assert_equal "${lines[5]}" "${e_lines[4]}"
}

@test "AdvAir ( StopServer )" {
   stopServer
}

