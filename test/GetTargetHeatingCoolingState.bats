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


@test "AdvAir Test Get TargetHeatingCoolingState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah TargetHeatingCoolingState TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[5]}" "2"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}
