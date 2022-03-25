setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}

beforeEach()
{
   _common_beforeEach
}


@test "AdvAir ( ezone inline ) Test PassOn5 Get CurrentTemperature" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   beforeEach
   if [ -f "/tmp/myAirContants.txt_TEST" ]; then rm "/tmp/myAirConstants.txt_TEST";fi
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
   # AdvAir now calls getSystemData 5 times before parse
   rm    ./data
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 192.168.0.173 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 192.168.0.173"
   # result is still the same
   assert_equal "${lines[1]}" "${e_lines[0]}"
   assert_equal "${lines[2]}" "${e_lines[5]}"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature z01" {
   ln -s ./testData/dataPassOn1 ./data
   beforeEach
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 192.168.0.173 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 192.168.0.173"
   assert_equal "${lines[1]}" "${e_lines[0]}"
}


@test "AdvAir ( zones inline ) Test PassOn1 Get CurrentTemperature z01" {
   ln -s ./testData/dataPassOn1 ./data
   beforeEach
   run ./compare/zones.txt Get Blah CurrentTemperature z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 192.168.0.173 z01
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 192.168.0.173"
   assert_equal "${lines[1]}" "${e_lines[0]}"
}

@test "AdvAir ( zones inline ) Test PassOn1 Get CurrentTemperature z03" {
   ln -s ./testData/dataPassOn1 ./data
   beforeEach
   run ./compare/zones.txt Get Blah CurrentTemperature z03 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON 192.168.0.173 z03
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "Using IP: 192.168.0.173"
   assert_equal "${lines[1]}" "${e_lines[0]}"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature with NoSensor Data (creating new myAirConstants" {
   # We symbolically link the directory of the test we want to use.
   #ln -s ./testData/dataPassOn1 ./data
   ln -s ./testData/dataOneZone ./data
   beforeEach
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   # No Sensors does not have .aircons.ac1.zones.z01.measuredTemp ( It's 0.0 )
   # Interesting, jq turns 0.0 into just 0.  Not a good thing
   assert_equal "${lines[1]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "${e_lines[0]}"
   # The noSensors fixes this
   assert_equal "${lines[1]}" "21"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature with NoSensor Data (with cached myAirConstants" {
   # We symbolically link the directory of the test we want to use.
   #ln -s ./testData/dataPassOn1 ./data
   ln -s ./testData/dataOneZone ./data
   beforeEach
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "21"
   e_status=$status
   e_lines=("${lines[@]}")
   # Running the same command again, will use the cached myAirConstants
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[1]}"
}
