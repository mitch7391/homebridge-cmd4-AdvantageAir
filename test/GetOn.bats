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

# ezone
@test "AdvAir Test Get On Fan" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[5]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Get On timer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blab On TEST_ON timer 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.countDownToOn"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.countDownToOff"
   assert_equal "${lines[6]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}

@test "AdvAir Test Get On fanTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blab On TEST_ON fanTimer 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Query the state file: ${TMPDIR}/AA-001/fanTimer.txt.ac1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[6]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}

@test "AdvAir Test Get On coolTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blab On TEST_ON coolTimer 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Query the state file: ${TMPDIR}/AA-001/coolTimer.txt.ac1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[6]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}

@test "AdvAir Test Get On heatTimer" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blab On TEST_ON heatTimer 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Query the state file: ${TMPDIR}/AA-001/heatTimer.txt.ac1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[6]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}

@test "AdvAir Test Get On z01" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blab On TEST_ON 127.0.0.1 z01
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[4]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}
@test "AdvAir Test Get On ac2 myZone=7" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Get Blab On myZone=7 127.0.0.1 ac2 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info.myZone"
   assert_equal "${lines[3]}" "1" #the return value from AdvAir.sh
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
}
@test "AdvAir Test Get On light:Study Patio" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Get Blab On 'light:Study Patio' 127.0.0.1 TEST_ON
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: light name: Study Patio ids=\"a70e005\""
   assert_equal "${lines[3]}" "Parsing for jqPath: .myLights.lights.\"a70e005\".state"
   assert_equal "${lines[4]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}
@test "AdvAir Test Get On light:Theatre (an offline light)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Get Blab On 'light:Theatre' 127.0.0.1 TEST_ON
   assert_equal "$status" "4"
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing id for \"light:Theatre\" failed"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
}
