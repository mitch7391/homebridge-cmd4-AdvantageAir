setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "combo ( ezone ) Get PassOn1 TemperatureDisplayUnits ( inline )" {
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/combo.txt Get Blah TemperatureDisplayUnits TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "0"
}
