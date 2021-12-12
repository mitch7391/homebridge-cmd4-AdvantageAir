# Understanding these test cases
#
# What we are trying to do is compare the execution of AdvAir.sh with either
# the previous ezone/zones scripts or some expected output. In that way
# you can rerun these tests after any change to AdvAir.sh and gaurantee the
# result in production without having to try every possible scenario.

# Unit tests have a setup function before and a teardown function after each
# test. These can be ignored if you are just trying to figure out what
# went wrong. Remember that what we are testing is BASH shell commands you can
# execute them also from the command line.

# For example:
#    cd test
#    ln -s ./testData/dataPassOn5 ./data
#    ./compare/AdvAir.sh Get Blah Brightness z01 192.168.50.99 TEST_ON
#
# Results to stdout:
#     Try 0
#     Try 1
#     Try 2
#     Try 3
#     Try 4
#     100
#
#
# Note: TEST_ON is so that we do not actually talk to the real device,
#       instead jq parses the given testData.
#
# Then afterwards:
#    $status      - is the result of the ./compare/AdvAir.sh command
#    ${lines[0]}  - is an array of text from the ./compare/AdvAir.sh command
#    assert_equal "${lines[0]}" "Try 0"  - compares the output in line 0.



setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}


@test "AdvAir ( ezone inline ) Test PassOn5 Get Brightness z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # The original scripts do not have this function, so you can only
   # test against known data
   run ./compare/AdvAir.sh Get Blah Brightness z01 192.168.50.99 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" "100"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get Brightness z01" {
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/AdvAir.sh Get Blah Brightness z01 192.168.50.99 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "100"
}

@test "AdvAir ( ezone inline ) Test PassOn3 Get Brightness z01" {
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/AdvAir.sh Get Blah Brightness z01 192.168.50.99 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "100"
}


@test "AdvAir ( ezone inline ) Test FailOn5 Get Brightness z01" {
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/AdvAir.sh Get Blah Brightness z01 192.168.50.99 TEST_ON
   assert_equal "$status" 1
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
}

@test "AdvAir ( ezone inline ) Test PassOn1 Get Brightness z03" {
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/AdvAir.sh Get Blah Brightness z03 192.168.50.99 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "85"
}
