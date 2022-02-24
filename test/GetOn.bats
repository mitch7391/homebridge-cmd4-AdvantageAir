setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
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
   # AdvAir now calls getSystemData 5 times before parse
   rm    ./data
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/AdvAir.sh Get Fan On TEST_ON
   assert_equal "$status" "$e_status" ]
   # result is still the same
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[5]}"

}

# ezone
@test "AdvAir ( ezone        ) Test PassOn1 Get On" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   _common_compareAgainstEzone Get Fan On TEST_ON
}


# zones
@test "AdvAir ( zones        ) Test PassOn1 Get On z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   _common_compareAgainstZones Get Fan On z01 TEST_ON
}
