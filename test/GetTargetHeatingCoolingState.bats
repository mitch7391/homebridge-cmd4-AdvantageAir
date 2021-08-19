setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "AdvAir ( ezone inline ) Test PassOn5 Get TargetHeatingCoolingState" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Get Blah TargetHeatingCoolingState TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" "2"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Get Blah TargetHeatingCoolingState TEST_ON
   assert_equal "$status" "$e_status" ]
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[1]}"
   assert_equal "${lines[2]}" "${e_lines[2]}"
   assert_equal "${lines[3]}" "${e_lines[3]}"
   assert_equal "${lines[4]}" "${e_lines[4]}"
   assert_equal "${lines[5]}" "${e_lines[5]}"
}

@test "AdvAir ( ezone        ) Test PassOn1 Get TargetHeatingCoolingState" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   _common_compareAgainstEzone Get Blah TargetHeatingCoolingState TEST_ON
}

@test "AdvAir ( ezone        ) Test PassOn3 Get TargetHeatingCoolingState" {
   ln -s ./testData/dataPassOn3 ./data
   _common_compareAgainstEzone Get Blah TargetHeatingCoolingState TEST_ON
}

@test "AdvAir ( ezone        ) Test PassOn5 Get TargetHeatingCoolingState" {
   ln -s ./testData/dataPassOn5 ./data
   _common_compareAgainstEzone Get Blah TargetHeatingCoolingState TEST_ON
}

@test "AdvAir ( ezone        ) Test FailOn5 Get TargetHeatingCoolingState" {
   ln -s ./testData/dataFailOn5 ./data
   _common_compareAgainstEzone Get Blah TargetHeatingCoolingState TEST_ON
}
