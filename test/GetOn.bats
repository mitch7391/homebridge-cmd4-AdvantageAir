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
   rm -f "${TMPDIR}/AA-001/myAirData.txt"*
   rm -f "${TMPDIR}/AA-001/myAirConstants.txt"*
   if [ ! -d "${TMPDIR}/AA-001" ]; then mkdir "${TMPDIR}/AA-001"; fi
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
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[8]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 9
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
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[7]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}
@test "AdvAir Test Get On light:Study Patio" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Get Blab On 'light:Study Patio' 127.0.0.1 ac2 TEST_ON
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac2.info.constant1"
   assert_equal "${lines[5]}" "path: light name: Study Patio ids=\"a70e005\""
   assert_equal "${lines[6]}" "Parsing for jqPath: .myLights.lights.\"a70e005\".state"
   assert_equal "${lines[7]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}
