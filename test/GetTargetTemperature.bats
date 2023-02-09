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


@test "AdvAir Test Get TargetTemperature (ac1 myZone=0)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Get Blah TargetTemperature 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.myZone"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.setTemp"
   assert_equal "${lines[4]}" "23"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir Test Get TargetTemperature (ac2 myZone=7)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   run ../AdvAir.sh Get Blah TargetTemperature 127.0.0.1 ac2 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info.myZone"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.zones.z07.setTemp"
   assert_equal "${lines[4]}" "24"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

