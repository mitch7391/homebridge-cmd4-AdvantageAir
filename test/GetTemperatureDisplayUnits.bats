setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "AdvAir ( ezone inline ) Get PassOn1 TemperatureDisplayUnits ( inline )" {
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Get Blah TemperatureDisplayUnits TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Get Blah TemperatureDisplayUnits TEST_ON
   assert_equal "$status" "$e_status" ]
   assert_equal "${lines[0]}" "${e_lines[0]}"
}

@test "AdvAir ( ezone       ) Get PassOn1 TemperatureDisplayUnits ( inline )" {
   # Bats "run" gobbles up all the stdout. Remove for debugging
   _common_compareAgainstEzone Get Blah TemperatureDisplayUnits TEST_ON
}
