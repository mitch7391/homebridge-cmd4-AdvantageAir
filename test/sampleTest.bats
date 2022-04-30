# Understanding these test cases
#
# What we are trying to do is compare the execution of AdvAir.sh with
# what it produces to stdout with various options given to it.
# Having these tests rerun each time after every change gaurantees the
# result in production without having to try every possible scenario.

# AdvAir.sh requires an AirCon, which we do not have or do not want to mess up.
# So instead we have a fake AirConServer.  The AirConServer is created automatically
# during the common_setup. So testing a bat is usually done by:
# npm run bats bats/GetCurrentTempature.bats


# If you need to test individual "curl" commands, you would first start the
# AirConServer yourself and then in another terminal window, run the
# specific curl command.
#
# For example in Terminal 1:
#    cd test
#    node ./AirConServer.js
#
# For example in Terminal 2:
#    # Issue the reInit
#  curl -s -g "http://localhost:2025/reInit"
#  # Do the load
#  curl -s -g "http://localhost:2025?load=testData/myPlace.txt"
#  run ../AdvAir.sh Get Blah CurrentDoorState 'thing:Garage' 127.0.0.1 TEST_ON

# The results to stdout are usually just the result, but are expanded via TEST_ON:
#  Try 0
#  Parsing for jqPath: .aircons.ac1.info
#  Parsing for jqPath: .aircons.ac1.info.noOfZones
#  Parsing for jqPath: .aircons.ac1.zones.z01.rssi
#  Parsing for jqPath: .aircons.ac1.info.constant1
#  path: thing name: Garage ids=\"6801801\"
#  Parsing for jqPath: .myThings.things.\"6801801\".value
#  1

#
# Script parsing have a few extra variables:
#    $status      - is the result of the AirConServer.sh command
#    ${lines[0]}  - is an array of text from the AirConServer.js command
#    assert_equal "${lines[0]}" "Try 0"  - compares the output in line 0.

setup()
{
   # This code is run *BEFORE* every test. Even skipped ones.
   # Bug, defining setup() must have code in it
   load './test/setup'
   _common_setup
}

teardown()
{
   # This code is run *AFTER* every test. Even skipped ones.
   # Bug, defining teardown() must have code in it
   _common_teardown
}
before()
{
      rm -f "/tmp/AA-001/AirConServer.out"
}

beforeEach()
{
   rm -f "/tmp/AA-001/myAirData.txt"*
   rm -f "/tmp/AA-001/myAirConstants.txt"*
   if [ ! -d "/tmp/AA-001" ]; then mkdir "/tmp/AA-001"; fi
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

@test "AdvAir Test Get CurrentDoorState ( Sample )" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?load=testData/myPlace.txt"
   run ../AdvAir.sh Get Blah CurrentDoorState 'thing:Garage' 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[5]}" "path: thing name: Garage ids=\"6801801\""
   assert_equal "${lines[6]}" "Parsing for jqPath: .myThings.things.\"6801801\".value"
   assert_equal "${lines[7]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}
