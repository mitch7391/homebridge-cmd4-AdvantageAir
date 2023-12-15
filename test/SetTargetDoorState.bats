setup()
{
   # This code is run *BEFORE* every test. Even skipped ones.
   # Bug, defining setup() must have code in it
   load './test/setup'
   _common_setup
}

teardown()
{
   # This code is run *AFTER* every test. Even skipped ones.
   # Bug, defining teardown() must have code in it
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

@test "AdvAir Test Set TargetDoorState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlace.txt"
   run ../AdvAir.sh Set "Garage" TargetDoorState 0 'thing:Garage' 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: thing name: Garage ids=\"6801801\""
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setThing?json={id:\"6801801\",value:100}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .myThings.things.\"6801801\".value=100"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Set TargetDoorState - flip enabled" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlace.txt"
   run ../AdvAir.sh Set "Garage" TargetDoorState 0 'thing:Garage' 127.0.0.1 flip TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: thing name: Garage ids=\"6801801\""
   # flip should make the value=0
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setThing?json={id:\"6801801\",value:0}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .myThings.things.\"6801801\".value=0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

