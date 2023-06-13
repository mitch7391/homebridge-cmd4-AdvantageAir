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
}

@test "AdvAir Test SetBrightness for Zone with no Temperature Sensor, specified damper 85" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myAirDataWith3noSensors.txt"
   run ../AdvAir.sh Set Blah Brightness 85 z05 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # No longer the same
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z05.rssi"
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z05:{value:85}}}}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .aircons.ac1.zones.z05.value=85"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test SetBrightness for Zone with Temperature Sensor, specified damper 85" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myAirDataWith3noSensors.txt"
   run ../AdvAir.sh Set Blah Brightness 85 z01 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # No longer the same
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
}

@test "AdvAir Test SetBrightness 15 With timer enabled State Off" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Blah Brightness 15 timer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.state"
   # No longer the same
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{countDownToOff:90}}}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .aircons.ac1.info.countDownToOff=90"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test SetBrightness 15 fanTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # need to create the fanTimer.txt file first
   run ../AdvAir.sh Get Blah Brightness fanTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blah Brightness 15 fanTimer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   assert_equal "${lines[1]}" "Query the state file: ${TMPDIR}/AA-001/fanTimer.txt.ac1"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[4]}" "Update the timer state file: ${TMPDIR}/AA-001/fanTimer.txt.ac1 with timeToOn: 5400 and timeToOff: 0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir Test SetBrightness 20 coolTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # need to create the fanTimer.txt file first
   run ../AdvAir.sh Get Blah Brightness coolTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blah Brightness 20 coolTimer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   assert_equal "${lines[1]}" "Query the state file: ${TMPDIR}/AA-001/coolTimer.txt.ac1"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[4]}" "Update the timer state file: ${TMPDIR}/AA-001/coolTimer.txt.ac1 with timeToOn: 0 and timeToOff: 7200"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir Test SetBrightness 25 heatTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # need to create the fanTimer.txt file first
   run ../AdvAir.sh Get Blah Brightness heatTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blah Brightness 25 heatTimer 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   assert_equal "${lines[1]}" "Query the state file: ${TMPDIR}/AA-001/heatTimer.txt.ac1"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[4]}" "Update the timer state file: ${TMPDIR}/AA-001/heatTimer.txt.ac1 with timeToOn: 9000 and timeToOff: 0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir Test Set brightness 80 light:Study Patio" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Blab Brightness 80 'light:Study Patio' 127.0.0.1 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: light name: Study Patio ids=\"a70e005\""
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"a70e005\",value:80}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .myLights.lights.\"a70e005\".value=80"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}
