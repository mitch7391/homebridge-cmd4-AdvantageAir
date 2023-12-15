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
   rm -f "${TMPDIR}/AA-001/fanTimer.txt"*
   rm -f "${TMPDIR}/AA-001/coolTimer.txt"*
   rm -f "${TMPDIR}/AA-001/heatTimer.txt"*
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
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z01.value"
   assert_equal "${lines[3]}" "100"
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
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
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z03.value"
   assert_equal "${lines[3]}" "85"
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
}

@test "AdvAir Test Get Brightness timer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah Brightness timer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.state"          
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.countDownToOff"          
   assert_equal "${lines[4]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir Test Get Brightness fanTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah Brightness fanTimer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Query the state file: ${TMPDIR}/AA-001/fanTimer.txt.ac1"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.state"          
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.mode"          
   assert_equal "${lines[5]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Get Brightness fanTimer (update timer)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah Brightness fanTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blah Brightness 15 fanTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Get Blah Brightness fanTimer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Query the state file: ${TMPDIR}/AA-001/fanTimer.txt.ac1"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.state"          
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.mode"          
   assert_equal "${lines[4]}" "Update the timer for vent with timeToOn: 5398 and timeToOff: 0"          
   assert_equal "${lines[5]}" "Update the timer state file: ${TMPDIR}/AA-001/fanTimer.txt.ac1 with timeToOn: 5398 and timeToOff: 0"          
   assert_equal "${lines[6]}" "15"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}

@test "AdvAir Test Get Brightness coolTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah Brightness coolTimer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Query the state file: ${TMPDIR}/AA-001/coolTimer.txt.ac1"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.state"          
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.mode"          
   assert_equal "${lines[5]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Get Brightness heatTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah Brightness heatTimer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Query the state file: ${TMPDIR}/AA-001/heatTimer.txt.ac1"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.state"          
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.mode"          
   assert_equal "${lines[5]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Get Brightness light:Study Patio" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Get "Study Patio" Brightness 'light:Study Patio' 127.0.0.1 ac2 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[2]}" "path: light name: Study Patio ids=\"a70e005\""
   assert_equal "${lines[3]}" "Parsing for jqPath: .myLights.lights.\"a70e005\".value"
   assert_equal "${lines[4]}" "100"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

