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
   rm "${TMPDIR}/AA-001/AirConServer.out"
}

beforeEach()
{
   _common_beforeEach
   rm -f "${TMPDIR}/AA-001/myAirData.txt"*
}

# Typical GarageDoorConfig for currentDoorState
#  "type": "GarageDoorOpener",
#  "displayName": "Garage Door",
#  "currentDoorState": 0,
#  "targetDoorState": 0,
#  "polling": [ { "characteristic": "currentDoorState" },
#               { "characteristic": "targetDoorState" }
#             ],
#  "state_cmd_suffix": "'thing:Garage' ${IP}"

@test "AdvAir Test Get CurrentDoorState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlace.txt"
   run ../AdvAir.sh Get Blah CurrentDoorState 'thing:Garage' 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: thing name: Garage ids=\"6801801\""
   assert_equal "${lines[3]}" "Parsing for jqPath: .myThings.things.\"6801801\".value"
   assert_equal "${lines[4]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir Test Get CurrentDoorState - flip enabled" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlace.txt"
   run ../AdvAir.sh Get Blah CurrentDoorState 'thing:Garage' flip 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: thing name: Garage ids=\"6801801\""
   assert_equal "${lines[3]}" "Parsing for jqPath: .myThings.things.\"6801801\".value"
   # flip should make this a 0
   assert_equal "${lines[4]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}
