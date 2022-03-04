# Understanding these test cases
#
# What we are trying to do is compare the execution of AirConServer.js
# So that way you can rerun these tests after any change gaurantees the
# result in production without having to try every possible scenario.

# Unit tests have a setup function before and a teardown function after each
# test. These can be ignored if you are just trying to figure out what
# went wrong. Remember that what we are testing is BASH shell commands you can
# execute them also from the command line.

# For example:
#    cd test
#    node ./AirConServer.js
#
# Results to stdout:
#
#
# Then afterwards:
#    $status      - is the result of the AirConServer.sh command
#    ${lines[0]}  - is an array of text from the AirConServer.js command
#    assert_equal "${lines[0]}" "Try 0"  - compares the output in line 0.

before()
{
   if [ -f "/tmp/AirConServer.out" ]; then
      rm "/tmp/AirConServer.out"
   fi
}

beforeEach()
{
   if [ -f "/tmp/myAirData.txt" ]; then
      rm "/tmp/myAirData.txt"
   fi
   if [ -f "/tmp/myAirData.txt.date" ]; then
      rm "/tmp/myAirData.txt.date"
   fi
   if [ -f "/tmp/myAirData.txt.lock" ]; then
      rm "/tmp/myAirData.txt.lock"
   fi
   if [ -f "/tmp/myAirConstants.txt" ]; then
      rm "/tmp/myAirConstants.txt"
   fi
}

setup() {
   # This code is run *BEFORE* every test. Even skipped ones.
   # Bug, defining setup() must have code in it
   echo "Before each" > /dev/null
}

teardown() {
   # This code is run *AFTER* every test. Even skipped ones.
   # Bug, defining teardown() must have code in it
   echo "After each" > /dev/null
}

@test "Sample Test (How to Skip)" {
   skip "This test is skipped just to show that skippping can be done."
   echo "Done"
}

@test "Sample Test Check Status of run command" {
   beforeEach
   # The Bats run command gobbles up stdout
   run echo "Hello world"
   [ "$status" = "0" ]
}

@test "Sample Test Check stdout of command" {
   beforeEach
   # The Bats run command gobbles up stdout
   # Remove the word "run" if test fails to see results to stdout
   run echo "Hello world"
   [ "${lines[0]}" = "Hello world" ]
}
