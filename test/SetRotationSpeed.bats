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


@test "AdvAir Test Set RotationSpeed 83 - fanSpeed" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Set Blah RotationSpeed 83 TEST_ON 127.0.0.1 fanSpeed
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{fan:high}}}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .aircons.ac1.info.fan=\"high\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Set RotationSpeed 78 - z01 ac1 (rssi=0 and zoneSpecified=true)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Set Blah RotationSpeed 78 TEST_ON z01 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[4]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{value:80}}}}"
   assert_equal "${lines[5]}" "Try 0"
   assert_equal "${lines[6]}" "Setting json: .aircons.ac1.zones.z01.value=80"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7 
}

@test "AdvAir Test Set RotationSpeed 78 - z01 ac2 (rssi!=0 and zoneSpecified=true)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ../AdvAir.sh Set Blah RotationSpeed 78 TEST_ON z01 127.0.0.1 ac2
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac2.zones.z01.rssi"
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
}
