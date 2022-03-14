# Understanding these test cases
#
# What we are trying to do is compare the execution of AirConServer.js
# So that way you can rerun these tests after any change gaurantees the
# result in production without having to try every possible scenario.

# Unit tests have a setup function before and a teardown function after each
# test. These can be ignored if you are just trying to figure out what
# went wrong. Remember that what we are testing is BASH shell commands you can
# execute them also from the command line.

# For example:
#    cd test
#    node ./AirConServer.js
#
# Results to stdout:
#
#
# Then afterwards:
#    $status      - is the result of the AirConServer.sh command
#    ${lines[0]}  - is an array of text from the AirConServer.js command
#    assert_equal "${lines[0]}" "Try 0"  - compares the output in line 0.

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
   if [ -f "/tmp/AirConServer.out" ]; then
      rm "/tmp/AirConServer.out"
   fi
}

eraseAirConServerDataFile()
{
   if [ -f "/tmp/AirConServerData.json" ]; then
      rm "/tmp/AirConServerData.json"
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

@test "StartServer Test /reInit" {
   beforeEach
   # Issue the reInit
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
}

@test "StartServer Test ?load" {
   beforeEach
   echo "Doing curl"
   run curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   echo "done StartServer testCASE"
}

@test "StartServer Test /getSystemData fails appropriately when nothing is loaded" {
   beforeEach
   # Issue the reInit
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # Get the systemData after the reInit
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "404 No File Loaded"
}

@test "StartServer Test ?failureCount fails appropriately" {
   beforeEach
   # run an old, now illegal command
   run curl -s -g "http://localhost:$PORT?failureCount=4"
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "SERVER: UNKNOWN query: failureCount"
   echo "done failureCount testCASE"
}

@test "StartServer Test /dumpstack, no entries" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
}

@test "StartServer Test /dumpstack, 1 entry, no repeat" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack with 1 entry no repeats
   run curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 0 filename: testData/basicPassingSystemData.txt"
}

@test "StartServer Test /dumpstack, 1 entry, repeat=5" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 5
   run curl -s -g "http://localhost:$PORT?repeat=5&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 5 filename: testData/basicPassingSystemData.txt"
}

@test "StartServer Test /dumpstack, 2 entry, repeat=3 & 5" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 3
   run curl -s -g "http://localhost:$PORT?repeat=3&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 3
   run curl -s -g "http://localhost:$PORT?repeat=5&load=testData/failedAirConRetrieveSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 2
   assert_equal "${lines[0]}" "repeat: 3 filename: testData/basicPassingSystemData.txt"
   assert_equal "${lines[1]}" "repeat: 5 filename: testData/failedAirConRetrieveSystemData.txt"
}

@test "StartServer Test /getSystemData, 1 entry, more requests than repeat, dumping stack" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 3
   run curl -s -g "http://localhost:$PORT?repeat=2&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # getSystemData 1
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r1=${#lines[@]}
   assert_equal "${#r1}" 3
   # getSystemData 2
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r2=${#lines[@]}
   assert_equal "$r1" "$r2"
   # getSystemData 3
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r3=${#lines[@]}
   assert_equal "$r1" "$r3"
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: -1 filename: testData/basicPassingSystemData.txt"
}

@test "StartServer Test /getSystemData, 2 entry repeat=1 & 2, more requests than repeat, dumping stack" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 1
   run curl -s -g "http://localhost:$PORT?repeat=1&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 2 Different data
   run curl -s -g "http://localhost:$PORT?repeat=2&load=testData/failedAirConRetrieveSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 2
   assert_equal "${lines[0]}" "repeat: 1 filename: testData/basicPassingSystemData.txt"
   assert_equal "${lines[1]}" "repeat: 2 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 1
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r1=${#lines[@]}
   assert_equal "${r1}" 368
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 2 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 2 (Should be new data )
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 237
   r2=${#lines[@]}
   assert_equal "${r2}" 237
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 1 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 3
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 237
   r3=${#lines[@]}
   assert_equal "${r3}" 237
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 0 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 4
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 237
   r4=${#lines[@]}
   assert_equal "$r3" "$r4"
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: -1 filename: testData/failedAirConRetrieveSystemData.txt"
}

@test "StartServer Test Load/Save data" {
   beforeEach
   eraseAirConServerDataFile
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 1
   run curl -s -g "http://localhost:$PORT?repeat=1&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # setAircon state = open
   run curl -s -g "http://localhost:$PORT?save"
   assert_equal "$status" 0
   # assert_equal "${#lines[@]}" 1
   # getSystemData - The size should still be the same
   # Save creates the /tmp/AirConSererData.json file
   run diff testData/basicPassingSystemData.txt /tmp/AirConServerData.json
   assert_equal "$status" 0
   #assert_equal "${#lines[@]}" 1
}

@test "StartServer Test Load/Set/Read new data" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:$PORT/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 1
   run curl -s -g "http://localhost:$PORT?repeat=1&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # AdvAir.sh TargetTemperature 9
   # ".aircons.$ac.info.setTemp"
   run curl -s -g "http://localhost:$PORT/setAircon?json={ac1:{info:{setTemp:9}}}"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # getSystemData
   # Check the Temp change
   run curl -s -g "http://localhost:$PORT/getSystemData" -o /tmp/out
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   jqResult=$( jq -e ".aircons.ac1.info.setTemp" < /tmp/out )
   echo "jqResult=$jqResult"
   assert_equal "$jqResult" "\"9\""
   # setAircon Temp = 22
   run curl -s -g "http://localhost:$PORT/setAircon?json={ac1:{info:{setTemp:22}}}"
   assert_equal "$status" 0
   # Check the Temp change
   run $( curl -s -g "http://localhost:$PORT/getSystemData" -o /tmp/out )
   assert_equal "$status" 0
   jqResult=$( jq -e ".aircons.ac1.info.setTemp" < /tmp/out )
   assert_equal "$jqResult" "\"22\""
}

@test "StartServer Test Load/Set/Read new data using AdvAir.sh" {
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
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:on,mode:heat}}}"
   assert_equal "${lines[3]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
   run ../AdvAir.sh Get Blah TargetHeatingCoolingState 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[5]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6

   # ReDo using state: off
   run ../AdvAir.sh Set Blah TargetHeatingCoolingState 0 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:$PORT/setAircon?json={ac1:{info:{state:off}}}"
   assert_equal "${lines[3]}" "Try 0"
   # AdvAir.sh does a get last
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
   run ../AdvAir.sh Get Blah TargetHeatingCoolingState 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[2]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3

}
