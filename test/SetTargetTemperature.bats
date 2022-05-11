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
   rm -f "${TMPDIR}/AA-001/myAirData.txt"*
   rm -f "${TMPDIR}/AA-001/myAirConstants.txt"*
   if [ ! -d "${TMPDIR}/AA-001" ]; then mkdir "${TMPDIR}/AA-001"; fi
}

@test "AdvAir Test Set TargetTemperature 23.5" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # the first AdvAir.sh run is to create the myAirConstants.txt.ac1
   run ../AdvAir.sh Get Blah TargetTemperature 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blah TargetTemperature 23.5 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   assert_equal "${lines[1]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{setTemp:23.5}}}"
   assert_equal "${lines[2]}" "Try 0"
   assert_equal "${lines[3]}" "Setting json: .aircons.ac1.info.setTemp=23.5"
   assert_equal "${lines[4]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{setTemp:23.5}}}}"
   assert_equal "${lines[5]}" "Try 0"
   assert_equal "${lines[6]}" "Setting json: .aircons.ac1.zones.z01.setTemp=23.5"
   assert_equal "${lines[7]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z02:{setTemp:23.5}}}}"
   assert_equal "${lines[8]}" "Try 0"
   assert_equal "${lines[9]}" "Setting json: .aircons.ac1.zones.z02.setTemp=23.5"
   assert_equal "${lines[10]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z03:{setTemp:23.5}}}}"
   assert_equal "${lines[11]}" "Try 0"
   assert_equal "${lines[12]}" "Setting json: .aircons.ac1.zones.z03.setTemp=23.5"
   assert_equal "${lines[13]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z04:{setTemp:23.5}}}}"
   assert_equal "${lines[14]}" "Try 0"
   assert_equal "${lines[15]}" "Setting json: .aircons.ac1.zones.z04.setTemp=23.5"
   assert_equal "${lines[16]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z05:{setTemp:23.5}}}}"
   assert_equal "${lines[17]}" "Try 0"
   assert_equal "${lines[18]}" "Setting json: .aircons.ac1.zones.z05.setTemp=23.5"
   assert_equal "${lines[19]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z06:{setTemp:23.5}}}}"
   assert_equal "${lines[20]}" "Try 0"
   assert_equal "${lines[21]}" "Setting json: .aircons.ac1.zones.z06.setTemp=23.5"
   # No more lines than expected
   assert_equal "${#lines[@]}" 22
}
