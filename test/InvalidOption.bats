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

@test "AdvAir Test Invalid Option 'BLAH'" {
   beforeEach
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Fan On TEST_ON BLAH
   assert_equal "$status" "1"
   assert_equal "${lines[0]}" "Unknown Option: BLAH"

}

@test "AdvAir Test IP" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" "0"
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

@test "AdvAir Test IP-debug" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Get Fan On TEST_ON 127.0.0.1-debug
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Diagnostic log is turned on"
   assert_equal "${lines[2]}" "Try 0"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[9]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 10

}

