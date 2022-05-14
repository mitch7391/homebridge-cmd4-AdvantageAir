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
   rm -f "${TMPDIR}/AA-001/AirConServer.out"
}

beforeEach()
{
   _common_beforeEach
   rm -f "${TMPDIR}/AA-001/myAirData.txt"*
   rm -f "${TMPDIR}/AA-001/myAirConstants.txt"*
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

@test "AdvAir Test Get Brightness light:Study Patio" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Get Blab Brightness 'light:Study Patio' 127.0.0.1 ac2 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac2.info.constant1"
   assert_equal "${lines[5]}" "path: light name: Study Patio ids=\"a70e005\""
   assert_equal "${lines[6]}" "Parsing for jqPath: .myLights.lights.\"a70e005\".value"
   assert_equal "${lines[7]}" "100"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

