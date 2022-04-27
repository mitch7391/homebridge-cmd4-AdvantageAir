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
   rm -f "/tmp/AA-001/AirConServer.out"*
}

eraseAirConServerDataFile()
{
   rm -f "/tmp/AA-001/AirConServerData.json"*
}

beforeEach()
{
   rm -f "/tmp/AA-001/myAirData.txt"*
   rm -f "/tmp/AA-001/myAirConstants.txt"*
   if [ ! -d "/tmp/AA-001" ]; then mkdir "/tmp/AA-001"; fi
}

@test "StartServer Test /reInit" {
   beforeEach
   # Issue the reInit
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
}

@test "StartServer Test ?load" {
   beforeEach
   echo "Doing curl"
   run curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   echo "done StartServer testCASE"
}

@test "StartServer Test /getSystemData fails appropriately when nothing is loaded" {
   beforeEach
   # Issue the reInit
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # Get the systemData after the reInit
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "404 No File Loaded"
}

@test "StartServer Test ?failureCount fails appropriately" {
   beforeEach
   # run an old, now illegal command
   run curl -s -g "http://localhost:2025?failureCount=4"
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "SERVER: UNKNOWN query: failureCount"
   echo "done failureCount testCASE"
}

@test "StartServer Test /dumpstack, no entries" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
}

@test "StartServer Test /dumpstack, 1 entry, no repeat" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack with 1 entry no repeats
   run curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 0 filename: testData/basicPassingSystemData.txt"
}

@test "StartServer Test /dumpstack, 1 entry, repeat=5" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 5
   run curl -s -g "http://localhost:2025?repeat=5&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 5 filename: testData/basicPassingSystemData.txt"
}

@test "StartServer Test /dumpstack, 2 entry, repeat=3 & 5" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 3
   run curl -s -g "http://localhost:2025?repeat=3&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 3
   run curl -s -g "http://localhost:2025?repeat=5&load=testData/failedAirConRetrieveSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 2
   assert_equal "${lines[0]}" "repeat: 3 filename: testData/basicPassingSystemData.txt"
   assert_equal "${lines[1]}" "repeat: 5 filename: testData/failedAirConRetrieveSystemData.txt"
}

@test "StartServer Test /getSystemData, 1 entry, more requests than repeat, dumping stack" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 3
   run curl -s -g "http://localhost:2025?repeat=2&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # getSystemData 1
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r1=${#lines[@]}
   assert_equal "${#r1}" 3
   # getSystemData 2
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r2=${#lines[@]}
   assert_equal "$r1" "$r2"
   # getSystemData 3
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r3=${#lines[@]}
   assert_equal "$r1" "$r3"
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: -1 filename: testData/basicPassingSystemData.txt"
}

@test "StartServer Test /getSystemData, 2 entry repeat=1 & 2, more requests than repeat, dumping stack" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 1
   run curl -s -g "http://localhost:2025?repeat=1&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 2 Different data
   run curl -s -g "http://localhost:2025?repeat=2&load=testData/failedAirConRetrieveSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 2
   assert_equal "${lines[0]}" "repeat: 1 filename: testData/basicPassingSystemData.txt"
   assert_equal "${lines[1]}" "repeat: 2 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 1
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 368
   r1=${#lines[@]}
   assert_equal "${r1}" 368
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 2 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 2 (Should be new data )
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 237
   r2=${#lines[@]}
   assert_equal "${r2}" 237
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 1 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 3
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 237
   r3=${#lines[@]}
   assert_equal "${r3}" 237
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 0 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 4
   run curl -s -g "http://localhost:2025/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 237
   r4=${#lines[@]}
   assert_equal "$r3" "$r4"
   # dump the stack
   run curl -s -g "http://localhost:2025/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: -1 filename: testData/failedAirConRetrieveSystemData.txt"
}

@test "StartServer Test Load/Save data" {
   beforeEach
   eraseAirConServerDataFile
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 1
   run curl -s -g "http://localhost:2025?repeat=1&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # setAircon state = open
   run curl -s -g "http://localhost:2025?save"
   assert_equal "$status" 0
   # assert_equal "${#lines[@]}" 1
   # getSystemData - The size should still be the same
   # Save creates the /tmp/AA-001/AirConSererData.json file
   run diff testData/basicPassingSystemData.txt /tmp/AA-001/AirConServerData.json
   assert_equal "$status" 0
   #assert_equal "${#lines[@]}" 1
}

@test "StartServer Test Load/Set/Read new data" {
   beforeEach
   # clear the stack
   run curl -s -g "http://localhost:2025/reInit"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # load stack repeat of 1
   run curl -s -g "http://localhost:2025?repeat=1&load=testData/basicPassingSystemData.txt"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # AdvAir.sh TargetTemperature 9
   # ".aircons.$ac.info.setTemp"
   run curl -s -g "http://localhost:2025/setAircon?json={ac1:{info:{setTemp:9}}}"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   # getSystemData
   # Check the Temp change
   run curl -s -g "http://localhost:2025/getSystemData" -o /tmp/AA-001/out
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 0
   jqResult=$( jq -e ".aircons.ac1.info.setTemp" < /tmp/AA-001/out )
   echo "jqResult=$jqResult"
   assert_equal "$jqResult" "\"9\""
   # setAircon Temp = 22
   run curl -s -g "http://localhost:2025/setAircon?json={ac1:{info:{setTemp:22}}}"
   assert_equal "$status" 0
   # Check the Temp change
   run $( curl -s -g "http://localhost:2025/getSystemData" -o /tmp/AA-001/out )
   assert_equal "$status" 0
   jqResult=$( jq -e ".aircons.ac1.info.setTemp" < /tmp/AA-001/out )
   assert_equal "$jqResult" "\"22\""
}

@test "StartServer Test Load/Set/Read new data using AdvAir.sh" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:2025/reInit"
   # Do the load
   curl -s -g "http://localhost:2025?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Blah TargetHeatingCoolingState 1 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{state:on,mode:heat}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.info.state=\"on\""
   assert_equal "${lines[5]}" "Setting json: .aircons.ac1.info.mode=\"heat\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
   run ../AdvAir.sh Get Blah TargetHeatingCoolingState 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[6]}" "1"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7

   # ReDo using state: off
   run ../AdvAir.sh Set Blah TargetHeatingCoolingState 0 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   assert_equal "${lines[1]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{state:off}}}"
   assert_equal "${lines[2]}" "Try 0"
   assert_equal "${lines[3]}" "Setting json: .aircons.ac1.info.state=\"off\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
   run ../AdvAir.sh Get Blah TargetHeatingCoolingState 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[2]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3

}
