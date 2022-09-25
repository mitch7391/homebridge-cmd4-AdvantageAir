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

@test "AdvAir Test Set TargetTemperature 23.5" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Blah TargetTemperature 23.5 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{setTemp:23.5}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.info.setTemp=23.5"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[7]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{setTemp:23.5}}}}"
   assert_equal "${lines[8]}" "Try 0"
   assert_equal "${lines[9]}" "Setting json: .aircons.ac1.zones.z01.setTemp=23.5"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z02.rssi"
   assert_equal "${lines[11]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z02:{setTemp:23.5}}}}"
   assert_equal "${lines[12]}" "Try 0"
   assert_equal "${lines[13]}" "Setting json: .aircons.ac1.zones.z02.setTemp=23.5"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z03.rssi"
   assert_equal "${lines[15]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z03:{setTemp:23.5}}}}"
   assert_equal "${lines[16]}" "Try 0"
   assert_equal "${lines[17]}" "Setting json: .aircons.ac1.zones.z03.setTemp=23.5"
   assert_equal "${lines[18]}" "Parsing for jqPath: .aircons.ac1.zones.z04.rssi"
   assert_equal "${lines[19]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z04:{setTemp:23.5}}}}"
   assert_equal "${lines[20]}" "Try 0"
   assert_equal "${lines[21]}" "Setting json: .aircons.ac1.zones.z04.setTemp=23.5"
   assert_equal "${lines[22]}" "Parsing for jqPath: .aircons.ac1.zones.z05.rssi"
   assert_equal "${lines[23]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z05:{setTemp:23.5}}}}"
   assert_equal "${lines[24]}" "Try 0"
   assert_equal "${lines[25]}" "Setting json: .aircons.ac1.zones.z05.setTemp=23.5"
   assert_equal "${lines[26]}" "Parsing for jqPath: .aircons.ac1.zones.z06.rssi"
   assert_equal "${lines[27]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z06:{setTemp:23.5}}}}"
   assert_equal "${lines[28]}" "Try 0"
   assert_equal "${lines[29]}" "Setting json: .aircons.ac1.zones.z06.setTemp=23.5"
   # No more lines than expected
   assert_equal "${#lines[@]}" 30
}
