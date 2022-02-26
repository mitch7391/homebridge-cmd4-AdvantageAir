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
   echo "in GetStatusLowBatter before startServer $(pwd)" >> /tmp/AirConServer.out
   before
   stopServer
   assert_equal "$rc" 0
   startServer
   assert_equal "$rc" 0
   echo "in GetStatusLowBatter after startServer" >> /tmp/AirConServer.out
}

@test "AdvAir ( zones inline ) Test PassOn5 Get StatusLowBattery z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn5 ./data
   # Bats "run" gobbles up all the stdout. Remove for debugging
   run ./compare/zones.txt Get Blah StatusLowBattery z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   # No fault found
   assert_equal "${lines[5]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   curl -s -g 'http://localhost:2025?load=testData/dataPassOn5/getSystemData.txt4' >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?debug=1' >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?loadFail=testData/dataPassOn5/getSystemData.txt0' >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?failureCount=5' >> /tmp/AirConServer.out
   run ./compare/AdvAir.sh Get Blah StatusLowBattery z01 127.0.0.1 TEST_ON
   assert_equal "$status" "$e_status" ]
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[1]}"
   assert_equal "${lines[2]}" "${e_lines[2]}"
   assert_equal "${lines[3]}" "${e_lines[3]}"
   assert_equal "${lines[4]}" "${e_lines[4]}"
   assert_equal "${lines[5]}" "${e_lines[5]}"

}

@test "AdvAir ( zones inline ) Test PassOn1 Get StatusLowBattery z01" {
   # We symbolically link the directory of the test we want to use.
   ln -s ./testData/dataPassOn1 ./data
   run ./compare/zones.txt Get Blah StatusLowBattery z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   curl -s -g 'http://localhost:2025?load=testData/dataPassOn1/getSystemData.txt0' >> /tmp/AirConServer.out
   run ./compare/AdvAir.sh Get Blah StatusLowBattery z01 127.0.0.1 TEST_ON
   assert_equal "$status" "$e_status" ]
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[1]}"
}

@test "AdvAir ( zones inline ) Test PassOn3 Get StatusLowBattery z01" {
   ln -s ./testData/dataPassOn3 ./data
   run ./compare/zones.txt Get Blah StatusLowBattery z01 TEST_ON
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "0"
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   curl -s -g 'http://localhost:2025?load=testData/dataPassOn1/getSystemData.txt0' >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?loadFail=testData/dataPassOn5/getSystemData.txt0' >> /tmp/AirConServer.out
   curl -s -g 'http://localhost:2025?failureCount=3' >> /tmp/AirConServer.out
   run ./compare/AdvAir.sh Get Blah StatusLowBattery z01 127.0.0.1 TEST_ON
   assert_equal "$status" "$e_status" ]
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[1]}"
   assert_equal "${lines[2]}" "${e_lines[2]}"
   assert_equal "${lines[3]}" "${e_lines[3]}"
}

@test "AdvAir ( zones inline ) Test FailOn5 Get StatusLowBattery z01" {
   ln -s ./testData/dataFailOn5 ./data
   run ./compare/zones.txt Get Blah StatusLowBattery z01 TEST_ON
   assert_equal "$status" 1
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Try 1"
   assert_equal "${lines[2]}" "Try 2"
   assert_equal "${lines[3]}" "Try 3"
   assert_equal "${lines[4]}" "Try 4"
   assert_equal "${lines[5]}" ""
   e_status=$status
   e_lines=("${lines[@]}")
   beforeEach
   curl -s -g 'http://localhost:2025?load=testData/dataFailOn5/getSystemData.txt0' >> /tmp/AirConServer.out
   run ./compare/AdvAir.sh Get Blah StatusLowBattery z01 127.0.0.1 TEST_ON
   assert_equal "$status" "$e_status" ]
   assert_equal "${lines[0]}" "${e_lines[0]}"
   assert_equal "${lines[1]}" "${e_lines[1]}"
   assert_equal "${lines[2]}" "${e_lines[2]}"
   assert_equal "${lines[3]}" "${e_lines[3]}"
   assert_equal "${lines[4]}" "${e_lines[4]}"
   assert_equal "${lines[5]}" "${e_lines[5]}"
}

@test "AdvAir ( StopServer )" {
   stopServer
}
