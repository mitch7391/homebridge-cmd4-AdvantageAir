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

load 'test/startServer'
load 'test/stopServer'

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
}

@test "AdvAir ( StartServer )" {
   echo "in StartServer.bats before startServer $(pwd)" >> /tmp/AirConServer.out
   before
   stopServer
   assert_equal "$rc" 0
   echo "StartServer After stopServer" >> /tmp/AirConServer.out
   startServer
   assert_equal "$rc" 0
   echo "StartServer Before setting debug=1" >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?debug=1' >> /tmp/AirConServer.out
   assert_equal "$rc" 0
   echo "StartServer After setting debug=1" >> /tmp/AirConServer.out
   echo "StartServer After startServer" >> /tmp/AirConServer.out
}

@test "StartServer Test ?load" {
   beforeEach
   echo "Doing curl" >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?load=testData/dataPassOn1/getSystemData.txt0' >> /tmp/AirConServer.out
   rc=$?
   assert_equal "$rc" 0
   echo "done StartServer testCASE" >> /tmp/AirConServer.out
}

@test "StartServer Test /getSystemData" {
   beforeEach
   echo "Doing curl" >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025/getSystemData' >> /tmp/AirConServer.out
   rc=$?
   assert_equal "$rc" 0
   echo "done StartServer testCASE" >> /tmp/AirConServer.out
}

@test "StartServer Test ?failureCount" {
   beforeEach
   echo "Doing curl" >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?failureCount=4' >> /tmp/AirConServer.out
   rc=$?
   assert_equal "$rc" 0
   echo "done StartServer testCASE" >> /tmp/AirConServer.out
}

@test "StartServer Test ?loadFailure" {
   beforeEach
   echo "Doing curl" >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?loadFailure=testData/dataPassOn1/getSystemData.txt0' >> /tmp/AirConServer.out
   rc=$?
   assert_equal "$rc" 0
   echo "done StartServer testCASE" >> /tmp/AirConServer.out
}

@test "AdvAir ( StopServer )" {
   stopServer
   rc=$?
   assert_equal "$rc" 0
}
