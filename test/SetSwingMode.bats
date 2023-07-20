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

@test "AdvAir Test Set SwingMode 1 z03 -set myZone=3" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myAirDataWith3noSensors.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Fan SwingMode 1 z03 127.0.0.1 TEST_ON 
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.zones.z03.state"
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z03:{state:open}}}}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .aircons.ac1.zones.z03.state=\"open\""
   assert_equal "${lines[6]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{myZone:3}}}"
   assert_equal "${lines[7]}" "Try 0"
   assert_equal "${lines[8]}" "Setting json: .aircons.ac1.info.myZone=3"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z03.setTemp"
   assert_equal "${lines[10]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{setTemp:24}}}"
   assert_equal "${lines[11]}" "Try 0"
   assert_equal "${lines[12]}" "Setting json: .aircons.ac1.info.setTemp=24"
   # No more lines than expected
   assert_equal "${#lines[@]}" 13
}
