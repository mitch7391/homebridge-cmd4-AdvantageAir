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
   rm -f "/tmp/AA-001/AirConServer.out"
}

beforeEach()
{
   rm -f "/tmp/AA-001/myAirData.txt"*
   rm -f "/tmp/AA-001/myAirConstants.txt"*
   if [ ! -d "/tmp/AA-001" ]; then mkdir "/tmp/AA-001"; fi
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

@test "AdvAir Test Get TargetDoorState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?load=testData/myPlace.txt"
   run ../AdvAir.sh Get Blah TargetDoorState 'thing:Garage' 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[5]}" "path: thing name: Garage ids=\"6801801\""
   assert_equal "${lines[6]}" "Parsing for jqPath: .myThings.things.\"6801801\".value"
   assert_equal "${lines[7]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir Test Get TargetDoorState - flip enabled" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?load=testData/myPlace.txt"
   run ../AdvAir.sh Get Blah TargetDoorState 'thing:Garage' flip 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[5]}" "path: thing name: Garage ids=\"6801801\""
   assert_equal "${lines[6]}" "Parsing for jqPath: .myThings.things.\"6801801\".value"
   # flip should make this a 0
   assert_equal "${lines[7]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}
