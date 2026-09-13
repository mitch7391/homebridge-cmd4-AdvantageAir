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

bigSystem1()
{
  local curlRunTime=6

  # A big system can hold $lockFile for 1 second to more than 60 seconds, with an overall average of 6 seconds
  # CMD4 timeout is set at 60 seoncds {timeout: 60000}

  # bigSystem1 simulates a situation where $lockFile is detected,
  # with the $MY_AIRDATA_FILE > 120 seconds old but < 180 seconds old
  # and the earlier "curl" completed within 6 seconds

  t0=$(date '+%s')
  t1=$((t0 - curlRunTime + 6))
  t2=$((t0 - 122)) # $MY_AIRDTA_FILE = 122 seconds old

  echo "$t1" > "${TMPDIR}/AA-001/myAirData.txt.lock"
  echo "$t2" > "${TMPDIR}/AA-001/myAirData.txt.date" 
  cp "testData/basicPassingSystemData.txt" "${TMPDIR}/AA-001/myAirData.txt"

  sleep 6
  rm -f "${TMPDIR}/AA-001/myAirData.txt.lock"
}

bigSystem2()
{
  local curlRunTime=61

  # A big system can hold $lockFile for 1 second to more than 60 seconds, with an overall average of 6 seconds
  # CMD4 timeout is set at 60 seoncds {CMD4 timeout: 60000}

  # bigSystem2 simulates a situation where $lockFile is detected,
  # with the $MY_AIRDATA_FILE > 120 seconds old but < 180 seconds old
  # and the earlier "curl" has taken more than 60 seconds and CMD4 timed out

  t0=$(date '+%s')
  t1=$((t0 - curlRunTime ))
  t2=$((t0 - 122)) # $MY_AIRDTA_FILE = 122 seconds old

  echo "$t1" > "${TMPDIR}/AA-001/myAirData.txt.lock"
  echo "$t2" > "${TMPDIR}/AA-001/myAirData.txt.date" 
  cp "testData/basicPassingSystemData.txt" "${TMPDIR}/AA-001/myAirData.txt"
}

bigSystem3()
{
  local curlRunTime=61

  # A big system can hold $lockFile for 1 second to more than 60 seconds, with an overall average of 6 seconds
  # CMD4 timeout is set at 60 seoncds {timeout: 60000}

  # bigSystem3 simulates a situation where $lockFile is detected,
  # and $MY_AIRDATA_FILE > 180 seconds old 
  # and the earlier "curl" has taken more than 60 seconds and CMD4 timed out

  t0=$(date '+%s')
  t1=$((t0 - curlRunTime))
  t2=$((t0 - 185)) # $MY_AIRDTA_FILE > 180 seconds old

  echo "$t1" > "${TMPDIR}/AA-001/myAirData.txt.lock"
  echo "$t2" > "${TMPDIR}/AA-001/myAirData.txt.date" 
  cp "testData/basicPassingSystemData.txt" "${TMPDIR}/AA-001/myAirData.txt"
}

# test for the situation where the $lockFile is detected and erlier curl completed within 6 seconds
@test "AdvAir Test Big AirCon System 1 - \$MY_AIRDATA_FILE =122s old and \$lockFile detected and earlier getSystemData completed within 6 seconds " {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   bigSystem1 &
   run ../AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Fetching myAirData from cached file" 
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[5]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 6 
}

# test for the situation where the $lockFile is detected and earlier curl timed out
@test "AdvAir Test Big AirCon System 2 - \$MY_AIRDATA_FILE =122s old and \$lockFile detected and earlier getSystemData timed out" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   bigSystem2 &
   run ../AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   # earlier curl to getSystemData has timed out
   assert_equal "${lines[2]}" "Earlier \"curl\" to getSystemData has timed out" 
   # no more time to retry, copy whatever in the cached file
   assert_equal "${lines[3]}" "Fetching myAirData from cached file" 
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[6]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}

# test for the situation where myAirData.txt is >180s old and $lockfile is detected and earlier curl timed out, revover and retry)
@test "AdvAir Test Big AirCon System 3 - \$MY_AIRDATA_FILE >180s old and \$lockFile detected and earlier getSystemData timed out, recover and retry" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   bigSystem3 &
   run ../AdvAir.sh Get Fan On TEST_ON 127.0.0.1
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   # revover and retry
   assert_equal "${lines[2]}" "Try 1"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.state"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.mode"
   assert_equal "${lines[6]}" "0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 7
}
