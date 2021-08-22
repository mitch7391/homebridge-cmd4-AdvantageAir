setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "AdvAir ( ezone inline ) Test PassOn5 Set On 1" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/ezone.txt Set Fan On 1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Setting url: http://192.168.0.173:2025/setAircon?json={ac1:{info:{state:on,mode:vent,fan:auto}}}"
   e_status=$status
   e_lines=("${lines[@]}")
   run ./compare/AdvAir.sh Set Fan On 1 TEST_ON
   assert_equal "$status" "$e_status"
   assert_equal "${lines[0]}" "${e_lines[0]}"

}

# ezone
@test "AdvAir ( ezone        ) Test PassOn1 Set On 1" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   _common_compareAgainstEzone Set Fan On 1 TEST_ON
}

@test "AdvAir ( ezone        ) Test PassOn3 Set On 1" {
   ln -s ./testData/dataPassOn3 ./data
   _common_compareAgainstEzone Set Fan On 1 TEST_ON
}

@test "AdvAir ( ezone        ) Test PassOn5 Set On 1" {
   ln -s ./testData/dataPassOn5 ./data
   _common_compareAgainstEzone Set Fan On 1 TEST_ON
}

@test "AdvAir ( ezone        ) Test FailOn5 Set On 1" {
   ln -s ./testData/dataFailOn5 ./data
   _common_compareAgainstEzone Set Fan On 1 TEST_ON
}


# zones
@test "AdvAir ( zones        ) Test PassOn1 Set On 1 z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   _common_compareAgainstZones Set Fan On 1 z01 TEST_ON
}

@test "AdvAir ( zones        ) Test PassOn3 Set On 1 z01" {
   ln -s ./testData/dataPassOn3 ./data
   _common_compareAgainstZones Set Fan On 1 z01 TEST_ON
}

@test "AdvAir ( zones        ) Test PassOn5 Set On 1 z01" {
   ln -s ./testData/dataPassOn5 ./data
   _common_compareAgainstZones Set Fan On 1 z01 TEST_ON
}

@test "AdvAir ( zones        ) Test FailOn5 Set On 1 z01" {
   ln -s ./testData/dataFailOn5 ./data
   _common_compareAgainstZones Set Fan On 1 z01 TEST_ON
}
