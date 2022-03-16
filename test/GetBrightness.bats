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
#    ../AdvAir.sh Get Blah Brightness z01 192.168.50.99 TEST_ON
#
# Results to stdout:
#     Try 0
#     Parsing for jqPath: .aircons.ac1.info
#     Try 1
#     Parsing for jqPath: .aircons.ac1.info
#     Try 2
#     Parsing for jqPath: .aircons.ac1.info
#     Try 3
#     Parsing for jqPath: .aircons.ac1.info
#     Try 4
#     Parsing for jqPath: .aircons.ac1.info
#     100
#
#
# Note: TEST_ON is so that we do not actually talk to the real device,
#       instead jq parses the given testData.
#
# Then afterwards:
#    $status      - is the result of the ../AdvAir.sh command
#    ${lines[0]}  - is an array of text from the ../AdvAir.sh command
#    assert_equal "${lines[0]}" "Try 0"  - compares the output in line 0.


# Example Cmd4 config for Brightness
# {
#    "type": "Lightbulb",
#    "displayName": "Light2",
#    "on": "FALSE",
#    "brightness": 50,
#    "name": "Light2",
#    "polling": [ { "characteristic": "on" },
#                 { "characteristic": "brightness" }
#               ],
#    "state_cmd_suffix": "'light:Light2' ${IP}"
# },



setup()
{
   load './test/setup'
   _common_setup
}

teardown()
{
   _common_teardown
}
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


@test "AdvAir Test Get Brightness z01" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah Brightness z01 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.zones.z01.value"
   assert_equal "${lines[6]}" "100"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}

@test "AdvAir Test Get Brightness z03" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah Brightness z03 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.zones.z03.value"
   assert_equal "${lines[6]}" "85"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}
