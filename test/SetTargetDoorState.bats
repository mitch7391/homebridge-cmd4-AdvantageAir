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
   if [ -f "/tmp/AirConServer.out" ]; then
      rm "/tmp/AirConServer.out"
   fi
}

beforeEach()
{
   if [ -f "/tmp/myAirData.txt" ]; then
      rm "/tmp/myAirData.txt"
   fi
   if [ -f "/tmp/myAirData.txt.date" ]; then
      rm "/tmp/myAirData.txt.date"
   fi
   if [ -f "/tmp/myAirData.txt.lock" ]; then
      rm "/tmp/myAirData.txt.lock"
   fi
   if [ -f "/tmp/myAirConstants.txt" ]; then
      rm "/tmp/myAirConstants.txt"
   fi
}

@test "AdvAir Test Set TargetDoorState" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlace.txt"
   run ../AdvAir.sh Set Blah TargetDoorState 1 'thing:Garage' 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: thing name: Garage ids=\"6801801\""
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setThing?json={id:\"6801801\",value:0}"
   assert_equal "${lines[4]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[5]}" "Try 0"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}
