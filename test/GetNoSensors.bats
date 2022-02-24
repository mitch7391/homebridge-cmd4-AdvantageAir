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

#   if [ -f "/tmp/myAirContants.txt" ]; then rm "/tmp/myAirConstants.txt";fi


@test "AdvAir ( ezone inline ) Test PassOn1 Get CurrentTemperature with NoSensor Data" {
   # We symbolically link the directory of the test we want to use.
   #ln -s ./testData/dataPassOn1 ./data
   ln -s ./testData/dataOneZone ./data
   beforeEach
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "25.4"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Get Blah CurrentTemperature TEST_ON
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "${e_lines[0]}"
   # The noSensors fixes this
   assert_equal "${lines[1]}" "23"
}
