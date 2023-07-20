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

# ezone
@test "AdvAir Test Set Active 0 z01 - close z01" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Fan Active 0 TEST_ON 127.0.0.1 z01
   assert_equal "$status" 0
   assert_equal "${lines[0]}" "Using IP: 127.0.0.1"
   assert_equal "${lines[1]}" "Try 0"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.myZone"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.noOfConstants"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info.constant2"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.info.constant3"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z02.state"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.zones.z03.state"
   assert_equal "${lines[12]}" "Parsing for jqPath: .aircons.ac1.zones.z04.state"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.zones.z05.state"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z06.state"
   assert_equal "${lines[15]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{state:close}}}}"
   assert_equal "${lines[16]}" "Try 0"
   assert_equal "${lines[17]}" "Setting json: .aircons.ac1.zones.z01.state=\"close\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 18
}
