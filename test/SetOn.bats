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

# fanSpecified = true because no zone (z01) specified
@test "AdvAir Test Set On 1          -fanSpecified = true (default)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   run ../AdvAir.sh Set Blah On 1 127.0.0.1 TEST_ON
   assert_equal "$status" 0
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # No longer the same
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{state:on,mode:vent}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.info.state=\"on\""
   assert_equal "${lines[5]}" "Setting json: .aircons.ac1.info.mode=\"vent\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Set On 0 timer    -timerSpecified = true" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Fan On 0 timer 127.0.0.1 TEST_ON
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # AdvAir.sh Set both "countDownToOn" and "countDownToOff" to 0
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{countDownToOn:0}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.info.countDownToOn=0"
   assert_equal "${lines[5]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{countDownToOff:0}}}"
   assert_equal "${lines[6]}" "Try 0"
   assert_equal "${lines[7]}" "Setting json: .aircons.ac1.info.countDownToOff=0"
   # No more lines than expected
   assert_equal "${#lines[@]}" 8
}

@test "AdvAir Test Set On 0 fanTimer    -fanTimerSpecified = true" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Needs to create the fanTimer.txt       
   run ../AdvAir.sh Get Blab On fanTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blab On 0 fanTimer 127.0.0.1 TEST_ON
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file" 
   assert_equal "${lines[1]}" "Update the timer state file: ${TMPDIR}/AA-001/fanTimer.txt.ac1 with timeToOn: 0 and timeToOff: 0" 
   # No more lines than expected
   assert_equal "${#lines[@]}" 2
}

@test "AdvAir Test Set On 0 coolTimer    -coolTimerSpecified = true" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Needs to create the coolTimer.txt       
   run ../AdvAir.sh Get Blab On coolTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blab On 0 coolTimer 127.0.0.1 TEST_ON
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file" 
   assert_equal "${lines[1]}" "Update the timer state file: ${TMPDIR}/AA-001/coolTimer.txt.ac1 with timeToOn: 0 and timeToOff: 0" 
   # No more lines than expected
   assert_equal "${#lines[@]}" 2
}

@test "AdvAir Test Set On 0 heatTimer    -heatTimerSpecified = true" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # Needs to create the heatTimer.txt       
   run ../AdvAir.sh Get Blab On  heatTimer 127.0.0.1 TEST_ON
   run ../AdvAir.sh Set Blab On 0 heatTimer 127.0.0.1 TEST_ON
   assert_equal "$status" "0"
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file" 
   assert_equal "${lines[1]}" "Update the timer state file: ${TMPDIR}/AA-001/heatTimer.txt.ac1 with timeToOn: 0 and timeToOff: 0" 
   # No more lines than expected
   assert_equal "${#lines[@]}" 2
}

@test "AdvAir Test Set On 1 light:Study Patio" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Fan On 1 'light:Study Patio' 127.0.0.1 TEST_ON
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: light name: Study Patio ids=\"a70e005\""
   assert_equal "${lines[3]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"a70e005\",state:on}"
   assert_equal "${lines[4]}" "Try 0"
   assert_equal "${lines[5]}" "Setting json: .myLights.lights.\"a70e005\".state=\"on\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 6
}

@test "AdvAir Test Set On 1 light:Patio (multiple lights with \"Patio\" as part of their names)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Fan On 1 'light:Patio' 127.0.0.1 TEST_ON
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "path: light name: Patio ids=\"0100706\""
   assert_equal "${lines[3]}" "\"140e006\""
   assert_equal "${lines[4]}" "\"150e001\""
   assert_equal "${lines[5]}" "\"3a0e004\""
   assert_equal "${lines[6]}" "\"3d00804\""
   assert_equal "${lines[7]}" "\"4b0e001\""
   assert_equal "${lines[8]}" "\"a70e005\""
   assert_equal "${lines[9]}" "\"f70d004\""
   assert_equal "${lines[10]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"0100706\",state:on}"
   assert_equal "${lines[11]}" "Try 0"
   assert_equal "${lines[12]}" "Setting json: .myLights.lights.\"0100706\".state=\"on\""
   assert_equal "${lines[13]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"140e006\",state:on}"
   assert_equal "${lines[14]}" "Try 0"
   assert_equal "${lines[15]}" "Setting json: .myLights.lights.\"140e006\".state=\"on\""
   assert_equal "${lines[16]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"150e001\",state:on}"
   assert_equal "${lines[17]}" "Try 0"
   assert_equal "${lines[18]}" "Setting json: .myLights.lights.\"150e001\".state=\"on\""
   assert_equal "${lines[19]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"3a0e004\",state:on}"
   assert_equal "${lines[20]}" "Try 0"
   assert_equal "${lines[21]}" "Setting json: .myLights.lights.\"3a0e004\".state=\"on\""
   assert_equal "${lines[22]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"3d00804\",state:on}"
   assert_equal "${lines[23]}" "Try 0"
   assert_equal "${lines[24]}" "Setting json: .myLights.lights.\"3d00804\".state=\"on\""
   assert_equal "${lines[25]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"4b0e001\",state:on}"
   assert_equal "${lines[26]}" "Try 0"
   assert_equal "${lines[27]}" "Setting json: .myLights.lights.\"4b0e001\".state=\"on\""
   assert_equal "${lines[28]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"a70e005\",state:on}"
   assert_equal "${lines[29]}" "Try 0"
   assert_equal "${lines[30]}" "Setting json: .myLights.lights.\"a70e005\".state=\"on\""
   assert_equal "${lines[31]}" "Setting url: http://127.0.0.1:2025/setLight?json={id:\"f70d004\",state:on}"
   assert_equal "${lines[32]}" "Try 0"
   assert_equal "${lines[33]}" "Setting json: .myLights.lights.\"f70d004\".state=\"on\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 34
}

@test "AdvAir Test Set On 1 light:Theatre (an offline light)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myPlaceFull.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Blab On 1 'light:Theatre' 127.0.0.1 TEST_ON
   assert_equal "$status" "4"
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Parsing id for \"light:Theatre\" failed"
   # No more lines than expected
   assert_equal "${#lines[@]}" 3
}

@test "AdvAir Test Set On 1 z01 on ac2 (an offline aircon unit)" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/basicPassingSystemData.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Blab On 1 z01 127.0.0.1 ac2 TEST_ON
   assert_equal "$status" "1"
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath failed: .aircons.ac2.info"
   assert_equal "${lines[2]}" "Try 1"
   assert_equal "${lines[3]}" "Parsing for jqPath failed: .aircons.ac2.info"
   assert_equal "${lines[4]}" "Try 2"
   assert_equal "${lines[5]}" "Parsing for jqPath failed: .aircons.ac2.info"
   assert_equal "${lines[6]}" "Try 3"
   assert_equal "${lines[7]}" "Parsing for jqPath failed: .aircons.ac2.info"
   assert_equal "${lines[8]}" "Try 4"
   assert_equal "${lines[9]}" "Parsing for jqPath failed: .aircons.ac2.info"
   # No more lines than expected
   assert_equal "${#lines[@]}" 10
}

@test "AdvAir Test Set On 1 myZone=3 -set myZone=3" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load
   curl -s -g "http://localhost:$PORT?load=testData/myAirDataWith3noSensors.txt"
   # TimerEnabled requires On to be set to 0
   run ../AdvAir.sh Set Fan On 1 myZone=3 127.0.0.1 TEST_ON 
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
 
@test "AdvAir Test Set On 0 z01      -close z01 (cZone) while only having z01 and z07 open" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load - this myAirData has two zones open, z01 (a cZone) and z07 (myZone)
   curl -s -g "http://localhost:$PORT?load=testData/myAirDataWith3noSensors.txt"
   run ../AdvAir.sh Set Blab On 0 z01 127.0.0.1 TEST_ON 
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # Parse the required items need to be checked before closing a zone
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.myZone"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.noOfConstants"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.constant2"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info.constant3"
   # Create zoneOpen.txt
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z02.state"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z03.state"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.zones.z04.state"
   assert_equal "${lines[12]}" "Parsing for jqPath: .aircons.ac1.zones.z05.state"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.zones.z06.state"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z07.state"
   assert_equal "${lines[15]}" "Parsing for jqPath: .aircons.ac1.zones.z08.state"
   assert_equal "${lines[16]}" "Parsing for jqPath: .aircons.ac1.zones.z09.state"
   assert_equal "${lines[17]}" "Parsing for jqPath: .aircons.ac1.zones.z10.state"
   assert_equal "${lines[18]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   # No more lines than expected
   assert_equal "${#lines[@]}" 19
}
 
@test "AdvAir Test Set On 0 z07      -close z07 (myZone) case 1" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load - this myAirData has two zones open, z01 (a cZone) and z07 (myZone)
   curl -s -g "http://localhost:$PORT?load=testData/myAirDataWith3noSensors.txt"
   run ../AdvAir.sh Set Blab On 0 z07 127.0.0.1 TEST_ON 
   # AdvAir.sh does a get first
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   # Parse the required items need to be checked before closing a zone
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.myZone"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.noOfConstants"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.constant2"
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.info.constant3"
   # Create zoneOpen.txt
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z02.state"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z03.state"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.zones.z04.state"
   assert_equal "${lines[12]}" "Parsing for jqPath: .aircons.ac1.zones.z05.state"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.zones.z06.state"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z07.state"
   assert_equal "${lines[15]}" "Parsing for jqPath: .aircons.ac1.zones.z08.state"
   assert_equal "${lines[16]}" "Parsing for jqPath: .aircons.ac1.zones.z09.state"
   assert_equal "${lines[17]}" "Parsing for jqPath: .aircons.ac1.zones.z10.state"
   # Check which zone is closed and with temperature sensors
   assert_equal "${lines[18]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[19]}" "Parsing for jqPath: .aircons.ac1.zones.z08.state"
   assert_equal "${lines[20]}" "Parsing for jqPath: .aircons.ac1.zones.z08.rssi"
   assert_equal "${lines[21]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z08:{state:open}}}}"
   assert_equal "${lines[22]}" "Try 0"
   assert_equal "${lines[23]}" "Setting json: .aircons.ac1.zones.z08.state=\"open\""
   assert_equal "${lines[24]}" "Parsing for jqPath: .aircons.ac1.zones.z08.rssi"
   assert_equal "${lines[25]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[26]}" "Parsing for jqPath: .aircons.ac1.zones.z01.rssi"
   assert_equal "${lines[27]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{myZone:1}}}"
   assert_equal "${lines[28]}" "Try 0"
   assert_equal "${lines[29]}" "Setting json: .aircons.ac1.info.myZone=1"
   assert_equal "${lines[30]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z07:{state:close}}}}"
   assert_equal "${lines[31]}" "Try 0"
   assert_equal "${lines[32]}" "Setting json: .aircons.ac1.zones.z07.state=\"close\""
   # No more lines than ex8ected
   assert_equal "${#lines[@]}" 33
}
 
@test "AdvAir Test Set On 1 z05      -open  z05 (noSensor)      step 1 of 4" {
   beforeEach
   # Issue the reInit
   curl -s -g "http://localhost:$PORT/reInit"
   # Do the load - this myAirData has two zones open, z01 (a cZone) and z07 (myZone)
   curl -s -g "http://localhost:$PORT?load=testData/myAirDataWith3noSensors.txt"
   # simulation a case where no cZone is open but with z05 (noSensor) and z09 (with sensor) open
   run ../AdvAir.sh Set Blab On 1 z05 127.0.0.1 TEST_ON 
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Try 0"
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info"
   assert_equal "${lines[2]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z05:{state:open}}}}"
   assert_equal "${lines[3]}" "Try 0"
   assert_equal "${lines[4]}" "Setting json: .aircons.ac1.zones.z05.state=\"open\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 5
}

@test "AdvAir Test Set On 1 z09      -open  z09 (with Sensor)   step 2 of 4" {
   #
   run ../AdvAir.sh Set Blab On 1 z09 127.0.0.1 TEST_ON 
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   assert_equal "${lines[1]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z09:{state:open}}}}"
   assert_equal "${lines[2]}" "Try 0"
   assert_equal "${lines[3]}" "Setting json: .aircons.ac1.zones.z09.state=\"open\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 4
} 

@test "AdvAir Test Set On 0 z01      -close z01 (cZone)         step 3 of 4" {
   #
   run ../AdvAir.sh Set Blab On 0 z01 127.0.0.1 TEST_ON 
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   # Parse the required items need to be checked before closing a zone
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info.myZone"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfConstants"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.constant3"
   # Create zoneOpen.txt
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z02.state"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z03.state"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z04.state"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.zones.z05.state"
   assert_equal "${lines[12]}" "Parsing for jqPath: .aircons.ac1.zones.z06.state"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.zones.z07.state"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z08.state"
   assert_equal "${lines[15]}" "Parsing for jqPath: .aircons.ac1.zones.z09.state"
   assert_equal "${lines[16]}" "Parsing for jqPath: .aircons.ac1.zones.z10.state"
   #
   assert_equal "${lines[17]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z01:{state:close}}}}"
   assert_equal "${lines[18]}" "Try 0"
   assert_equal "${lines[19]}" "Setting json: .aircons.ac1.zones.z01.state=\"close\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 20
   # By now, there are 3 zones open: z05 (noSensor), z09 (with sensor) and z07 (myZone)
}

@test "AdvAir Test Set On 0 z07      -close z07 (myZone) case 2 step 4 of 4" {
   # By now, there are 3 zones open: z05 (noSensor), z09 (with sensor) and z07 (myZone)
   # Now close myZone
   run ../AdvAir.sh Set Blab On 0 z07 127.0.0.1 TEST_ON 
   assert_equal "$status" "0"
   # AdvAir.sh does a get first
   assert_equal "${lines[0]}" "Getting myAirData.txt from cached file"
   # Parse the required items need to be checked before closing a zone
   assert_equal "${lines[1]}" "Parsing for jqPath: .aircons.ac1.info.myZone"
   assert_equal "${lines[2]}" "Parsing for jqPath: .aircons.ac1.info.noOfZones"
   assert_equal "${lines[3]}" "Parsing for jqPath: .aircons.ac1.info.noOfConstants"
   assert_equal "${lines[4]}" "Parsing for jqPath: .aircons.ac1.info.constant1"
   assert_equal "${lines[5]}" "Parsing for jqPath: .aircons.ac1.info.constant2"
   assert_equal "${lines[6]}" "Parsing for jqPath: .aircons.ac1.info.constant3"
   # No need to create zoneOpen.txt
   # because it is within the 10s validity of the zoneOpen.txt
   #
   # Check which zone is opened and with temperature sensors, then assign myZone to it
   assert_equal "${lines[7]}" "Parsing for jqPath: .aircons.ac1.zones.z01.state"
   assert_equal "${lines[8]}" "Parsing for jqPath: .aircons.ac1.zones.z08.state"
   assert_equal "${lines[9]}" "Parsing for jqPath: .aircons.ac1.zones.z02.state"
   assert_equal "${lines[10]}" "Parsing for jqPath: .aircons.ac1.zones.z03.state"
   assert_equal "${lines[11]}" "Parsing for jqPath: .aircons.ac1.zones.z04.state"
   assert_equal "${lines[12]}" "Parsing for jqPath: .aircons.ac1.zones.z05.state"
   assert_equal "${lines[13]}" "Parsing for jqPath: .aircons.ac1.zones.z05.rssi"
   assert_equal "${lines[14]}" "Parsing for jqPath: .aircons.ac1.zones.z06.state"
   assert_equal "${lines[15]}" "Parsing for jqPath: .aircons.ac1.zones.z09.state"
   assert_equal "${lines[16]}" "Parsing for jqPath: .aircons.ac1.zones.z09.rssi"
   assert_equal "${lines[17]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{info:{myZone:9}}}"
   assert_equal "${lines[18]}" "Try 0"
   assert_equal "${lines[19]}" "Setting json: .aircons.ac1.info.myZone=9"
   # Finally z07 can now be closed
   assert_equal "${lines[20]}" "Setting url: http://127.0.0.1:2025/setAircon?json={ac1:{zones:{z07:{state:close}}}}"
   assert_equal "${lines[21]}" "Try 0"
   assert_equal "${lines[22]}" "Setting json: .aircons.ac1.zones.z07.state=\"close\""
   # No more lines than expected
   assert_equal "${#lines[@]}" 23
}
