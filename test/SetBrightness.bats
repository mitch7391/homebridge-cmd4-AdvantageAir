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

@test "AdvAir Test SetBrightness With Zone Specified damper 15" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Blah Brightness 15 z01 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # No longer the same
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{value:15}}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.zones.z01.value=15"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}
@test "AdvAir Test SetBrightness With timer enabled State Off" {
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
