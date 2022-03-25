setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "AdvAir ( zones inline ) Test PassOn5 Get StatusLowBattery z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/zones.txt Get Blah StatusLowBattery z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   # No fault found
   assert_equal "${lines[5]}" "0"
   z_status=$status
   z_lines=("${lines[@]}")
   # AdvAir now calls getSystemData 5 times before parse
   rm    ./data
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/AdvAir.sh Get Blah StatusLowBattery z01 TEST_ON
   assert_equal "$status" "$z_status" ]
   assert_equal "${lines[0]}" "${z_lines[0]}"
   assert_equal "${lines[1]}" "${z_lines[5]}"

}

@test "AdvAir ( zones        ) Test PassOn1 Get StatusLowBattery z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   _common_compareAgainstZones Get Blah StatusLowBattery z01 TEST_ON
}
