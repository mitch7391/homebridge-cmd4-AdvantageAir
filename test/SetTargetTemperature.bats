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

@test "AdvAir Test Set TargetTemperature 23.5 (ac1 myZone=0)" {
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
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.myZone"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[8]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{setTemp:23.5}}}}"
   assert_equal "${lines[9]}" "Try 0"
   assert_equal "${lines[10]}" "Setting json: .aircons.ac1.zones.z01.setTemp=23.5"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.zones.z02.rssi"
   assert_equal "${lines[12]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z02:{setTemp:23.5}}}}"
   assert_equal "${lines[13]}" "Try 0"
   assert_equal "${lines[14]}" "Setting json: .aircons.ac1.zones.z02.setTemp=23.5"
   assert_equal "${lines[15]}" "Parsing for jqPath: .aircons.ac1.zones.z03.rssi"
   assert_equal "${lines[16]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z03:{setTemp:23.5}}}}"
   assert_equal "${lines[17]}" "Try 0"
   assert_equal "${lines[18]}" "Setting json: .aircons.ac1.zones.z03.setTemp=23.5"
   assert_equal "${lines[19]}" "Parsing for jqPath: .aircons.ac1.zones.z04.rssi"
   assert_equal "${lines[20]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z04:{setTemp:23.5}}}}"
   assert_equal "${lines[21]}" "Try 0"
   assert_equal "${lines[22]}" "Setting json: .aircons.ac1.zones.z04.setTemp=23.5"
   assert_equal "${lines[23]}" "Parsing for jqPath: .aircons.ac1.zones.z05.rssi"
   assert_equal "${lines[24]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z05:{setTemp:23.5}}}}"
   assert_equal "${lines[25]}" "Try 0"
   assert_equal "${lines[26]}" "Setting json: .aircons.ac1.zones.z05.setTemp=23.5"
   assert_equal "${lines[27]}" "Parsing for jqPath: .aircons.ac1.zones.z06.rssi"
   assert_equal "${lines[28]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z06:{setTemp:23.5}}}}"
   assert_equal "${lines[29]}" "Try 0"
   assert_equal "${lines[30]}" "Setting json: .aircons.ac1.zones.z06.setTemp=23.5"
   # No more lines than expected
   assert_equal "${#lines[@]}" 31
}

@test "AdvAir Test Set TargetTemperature 22 (ac2 myZone=7)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   run ../AdvAir.sh Set Blah TargetTemperature 22 127.0.0.1 ac2 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac2.info"
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac2:{info:{setTemp:22}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac2.info.setTemp=22"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac2.info.myZone"
   assert_equal "${lines[6]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac2:{zones:{z07:{setTemp:22}}}}"
   assert_equal "${lines[7]}" "Try 0"
   assert_equal "${lines[8]}" "Setting json: .aircons.ac2.zones.z07.setTemp=22"
   # No more lines than expected
   assert_equal "${#lines[@]}" 9
}
