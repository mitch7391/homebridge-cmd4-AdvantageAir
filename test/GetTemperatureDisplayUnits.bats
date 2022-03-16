setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "AdvAir Test Get TemperatureDisplayUnits" {
   # Bats "run" gobbles up all the stdout. Remove for debugging
   # run ./compare/ezone.txt Get Blah TemperatureDisplayUnits TEST_ON
   # assert_equal "$status" 0
   # For shellcheck
   assert_equal "0" "0"
   # No more lines than expected
   # assert_equal "${#lines[@]}" 1
   # e_status=$status
   # e_lines=("${lines[@]}")
   # TemperatureDisplayUnits has been removed from AdvAir.sh
   # run ../AdvAir.sh Get Blah TemperatureDisplayUnits TEST_ON
   # assert_equal "$status" "$e_status" ]
   # assert_equal "${lines[0]}" "${e_lines[0]}"
}
