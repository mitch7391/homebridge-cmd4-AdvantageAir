setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "AdvAir ( ezone inline ) Test Invalid Option 'BLAH'" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   # Old one cannot handle this
   # run ./compare/ezone.txt Get Fan On TEST_ON
   # assert_equal "$status" 0
   run ./compare/AdvAir.sh Get Fan On TEST_ON BLAH
   assert_equal "$status" "1"
   assert_equal "${lines[0]}" "Unknown Option: BLAH"

}

@test "AdvAir ( ezone inline ) Test IP PassOn1" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   # Old one cannot handle this
   # run ./compare/ezone.txt Get Fan On TEST_ON 172.168.2.3
   # assert_equal "$status" 0
   run ./compare/AdvAir.sh Get Fan On TEST_ON 172.168.2.3
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 172.168.2.3"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "0"

}
