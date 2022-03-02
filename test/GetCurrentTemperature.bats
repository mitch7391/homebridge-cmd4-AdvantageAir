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

@test "AdvAir ( ezone inline ) Test PassOn5 Get CurrentTemperature" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" "25.4"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/dataPassOn5/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn5/getSystemData.txt4"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"
   assert_equal "${lines[5]}" "${e_lines[4]}"
   assert_equal "${lines[6]}" "${e_lines[5]}"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
}

@test "AdvAir ( ezone inline ) Test PassOn3 Get CurrentTemperature" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/dataPassOn3/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn3/getSystemData.txt2"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
}

@test "AdvAir ( ezone inline ) Test FailOn5 Get CurrentTemperature" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
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
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"
   assert_equal "${lines[5]}" "${e_lines[4]}"
}


@test "AdvAir ( zones inline ) Test PassOn1 Get CurrentTemperature z01" {
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/zones.txt Get Blah CurrentTemperature z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
}

@test "AdvAir ( zones inline ) Test PassOn3 Get CurrentTemperature z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/zones.txt Get Blah CurrentTemperature z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=2&load=testData/dataPassOn3/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn3/getSystemData.txt2"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
}

@test "AdvAir ( zones inline ) Test PassOn5 Get CurrentTemperature z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   run ./compare/zones.txt Get Blah CurrentTemperature z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" "25.4"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?repeat=4&load=testData/dataPassOn5/getSystemData.txt0"
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn5/getSystemData.txt4"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"
   assert_equal "${lines[5]}" "${e_lines[4]}"
   assert_equal "${lines[6]}" "${e_lines[5]}"
}

@test "AdvAir ( zones inline ) Test FailOn5 Get CurrentTemperature z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/zones.txt Get Blah CurrentTemperature z01 TEST_ON
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
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[1]}"
   assert_equal "${lines[3]}" "${e_lines[2]}"
   assert_equal "${lines[4]}" "${e_lines[3]}"
   assert_equal "${lines[5]}" "${e_lines[4]}"
}

@test "AdvAir ( zones inline ) Test PassOn1 Get CurrentTemperature z03" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/zones.txt Get Blah CurrentTemperature z03 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataPassOn1/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1 z03
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature with NoSensor Data (creating new myAirConstants" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataOneZone ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   # No Sensors does not have .aircons.ac1.zones.z01.measuredTemp ( It's 0.0 )
   # Interesting, jq turns 0.0 into just 0.  Not a good thing
   assert_equal "${lines[1]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   before
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataOneZone/getSystemData.txt0"
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[0]}"
   # The noSensors fixes this
   assert_equal "${lines[2]}" "21"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature with NoSensor Data (with cached myAirConstants" {
   # We symbolically link the directory of the test we want to use.
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/dataOneZone/getSystemData.txt0"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "21"
   e_status=$status
   e_lines=("${lines[@]}")
   # Running the same command again, will use the cached myAirConstants
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 127.0.0.1
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "${e_lines[1]}"
   assert_equal "${lines[2]}" "21"
}
