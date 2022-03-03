# Understanding these test cases
#
# What we are trying to do is compare the execution of AirConServer.js with either
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
   assert_equal "${#lines[@]}" 1
   r1=${lines[0]}
   assert_equal "${#r1}" 5732
   # getSystemData 2
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   r2=${lines[0]}
   assert_equal "$r1" "$r2"
   # getSystemData 3
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   r3=${lines[0]}
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
   assert_equal "${#lines[@]}" 1
   r1=${lines[0]}
   assert_equal "${#r1}" 5732
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 2 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 2 (Should be new data )
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   r2=${lines[0]}
   assert_equal "${#r2}" 3867
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 1 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 3
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   r3=${lines[0]}
   assert_equal "${#r3}" 3867
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: 0 filename: testData/failedAirConRetrieveSystemData.txt"
   # getSystemData 4
   run curl -s -g "http://localhost:$PORT/getSystemData"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   r4=${lines[0]}
   assert_equal "$r3" "$r4"
   # dump the stack
   run curl -s -g "http://localhost:$PORT/dumpStack"
   assert_equal "$status" 0
   assert_equal "${#lines[@]}" 1
   assert_equal "${lines[0]}" "repeat: -1 filename: testData/failedAirConRetrieveSystemData.txt"
}
