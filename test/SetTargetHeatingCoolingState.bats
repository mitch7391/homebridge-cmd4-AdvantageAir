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

@test "AdvAir Test Set TargetHeatingCoolingState 1" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Blah TargetHeatingCoolingState 1 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # No longer the same
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{state:on,mode:heat}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.info.state=\"on\""
   assert_equal "${lines[5]}" "Setting json: .aircons.ac1.info.mode=\"heat\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}
